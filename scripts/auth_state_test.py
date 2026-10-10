"""Synthetic state safety checks; never open the actual application state."""
import importlib.util
import json
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import unittest
from urllib.request import Request, urlopen

spec = importlib.util.spec_from_file_location('local_auth', Path(__file__).with_name('local_auth.py'))
local_auth = importlib.util.module_from_spec(spec)
spec.loader.exec_module(local_auth)


class StateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='ca-state-test-')
        self.parent = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def test_secret_survives_reopen_and_concurrent_start_is_denied(self):
        run, secret, lock = local_auth.persistent_state(self.parent)
        self.assertEqual((run.stat().st_mode & 0o777), 0o700)
        self.assertEqual(((run / 'auth-secret').stat().st_mode & 0o777), 0o600)
        self.assertEqual(len(secret), 64)
        with self.assertRaises(BlockingIOError):
            local_auth.persistent_state(self.parent)
        lock.close()
        resumed, reused_secret, resumed_lock = local_auth.persistent_state(self.parent)
        try:
            self.assertEqual(resumed, run)
            self.assertTrue(reused_secret == secret)
        finally:
            resumed_lock.close()

    def test_unmarked_data_is_never_adopted(self):
        run = self.parent / 'persistent-synthetic'
        run.mkdir(mode=0o700)
        (run / 'data').mkdir()
        with self.assertRaisesRegex(RuntimeError, 'Unmarked'):
            local_auth.persistent_state(self.parent)
        self.assertFalse((run / 'auth-secret').exists())

    def test_private_profile_is_separate_and_wrong_marker_blocks_reuse(self):
        # All state here is generated inside this disposable fixture, never owner data.
        synthetic, _, synthetic_lock = local_auth.persistent_state(self.parent)
        private, _, private_lock = local_auth.persistent_state(
            self.parent, 'persistent-private-mail', 'community-access-private-mail-v1\n')
        try:
            self.assertNotEqual(synthetic, private)
        finally:
            synthetic_lock.close()
            private_lock.close()
        with self.assertRaisesRegex(RuntimeError, 'marker mismatch'):
            local_auth.persistent_state(self.parent, 'persistent-private-mail')

    def test_symlink_directory_and_file_are_denied(self):
        target = self.parent / 'other'
        target.mkdir(mode=0o700)
        (self.parent / 'persistent-synthetic').symlink_to(target)
        with self.assertRaises(RuntimeError):
            local_auth.persistent_state(self.parent)
        (self.parent / 'persistent-synthetic').unlink()
        run, _, lock = local_auth.persistent_state(self.parent)
        lock.close()
        # Only generated synthetic files inside this disposable test directory.
        (run / 'auth-secret').rename(run / 'saved-test-secret')
        (run / 'auth-secret').symlink_to(run / 'saved-test-secret')
        with self.assertRaises(OSError):
            local_auth.persistent_state(self.parent)

    def test_open_permissions_and_missing_secret_do_not_trigger_replacement(self):
        run, _, lock = local_auth.persistent_state(self.parent)
        lock.close()
        (run / 'auth-secret').chmod(0o644)
        with self.assertRaises(RuntimeError):
            local_auth.persistent_state(self.parent)
        (run / 'auth-secret').unlink()
        with self.assertRaises(FileNotFoundError):
            local_auth.persistent_state(self.parent)
        self.assertFalse((run / 'auth-secret').exists())


class ControllerRestartTest(unittest.TestCase):
    def test_full_controller_reopens_its_own_synthetic_cluster(self):
        source = Path(__file__).resolve().parent.parent
        with tempfile.TemporaryDirectory(prefix='ca-controller-test-') as directory:
            fixture = Path(directory)
            shim = fixture / 'run_fixture.py'
            shim.write_text(
                'import importlib.util\nfrom pathlib import Path\n'
                f'spec = importlib.util.spec_from_file_location("auth_fixture", {str(source / "scripts/local_auth.py")!r})\n'
                'module = importlib.util.module_from_spec(spec)\nspec.loader.exec_module(module)\n'
                'module.ROOT = Path(__file__).resolve().parent\nraise SystemExit(module.main())\n')
            (fixture / 'server').mkdir()
            # Only the fixture listener uses a free port; the application listener is unchanged.
            (fixture / 'server/start.mjs').write_text(
                f'import {{ createAuth }} from {json.dumps((source / "server/auth.mjs").as_uri())};\n'
                f'import {{ createApp }} from {json.dumps((source / "server/http.mjs").as_uri())};\n'
                'import { writeFileSync } from "node:fs";\n'
                'const state = await createAuth();\nconst server = createApp(state);\n'
                'server.listen(0, "127.0.0.1", () => writeFileSync("ready-port", String(server.address().port), {mode: 0o600}));\n'
                'for (const signal of ["SIGINT", "SIGTERM"]) process.once(signal, async () => {\n'
                'await new Promise(resolve => server.close(resolve)); await state.pool.end(); });\n')
            child = None

            def stop():
                nonlocal child
                if child is not None:
                    child.send_signal(signal.SIGTERM)
                    try:
                        self.assertEqual(child.wait(timeout=20), 0)
                    finally:
                        if child.poll() is None:
                            child.kill()
                            child.wait(timeout=5)
                        child = None

            def start():
                nonlocal child
                ready = fixture / 'ready-port'
                if ready.exists():
                    ready.unlink()
                child = subprocess.Popen(['/usr/bin/python3', '-I', str(shim)], cwd=fixture,
                    env={'PATH': '/opt/homebrew/bin:/usr/bin:/bin'},
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                deadline = time.monotonic() + 20
                while not ready.exists() and child.poll() is None and time.monotonic() < deadline:
                    time.sleep(0.05)
                self.assertTrue(ready.exists(), 'Synthetic controller did not start')
                return 'http://127.0.0.1:' + ready.read_text()

            def call(base, path, body=None, token=None):
                headers = {'Host': '127.0.0.1:8000', 'Origin': 'http://127.0.0.1:8300',
                           'Content-Type': 'application/json'}
                if token:
                    headers['Authorization'] = 'Bearer ' + token
                request = Request(base + path, headers=headers,
                    data=None if body is None else json.dumps(body).encode())
                with urlopen(request, timeout=5) as response:
                    return json.loads(response.read()), response.headers.get('set-auth-token')

            try:
                base = start()
                _, token = call(base, '/api/auth/sign-up/email', {
                    'name': 'Controller fixture', 'email': 'controller@example.invalid',
                    'password': 'Synthetic-Controller-2026!'})
                self.assertTrue(bool(token))
                stop()
                base = start()
                snapshot, _ = call(base, '/api/account/me', token=token)
                self.assertEqual(snapshot['user']['email'], 'controller@example.invalid')
                self.assertFalse(snapshot['product_available'])
                _, new_token = call(base, '/api/auth/sign-in/email', {
                    'email': 'controller@example.invalid', 'password': 'Synthetic-Controller-2026!'})
                self.assertTrue(bool(new_token))
                stop()
                self.assertFalse((fixture / '.local/better-auth/persistent-synthetic/data/postmaster.pid').exists())
            finally:
                stop()



if __name__ == '__main__':
    unittest.main()

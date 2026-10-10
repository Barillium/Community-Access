"""Tunnel owner helper checks using only isolated synthetic files."""
import contextlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location('tunnel_fixture', ROOT / 'scripts/configure_https_tunnel.py')
setup = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(setup)


class TunnelSetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='ca-tunnel-fixture-', dir='/private/tmp')
        self.addCleanup(self.temp.cleanup)
        setup.PRIVATE = Path(self.temp.name) / 'private'
        setup.TOKEN = setup.PRIVATE / 'cloudflare-tunnel.token'

    def configure(self, token):
        output = io.StringIO()
        with patch('sys.argv', ['configure_https_tunnel.py']), \
                patch('sys.stdin.isatty', return_value=True), \
                patch('getpass.getpass', return_value=token), contextlib.redirect_stdout(output):
            self.assertEqual(setup.main(), 0)
        return output.getvalue()

    def test_private_storage_and_no_token_output(self):
        token = 'synthetic-tunnel-fixture-' * 3
        output = self.configure(token)
        self.assertNotIn(token, output)
        self.assertEqual(setup.TOKEN.read_text().strip(), token)
        self.assertEqual(setup.TOKEN.stat().st_mode & 0o777, 0o600)
        self.assertEqual(setup.PRIVATE.stat().st_mode & 0o777, 0o700)

    def test_invalid_input_does_not_replace_existing_token(self):
        self.configure('synthetic-tunnel-fixture-' * 3)
        previous = setup.TOKEN.read_text()
        with self.assertRaises(ValueError):
            self.configure('cloudflared tunnel run --token synthetic-value')
        self.assertEqual(setup.TOKEN.read_text(), previous)

    def test_noninteractive_and_unsafe_files_are_rejected_without_start(self):
        with patch('sys.argv', ['configure_https_tunnel.py']), patch('sys.stdin.isatty', return_value=False):
            with self.assertRaises(ValueError):
                setup.main()
        self.configure('synthetic-tunnel-fixture-' * 3)
        setup.TOKEN.chmod(0o644)
        with patch('sys.argv', ['configure_https_tunnel.py', '--run']), \
                patch('sys.stdin.isatty', return_value=True), patch('subprocess.call') as run:
            with self.assertRaises(ValueError):
                setup.main()
            run.assert_not_called()

    def test_token_file_argument_and_sanitized_environment(self):
        self.configure('synthetic-tunnel-fixture-' * 3)
        response = io.BytesIO(b'{"providers":["google"]}')
        with patch('sys.argv', ['configure_https_tunnel.py', '--run']), \
                patch('sys.stdin.isatty', return_value=True), \
                patch('urllib.request.urlopen', return_value=response), \
                patch('subprocess.call', return_value=0) as run, \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(setup.main(), 0)
        args, kwargs = run.call_args
        self.assertIn('--token-file', args[0])
        self.assertNotIn('--token', args[0])
        self.assertNotIn('synthetic-tunnel-fixture-' * 3, str(args))
        self.assertEqual(set(kwargs['env']), {'PATH','HOME','LC_ALL'})


if __name__ == '__main__':
    unittest.main()

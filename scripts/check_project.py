"""Check the current local learning project; no installation or live Codex call."""
import argparse
import importlib.util
from pathlib import Path
import tempfile
import subprocess
import sys
import time
import unittest

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('runner', ROOT / 'scripts/task_runner.py')
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scope', choices=['current', 'app', 'core', 'product'], default='current')
    parser.add_argument('--include-reviewed', nargs='*', default=[])
    args = parser.parse_args()
    if args.scope == 'product':
        print('BLOCKED: full product coverage incomplete: invitations, onboarding, retention, revocation and Flutter integration.')
        return 2
    # Review new files and stage their explicit paths before this check. Ignored files
    # and real credentials are never collected. Use working contents, not index bytes.
    names = r.git('ls-files', '-z').decode().split('\0')
    files = {}
    for name in dict.fromkeys([*filter(None, names), *args.include_reviewed]):
        r.source_path(name)
        p = ROOT / name
        r.require(p.is_file() and not p.is_symlink(), 'Missing or symlink source')
        r.require(p.stat().st_size <= r.MAX_BYTES, 'Oversized source')
        files[name] = p.read_bytes()
    with tempfile.TemporaryDirectory(prefix='community-check-') as d:
        parent = Path(d).resolve()
        work = parent / 'candidate'
        r.export(files, work)
        canary = parent / 'canary'
        canary.write_text('synthetic\n')
        deadline = time.monotonic() + 240
        r.probe(work, parent / 'probe', canary, deadline)
        checks = r.gates(work, files, {'scope': 'app-ui' if args.scope in {'app', 'core'} else 'docs', 'allowed_files': [], 'acceptance': []},
                         parent / 'checks', deadline, r.RUNTIME)
        for check in checks:
            print(check['check'] + ': ' + check['status'], flush=True)
            if check['status'] != 'passed':
                print(check['detail'])
        if any(c['status'] != 'passed' for c in checks):
            return 1
    if args.scope == 'core':
        r.require('scripts/check_supabase.py' in files and
                  files['scripts/check_supabase.py'] == (ROOT/'scripts/check_supabase.py').read_bytes(),
                  'Reviewed backend controller missing or changed')
        with r.single_run(r.state_dir()):
            backend = subprocess.run([sys.executable, '-I',
                str(ROOT/'scripts/check_supabase.py')], cwd=ROOT, timeout=180)
            r.require(backend.returncode == 0, 'Backend Auth/API checks failed or unavailable')
            env = {'PATH': '/opt/homebrew/bin:/usr/bin:/bin', 'HOME': str(Path.home()),
                   'DOCKER_HOST': 'unix://' + str(Path.home()/'.colima/community-access-test/docker.sock')}
            lint = subprocess.run(['supabase', 'db', 'lint', '--local', '--schema',
                'public,access_private', '--fail-on', 'warning'], cwd=ROOT, env=env, timeout=60,
                capture_output=True, text=True)
            r.require(lint.returncode == 0, 'Local backend SQL analysis failed or unavailable')
            print('backend-sql-analysis: passed', flush=True)
    suite = unittest.defaultTestLoader.discover(str(ROOT / 'scripts/runner_tests'))
    r.require(suite.countTestCases() > 0, 'Required runner tests missing')
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if result.skipped:
        print('BLOCKED: skipped required runner tests')
        return 2
    if not result.wasSuccessful():
        return 1
    r.git('diff', '--check')
    r.git('diff', '--cached', '--check')
    print('PASS: checked scope ' + args.scope + '; not a complete product acceptance.')
    print('NOT RUN: full product flows, Flutter backend integration, live Codex, other platforms.')
    if args.scope == 'current':
        print('NOT RUN: app and backend suites (use --scope app or core).')
    elif args.scope == 'app':
        print('NOT RUN: backend suite (use --scope core with local Supabase already running).')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (r.Blocked, OSError, ValueError, subprocess.SubprocessError) as exc:
        print('BLOCKED: ' + str(exc))
        raise SystemExit(2)

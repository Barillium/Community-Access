"""Check the current local learning project; no installation or live Codex call."""
import argparse
import importlib.util
from pathlib import Path
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('runner', ROOT / 'scripts/task_runner.py')
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scope', choices=['current', 'product'], default='current')
    args = parser.parse_args()
    if args.scope == 'product':
        print('BLOCKED: app, database and actual-user-role suites are not implemented.')
        return 2
    # Review new files and stage their explicit paths before this check. Ignored files
    # and real credentials are never collected. Use working contents, not index bytes.
    names = r.git('ls-files', '-z').decode().split('\0')
    files = {}
    for name in filter(None, names):
        if name in {'.gitignore', 'scripts/.gitkeep'}:
            pass
        else:
            r.safe_path(name)
            r.require(Path(name).suffix in {'.md', '.dart', '.py', '.json', '.yaml', '.lock'},
                      'Unreviewed source type: ' + name)
            r.require(not any(x in {'private', 'personal', 'secrets', 'dumps', 'backups', 'exports'}
                              for x in Path(name).parts), 'Sensitive source path')
        r.require(Path(name).name not in {'auth.json', 'credentials.json', 'config.json'}
                  and not Path(name).name.startswith('service-account'), 'Credential/config source')
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
        deadline = time.monotonic() + 120
        r.probe(work, parent / 'probe', canary, deadline)
        checks = r.gates(work, files, {'allowed_files': [], 'acceptance': []},
                         parent / 'checks', deadline, r.RUNTIME)
        for check in checks:
            print(check['check'] + ': ' + check['status'], flush=True)
            if check['status'] != 'passed':
                print(check['detail'])
        if any(c['status'] != 'passed' for c in checks):
            return 1
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
    print('PASS: current documentation, Dart exercise and runner only.')
    print('NOT RUN: Flutter app, database, actual user roles, live Codex, other platforms.')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (r.Blocked, OSError, ValueError) as exc:
        print('BLOCKED: ' + str(exc))
        raise SystemExit(2)

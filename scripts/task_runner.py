#!/usr/bin/env python3
"""One manually approved task. Standard library only; macOS Seatbelt required."""
import argparse
import contextlib
import difflib
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import resource
import signal
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = 'scripts/task_runner.py'
MAX_BYTES = 256_000
MAX_OUTPUT = 1_000_000
CODEX_STATE_FILE_LIMIT = 16 * 1024 * 1024
SCOPES = {'docs', 'dart-learning'}
PROTECTED_TEST = 'exercises/dart_basics/test/application_status_test.dart'
RUNTIME = Path('/Users/stanynyssen/develop/flutter/bin/cache/dart-sdk')
CODEX = Path('/Applications/ChatGPT.app/Contents/Resources/codex')


class Blocked(Exception):
    pass


def canonical(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(',', ':'))


def digest(value):
    return hashlib.sha256(canonical(value).encode()).hexdigest()


def require(condition, reason):
    if not condition:
        raise Blocked(reason)


def safe_path(name):
    require(isinstance(name, str) and 0 < len(name) < 200, 'Invalid path')
    p = PurePosixPath(name)
    require(not p.is_absolute() and str(p) == name and '..' not in p.parts,
            'Path traversal or noncanonical path')
    require(not any(part.startswith('.') for part in p.parts), 'Hidden path')
    require(re.fullmatch(r'[A-Za-z0-9_./-]+', name) is not None, 'Unsafe path characters')
    return name


def validate_task(task):
    require(isinstance(task, dict), 'Task must be an object')
    require(set(task) == {'id', 'title', 'instructions', 'scope', 'risk',
                          'synthetic_data_only', 'allowed_files', 'acceptance'},
            'Unexpected or missing task fields')
    require(isinstance(task['id'], str) and re.fullmatch(r'[a-z][a-z0-9-]{2,50}', task['id']) is not None, 'Invalid id')
    require(task['risk'] == 'low' and task['synthetic_data_only'] is True,
            'Only human-classified low-risk synthetic tasks supported')
    require(isinstance(task['scope'], str) and task['scope'] in SCOPES, 'App/database/roles or other scope not implemented')
    for key in ('title', 'instructions'):
        require(isinstance(task[key], str) and 0 < len(task[key]) <= 8000, 'Invalid task text')
    paths = task['allowed_files']
    require(isinstance(paths, list) and 0 < len(paths) <= 5 and all(isinstance(p, str) for p in paths) and len(set(paths)) == len(paths),
            'One to five unique files required')
    for name in paths:
        safe_path(name)
        docs = name == 'README.md' or (name.startswith('docs/learning/') and name.endswith('.md'))
        dart = (name.startswith('exercises/dart_basics/lib/') or
                name.startswith('exercises/dart_basics/bin/')) and name.endswith('.dart')
        require(docs or (task['scope'] == 'dart-learning' and dart), 'Protected or unsupported file')
    require(isinstance(task['acceptance'], list) and 0 < len(task['acceptance']) <= 20,
            'Explicit acceptance checks required')
    for rule in task['acceptance']:
        require(isinstance(rule, dict) and set(rule) == {'path', 'contains'}, 'Only literal contains checks supported')
        require(rule['path'] in paths and isinstance(rule['contains'], str)
                and 0 < len(rule['contains']) <= 2000, 'Invalid acceptance rule')
    require({r['path'] for r in task['acceptance']} == set(paths), 'Each target needs acceptance')
    return task


def git(*args, root=ROOT):
    # No shell, hooks or global config; no host credentials are needed for local Git.
    env = {'PATH': '/usr/bin:/bin', 'LC_ALL': 'C', 'GIT_CONFIG_NOSYSTEM': '1',
           'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_TERMINAL_PROMPT': '0'}
    result = subprocess.run(['/usr/bin/git', '-c', 'core.hooksPath=/dev/null', *args],
                            cwd=root, env=env, capture_output=True, timeout=15)
    require(result.returncode == 0, 'Local Git operation failed: ' + args[0])
    return result.stdout


def clean_repo():
    require(not git('status', '--porcelain'), 'Uncommitted changes: refusing to start')


def committed_files(commit):
    require(re.fullmatch('[0-9a-f]{40}', commit) is not None, 'Full commit SHA required')
    files = {}
    entries = git('ls-tree', '-rz', '--full-tree', commit).split(b'\0')
    total = 0
    for entry in filter(None, entries):
        meta, raw_name = entry.split(b'\t', 1)
        mode, kind, oid = meta.split()
        name = raw_name.decode('utf-8')
        require(mode == b'100644' and kind == b'blob', 'Only regular non-executable source files supported')
        require(name in {'.gitignore', 'scripts/.gitkeep'} or
                (not any(x.startswith('.') for x in PurePosixPath(name).parts) and
                 Path(name).suffix in {'.md', '.dart', '.py', '.json', '.yaml', '.lock'}),
                'Unreviewed file type/path in baseline')
        require(not re.search(r'(^|/)(secrets|private|personal|backups|dumps|exports)(/|$)', name),
                'Sensitive data directory in baseline')
        require(Path(name).name not in {'auth.json', 'credentials.json', 'config.json'}
                and not Path(name).name.startswith('service-account'), 'Credential/config file in baseline')
        data = git('cat-file', 'blob', oid.decode())
        require(len(data) <= MAX_BYTES and b'\0' not in data, 'Large/binary source file')
        data.decode('utf-8')
        files[name] = data
        total += len(data)
    require(total <= 2_000_000, 'Baseline too large for v1')
    return files


def export(files, destination):
    destination.mkdir(parents=True, exist_ok=False)
    for name, data in files.items():
        p = destination / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)


def state_dir():
    p = ROOT / '.local' / 'task-runner'
    for candidate in (ROOT / '.local', p):
        require(not candidate.is_symlink(), 'Symlink in control state path')
        candidate.mkdir(exist_ok=True, mode=0o700)
    return p


@contextlib.contextmanager
def single_run(state):
    require(not (state / 'cleanup-required').exists(), 'Previous child cleanup unresolved; manual inspection required')
    lock = state / 'active.lock'
    require(not lock.is_symlink(), 'Symlink lock')
    with lock.open('a') as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise Blocked('Another task is running') from None
        try:
            yield
        finally:
            fcntl.flock(handle, fcntl.LOCK_UN)


def environment(scratch):
    # Never inherit cloud keys, SSH agent, proxy variables, PYTHONPATH or host HOME.
    return {'PATH': '/usr/bin:/bin', 'HOME': str(scratch), 'TMPDIR': str(scratch),
            'LANG': 'en_US.UTF-8', 'LC_ALL': 'en_US.UTF-8', 'CI': 'true',
            'DART_SUPPRESS_ANALYTICS': 'true', 'FLUTTER_SUPPRESS_ANALYTICS': 'true',
            'PYTHONDONTWRITEBYTECODE': '1'}


def seatbelt(reads, writes, executables, network=False):
    require(sys.platform == 'darwin' and Path('/usr/bin/sandbox-exec').is_file(),
            'Verified macOS Seatbelt backend required; no unsandboxed fallback')
    quote = lambda p: json.dumps(str(Path(p).resolve()))
    lines = ['(version 1)', '(deny default)', '(allow process-fork)',
             '(allow sysctl-read)', '(allow file-read-metadata)',
             '(allow file-read* (literal "/"))',
             '(allow signal (target self))']
    # OS runtime resources only. No /Users, /Volumes, host /tmp or Keychain access.
    for p in ['/System/Library', '/usr/lib', '/usr/share', '/private/etc/ssl']:
        lines.append('(allow file-read* (subpath ' + quote(p) + '))')
    for p in ['/dev/null', '/dev/random', '/dev/urandom']:
        lines.append('(allow file-read* (literal ' + quote(p) + '))')
    for p in reads:
        lines.append('(allow file-read* (subpath ' + quote(p) + '))')
    for p in writes:
        lines.append('(allow file-read* file-write* (subpath ' + quote(p) + '))')
    for p in executables:
        lines.append('(allow process-exec (literal ' + quote(p) + '))')
    lines.append('(allow file-write* (literal "/dev/null"))')
    if network:
        lines.extend(['(allow network-outbound)',
                      '(allow mach-lookup (global-name "com.apple.SystemConfiguration.configd"))',
                      '(allow file-read* (literal "/private/etc/resolv.conf") (literal "/private/etc/hosts"))'])
    return '\n'.join(lines)


def command(argv, cwd, scratch, deadline, policy, env=None, max_file_bytes=MAX_OUTPUT):
    require(MAX_OUTPUT <= max_file_bytes <= CODEX_STATE_FILE_LIMIT, 'Invalid file-size limit')
    remaining = deadline - time.monotonic()
    require(remaining > 0, 'Runtime limit reached')
    scratch.mkdir(parents=True, exist_ok=True)
    out, err = scratch / 'stdout.txt', scratch / 'stderr.txt'
    def limits():
        resource.setrlimit(resource.RLIMIT_FSIZE, (max_file_bytes, max_file_bytes))
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    wrapped = ['/usr/bin/sandbox-exec', '-p', policy, *map(str, argv)]
    with out.open('wb') as stdout, err.open('wb') as stderr:
        process = subprocess.Popen(wrapped, cwd=cwd, env=env or environment(scratch),
                                   stdin=subprocess.DEVNULL, stdout=stdout, stderr=stderr,
                                   start_new_session=True, preexec_fn=limits)
        try:
            code = process.wait(timeout=max(0.01, deadline-time.monotonic()))
        except subprocess.TimeoutExpired:
            raise Blocked('Runtime limit reached') from None
        finally:
            # Also clean up ordinary child processes after a successful parent exit.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                raise Blocked('Child cleanup failed; stop further runs and inspect PID ' + str(process.pid)) from None
    require(out.stat().st_size < MAX_OUTPUT and err.stat().st_size < MAX_OUTPUT,
            'Command output limit reached')
    return code, out.read_text(errors='replace'), err.read_text(errors='replace')


def probe(work, scratch, forbidden, deadline):
    """No real secret is read: forbidden is a synthetic controller canary."""
    executable = Path(sys.executable).resolve()
    script = '''import os, pathlib, socket, sys
work, secret = map(pathlib.Path, sys.argv[1:])
assert (work / 'README.md').is_file()
for path in [secret, work / 'README.md']:
 try:
  path.write_text('tamper')
 except PermissionError: pass
 else: raise SystemExit(3)
try:
 secret.read_text()
except PermissionError: pass
else: raise SystemExit(4)
s=socket.socket()
try:
 s.bind(('127.0.0.1',0))
except PermissionError: pass
else: raise SystemExit(5)
print('isolation-ok')
'''
    policy = seatbelt([work, Path(sys.base_prefix)], [scratch], [executable])
    code, out, _ = command([executable, '-I', '-c', script, work, forbidden], work,
                           scratch, deadline, policy)
    require(code == 0 and out.strip() == 'isolation-ok', 'Isolation probe failed')


def proposal_files(proposal, task):
    require(isinstance(proposal, dict) and set(proposal) == {'files'}, 'Invalid proposal envelope')
    require(isinstance(proposal['files'], list) and 0 < len(proposal['files']) <= 5,
            'Empty or oversized proposal')
    changes = {}
    for entry in proposal['files']:
        require(isinstance(entry, dict) and set(entry) == {'path', 'content'}, 'Invalid proposal entry')
        name = safe_path(entry['path'])
        require(name in task['allowed_files'] and name not in changes, 'Unauthorized or duplicate target')
        require(isinstance(entry['content'], str), 'Content must be text')
        data = entry['content'].encode()
        require(0 < len(data) <= MAX_BYTES and b'\0' not in data, 'Invalid content size/type')
        changes[name] = data
    return changes


def apply_proposal(proposal, task, work):
    work = work.resolve()
    changes = proposal_files(proposal, task)  # Validate the entire proposal before writing anything.
    for name in changes:
        p = work / name
        require(all(not q.is_symlink() for q in [p, *p.parents]), 'Symlink in target')
    for name, data in changes.items():
        p = work / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)


def document_checks(work):
    errors = []
    for p in sorted(work.rglob('*.md')):
        s = p.read_text()
        if not s.endswith('\n') or any(line != line.rstrip() for line in s.splitlines()):
            errors.append(str(p.relative_to(work)) + ': whitespace')
        if s.count('```') % 2:
            errors.append(str(p.relative_to(work)) + ': code fence')
        for target in re.findall(r'\]\(([^)]+)\)', s):
            if '://' in target or target.startswith('#'):
                continue
            target = target.split('#')[0]
            resolved = (p.parent / target).resolve()
            if not resolved.is_relative_to(work.resolve()) or not resolved.exists():
                errors.append(str(p.relative_to(work)) + ': missing relative link')
    return errors


def integrity(work, baseline, task):
    current = {}
    for p in work.rglob('*'):
        require(not p.is_symlink(), 'Symlink appeared in candidate')
        if p.is_file():
            current[str(p.relative_to(work))] = p.read_bytes()
    changed = {p for p in set(current) | set(baseline) if current.get(p) != baseline.get(p)}
    require(changed <= set(task['allowed_files']), 'Protected baseline modified')
    return sorted(changed)


def gates(work, baseline, task, scratch, deadline, dart_sdk):
    integrity(work, baseline, task)
    results = []
    def result(name, passed, detail):
        results.append({'check': name, 'status': 'passed' if passed else 'failed', 'detail': detail})
    errors = document_checks(work)
    result('documents', not errors, '; '.join(errors) or 'Markdown and relative links')
    for i, rule in enumerate(task['acceptance']):
        p = work / rule['path']
        result('acceptance-' + str(i+1), p.is_file() and rule['contains'] in p.read_text(),
               'Frozen literal acceptance check')
    required = ['exercises/dart_basics/lib/application_status.dart', PROTECTED_TEST,
                'exercises/dart_basics/bin/main.dart', 'exercises/dart_basics/pubspec.yaml']
    require(all((work / name).is_file() for name in required), 'Required Dart source/tests missing')
    dart = dart_sdk / 'bin/dart'
    require(dart.is_file(), 'Dart runtime unavailable')
    cmds = [
        ('dart-format', [dart, 'format', '--output=none', '--set-exit-if-changed', 'bin', 'lib', 'test']),
        ('dart-analyze', [dart, 'analyze']),
        ('dart-tests', [dart, 'test/application_status_test.dart']),
    ]
    cwd = work / 'exercises/dart_basics'
    for name, argv in cmds:
        temp = scratch / name
        temp.mkdir(parents=True, exist_ok=True)
        policy = seatbelt([work, dart_sdk], [temp], [dart, dart_sdk / 'bin/dartvm',
                          dart_sdk / 'bin/dartaotruntime'])
        code, out, err = command(argv, cwd, temp, deadline, policy)
        passed = code == 0
        if name == 'dart-tests':
            passed = passed and '9 Pruefungen, 0 Fehler.' in out
        result(name, passed, (out + err)[-6000:])
    integrity(work, baseline, task)
    return results


def codex_argv(executable, work, output, schema, model, prompt):
    argv = [str(executable), '-a', 'never', 'exec', '--ignore-user-config', '--ignore-rules',
            '--ephemeral', '--sandbox', 'read-only', '--skip-git-repo-check',
            '--color', 'never', '--output-schema', str(schema), '-o', str(output),
            '-C', str(work), '-m', model]
    for feature in ['shell_tool', 'apps', 'plugins', 'hooks', 'memories', 'multi_agent',
                    'multi_agent_v2', 'browser_use', 'computer_use', 'image_generation',
                    'code_mode_host', 'shell_snapshot', 'skill_search']:
        argv += ['--disable', feature]
    argv += ['-c', 'web_search="disabled"', '-c', 'allow_login_shell=false', prompt]
    return argv


def auth_read_paths(auth_home):
    """Validate names/types only; never inspect credential or log contents."""
    require(auth_home is not None and auth_home.is_dir() and not auth_home.is_symlink(),
            'Dedicated development-only Codex home required; no host credentials copied')
    auth_file = auth_home / 'auth.json'
    require(auth_file.is_file() and not auth_file.is_symlink(),
            'Separate Codex login not configured; perform manual login first')
    require(set(p.name for p in auth_home.iterdir()) <= {'auth.json', 'log', 'tmp'},
            'Unexpected auth home entry; settings/plugins/MCPs forbidden')
    for name in ('log', 'tmp'):
        p = auth_home / name
        require(not p.is_symlink() and (not p.exists() or p.is_dir()),
                'Login auxiliary paths must be ordinary directories')
    # Login creates log/tmp. Their contents are neither inspected nor granted.
    return [auth_file]


def prepare_codex_home(scratch, auth_file):
    """Fresh writable runtime state; the original credential remains read-only."""
    runtime_home = scratch / 'codex-home'
    runtime_home.mkdir(exist_ok=False, mode=0o700)
    (runtime_home / 'auth.json').symlink_to(auth_file.resolve())
    return runtime_home


def live_proposal(task, work, scratch, auth_home, model, deadline, feedback):
    auth_paths = auth_read_paths(auth_home)
    require(CODEX.is_file() and model, 'Codex executable and explicit model required')
    scratch.mkdir(parents=True, exist_ok=True)
    schema = scratch / 'proposal.schema.json'
    schema.write_text(json.dumps({'type': 'object', 'additionalProperties': False,
        'properties': {'files': {'type': 'array', 'items': {'type': 'object',
        'additionalProperties': False, 'properties': {'path': {'type': 'string'},
        'content': {'type': 'string'}}, 'required': ['path', 'content']}}}, 'required': ['files']}))
    output = scratch / 'proposal.json'
    # Only approved source content is sent; no whole-machine context or transcripts.
    context = {name: (work/name).read_text() if (work/name).exists() else ''
               for name in task['allowed_files']}
    prompt = ('Return JSON file replacements only. Do not run tools, request approvals, change '
              'risk or create follow-up tasks. This is synthetic local development. '\
              'Acceptance is evaluated independently.\n' + canonical(task) + '\nSOURCE:\n' +
              canonical(context) + '\nLAST CHECKS:\n' + canonical(feedback))
    env = environment(scratch)
    env['CODEX_HOME'] = str(prepare_codex_home(scratch, auth_paths[0]))
    policy = seatbelt([work, CODEX.parent, *auth_paths], [scratch], [CODEX], network=True)
    code, _, _ = command(codex_argv(CODEX, work, output, schema, model, prompt),
                          work, scratch, deadline, policy, env, max_file_bytes=CODEX_STATE_FILE_LIMIT)
    require(code == 0 and output.is_file() and not output.is_symlink(), 'Codex failed (exit ' + str(code) + '); raw output kept separate, not a passed check')
    require(output.stat().st_size <= MAX_OUTPUT, 'Oversized Codex response')
    return json.loads(output.read_text())


def diff_files(baseline, work, changed):
    return ''.join(''.join(difflib.unified_diff(
        baseline.get(name, b'').decode().splitlines(True), (work/name).read_text().splitlines(True),
        fromfile='a/'+name if name in baseline else '/dev/null', tofile='b/'+name)) for name in changed)


def execute(task, baseline, run_dir, timeout, provider, dart_sdk=RUNTIME, max_repairs=2):
    require(1 <= timeout <= 1800 and 0 <= max_repairs <= 2, 'Invalid execution limits')
    deadline = time.monotonic() + timeout
    run_dir = run_dir.resolve()
    run_dir.mkdir(parents=True, exist_ok=False, mode=0o700)
    work = run_dir / 'candidate'
    export(baseline, work)
    canary = run_dir / 'control-canary.txt'
    canary.write_text('synthetic controller boundary\n')
    report = {'status': 'blocked', 'attempts': [], 'scope': task['scope'],
              'not_run': ['Flutter app tests: app absent/unsupported',
                          'Database tests: backend absent/unsupported',
                          'Actual-user-role tests: roles environment absent/unsupported'],
              'automatic_merge': False, 'deployment': False}
    try:
        probe(work, run_dir/'probe', canary, deadline)
        report['isolation_probe'] = 'passed'
        # Detect pre-existing failures independently of the new acceptance criterion.
        baseline_task = dict(task, acceptance=[])
        initial = gates(work, baseline, baseline_task, run_dir/'baseline', deadline, dart_sdk)
        report['baseline_checks'] = initial
        require(all(c['status']=='passed' for c in initial), 'Baseline checks failed; no incidental fixes')
        feedback = []
        for attempt in range(max_repairs + 1):
            require(time.monotonic() < deadline, 'Runtime limit reached')
            proposal = provider(task, work, run_dir/f'agent-{attempt}', deadline, feedback)
            apply_proposal(proposal, task, work)
            checks = gates(work, baseline, task, run_dir/f'checks-{attempt}', deadline, dart_sdk)
            report['attempts'].append({'number': attempt+1, 'checks': checks})
            changed = integrity(work, baseline, task)
            require(changed, 'No change proposed')
            if all(c['status']=='passed' for c in checks):
                report['status'] = 'ready_for_review'
                break
            report['status'] = 'failed'
            feedback = checks
        changed = integrity(work, baseline, task)
        report['changed_files'] = changed
        (run_dir/'changes.patch').write_text(diff_files(baseline, work, changed))
    except (Blocked, OSError, ValueError, subprocess.SubprocessError) as exc:
        report['status'] = 'blocked'
        report['reason'] = str(exc)
        if 'Child cleanup failed' in str(exc):
            (run_dir.parent / 'cleanup-required').write_text(str(exc)+'\n')
    finally:
        report['elapsed_seconds'] = round(timeout - (deadline-time.monotonic()), 2)
        (run_dir/'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    return report


def trusted_control(commit):
    require(re.fullmatch('[0-9a-f]{40}', commit) is not None, 'Full control commit SHA required')
    require(git('show', commit+':'+SCRIPT) == Path(__file__).read_bytes(),
            'Runner differs from approved control commit')
    return committed_files(commit)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='mode', required=True)
    for name in ('dry-run', 'approve'):
        p = sub.add_parser(name)
        p.add_argument('task', type=Path)
        p.add_argument('--base', required=True)
        p.add_argument('--control', required=True)
        if name == 'approve':
            p.add_argument('--confirm-task-sha256', required=True)
    p = sub.add_parser('demo', help='Deterministic simulation, never a real Codex run')
    p.add_argument('--base', required=True)
    p.add_argument('--control', required=True)
    p = sub.add_parser('run')
    p.add_argument('approval')
    p.add_argument('--codex-home', type=Path)
    p.add_argument('--model')
    p.add_argument('--timeout', type=int, default=600)
    args = parser.parse_args()
    if args.mode == 'demo':
        clean_repo()
        trusted_control(args.control)
        baseline = committed_files(args.base)
        task = validate_task({'id': 'synthetic-demo', 'title': 'Synthetisches Lernbeispiel',
            'instructions': 'Schreibe einen kurzen Hinweis zur getrennten Eventbestätigung.',
            'scope': 'docs', 'risk': 'low', 'synthetic_data_only': True,
            'allowed_files': ['docs/learning/runner-demo.md'],
            'acceptance': [{'path': 'docs/learning/runner-demo.md',
                            'contains': 'Mitgliedschaft ist keine Eventbestätigung.'}]})
        state = state_dir()
        with single_run(state):
            destination = state / ('demo-' + uuid.uuid4().hex[:8])
            proposal = {'files': [{'path': 'docs/learning/runner-demo.md',
                'content': '# Synthetisches Beispiel\n\nMitgliedschaft ist keine Eventbestätigung.\n'}]}
            report = execute(task, baseline, destination, 120, lambda *a: proposal)
            report['mode'] = 'simulation_only'
            report['codex_executed'] = False
            report['base_commit'] = args.base
            report['control_commit'] = args.control
            (destination / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
            print(json.dumps({'mode': 'simulation_only', 'status': report['status'],
                              'report': str(destination/'report.json')}, ensure_ascii=False))
            return 0 if report['status'] == 'ready_for_review' else 2
    if args.mode in ('dry-run', 'approve'):
        task = validate_task(json.loads(args.task.read_text()))
        baseline = committed_files(args.base)
        trusted_control(args.control)
        require(all(p in baseline or p.startswith('docs/learning/') for p in task['allowed_files']),
                'New files restricted to learning documentation in v1')
        plan = {'task': task, 'base_commit': args.base, 'control_commit': args.control,
                'task_sha256': digest(task), 'checks': ['documents', 'frozen acceptance',
                'dart-format', 'dart-analyze', 'nine protected Dart cases'], 'max_repairs': 2}
        if args.mode == 'dry-run':
            print(json.dumps(dict(plan, status='dry_run_only'), indent=2, ensure_ascii=False))
            return 0
        clean_repo()
        require(args.confirm_task_sha256 == digest(task), 'Explicit task digest mismatch')
        state = state_dir()
        with single_run(state):
            path = state / (task['id']+'.approval.json')
            with path.open('x') as f:
                json.dump(plan, f, ensure_ascii=False, indent=2)
            print('Approval saved locally: '+task['id'])
        return 0
    require(re.fullmatch(r'[a-z][a-z0-9-]{2,50}', args.approval) is not None, 'Invalid approval id')
    require(1 <= args.timeout <= 1800, 'Timeout must be 1..1800 seconds')
    clean_repo()
    state = state_dir()
    with single_run(state):
        path = state/(args.approval+'.approval.json')
        require(path.is_file() and not path.is_symlink(), 'No manual approval found')
        approval = json.loads(path.read_text())
        task = validate_task(approval['task'])
        require(task['id'] == args.approval and digest(task) == approval['task_sha256'],
                'Approval content mismatch')
        trusted_control(approval['control_commit'])
        baseline = committed_files(approval['base_commit'])
        require(git('rev-parse', 'HEAD').decode().strip() == approval['base_commit'],
                'HEAD differs from approved baseline')
        # Consume before launching anything; failure requires a new, manually reviewed approval id.
        with (state/(args.approval+'.used')).open('x') as f:
            f.write(approval['task_sha256']+'\n')
        destination = state/('run-'+task['id']+'-'+uuid.uuid4().hex[:8])
        provider = lambda t,w,s,d,f: live_proposal(t,w,s,args.codex_home,args.model,d,f)
        report = execute(task, baseline, destination, args.timeout, provider)
        report.update({'mode': 'live_codex', 'base_commit': approval['base_commit'],
                       'control_commit': approval['control_commit'], 'task_sha256': approval['task_sha256']})
        (destination/'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
        print(json.dumps({'status': report['status'], 'report': str(destination/'report.json'),
                          'reason': report.get('reason')}, ensure_ascii=False))
        return 0 if report['status']=='ready_for_review' else 2


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (Blocked, OSError, ValueError, subprocess.SubprocessError) as exc:
        print('BLOCKED: '+str(exc), file=sys.stderr)
        raise SystemExit(2)

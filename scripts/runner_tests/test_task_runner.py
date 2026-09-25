"""Runner tests use synthetic fixtures and offline CLI startup; no model calls."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / 'task_runner.py'
spec = importlib.util.spec_from_file_location('task_runner', SOURCE)
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)


def task():
    return {'id': 'demo-doc', 'title': 'Synthetic demo', 'instructions': 'Add example heading',
            'scope': 'docs', 'risk': 'low', 'synthetic_data_only': True,
            'allowed_files': ['docs/learning/demo.md'],
            'acceptance': [{'path': 'docs/learning/demo.md', 'contains': '# Beispiel'}]}


def baseline():
    root = SOURCE.parent.parent
    paths = ['README.md', 'exercises/dart_basics/lib/application_status.dart',
             'exercises/dart_basics/bin/main.dart', r.PROTECTED_TEST,
             'exercises/dart_basics/pubspec.yaml', 'exercises/dart_basics/pubspec.lock']
    data = {p: (root/p).read_bytes() for p in paths}
    data['README.md'] = b'# Synthetic repository\n'
    return data


class PolicyTests(unittest.TestCase):
    def test_codex_uses_fixed_public_ca_not_inherited_overrides(self):
        with tempfile.TemporaryDirectory() as d:
            parent = Path(d)
            ca = parent / 'synthetic-public-ca.pem'
            ca.write_text('synthetic test placeholder; not used for a connection')
            with patch.object(r, 'SYSTEM_CA_FILE', ca), patch.dict(os.environ,
                    {'SSL_CERT_FILE': '/untrusted-override', 'SSL_CERT_DIR': '/untrusted-dir'}):
                env = r.codex_environment(parent, parent/'home')
            self.assertEqual(env['SSL_CERT_FILE'], str(ca))
            self.assertEqual(env['CODEX_HOME'], str(parent/'home'))
            self.assertNotIn('SSL_CERT_DIR', env)
            self.assertNotIn('NODE_TLS_REJECT_UNAUTHORIZED', env)

    def test_missing_system_ca_blocks_codex_start(self):
        with tempfile.TemporaryDirectory() as d:
            parent = Path(d)
            with patch.object(r, 'SYSTEM_CA_FILE', parent/'missing.pem'):
                with self.assertRaisesRegex(r.Blocked, 'CA bundle unavailable'):
                    r.codex_environment(parent, parent/'home')

    def test_runtime_home_links_only_explicit_development_login(self):
        with tempfile.TemporaryDirectory() as d:
            parent = Path(d).resolve()
            auth = parent / 'synthetic-auth.json'
            auth.write_text('synthetic-only')
            scratch = parent / 'scratch'
            scratch.mkdir()
            home = r.prepare_codex_home(scratch, auth)
            self.assertTrue((home / 'auth.json').is_symlink())
            self.assertEqual((home / 'auth.json').resolve(), auth)
            self.assertEqual(auth.read_text(), 'synthetic-only')
            with self.assertRaises(FileExistsError):
                r.prepare_codex_home(scratch, auth)

    def test_login_auxiliary_dirs_do_not_grant_extra_reads(self):
        with tempfile.TemporaryDirectory() as d:
            home = Path(d)
            (home / 'auth.json').write_text('synthetic')
            for name in ('log', 'tmp'):
                (home / name).mkdir()
            with patch.object(Path, 'read_text', side_effect=AssertionError('No content reads')):
                self.assertEqual(r.auth_read_paths(home), [home / 'auth.json'])

    def test_login_rejects_config_and_auxiliary_symlinks(self):
        with tempfile.TemporaryDirectory() as d:
            home = Path(d)
            (home / 'auth.json').write_text('synthetic')
            (home / 'config.toml').write_text('synthetic')
            with self.assertRaises(r.Blocked):
                r.auth_read_paths(home)
            (home / 'config.toml').unlink()
            (home / 'log').symlink_to(home)
            with self.assertRaises(r.Blocked):
                r.auth_read_paths(home)
            (home / 'log').unlink()
            (home / 'tmp').write_text('not a directory')
            with self.assertRaises(r.Blocked):
                r.auth_read_paths(home)

    def test_sensitive_baseline_names_rejected_before_content_read(self):
        for name in ['auth.json', 'credentials.json', 'config.json',
                     'personal/note.md', 'service-account-demo.json']:
            entry = b'100644 blob ' + b'a'*40 + b'\t' + name.encode() + b'\0'
            with self.subTest(name=name), patch.object(r, 'git', return_value=entry) as fake:
                with self.assertRaises(r.Blocked):
                    r.committed_files('b'*40)
                self.assertEqual(fake.call_count, 1)

    def test_task_digest_changes_with_acceptance(self):
        a = task(); b = task(); b['acceptance'][0]['contains'] = 'other'
        self.assertNotEqual(r.digest(a), r.digest(b))

    def test_no_protected_targets(self):
        for path in ['AGENTS.md', 'scripts/task_runner.py', r.PROTECTED_TEST,
                     '.local/approval.json', '../escape.md', '/tmp/escape.md',
                     'app/lib/main.dart', 'supabase/seed.sql', 'docs/product-spec.md']:
            t=task(); t['allowed_files']=[path]; t['acceptance'][0]['path']=path
            with self.subTest(path=path), self.assertRaises(r.Blocked): r.validate_task(t)

    def test_no_app_or_database_false_success(self):
        for scope in ['app', 'database', 'roles', 'full-product']:
            t=task(); t['scope']=scope
            with self.subTest(scope=scope), self.assertRaises(r.Blocked): r.validate_task(t)

    def test_risk_and_approval_cannot_come_from_proposal(self):
        for extra in ['approved', 'risk', 'acceptance']:
            p={'files':[{'path':'docs/learning/demo.md','content':'# Example\n'}],extra:True}
            with self.assertRaises(r.Blocked): r.proposal_files(p,task())

    def test_bad_proposal_does_not_partially_apply(self):
        with tempfile.TemporaryDirectory() as d:
            w=Path(d)
            p={'files':[{'path':'docs/learning/demo.md','content':'safe\n'},
                        {'path':'AGENTS.md','content':'weaken rules\n'}]}
            with self.assertRaises(r.Blocked): r.apply_proposal(p,task(),w)
            self.assertFalse((w/'docs').exists())

    def test_no_duplicate_or_oversize_files(self):
        entry={'path':'docs/learning/demo.md','content':'x\n'}
        with self.assertRaises(r.Blocked): r.proposal_files({'files':[entry,entry]},task())
        with self.assertRaises(r.Blocked):
            r.proposal_files({'files':[dict(entry,content='x'*(r.MAX_BYTES+1))]},task())

    def test_symlink_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d); (p/'work').mkdir(); (p/'outside').mkdir(); (p/'work/docs').symlink_to(p/'outside')
            with self.assertRaises(r.Blocked):
                r.apply_proposal({'files':[{'path':'docs/learning/demo.md','content':'x\n'}]},task(),p/'work')
            self.assertFalse(list((p/'outside').iterdir()))

    def test_environment_drops_credentials_and_host_configuration(self):
        os.environ['RUNNER_TEST_SECRET']='synthetic'
        env=r.environment(Path('/synthetic'))
        self.assertNotIn('RUNNER_TEST_SECRET',env)
        self.assertNotIn('SSH_AUTH_SOCK',env)
        self.assertNotIn('PYTHONPATH',env)

    def test_lock_rejects_concurrent_run(self):
        with tempfile.TemporaryDirectory() as d:
            with r.single_run(Path(d)):
                with self.assertRaises(r.Blocked):
                    with r.single_run(Path(d)): pass
            with r.single_run(Path(d)): pass

    def test_frozen_test_tamper_detected(self):
        with tempfile.TemporaryDirectory() as d:
            w=Path(d)/'work'; b=baseline(); r.export(b,w)
            (w/r.PROTECTED_TEST).write_text('void main() {}\n')
            with self.assertRaises(r.Blocked): r.integrity(w,b,task())


    def test_malformed_task_is_blocked(self):
        for value in [None, [], dict(task(), id=12), dict(task(), scope=[]),
                      dict(task(), allowed_files=[{}]), dict(task(), acceptance=[None])]:
            with self.subTest(value=value), self.assertRaises(r.Blocked):
                r.validate_task(value)

    def test_unresolved_cleanup_blocks_next_start(self):
        with tempfile.TemporaryDirectory() as d:
            state=Path(d); (state/'cleanup-required').write_text('synthetic incident')
            with self.assertRaises(r.Blocked):
                with r.single_run(state): self.fail('Must not enter')

    def test_control_code_must_match_approved_commit(self):
        with patch.object(r, 'git', return_value=b'different controller'):
            with self.assertRaises(r.Blocked): r.trusted_control('a'*40)

    def test_relative_link_must_not_escape_snapshot(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d); w=p/'work'; w.mkdir(); (p/'outside.md').write_text('synthetic')
            (w/'README.md').write_text('[escape](../outside.md)\n')
            self.assertTrue(r.document_checks(w))

    def test_codex_has_no_bypass_and_no_inherited_config(self):
        argv=r.codex_argv(Path('/codex'),Path('/work'),Path('/out'),Path('/schema'),'chosen-model','prompt')
        self.assertIn('--ignore-user-config',argv)
        self.assertIn('--ignore-rules',argv)
        self.assertIn('never',argv)
        self.assertIn('read-only',argv)
        self.assertNotIn('--dangerously-bypass-approvals-and-sandbox',argv)


@unittest.skipUnless(sys.platform=='darwin', 'Actual macOS Seatbelt required; not an execution proof elsewhere')
class SandboxTests(unittest.TestCase):
    def test_runtime_state_writable_original_auth_readonly(self):
        with tempfile.TemporaryDirectory() as d:
            parent = Path(d).resolve()
            auth = parent / 'synthetic-auth.json'
            auth.write_text('synthetic-only')
            scratch = parent / 'scratch'
            scratch.mkdir()
            home = r.prepare_codex_home(scratch, auth)
            exe = Path(sys.executable).resolve()
            policy = r.seatbelt([Path(sys.base_prefix), auth], [scratch], [exe])
            code = """from pathlib import Path
import sys
home=Path(sys.argv[1])
assert (home/'auth.json').read_text()=='synthetic-only'
try: (home/'auth.json').write_text('tamper')
except PermissionError: pass
else: raise SystemExit(3)
(home/'synthetic-state').write_bytes(b'x'*2_000_000)
print('runtime-isolated')
"""
            status, out, err = r.command([exe, '-I', '-c', code, home], parent, scratch,
                time.monotonic()+15, policy, max_file_bytes=r.CODEX_STATE_FILE_LIMIT)
            self.assertEqual(status, 0, err)
            self.assertEqual(out.strip(), 'runtime-isolated')
            self.assertEqual(auth.read_text(), 'synthetic-only')
            self.assertEqual((home/'synthetic-state').stat().st_size, 2_000_000)

    def test_actual_codex_initializes_offline_runtime_without_credentials(self):
        with tempfile.TemporaryDirectory() as d:
            parent = Path(d).resolve()
            work = parent / 'work'
            work.mkdir()
            scratch = parent / 'scratch'
            scratch.mkdir()
            # No real login and no network: prove startup, never a model result.
            auth = parent / 'absent-auth.json'
            home = r.prepare_codex_home(scratch, auth)
            schema = scratch / 'schema.json'
            schema.write_text(json.dumps({'type':'object', 'properties':{'text':{'type':'string'}},
                'required':['text'], 'additionalProperties':False}))
            env = r.environment(scratch)
            env['CODEX_HOME'] = str(home)
            policy = r.seatbelt([work, r.CODEX.parent], [scratch], [r.CODEX])
            with self.assertRaisesRegex(r.Blocked, 'Runtime limit reached'):
                r.command(r.codex_argv(r.CODEX, work, scratch/'proposal.json', schema,
                    'gpt-6-sol', 'Synthetic offline startup probe. No tools.'), work, scratch,
                    time.monotonic()+5, policy, env, max_file_bytes=r.CODEX_STATE_FILE_LIMIT)
            stderr = (scratch/'stderr.txt').read_text()
            self.assertIn('OpenAI Codex', stderr)
            self.assertNotIn('failed to initialize in-process app-server client', stderr)
            self.assertTrue((home/'state_5.sqlite').is_file())
            self.assertFalse(auth.exists())

    def test_login_file_readable_but_auxiliary_contents_denied(self):
        with tempfile.TemporaryDirectory() as d:
            parent = Path(d).resolve()
            home = parent / 'auth'
            home.mkdir()
            (home / 'auth.json').write_text('synthetic-only')
            for name in ('log', 'tmp'):
                (home / name).mkdir()
                (home / name / 'canary').write_text('synthetic-hidden')
            exe = Path(sys.executable).resolve()
            scratch = parent / 'scratch'
            policy = r.seatbelt([Path(sys.base_prefix), *r.auth_read_paths(home)], [scratch], [exe])
            code = """from pathlib import Path
import sys
home=Path(sys.argv[1])
assert (home/'auth.json').read_text()=='synthetic-only'
for name in ('log','tmp'):
 try: (home/name/'canary').read_text()
 except PermissionError: pass
 else: raise SystemExit(3)
print('auth-boundary-ok')
"""
            status, out, err = r.command([exe, '-I', '-c', code, home], parent, scratch,
                                        time.monotonic()+15, policy)
            self.assertEqual(status, 0, err)
            self.assertEqual(out.strip(), 'auth-boundary-ok')

    def test_read_write_network_boundary(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d); w=p/'work'; w.mkdir(); (w/'README.md').write_text('# Example\n')
            canary=p/'approval'; canary.write_text('synthetic\n')
            r.probe(w,p/'scratch',canary,time.monotonic()+15)
            self.assertEqual(canary.read_text(),'synthetic\n')
            self.assertEqual((w/'README.md').read_text(),'# Example\n')

    def test_timeout(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d); exe=Path(sys.executable).resolve()
            policy=r.seatbelt([Path(sys.base_prefix)],[p],[exe])
            started=time.monotonic()
            with self.assertRaisesRegex(r.Blocked,'Runtime limit'):
                r.command([exe,'-I','-c','import time; time.sleep(20)'],p,p,started+0.3,policy)
            self.assertLess(time.monotonic()-started,3)

    def test_runtime_missing_is_blocked(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'run'
            result=r.execute(task(),baseline(),p,30,lambda *a: {},dart_sdk=Path('/missing-sdk'))
            self.assertEqual(result['status'],'blocked')
            self.assertEqual(result['attempts'],[])

    def test_failing_baseline_never_calls_agent(self):
        with tempfile.TemporaryDirectory() as d:
            b=baseline(); b.pop(r.PROTECTED_TEST)
            result=r.execute(task(),b,Path(d)/'run',30,lambda *a: self.fail('Agent must not run'))
            self.assertEqual(result['status'],'blocked')
            self.assertIn('missing',result['reason'])

    def test_real_checks_with_deterministic_proposal_not_live_codex(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'run'
            result=r.execute(task(),baseline(),p,90,lambda *a:
                {'files':[{'path':'docs/learning/demo.md','content':'# Beispiel\n'}]})
            self.assertEqual(result['status'],'ready_for_review',result)
            self.assertEqual(len(result['attempts']),1)
            self.assertIn('# Beispiel',(p/'changes.patch').read_text())
            self.assertTrue(result['not_run'])

    def test_at_most_two_repairs(self):
        with tempfile.TemporaryDirectory() as d:
            count=[]
            def provider(*args):
                count.append(1)
                return {'files':[{'path':'docs/learning/demo.md','content':'# Wrong heading\n'}]}
            result=r.execute(task(),baseline(),Path(d)/'run',120,provider)
            self.assertEqual(result['status'],'failed',result)
            self.assertEqual(len(count),3)
            self.assertEqual(len(result['attempts']),3)

    def test_failed_then_repaired(self):
        with tempfile.TemporaryDirectory() as d:
            replies=iter(['# Not yet\n','# Beispiel\n'])
            result=r.execute(task(),baseline(),Path(d)/'run',90,lambda *a:
                {'files':[{'path':'docs/learning/demo.md','content':next(replies)}]})
            self.assertEqual(result['status'],'ready_for_review',result)
            self.assertEqual(len(result['attempts']),2)


@unittest.skipUnless(sys.platform=='darwin', 'macOS-only CLI integration')
class CliTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='runner-cli-test-')
        self.addCleanup(self.temp.cleanup)
        self.parent=Path(self.temp.name).resolve()
        self.repo=self.parent/'repo'
        files=baseline()
        files['scripts/task_runner.py']=SOURCE.read_bytes()
        files['.gitignore']=b'.local/\n'
        r.export(files,self.repo)
        for args in [('init',), ('add','--','README.md','.gitignore','scripts/task_runner.py',
                         'exercises/dart_basics'),
                     ('-c','user.name=Synthetic Test','-c','user.email=test@example.invalid',
                      'commit','-m','Synthetic fixture')]:
            r.git(*args,root=self.repo)
        self.sha=r.git('rev-parse','HEAD',root=self.repo).decode().strip()
        self.task=self.parent/'task.json'; self.task.write_text(json.dumps(task()))

    def cli(self,*args):
        return subprocess.run([sys.executable,'-I',str(self.repo/'scripts/task_runner.py'),*args],
                              cwd=self.repo,env=r.environment(self.parent),
                              capture_output=True,text=True,timeout=45)

    def test_dry_run_manual_approval_and_one_use_blocked_live_run(self):
        flags=[str(self.task),'--base',self.sha,'--control',self.sha]
        dry=self.cli('dry-run',*flags)
        self.assertEqual(dry.returncode,0,dry.stderr)
        self.assertEqual(json.loads(dry.stdout)['status'],'dry_run_only')
        self.assertFalse((self.repo/'.local').exists())
        wrong=self.cli('approve',*flags,'--confirm-task-sha256','wrong')
        self.assertEqual(wrong.returncode,2)
        good=self.cli('approve',*flags,'--confirm-task-sha256',r.digest(task()))
        self.assertEqual(good.returncode,0,good.stderr)
        run=self.cli('run','demo-doc','--timeout','30')
        self.assertEqual(run.returncode,2,run.stdout+run.stderr)
        report=json.loads(Path(json.loads(run.stdout)['report']).read_text())
        self.assertEqual(report['status'],'blocked')
        self.assertIn('Codex home required',report['reason'])
        self.assertEqual(report['attempts'],[])
        again=self.cli('run','demo-doc','--timeout','30')
        self.assertEqual(again.returncode,2)
        self.assertEqual(r.git('status','--porcelain',root=self.repo),b'')

    def test_demo_cli_produces_patch_and_explicit_simulation_report(self):
        run=self.cli('demo','--base',self.sha,'--control',self.sha)
        self.assertEqual(run.returncode,0,run.stdout+run.stderr)
        report_path=Path(json.loads(run.stdout)['report'])
        report=json.loads(report_path.read_text())
        self.assertEqual(report['mode'],'simulation_only')
        self.assertFalse(report['codex_executed'])
        self.assertEqual(report['status'],'ready_for_review')
        self.assertTrue((report_path.parent/'changes.patch').is_file())
        self.assertFalse((self.repo/'docs/learning/runner-demo.md').exists())
        self.assertEqual(r.git('status','--porcelain',root=self.repo),b'')


if __name__=='__main__':
    unittest.main()

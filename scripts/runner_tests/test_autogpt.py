"""Synthetic Agent Protocol fixtures. No AutoGPT install, server or model call."""
import http.client
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

import test_task_runner as existing

r = existing.r
TASK_ID = '11111111-2222-3333-4444-555555555555'


def config():
    return r.provider_config('autogpt', 'http://127.0.0.1:8000/ap/v1', 'synthetic-model', True)


def proposal():
    return {'files': [{'path': 'docs/learning/demo.md', 'content': '# Beispiel\n'}]}


def first_step():
    return {'task_id': TASK_ID, 'status': 'completed', 'is_last': False, 'artifacts': [],
            'additional_output': {'use_tool': {'name': 'finish',
                'arguments': {'reason': json.dumps(proposal())}}, 'use_tools': None}}


class ProtocolTests(unittest.TestCase):
    def test_only_numeric_loopback_with_fixed_api_path(self):
        for endpoint in ['http://localhost:8000/ap/v1', 'https://127.0.0.1:8000/ap/v1',
                         'http://127.0.0.1:8000/ap/v1/', 'http://127.0.0.1:8000/ap/v1?token=x',
                         'http://user:pass@127.0.0.1:8000/ap/v1', 'http://127.0.0.2:8000/ap/v1',
                         'http://127.0.0.1:80/ap/v1', 'http://127.0.0.1:65536/ap/v1', None]:
            with self.subTest(endpoint=endpoint), self.assertRaises(r.Blocked):
                r.autogpt_port(endpoint)

    def test_runtime_review_and_model_required(self):
        for model, reviewed in [('synthetic-model', False), (None, True), ('bad model', True)]:
            with self.assertRaises(r.Blocked):
                r.provider_config('autogpt', 'http://127.0.0.1:8000/ap/v1', model, reviewed)
        for key, value in [('upstream_commit', 'a'*40), ('mode', 'continuous'), ('extra', True)]:
            changed = dict(config(), **{key: value})
            with self.assertRaises(r.Blocked): r.checked_provider(changed)

    def test_one_fresh_task_one_proposal_and_no_execution_request(self):
        with patch.object(r, 'autogpt_request', side_effect=[{'task_id': TASK_ID}, first_step()]) as req:
            self.assertEqual(r.autogpt_first_action(config(), 'synthetic source', time.monotonic()+5), proposal())
        self.assertEqual(req.call_count, 2)
        self.assertEqual([call.args[1] for call in req.call_args_list],
                         ['/agent/tasks', '/agent/tasks/'+TASK_ID+'/steps'])
        self.assertEqual(req.call_args_list[1].args[2], {'input': 'synthetic source'})

    def test_invalid_or_existing_task_never_gets_a_step(self):
        for created in [{'task_id': '../foreign'}, {'task_id': TASK_ID, 'artifacts': [{}]}]:
            with patch.object(r, 'autogpt_request', return_value=created) as req:
                with self.assertRaises(r.Blocked):
                    r.autogpt_first_action(config(), 'synthetic', time.monotonic()+5)
                self.assertEqual(req.call_count, 1)

    def test_running_failed_foreign_or_executed_step_blocks(self):
        for key, value in [('status', 'running'), ('status', 'failed'), ('task_id', 'foreign'),
                           ('is_last', True), ('is_last', 'false'), ('artifacts', [{}])]:
            step = dict(first_step(), **{key: value})
            with patch.object(r, 'autogpt_request', side_effect=[{'task_id': TASK_ID}, step]):
                with self.assertRaises(r.Blocked):
                    r.autogpt_first_action(config(), 'synthetic', time.monotonic()+5)

    def test_tools_parallel_actions_and_action_results_rejected(self):
        for mutate in [lambda extra: extra['use_tool'].update(name='execute_shell'),
                       lambda extra: extra.update(use_tools=[{'name': 'other'}]),
                       lambda extra: extra.update(last_action={}),
                       lambda extra: extra['use_tool']['arguments'].update(reason='```json\n{}\n```'),
                       lambda extra: extra['use_tool']['arguments'].update(approval=True)]:
            step = first_step(); mutate(step['additional_output'])
            with patch.object(r, 'autogpt_request', side_effect=[{'task_id': TASK_ID}, step]) as req:
                with self.assertRaises(r.Blocked):
                    r.autogpt_first_action(config(), 'synthetic', time.monotonic()+5)
                self.assertEqual(req.call_count, 2)

    def test_http_status_type_size_and_malformed_json_block(self):
        for status, media, raw in [(302, 'application/json', b'{}'),
                                    (500, 'application/json', b'synthetic-secret'),
                                    (200, 'text/html', b'{}'),
                                    (200, 'application/json', b'x'*(r.MAX_OUTPUT+1)),
                                    (200, 'application/json', b'not-json'),
                                    (200, 'application/json', b'[]')]:
            with patch.object(http.client, 'HTTPConnection') as factory:
                response = factory.return_value.getresponse.return_value
                response.status = status
                response.getheader.return_value = media
                response.read.return_value = raw
                with self.assertRaises(r.Blocked) as blocked:
                    r.autogpt_request(8000, '/agent/tasks', {'input': 'synthetic'}, time.monotonic()+5)
                self.assertNotIn('synthetic-secret', str(blocked.exception))
                factory.return_value.close.assert_called_once()
                self.assertEqual(factory.return_value.request.call_count, 1)

    def test_json_transport_uses_exact_route_and_no_credentials(self):
        with patch.object(http.client, 'HTTPConnection') as factory:
            response = factory.return_value.getresponse.return_value
            response.status = 201
            response.getheader.return_value = 'application/json; charset=utf-8'
            response.read.return_value = json.dumps({'task_id': TASK_ID}).encode()
            self.assertEqual(r.autogpt_request(8000, '/agent/tasks', {'input': 'synthetic'},
                             time.monotonic()+5), {'task_id': TASK_ID})
            call = factory.return_value.request.call_args
            self.assertEqual(call.args, ('POST', '/ap/v1/agent/tasks'))
            self.assertEqual(json.loads(call.kwargs['body']), {'input': 'synthetic'})
            self.assertEqual(set(call.kwargs['headers']), {'Content-Type', 'Accept'})
            response.read.assert_called_once_with(r.MAX_OUTPUT+1)
            factory.return_value.close.assert_called_once()

    def test_transport_ignores_proxy_and_never_retries(self):
        with patch.dict(r.os.environ, {'HTTP_PROXY': 'http://untrusted.invalid', 'OPENAI_API_KEY': 'synthetic'}):
            with patch.object(http.client, 'HTTPConnection') as factory:
                factory.return_value.request.side_effect = OSError('synthetic-secret')
                with self.assertRaises(r.Blocked) as blocked:
                    r.autogpt_request(8000, '/agent/tasks', {'input': 'synthetic'}, time.monotonic()+5)
                self.assertNotIn('synthetic-secret', str(blocked.exception))
                self.assertEqual(factory.call_args.args, ('127.0.0.1', 8000))
                factory.return_value.request.assert_called_once()
                self.assertNotIn('Authorization', factory.return_value.request.call_args.kwargs['headers'])

    def test_deadline_blocks_before_connecting(self):
        with patch.object(http.client, 'HTTPConnection') as factory:
            with self.assertRaises(r.Blocked):
                r.autogpt_request(8000, '/agent/tasks', {}, time.monotonic()-1)
            factory.assert_not_called()

    def test_adapter_passes_only_allowed_context_and_validates_whole_proposal(self):
        with tempfile.TemporaryDirectory() as d:
            work = Path(d)/'work'; work.mkdir()
            (work/'README.md').write_text('synthetic source outside allowed files')
            def fake_command(argv, cwd, scratch, deadline, policy):
                self.assertIn('-I', argv)
                request = json.loads((scratch/'request.json').read_text())
                self.assertNotIn('source outside allowed', request['prompt'])
                self.assertNotIn(str(work), policy)
                bad = {'files': [proposal()['files'][0], {'path': 'AGENTS.md', 'content': 'tamper'}]}
                (scratch/'proposal.json').write_text(json.dumps(bad))
                return 0, '', ''
            with patch.object(r, 'command', side_effect=fake_command):
                with self.assertRaises(r.Blocked):
                    r.autogpt_proposal(existing.task(), work, Path(d)/'scratch', config(),
                                       time.monotonic()+5, [])
            self.assertFalse((work/'docs').exists())


@unittest.skipUnless(sys.platform == 'darwin', 'macOS-only sandbox verification')
class SandboxTests(unittest.TestCase):
    def test_protocol_proposal_passes_existing_gates_and_produces_review_patch(self):
        with tempfile.TemporaryDirectory() as d:
            run = Path(d)/'run'
            def provider(task, work, scratch, deadline, feedback):
                return r.autogpt_first_action(config(), 'synthetic fixture', deadline)
            with patch.object(r, 'autogpt_request', side_effect=[{'task_id': TASK_ID}, first_step()]) as req:
                result = r.execute(existing.task(), existing.baseline(), run, 30, provider)
            self.assertEqual(result['status'], 'ready_for_review', result)
            self.assertEqual(result['changed_files'], ['docs/learning/demo.md'])
            self.assertTrue((run/'changes.patch').is_file())
            self.assertEqual(req.call_count, 2)
            self.assertFalse(result['automatic_merge'])
            self.assertFalse(result['deployment'])

    def test_worker_cannot_read_candidate_or_connect_to_other_address(self):
        with tempfile.TemporaryDirectory() as d:
            parent = Path(d).resolve()
            scratch = parent/'scratch'; scratch.mkdir()
            forbidden = parent/'synthetic-canary'; forbidden.write_text('synthetic')
            script = '''import pathlib, socket, sys
try: pathlib.Path(sys.argv[1]).read_text()
except PermissionError: pass
else: raise SystemExit(3)
try: socket.create_connection(('192.0.2.1', 9), timeout=1)
except PermissionError: pass
else: raise SystemExit(4)
try: socket.create_connection(('127.0.0.1', 8001), timeout=1)
except PermissionError: pass
else: raise SystemExit(5)
print('adapter-isolation-ok')
'''
            code, out, err = r.command([Path(sys.executable).resolve(), '-I', '-c', script, forbidden],
                scratch, scratch, time.monotonic()+5, r.autogpt_policy(scratch, config()))
            self.assertEqual(code, 0, err)
            self.assertEqual(out.strip(), 'adapter-isolation-ok')


@unittest.skipUnless(sys.platform == 'darwin', 'macOS-only CLI integration')
class AutoGPTCliTests(unittest.TestCase):
    setUp = existing.CliTests.setUp
    cli = existing.CliTests.cli

    def flags(self):
        return [str(self.task), '--base', self.sha, '--control', self.sha, '--provider', 'autogpt',
                '--autogpt-endpoint', 'http://127.0.0.1:8000/ap/v1', '--model', 'synthetic-model']

    def test_no_runtime_review_no_approval_state(self):
        result = self.cli('dry-run', *self.flags())
        self.assertEqual(result.returncode, 2)
        self.assertIn('review required', result.stderr)
        self.assertFalse((self.repo/'.local').exists())

    def test_provider_digest_and_mismatch_leave_approval_unused(self):
        flags = [*self.flags(), '--autogpt-runtime-reviewed']
        dry = self.cli('dry-run', *flags)
        self.assertEqual(dry.returncode, 0, dry.stderr)
        plan = json.loads(dry.stdout)
        self.assertEqual(plan['provider']['mode'], 'first-action-only')
        self.assertFalse((self.repo/'.local').exists())
        wrong = self.cli('approve', *flags, '--confirm-task-sha256', r.digest(existing.task()))
        self.assertEqual(wrong.returncode, 2)
        # Fixture-only approval in a disposable synthetic Git repository.
        good = self.cli('approve', *flags, '--confirm-task-sha256', r.digest(existing.task()),
                        '--confirm-provider-sha256', plan['provider_sha256'])
        self.assertEqual(good.returncode, 0, good.stderr)
        mismatch = self.cli('run', 'demo-doc', '--provider', 'codex')
        self.assertEqual(mismatch.returncode, 2)
        self.assertIn('Provider differs', mismatch.stderr)
        override = self.cli('run', 'demo-doc', '--provider', 'autogpt', '--model', 'other')
        self.assertEqual(override.returncode, 2)
        self.assertFalse((self.repo/'.local/task-runner/demo-doc.used').exists())
        self.assertEqual(r.git('status', '--porcelain', root=self.repo), b'')

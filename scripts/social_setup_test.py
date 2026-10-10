"""Private setup regression with synthetic keys and isolated temporary files."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location('social_setup_fixture', ROOT / 'scripts/configure_social_auth.py')
setup = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(setup)


class SocialSetupTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='ca-social-setup-', dir='/private/tmp')
        self.addCleanup(self.temporary.cleanup)
        setup.PRIVATE = Path(self.temporary.name) / 'private'
        setup.CONFIG = setup.PRIVATE / 'social-login.json'

    def configure(self, answers, hidden):
        output = io.StringIO()
        with patch('sys.argv', ['configure_social_auth.py']), \
                patch('sys.stdin.isatty', return_value=True), \
                patch('builtins.input', side_effect=answers), \
                patch('getpass.getpass', side_effect=hidden), contextlib.redirect_stdout(output):
            self.assertEqual(setup.main(), 0)
        return output.getvalue()

    def test_google_apple_facebook_order_private_storage_and_redacted_check(self):
        key = subprocess.run(['node', '-e',
            "const {generateKeyPairSync}=require('node:crypto');"
            "process.stdout.write(generateKeyPairSync('ec',{namedCurve:'prime256v1'}).privateKey.export({type:'pkcs8',format:'pem'}));"],
            capture_output=True, text=True, check=True).stdout
        key_path = Path(self.temporary.name) / 'synthetic.p8'
        descriptor = os.open(key_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, 'w') as file:
            file.write(key)
        output = self.configure(['https://auth.example.invalid', 'https://app.example.invalid', 'j', 'j', 'j'],
            ['synthetic-google', 'synthetic-google-secret', 'synthetic-apple', 'SYNTHETIC1', 'SYNTHETIC2', str(key_path),
             'synthetic-facebook', 'synthetic-facebook-secret'])
        stored = json.loads(setup.read_private(setup.CONFIG))
        self.assertEqual(stored['CA_SOCIAL_PROVIDERS'], 'google,apple,facebook')
        self.assertEqual(stored['APPLE_PRIVATE_KEY'], key)
        self.assertEqual(setup.CONFIG.stat().st_mode & 0o777, 0o600)
        self.assertEqual(setup.PRIVATE.stat().st_mode & 0o777, 0o700)
        self.assertNotIn('synthetic-google-secret', output)
        self.assertNotIn('PRIVATE KEY', output)
        output = io.StringIO()
        with patch('sys.argv', ['configure_social_auth.py', '--check']), contextlib.redirect_stdout(output):
            self.assertEqual(setup.main(), 0)
        self.assertNotIn('synthetic-facebook-secret', output.getvalue())
        self.configure(['', '', 'N', 'N', 'N'], [])
        self.assertEqual(json.loads(setup.read_private(setup.CONFIG)), stored)

    def test_unsafe_private_files_and_directory_are_rejected(self):
        setup.private_directory()
        unsafe = Path(self.temporary.name) / 'unsafe'
        unsafe.write_text('synthetic-value')
        unsafe.chmod(0o644)
        with self.assertRaises(ValueError):
            setup.read_private(unsafe)
        unsafe.chmod(0o600)
        link = Path(self.temporary.name) / 'link'
        link.symlink_to(unsafe)
        with self.assertRaises(OSError):
            setup.read_private(link)
        setup.PRIVATE.chmod(0o755)
        with self.assertRaises(ValueError):
            setup.private_directory()
        setup.PRIVATE.chmod(0o700)

    def test_failed_configuration_cannot_replace_existing_provider_settings(self):
        self.configure(['', '', 'j', 'N', 'N'], ['synthetic-google', 'synthetic-google-secret'])
        previous = setup.CONFIG.read_text()
        with self.assertRaises(ValueError):
            self.configure(['https://user:private@example.invalid', '', 'N', 'N', 'N'], [])
        self.assertEqual(setup.CONFIG.read_text(), previous)


if __name__ == '__main__':
    unittest.main()

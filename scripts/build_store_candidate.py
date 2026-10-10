"""Build local, unsigned store candidates with allowlisted public settings. No upload."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
PUBLIC_KEYS = {'CA_STORE_BUILD', 'CA_PRIVATE_MAIL', 'CA_AUTH_API_ORIGIN', 'CA_AUTH_UI_ORIGIN', 'CA_MINIMUM_ACCOUNT_AGE'}

def validate(settings):
    from urllib.parse import urlsplit
    if set(settings) != PUBLIC_KEYS or any(not isinstance(v, str) for v in settings.values()):
        raise ValueError('Only the five reviewed public build settings are allowed.')
    if settings['CA_STORE_BUILD'] != 'true' or settings['CA_PRIVATE_MAIL'] != 'true':
        raise ValueError('Store candidate requires explicit real-account UI mode.')
    if settings['CA_MINIMUM_ACCOUNT_AGE'] != '16':
        raise ValueError('Current owner decision is account age 16; review a change separately.')
    for key in ('CA_AUTH_API_ORIGIN', 'CA_AUTH_UI_ORIGIN'):
        uri = urlsplit(settings[key])
        # The existing public project domain is the only prepared target.
        if uri.scheme != 'https' or uri.netloc != 'communityaccess.de' or uri.path or uri.query or uri.fragment:
            raise ValueError('Only the prepared public HTTPS origin is allowed.')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', choices=['web', 'android', 'ios'], required=True)
    args = parser.parse_args()
    settings_path = ROOT / 'client/config/store-candidate.json'
    settings = json.loads(settings_path.read_text())
    validate(settings)
    flutter = shutil.which('flutter')
    if not flutter:
        raise SystemExit('Flutter is not installed.')
    # No API/mail/payment/database credentials or upload-key variables reach the compiler.
    env = {key: os.environ[key] for key in ('PATH', 'HOME', 'LANG', 'TMPDIR') if key in os.environ}
    if args.platform == 'ios':
        selected = subprocess.run(['xcode-select', '-p'], capture_output=True, text=True, check=False)
        if selected.returncode or '/Xcode.app/' not in selected.stdout:
            raise SystemExit('Blocked: full Xcode and an iOS SDK are required; nothing installed.')
    if args.platform == 'android':
        sdk = Path(os.environ.get('ANDROID_SDK_ROOT', str(Path.home() / 'Library/Android/sdk')))
        if not (sdk / 'platforms/android-36/android.jar').is_file():
            raise SystemExit('Blocked: an already installed Android SDK platform 36 is required; no SDK download or license acceptance performed.')
        if not shutil.which('java'):
            raise SystemExit('Blocked: a compatible JDK is required.')
        env['ANDROID_SDK_ROOT'] = str(sdk)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    output = ROOT / '.local/store-launch/candidates' / stamp / args.platform
    output.mkdir(parents=True, exist_ok=False)
    common = ['--release', '--no-pub', '--dart-define-from-file=' + str(settings_path)]
    if args.platform == 'web':
        command = [flutter, 'build', 'web', *common, '--no-web-resources-cdn', '--pwa-strategy=none', '--output=' + str(output)]
    else:
        command = [flutter, 'build', 'appbundle' if args.platform == 'android' else 'ios', *common]
        if args.platform == 'ios':
            command.append('--no-codesign')
    result = subprocess.run(command, cwd=ROOT / 'client', env=env, check=False)
    if result.returncode:
        raise SystemExit(result.returncode)
    if args.platform == 'web':
        if not (output / 'main.dart.js').is_file():
            raise SystemExit('Incomplete web candidate.')
        index = output / 'index.html'
        html = index.read_text().replace("connect-src 'self' http://127.0.0.1:8000 http://127.0.0.1:8400", "connect-src 'self'")
        index.write_text(html)
    elif args.platform == 'android':
        artifact = ROOT / 'client/build/app/outputs/bundle/release/app-release.aab'
        if not artifact.is_file():
            raise SystemExit('Android bundle is missing.')
        shutil.copy2(artifact, output / artifact.name)
    else:
        artifact = ROOT / 'client/build/ios/iphoneos/Runner.app'
        if not artifact.is_dir():
            raise SystemExit('Unsigned iOS app is missing.')
        shutil.copytree(artifact, output / artifact.name)
    (output / 'candidate.json').write_text(json.dumps({
        'platform': args.platform, 'application_id': 'de.communityaccess.app',
        'built_at_utc': stamp, 'signed': False, 'uploaded': False,
        'store_ready': False, 'note': 'Local candidate only. See store-launch readiness report.',
    }, indent=2) + '\n')
    print('Local candidate, not uploaded or approved: ' + str(output))

if __name__ == '__main__':
    main()

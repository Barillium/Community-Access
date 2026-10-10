"""Read-only launch prerequisites. Exit 2 means documented launch blockers, never approval."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent

def audit(root=ROOT):
    plan = json.loads((root / 'docs/store-launch/release-plan.json').read_text())
    checks = []
    def check(name, passed, detail):
        checks.append({'check': name, 'status': 'passed' if passed else 'blocked', 'detail': detail})
    check('native_source_projects', all((root / p).is_file() for p in (
        'client/android/app/src/main/AndroidManifest.xml', 'client/ios/Runner/Info.plist')),
        'Source presence only; no native compilation or device proof.')
    gradle = (root / 'client/android/app/build.gradle.kts').read_text()
    check('release_has_no_debug_signing_fallback', 'signingConfigs.getByName("debug")' not in gradle,
        'Static source check only; inspect the actual signed bundle before distribution.')
    check('prepared_store_material', all((root / p).is_file() for p in (
        'docs/store-launch/store-listing.de.md', 'docs/store-launch/store-listing.en.md',
        'client/web/support.html', 'client/web/konto-loeschen.html')),
        'Prepared local files; public URL availability is not verified.')
    xcode = subprocess.run(['xcode-select', '-p'], text=True, capture_output=True, check=False) if shutil.which('xcode-select') else None
    check('full_xcode', bool(xcode and xcode.returncode == 0 and '/Xcode.app/' in xcode.stdout),
        'Full Xcode/iOS SDK required; no installation or license acceptance performed.')
    sdk = Path.home() / 'Library/Android/sdk/platforms/android-36/android.jar'
    check('android_sdk_36', sdk.is_file(), 'Android SDK 36/JDK/Gradle and actual bundle compilation remain to verify.')
    for name, evidence in plan['evidence'].items():
        # A text value is an owner-supplied reference, never a verified result.
        checks.append({'check': name, 'status': 'blocked' if evidence is None else 'unverified',
                       'detail': 'Missing observed launch proof.' if evidence is None else 'Evidence reference requires review; not validated by this script.'})
    return {'app': plan['app_name'], 'checked_at_utc': datetime.now(timezone.utc).isoformat(),
            'scope': 'Local source and prerequisite inspection only', 'store_ready': False,
            'publication_performed': False, 'checks': checks}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = audit()
    if args.output:
        target = args.output.resolve()
        local = (ROOT / '.local/store-launch').resolve()
        if not target.is_relative_to(local):
            raise SystemExit('Reports may only be written below .local/store-launch.')
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(result, indent=2) + '\n')
    for item in result['checks']:
        print(item['status'].upper() + ': ' + item['check'])
    print('BLOCKED: local preparation is not a store launch approval.')
    raise SystemExit(2)

if __name__ == '__main__':
    main()

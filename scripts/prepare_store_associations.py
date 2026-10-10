"""Generate local domain association files from owner-provided public signing IDs; publish nothing."""
import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apple-team-id', required=True)
    parser.add_argument('--android-sha256', action='append', required=True)
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Z0-9]{10}', args.apple_team_id):
        raise SystemExit('Use the actual public Apple Team ID, no placeholder.')
    if any(not re.fullmatch(r'(?:[A-Fa-f0-9]{2}:){31}[A-Fa-f0-9]{2}', value) for value in args.android_sha256):
        raise SystemExit('Use actual SHA-256 signing certificate fingerprints.')
    directory = ROOT / '.local/store-launch/domain-associations/.well-known'
    directory.mkdir(parents=True, exist_ok=True)
    # Avoid automatically publishing guessed or duplicate signing associations.
    android = [{'relation':['delegate_permission/common.handle_all_urls'], 'target':{
        'namespace':'android_app', 'package_name':'de.communityaccess.app',
        'sha256_cert_fingerprints': sorted(set(v.upper() for v in args.android_sha256))}}]
    apple = {'applinks':{'details':[{'appIDs':[args.apple_team_id + '.de.communityaccess.app'],
                                  'components':[{'/':'/'}]}]}}
    for name,data in [('assetlinks.json',android),('apple-app-site-association',apple)]:
        path = directory / name
        if path.exists():
            raise SystemExit('Existing association file; inspect it before choosing a new output location.')
    for name,data in [('assetlinks.json',android),('apple-app-site-association',apple)]:
        (directory/name).write_text(json.dumps(data,indent=2) + '\n')
    print('Local association files prepared; verify real app-signing certificate and deploy separately over HTTPS.')

if __name__ == '__main__':
    main()

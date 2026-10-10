"""Owner-only named Cloudflare connector setup; never run with real tokens in AI tools."""
import argparse
import getpass
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
PRIVATE = Path.home() / '.community-access-private'
TOKEN = PRIVATE / 'cloudflare-tunnel.token'
BINARY = ROOT / '.local/tools/cloudflared-2026.9.3/cloudflared'


def private_directory():
    PRIVATE.mkdir(mode=0o700, exist_ok=True)
    info = PRIVATE.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
        raise ValueError('Private directory required')


def main():
    parser = argparse.ArgumentParser(description='Benannten Tunnel privat konfigurieren; legt keine Cloud-Ressourcen oder DNS-Einträge an.')
    parser.add_argument('--run', action='store_true')
    args = parser.parse_args()
    if not sys.stdin.isatty():
        raise ValueError('Private owner terminal required')
    private_directory()
    if args.run:
        info = TOKEN.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or \
                stat.S_IMODE(info.st_mode) != 0o600 or info.st_nlink != 1:
            raise ValueError('Private token file required')
        if not BINARY.is_file():
            raise ValueError('Reviewed connector missing')
        # Public metadata only. The gateway already verifies private backend mode.
        req = urllib.request.Request('http://127.0.0.1:8400/api/account/social/providers',
                                     headers={'Host': 'communityaccess.de'})
        with urllib.request.urlopen(req, timeout=5) as response:
            status = json.loads(response.read(4096))
        if not isinstance(status.get('providers'), list) or \
                any(p not in ('google', 'apple', 'facebook') for p in status['providers']):
            raise ValueError('Public gateway required')
        print('Benannter Connector startet. Healthy-Status und HTTPS separat im Betreiberbrowser prüfen.', flush=True)
        env = {'PATH': '/usr/bin:/bin', 'HOME': str(PRIVATE), 'LC_ALL': 'C'}
        return subprocess.call([str(BINARY), 'tunnel', '--config', '/dev/null', '--no-autoupdate',
                                '--protocol', 'http2', '--metrics', '127.0.0.1:0',
                                '--management-diagnostics=false', '--loglevel', 'error',
                                'run', '--token-file', str(TOKEN)], cwd=PRIVATE, env=env,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    token = getpass.getpass('Cloudflare-Tunnel-Token (verdeckt, nicht den Installationsbefehl): ').strip()
    if not re.fullmatch(r'[A-Za-z0-9_+=/-]{40,8192}', token):
        raise ValueError('Invalid token format')
    descriptor, temporary = tempfile.mkstemp(prefix='tunnel-', dir=PRIVATE)
    try:
        with os.fdopen(descriptor, 'w') as file:
            file.write(token + '\n')
            file.flush()
            os.fsync(file.fileno())
        os.replace(temporary, TOKEN)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    print('Token privat gespeichert; noch kein Tunnel gestartet oder HTTPS nachgewiesen.')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, EOFError, subprocess.SubprocessError):
        raise SystemExit('Tunnel-Einrichtung nicht abgeschlossen. Dateirechte, Gateway und Portal prüfen; Details verborgen.')
    except KeyboardInterrupt:
        raise SystemExit('Tunnel-Einrichtung beendet.')

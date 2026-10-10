"""Owner-operated social setup. Never run this with real credentials in AI tools."""
import argparse
import getpass
import json
import os
from pathlib import Path
import shlex
import stat
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
PRIVATE = Path.home() / '.community-access-private'
CONFIG = PRIVATE / 'social-login.json'
ORDER = ('google', 'apple', 'facebook')


def read_private(path):
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(descriptor) as file:
        info = os.fstat(file.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or \
                stat.S_IMODE(info.st_mode) != 0o600 or info.st_nlink != 1:
            raise ValueError('Private file required')
        value = file.read(32769)
        if len(value) > 32768:
            raise ValueError('Configuration too large')
        return value


def private_directory():
    PRIVATE.mkdir(mode=0o700, exist_ok=True)
    info = PRIVATE.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
        raise ValueError('Private directory required')


def validate(config):
    # The actual stable auth secret comes from the private runtime controller.
    # Use a synthetic value solely to validate provider configuration offline.
    result = subprocess.run(['node', '--input-type=module', '-e',
        "import {socialConfiguration} from './server/social.mjs';"
        "let data='';for await(const part of process.stdin)data+=part;"
        "try{socialConfiguration(JSON.parse(data));}catch{process.exitCode=2;}"],
        cwd=ROOT, input=json.dumps({**config, 'BETTER_AUTH_SECRET': 'synthetic-validation-key-' * 3}),
        text=True, capture_output=True, timeout=10)
    if result.returncode:
        raise ValueError('Invalid provider configuration')


def main():
    parser = argparse.ArgumentParser(description='Google → Apple → Facebook privat konfigurieren; keine Anbieter-Apps oder Veröffentlichung anlegen.')
    parser.add_argument('--check', action='store_true', help='Nur Konfiguration prüfen; keine Secrets anzeigen.')
    parser.add_argument('--run', action='store_true', help='Privaten lokalen Auth-Server mit gespeicherter Konfiguration starten.')
    args = parser.parse_args()
    if args.check and args.run:
        raise ValueError('Choose one operation')
    if not args.check and not sys.stdin.isatty():
        raise ValueError('Private interactive terminal required')
    private_directory()
    if CONFIG.is_symlink():
        raise ValueError('Private configuration cannot be a symlink')
    config = json.loads(read_private(CONFIG)) if CONFIG.exists() else {}
    allowed = {'CA_SOCIAL_PROVIDERS', 'CA_AUTH_API_ORIGIN', 'CA_AUTH_UI_ORIGIN',
        'GOOGLE_CLIENT_ID', 'GOOGLE_CLIENT_SECRET', 'APPLE_CLIENT_ID', 'APPLE_TEAM_ID',
        'APPLE_KEY_ID', 'APPLE_PRIVATE_KEY', 'FACEBOOK_CLIENT_ID', 'FACEBOOK_CLIENT_SECRET'}
    if not isinstance(config, dict) or set(config) - allowed or any(not isinstance(v, str) for v in config.values()):
        raise ValueError('Invalid private configuration')
    if args.check or args.run:
        validate(config)
        providers = config.get('CA_SOCIAL_PROVIDERS', '')
        if not providers:
            raise ValueError('No configured providers')
        print('Konfiguration geprüft: ' + providers + '. Kein Live-Login-Nachweis.')
        if args.check:
            return 0
        resend = getpass.getpass('Resend-Schlüssel für den privaten Mailmodus (verdeckt): ')
        return subprocess.call([sys.executable, '-I', str(ROOT / 'scripts/local_auth.py'), '--private-mail'],
            cwd=ROOT, env={**os.environ, **config, 'RESEND_API_KEY': resend})

    print('Diese Einrichtung speichert serverseitige Zugangsdaten ausschließlich im privaten Benutzerordner.')
    print('Anbieter-Apps müssen zuvor eingerichtet sein. Keine Schlüssel in Chat oder Repository kopieren.')
    for name, label, fallback in [
        ('CA_AUTH_API_ORIGIN', 'Auth-Origin', 'http://127.0.0.1:8000'),
        ('CA_AUTH_UI_ORIGIN', 'Flutter-Origin', 'http://127.0.0.1:8300'),
    ]:
        current = config.get(name, fallback)
        config[name] = input(label + ' [' + current + ']: ').strip() or current
    providers = set(config.get('CA_SOCIAL_PROVIDERS', '').split(',')) - {''}
    for provider in ORDER:
        label = provider.title()
        action = 'aktualisieren' if provider in providers else 'einrichten'
        if input(label + ' jetzt ' + action + '? [j/N]: ').strip().lower() != 'j':
            continue
        prefix = provider.upper()
        config[prefix + '_CLIENT_ID'] = getpass.getpass(label + ' Client ID (verdeckt): ').strip()
        if provider == 'apple':
            config['APPLE_TEAM_ID'] = getpass.getpass('Apple Team ID (verdeckt): ').strip()
            config['APPLE_KEY_ID'] = getpass.getpass('Apple Key ID (verdeckt): ').strip()
            path = Path(getpass.getpass('Absoluter Pfad zur privaten .p8-Datei (Dateirechte 600): ')).expanduser()
            if not path.is_absolute():
                raise ValueError('Absolute private key path required')
            config['APPLE_PRIVATE_KEY'] = read_private(path)
        else:
            config[prefix + '_CLIENT_SECRET'] = getpass.getpass(label + ' Client Secret (verdeckt): ').strip()
        providers.add(provider)
    config['CA_SOCIAL_PROVIDERS'] = ','.join(p for p in ORDER if p in providers)
    validate(config)
    if not providers:
        print('Kein Anbieter ausgewählt; nichts gespeichert.')
        return 0
    descriptor, temporary = tempfile.mkstemp(prefix='social-', dir=PRIVATE)
    try:
        with os.fdopen(descriptor, 'w') as file:
            json.dump(config, file)
            file.flush()
            os.fsync(file.fileno())
        os.replace(temporary, CONFIG)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    print('Privat gespeichert: ' + config['CA_SOCIAL_PROVIDERS'] + '. Noch kein Live-Login durchgeführt.')
    print('Flutter vor Veröffentlichung passend bauen:')
    print('flutter build web --no-pub --dart-define=CA_PRIVATE_MAIL=true ' +
          shlex.quote('--dart-define=CA_AUTH_API_ORIGIN=' + config['CA_AUTH_API_ORIGIN']) + ' ' +
          shlex.quote('--dart-define=CA_AUTH_UI_ORIGIN=' + config['CA_AUTH_UI_ORIGIN']))
    print('Serverstart: python3 -I scripts/configure_social_auth.py --run')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.SubprocessError, EOFError):
        raise SystemExit('Einrichtung nicht abgeschlossen. Private Dateirechte und Anbieter-Konfiguration prüfen; Details verborgen.')
    except KeyboardInterrupt:
        raise SystemExit('Einrichtung abgebrochen.')

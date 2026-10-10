"""Build a separate, secret-free HTTPS Flutter release; publish nothing."""
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
ORIGIN = 'https://communityaccess.de'


def main():
    flutter = shutil.which('flutter')
    if not flutter:
        raise SystemExit('Flutter fehlt im PATH; vorhandene SDK-Einrichtung verwenden.')
    release = ROOT / '.local' / 'public-web' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    release.mkdir(parents=True, exist_ok=False)
    # Real provider/mail/database credentials must never reach the compiler.
    env = {key: os.environ[key] for key in ('PATH', 'HOME', 'LANG', 'TMPDIR') if key in os.environ}
    result = subprocess.run([flutter, 'build', 'web', '--release', '--no-pub',
                             '--no-web-resources-cdn', '--pwa-strategy=none',
                             '--output=' + str(release),
                             '--dart-define=CA_PRIVATE_MAIL=true',
                             '--dart-define=CA_AUTH_API_ORIGIN=' + ORIGIN,
                             '--dart-define=CA_AUTH_UI_ORIGIN=' + ORIGIN],
                            cwd=ROOT / 'client', env=env, check=False)
    if result.returncode:
        raise SystemExit(result.returncode)
    if not (release / 'index.html').is_file() or not (release / 'main.dart.js').is_file():
        raise SystemExit('Web-Release unvollständig; kein Freigabemarker geschrieben.')
    index = release / 'index.html'
    # Public metadata uses only the reviewed public origin, never Uri.base or
    # invitation/account fragments. The development build stays local.
    html = index.read_text(encoding='utf-8').replace(
        "connect-src 'self' http://127.0.0.1:8000 http://127.0.0.1:8400", "connect-src 'self'").replace(
        'Lokaler synthetischer Community-Access-Prototyp',
        'Öffentlich geteilte Events und Communities entdecken. Zugang und Eventteilnahme werden separat entschieden.').replace(
        'content="social-preview.png"', f'content="{ORIGIN}/social-preview.png"')
    html = html.replace('</head>',
        f'<link rel="canonical" href="{ORIGIN}/">\n'
        f'<meta property="og:url" content="{ORIGIN}/">\n'
        '</head>')
    index.write_text(html, encoding='utf-8')
    (release / 'public-release.json').write_text(json.dumps({
        'apiOrigin': ORIGIN, 'uiOrigin': ORIGIN, 'privateMail': True,
    }) + '\n', encoding='utf-8')
    print('Separater Web-Release erstellt (noch nicht veröffentlicht): ' + str(release))


if __name__ == '__main__':
    main()

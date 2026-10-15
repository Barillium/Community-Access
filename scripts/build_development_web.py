"""Build the existing Flutter UI for the isolated Cloudflare Development preview."""
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
ORIGIN = 'https://community-access-development.stany-nyssen.workers.dev'


def main():
    flutter = shutil.which('flutter')
    if not flutter:
        raise SystemExit('Flutter fehlt im PATH.')
    out = ROOT / 'client/build/development-web'
    env = {k: os.environ[k] for k in ('PATH', 'HOME', 'LANG', 'TMPDIR') if k in os.environ}
    subprocess.run([
        flutter, 'build', 'web', '--release', '--no-pub',
        '--no-web-resources-cdn', '--pwa-strategy=none', '--output=' + str(out),
        '--dart-define=CA_PRODUCT_EDITION=v1', '--dart-define=CA_PRIVATE_MAIL=true',
        '--dart-define=CA_AUTH_API_ORIGIN=' + ORIGIN,
        '--dart-define=CA_AUTH_UI_ORIGIN=' + ORIGIN,
    ], cwd=ROOT / 'client', env=env, check=True)
    index = out / 'index.html'
    html = index.read_text().replace(
        "connect-src 'self' http://127.0.0.1:8000 http://127.0.0.1:8400", "connect-src 'self'")
    html = html.replace('Lokaler synthetischer Community-Access-Prototyp',
                        'Community Access – Development-Vorschau')
    html = html.replace('content="social-preview.png"', f'content="{ORIGIN}/social-preview.png"')
    html = html.replace('</head>', '''<style>
        #development-preview{position:fixed;bottom:8px;left:50%;transform:translateX(-50%);
        z-index:2147483647;padding:6px 12px;background:#fff;color:#171713;
        font:12px/1.4 sans-serif;text-align:center;max-width:calc(100vw - 32px);
        width:max-content;pointer-events:none}
        </style></head>''')
    html = html.replace('</body>', '''<aside id="development-preview" aria-label="Development-Vorschau">
        Development · Kontofunktionen und Zahlungen nicht verbunden</aside></body>''')
    index.write_text(html)
    shutil.copytree(ROOT / 'deploy/development/event-media', out / 'event-media', dirs_exist_ok=True)
    (out / 'robots.txt').write_text('User-agent: *\nDisallow: /\n')
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    (out / 'development-release.json').write_text(json.dumps({
        'gitCommit': commit, 'environment': 'development', 'mode': 'frontend-preview',
        'backendConnected': False, 'apiOrigin': ORIGIN, 'productEdition': 'v1',
    }, indent=2) + '\n')
    print('Development build: ' + str(out))


if __name__ == '__main__':
    main()

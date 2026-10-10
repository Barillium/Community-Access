"""Read public DNS and anonymous root HTTP/TLS metadata. Change nothing."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import json
import subprocess
from tempfile import TemporaryDirectory

DOMAIN = 'communityaccess.de'
RECORDS = [(DOMAIN, kind) for kind in ('NS', 'A', 'AAAA', 'MX', 'DS', 'CAA', 'TXT')]
RECORDS += [('_dmarc.' + DOMAIN, 'TXT'), ('send.' + DOMAIN, 'CNAME'),
            ('rsend.' + DOMAIN, 'CNAME'), ('resend._domainkey.' + DOMAIN, 'TXT')]
# Additional names explicitly observed in the current one.com DNS portal.
RECORDS += [('www.' + DOMAIN, kind) for kind in ('A', 'AAAA')]
RECORDS += [(selector + '._domainkey.' + DOMAIN, 'CNAME')
            for selector in ('ed1', 'rsa1')]


def dns(item):
    resolver, name, kind = item
    # This macOS dig has no -r option; use a new empty HOME for .digrc isolation.
    with TemporaryDirectory(prefix='ca-public-dns-') as home:
        result = subprocess.run(['dig', '@' + resolver, name, kind, '+tcp', '+time=3', '+tries=1',
                                 '+noall', '+comments', '+answer'], capture_output=True,
                                text=True, timeout=8,
                                env={'PATH': '/usr/bin:/bin', 'HOME': home, 'LC_ALL': 'C'})
    return {'resolver': resolver, 'name': name, 'type': kind,
            'exit': result.returncode, 'answer': result.stdout.strip(),
            'error': result.stderr.strip()}


def http(url):
    result = subprocess.run(['curl', '--disable', '--silent', '--show-error', '--head',
                             '--connect-timeout', '5', '--max-time', '12',
                             '--proto', '=http,https', url], capture_output=True,
                            text=True, timeout=15)
    allowed = {'location', 'strict-transport-security', 'content-security-policy',
               'x-content-type-options', 'x-frame-options', 'referrer-policy',
               'permissions-policy', 'server', 'content-type', 'cache-control'}
    # Cookies and unrelated headers are never persisted. No redirects, auth or -k.
    lines = [line for line in result.stdout.splitlines()
             if line.startswith('HTTP/') or line.partition(':')[0].lower() in allowed]
    return {'url': url, 'exit': result.returncode, 'headers': lines,
            'error': result.stderr.strip(), 'certificate_verification': True}


def main():
    with ThreadPoolExecutor(max_workers=4) as pool:
        records = list(pool.map(dns, [(r, n, k) for r in ('1.1.1.1', '8.8.8.8')
                                      for n, k in RECORDS]))
        responses = list(pool.map(http, ['http://' + DOMAIN + '/',
                                         'https://' + DOMAIN + '/',
                                         'https://www.' + DOMAIN + '/']))
    print(json.dumps({'observed_at_utc': datetime.now(timezone.utc).isoformat(),
                      'scope': 'public DNS and anonymous HEAD only; no DNS changes',
                      'dns': records, 'http': responses}, indent=2))


if __name__ == '__main__':
    main()

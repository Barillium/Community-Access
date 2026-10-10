"""Expose only the synthetic dashboard gateway for at most 30 minutes."""
import json
from pathlib import Path
import re
import selectors
import signal
import subprocess
import tempfile
import time
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
BINARY = ROOT / '.local/tools/cloudflared-2026.9.3/cloudflared'


def main():
    processes = []
    stopping = False

    def stop(*_):
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    state = ROOT / '.local/dashboard-tunnel'
    state.mkdir(parents=True, exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix='run-', dir=state))
    env = {'PATH': '/opt/homebrew/bin:/usr/bin:/bin', 'HOME': str(run), 'LC_ALL': 'C'}
    try:
        with urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=5) as response:
            health = json.load(response)
        if health.get('synthetic') is not True or health.get('dashboardEnabled') is not True:
            raise RuntimeError('Start the synthetic dashboard-enabled auth service first.')
        if not BINARY.is_file():
            raise RuntimeError('Reviewed project-local cloudflared executable is missing.')
        gateway = subprocess.Popen(['node', 'server/start_dashboard_gateway.mjs'], cwd=ROOT,
                                   env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        processes.append(gateway)
        selector = selectors.DefaultSelector()
        selector.register(gateway.stdout, selectors.EVENT_READ, 'gateway')
        ready = False
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline and not stopping:
            for key, _ in selector.select(timeout=0.5):
                line = key.fileobj.readline()
                if b'Dashboard-Weiterleitung bereit' in line:
                    ready = True
            if ready or gateway.poll() is not None:
                break
        if not ready:
            raise RuntimeError('Local dashboard gateway could not start; check port 8001.')
        tunnel = subprocess.Popen([str(BINARY), 'tunnel', '--no-autoupdate',
            '--url', 'http://127.0.0.1:8001', '--http-host-header', '127.0.0.1:8001',
            '--protocol', 'http2', '--metrics', '127.0.0.1:0',
            '--management-diagnostics=false', '--loglevel', 'info'], cwd=run,
            env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        processes.append(tunnel)
        selector.register(tunnel.stdout, selectors.EVENT_READ, 'tunnel')
        deadline = time.monotonic() + 1800
        startup_deadline = time.monotonic() + 60
        public_url = None
        while not stopping and time.monotonic() < deadline:
            for key, _ in selector.select(timeout=0.5):
                line = key.fileobj.readline()
                if not line:
                    selector.unregister(key.fileobj)
                    continue
                # Do not print raw connector output or persist request logs.
                if key.data == 'tunnel':
                    match = re.search(rb'https://[a-z0-9-]+\.trycloudflare\.com', line)
                    if match and public_url is None:
                        public_url = match[0].decode('ascii')
                        (state / 'latest-url.txt').write_text(public_url + '\n')
                        print('Dashboard HTTPS URL: ' + public_url, flush=True)
                        print('Nur Dashboard-Lesezugriffe; automatisches Ende nach 30 Minuten.', flush=True)
            if any(process.poll() is not None for process in processes):
                raise RuntimeError('Temporary tunnel or gateway stopped unexpectedly.')
            if public_url is None and time.monotonic() > startup_deadline:
                raise RuntimeError('No temporary HTTPS address received within 60 seconds.')
        return 0
    except (OSError, ValueError, RuntimeError) as error:
        # Exceptions are not dumped: environment, URLs and headers may be sensitive.
        print('Dashboard-Tunnel konnte nicht fortgesetzt werden: ' +
              (str(error) if isinstance(error, RuntimeError) else type(error).__name__), flush=True)
        return 2
    finally:
        for process in reversed(processes):
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
        print('Temporärer Dashboard-Tunnel und Weiterleitung beendet.', flush=True)


if __name__ == '__main__':
    raise SystemExit(main())

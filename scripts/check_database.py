"""Fresh synthetic PostgreSQL infrastructure test; no Supabase or product schema."""
import concurrent.futures
import json
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
BIN = Path('/opt/homebrew/opt/postgresql@17/bin')


def main():
    for name in ('initdb', 'pg_ctl', 'psql'):
        if not (BIN / name).is_file():
            raise RuntimeError('Required PostgreSQL 17 executable missing: ' + name)
    state = ROOT / '.local' / 'database-tests'
    state.mkdir(parents=True, exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix='run-', dir=state))
    socket = Path(tempfile.mkdtemp(prefix='ca-pg-', dir='/tmp'))
    data = run / 'data'
    env = {'PATH': '/usr/bin:/bin', 'HOME': str(run), 'LC_ALL': 'C',
           'PGPASSFILE': str(run / 'unused-password-file'), 'PGCONNECT_TIMEOUT': '3'}
    deadline = time.monotonic() + 90
    report = {'status': 'blocked', 'checks': [], 'data_directory': str(data),
              'socket_directory': str(socket), 'product_tests': 'not implemented',
              'supabase_auth_and_api': 'not implemented'}

    def command(name, *args, sql=None):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise RuntimeError('Test deadline exceeded')
        result = subprocess.run([str(BIN / name), *args], input=sql, text=True,
                                capture_output=True, env=env, timeout=min(remaining, 30))
        if result.returncode:
            # Only synthetic fixtures are allowed; avoid dumping arbitrary SQL/output.
            raise RuntimeError(name + ' failed with exit ' + str(result.returncode))
        return result.stdout.strip()

    def query(sql):
        return command('psql', '-X', '-v', 'ON_ERROR_STOP=1', '-A', '-t',
                       '-h', str(socket), '-p', '55439', '-U', 'fixture_admin',
                       '-d', 'postgres', sql=sql)

    try:
        command('initdb', '-D', str(data), '-U', 'fixture_admin',
                '--auth-local=trust', '--auth-host=reject', '--no-locale', '-E', 'UTF8')
        with (data / 'postgresql.conf').open('a') as f:
            f.write("\nlisten_addresses = ''\nport = 55439\n")
            f.write("unix_socket_directories = '" + str(socket) + "'\n")
            f.write("unix_socket_permissions = 0700\nlogging_collector = off\n")
            f.write("log_statement = 'none'\nlog_min_error_statement = 'panic'\n")
        command('pg_ctl', '-D', str(data), '-l', str(run / 'server.log'), '-w', '-t', '15', 'start')
        if query('SHOW data_directory;') != str(data):
            raise RuntimeError('Wrong data directory')
        if query('SHOW listen_addresses;') != '':
            raise RuntimeError('Unexpected TCP listener')
        if query('SHOW unix_socket_directories;') != str(socket):
            raise RuntimeError('Wrong socket directory')
        if socket.stat().st_mode & 0o077:
            raise RuntimeError('Socket directory permissions too broad')
        report['checks'].append('fresh isolated cluster, private socket, no TCP')
        query((ROOT / 'tests/database/infrastructure.sql').read_text())
        report['checks'].append('synthetic seed and transaction rollback')
        sql = "UPDATE infrastructure_fixture.counter SET value=value+1 WHERE id=1 RETURNING value;"
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            futures = [pool.submit(query, sql) for _ in range(2)]
            for future in futures:
                future.result()
        if query('SELECT value FROM infrastructure_fixture.counter WHERE id=1;') != '2':
            raise RuntimeError('Concurrent updates lost')
        report['checks'].append('two independent concurrent connections: no lost update')
        report['status'] = 'passed'
    except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
        report['reason'] = str(exc)
    finally:
        if (data / 'postmaster.pid').exists():
            try:
                result = subprocess.run([str(BIN / 'pg_ctl'), '-D', str(data),
                    '-m', 'fast', '-w', '-t', '15', 'stop'], env=env,
                    capture_output=True, timeout=20)
                if result.returncode or (data / 'postmaster.pid').exists():
                    raise RuntimeError('Database shutdown not confirmed')
            except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
                report['status'] = 'blocked'
                report['cleanup_error'] = str(exc)
        report['server_stopped'] = not (data / 'postmaster.pid').exists()
        report['elapsed_seconds'] = round(time.monotonic() - (deadline - 90), 2)
        (run / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report, indent=2))
        print('Report: ' + str(run / 'report.json'))
    return 0 if report['status'] == 'passed' else 2


if __name__ == '__main__':
    raise SystemExit(main())

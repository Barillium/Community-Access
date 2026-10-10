"""Two NEW synthetic PG17 clusters; never accepts a source/restore path."""
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
BIN = Path('/opt/homebrew/opt/postgresql@17/bin')
MARKER = 'community-access-synthetic-backup-v1\n'


def main():
    if sys.argv[1:] not in ([], ['--ssd-test']):
        raise SystemExit('Usage: check_backup_restore.py [--ssd-test]; NEW synthetic sources only.')
    ssd_test = sys.argv[1:] == ['--ssd-test']
    if shutil.disk_usage('/private/tmp').free < 600 * 1024 * 1024:
        raise SystemExit('At least 600 MiB free required for two disposable fixtures.')
    archive_dir = None
    if ssd_test:
        volume = Path('/Volumes/SanDisk')
        if not volume.is_mount() or volume.is_symlink() or volume.resolve() != volume:
            raise SystemExit('The explicitly selected SanDisk volume must be mounted directly.')
        parent = volume / 'Community Access Backups'
        parent.mkdir(exist_ok=True)
        if parent.is_symlink() or parent.resolve() != parent:
            raise SystemExit('Direct backup directory required.')
        archive_dir = Path(tempfile.mkdtemp(prefix='synthetic-restore-test-', dir=parent))
    run = Path(tempfile.mkdtemp(prefix='ca-backup-test-', dir='/private/tmp'))
    (run / 'synthetic-state').write_text(MARKER)
    env = {'PATH': '/opt/homebrew/bin:/usr/bin:/bin', 'HOME': str(run), 'LC_ALL': 'C',
           'PGPASSFILE': str(run / 'unused-password-file'), 'PGCONNECT_TIMEOUT': '3'}
    clusters, sockets, stopped = [], [], True

    def command(name, *args, sql=None):
        result = subprocess.run([str(BIN / name), *args], input=sql, text=True,
                                capture_output=True, env=env, timeout=45)
        if result.returncode:
            raise RuntimeError(name + ' failed; raw diagnostic withheld')
        return result.stdout.strip()

    try:
        for label in ('source', 'restore'):
            data = run / label
            socket = Path(tempfile.mkdtemp(prefix='ca-auth-', dir='/private/tmp'))
            sockets.append(socket)
            command('initdb', '-D', str(data), '-U', 'fixture_admin', '--auth-local=trust',
                    '--auth-host=reject', '--no-locale', '-E', 'UTF8')
            options = "-c listen_addresses='' -c port=55440 -c unix_socket_permissions=0700 " + \
                '-c log_statement=none -c log_min_error_statement=panic -c unix_socket_directories=' + str(socket)
            # Record ownership before start: a timeout may still leave a server.
            clusters.append(data)
            command('pg_ctl', '-D', str(data), '-l', str(run / (label + '.log')),
                    '-o', options, '-w', '-t', '15', 'start')
            command('psql', '-X', '-v', 'ON_ERROR_STOP=1', '-h', str(socket), '-p', '55440',
                    '-U', 'fixture_admin', '-d', 'postgres', sql='CREATE DATABASE community_auth;')
        node_env = {**env, 'CA_BACKUP_FIXTURE': str(run),
                    'CA_BACKUP_SOURCE_SOCKET': str(sockets[0]),
                    'CA_BACKUP_RESTORE_SOCKET': str(sockets[1]),
                    'BETTER_AUTH_SECRET': secrets.token_urlsafe(48),
                    'BETTER_AUTH_TELEMETRY': '0', 'NODE_ENV': 'development'}
        if archive_dir:
            node_env['CA_BACKUP_SSD_FIXTURE'] = str(archive_dir)
        return subprocess.run(['node', '--test', 'server/backup_restore.test.mjs'],
                              cwd=ROOT, env=node_env, timeout=180).returncode
    finally:
        for data in reversed(clusters):
            if not (data / 'postmaster.pid').exists():
                continue
            try:
                command('pg_ctl', '-D', str(data), '-m', 'fast', '-w', '-t', '15', 'stop')
            except (OSError, RuntimeError, subprocess.SubprocessError):
                stopped = False
        if stopped and all(not (data / 'postmaster.pid').exists() for data in clusters):
            # Only directories freshly created by this invocation. No caller paths.
            for socket in sockets:
                socket.rmdir()
            shutil.rmtree(run)
            if archive_dir:
                # Only this invocation's exclusive encrypted synthetic file.
                archive = archive_dir / 'synthetic-backup.aesgcm'
                if archive.exists():
                    archive.unlink()
                archive_dir.rmdir()
            print('Own synthetic backup fixtures stopped and removed.')
        else:
            print('Fixture shutdown unconfirmed; own data retained at ' + str(run))


if __name__ == '__main__':
    raise SystemExit(main())

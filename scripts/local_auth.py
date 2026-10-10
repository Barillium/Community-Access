"""Run synthetic Better Auth with reusable local state or isolated test fixtures."""
import fcntl
import os
from pathlib import Path
import re
import secrets
import signal
import stat
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
BIN = Path('/opt/homebrew/opt/postgresql@17/bin')
STATE_MARKER = 'community-access-synthetic-auth-v1\n'


def private_directory(path):
    """Reject redirects and foreign ownership before using local state."""
    path.mkdir(mode=0o700, exist_ok=True)
    info = path.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o022:
        raise RuntimeError('Unsafe local state directory')
    return info


def private_file(path, value=None):
    flags = os.O_RDWR | os.O_NOFOLLOW
    if value is not None:
        flags |= os.O_CREAT | os.O_EXCL
    descriptor = os.open(path, flags, 0o600)
    file = os.fdopen(descriptor, 'r+')
    info = os.fstat(file.fileno())
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or \
            stat.S_IMODE(info.st_mode) != 0o600 or info.st_nlink != 1:
        file.close()
        raise RuntimeError('Unsafe local state file')
    if value is not None:
        file.write(value)
        file.flush()
        os.fsync(file.fileno())
        file.seek(0)
    return file


def persistent_state(parent, run_name='persistent-synthetic', marker_value=STATE_MARKER):
    """The lock stays held for the entire run. Never import old test clusters."""
    run = parent / run_name
    info = private_directory(run)
    if stat.S_IMODE(info.st_mode) != 0o700:
        raise RuntimeError('Private synthetic state directory required')
    lock_path = run / 'run.lock'
    try:
        lock = private_file(lock_path, '')
    except FileExistsError:
        lock = private_file(lock_path)
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        marker = run / 'synthetic-state'
        secret_path = run / 'auth-secret'
        if not marker.exists():
            if set(run.iterdir()) != {lock_path}:
                raise RuntimeError('Unmarked local state; refusing automatic adoption')
            with private_file(secret_path, secrets.token_urlsafe(48) + '\n'):
                pass
            with private_file(marker, marker_value):
                pass
        with private_file(marker) as file:
            if file.read(128) != marker_value:
                raise RuntimeError('Synthetic state marker mismatch')
        with private_file(secret_path) as file:
            secret = file.read(128).strip()
        if not re.fullmatch(r'[A-Za-z0-9_-]{64}', secret):
            raise RuntimeError('Invalid synthetic auth secret; no automatic replacement')
        return run, secret, lock
    except BaseException:
        lock.close()
        raise


def main():
    args = sys.argv[1:]
    if args not in ([], ['--persistent'], ['--fresh'], ['--test'], ['--test-persistence'], ['--test-store'], ['--test-v1'], ['--test-mail'], ['--test-directory'], ['--test-social'], ['--test-access'], ['--access-demo'], ['--directory-demo'], ['--private-mail'], ['--test-ticketing'], ['--test-private-access'], ['--ticketing-demo'], ['--test-native-ticketing'], ['--native-ticketing-demo']):
        raise SystemExit('Usage: python3 -I scripts/local_auth.py [--persistent|--fresh|--test|--test-persistence|--test-store|--test-v1|--test-mail|--test-directory|--test-social|--test-access|--access-demo|--directory-demo|--private-mail|--test-ticketing|--test-private-access|--ticketing-demo|--test-native-ticketing|--native-ticketing-demo]')
    private_mail = args == ['--private-mail']
    if private_mail and not re.fullmatch(r're_[A-Za-z0-9_-]+', os.environ.get('RESEND_API_KEY', '')):
        raise SystemExit('Privater Mailbetrieb benötigt einen verdeckt eingegebenen Resend-Schlüssel.')
    testing = args in (['--test'], ['--test-persistence'], ['--test-store'], ['--test-v1'], ['--test-mail'], ['--test-directory'], ['--test-social'], ['--test-access'], ['--test-ticketing'], ['--test-private-access'], ['--test-native-ticketing'])
    persistent = not testing and args not in (['--fresh'], ['--directory-demo'], ['--access-demo'], ['--ticketing-demo'], ['--native-ticketing-demo'])
    state = Path.home() / '.community-access-private' if private_mail else ROOT / '.local' / 'better-auth'
    marker_value = 'community-access-private-mail-v1\n' if private_mail else STATE_MARKER
    if not private_mail:
        private_directory(ROOT / '.local')
    private_directory(state)
    if private_mail and stat.S_IMODE(state.stat().st_mode) != 0o700:
        raise RuntimeError('Private runtime directory required')
    lock = None
    if persistent:
        run, auth_secret, lock = persistent_state(state,
            'persistent-private-mail' if private_mail else 'persistent-synthetic', marker_value)
    else:
        run = Path(tempfile.mkdtemp(prefix='run-', dir=state))
        auth_secret = secrets.token_urlsafe(48)
    socket = Path(tempfile.mkdtemp(prefix='ca-auth-', dir='/private/tmp'))
    data = run / 'data'
    env = {'PATH': '/opt/homebrew/bin:/usr/bin:/bin', 'HOME': str(run), 'LC_ALL': 'C',
           'PGPASSFILE': str(run / 'unused-password-file'), 'PGCONNECT_TIMEOUT': '3'}
    child = None
    ticket_child = None
    database_started = False
    interrupted_run = False

    def command(name, *args, sql=None):
        result = subprocess.run([str(BIN / name), *args], input=sql, text=True,
                                capture_output=True, env=env, timeout=30)
        if result.returncode:
            raise RuntimeError(name + ' failed; diagnostic output withheld')
        return result.stdout.strip()

    def interrupted(*_):
        nonlocal interrupted_run
        interrupted_run = True
        if child and child.poll() is None:
            child.terminate()

    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        new_database = not data.exists()
        if new_database:
            # A missing cluster in an already initialized state must not erase accounts silently.
            if (run / 'database-ready').exists():
                raise RuntimeError('Initialized synthetic database missing; refusing replacement')
            command('initdb', '-D', str(data), '-U', 'fixture_admin', '--auth-local=trust',
                    '--auth-host=reject', '--no-locale', '-E', 'UTF8')
            with (data / 'postgresql.conf').open('a') as config:
                config.write("\nlisten_addresses = ''\nport = 55440\n")
                config.write("unix_socket_directories = ''\n")
                config.write("unix_socket_permissions = 0700\nlog_statement = 'none'\n")
                config.write("log_min_error_statement = 'panic'\n")
        else:
            info = data.lstat()
            if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or \
                    stat.S_IMODE(info.st_mode) != 0o700 or (data / 'PG_VERSION').read_text().strip() != '17':
                raise RuntimeError('Unexpected synthetic PostgreSQL cluster')
            if not (run / 'database-ready').exists() or (data / 'postmaster.pid').exists():
                raise RuntimeError('Synthetic database incomplete or already running; manual review required')
            with private_file(run / 'database-ready') as file:
                if file.read(128) != marker_value:
                    raise RuntimeError('Synthetic database marker mismatch')
        if interrupted_run:
            return 130
        try:
            with private_file(run / 'server.log', ''):
                pass
        except FileExistsError:
            with private_file(run / 'server.log'):
                pass
        pg_options = "-c listen_addresses='' -c port=55440 -c unix_socket_permissions=0700 " + \
            '-c log_statement=none -c log_min_error_statement=panic -c unix_socket_directories=' + str(socket)
        command('pg_ctl', '-D', str(data), '-l', str(run / 'server.log'),
                '-o', pg_options, '-w', '-t', '15', 'start')
        database_started = True
        def inspect(sql):
            return command('psql', '-X', '-A', '-t', '-v', 'ON_ERROR_STOP=1',
                           '-h', str(socket), '-p', '55440', '-U', 'fixture_admin',
                           '-d', 'postgres', sql=sql)
        if inspect('SHOW data_directory;') != str(data) or inspect('SHOW listen_addresses;') != '' or \
                inspect('SHOW unix_socket_directories;') != str(socket):
            raise RuntimeError('Unexpected database instance or TCP listener')
        if new_database:
            command('psql', '-X', '-v', 'ON_ERROR_STOP=1', '-h', str(socket), '-p', '55440',
                    '-U', 'fixture_admin', '-d', 'postgres', sql='CREATE DATABASE community_auth;')
            with private_file(run / 'database-ready', marker_value):
                pass
        node_env = {**env, 'CA_DATABASE_SOCKET': str(socket), 'NODE_ENV': 'development',
                    'BETTER_AUTH_TELEMETRY': '0', 'BETTER_AUTH_SECRET': auth_secret,
                    'CA_PRODUCT_EDITION': 'v1' if args==['--test-v1'] else os.environ.get('CA_PRODUCT_EDITION','extended' if testing else 'v1')}
        if private_mail or args == ['--test-mail']:
            # Bootstrap stays local and owner-operated. The HTTP process never
            # receives PostgreSQL superuser/role-management privileges.
            inspect("""DO $$ BEGIN
                IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='auth_app') THEN
                    CREATE ROLE auth_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
                        NOREPLICATION NOBYPASSRLS;
                END IF;
                IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='auth_app' AND
                    (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls))
                    OR EXISTS (SELECT 1 FROM pg_auth_members m JOIN pg_roles r
                        ON m.member=r.oid WHERE r.rolname='auth_app') THEN
                    RAISE EXCEPTION 'Unsafe private application role';
                END IF;
            END $$;
            REVOKE CONNECT ON DATABASE community_auth FROM PUBLIC;
            GRANT CONNECT ON DATABASE community_auth TO auth_app;""")
            command('psql', '-X', '-v', 'ON_ERROR_STOP=1', '-h', str(socket), '-p', '55440',
                    '-U', 'fixture_admin', '-d', 'community_auth', sql="""
                    GRANT USAGE, CREATE ON SCHEMA public TO auth_app;
                    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO auth_app;
                    GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO auth_app;
                    """)
            node_env['CA_DATABASE_USER'] = 'auth_app'
        if private_mail:
            node_env.update({'CA_AUTH_PROFILE': 'private-mail', 'NODE_ENV': 'production',
                             'RESEND_API_KEY': os.environ['RESEND_API_KEY']})
            # Explicitly selected providers only. Owner supplies credentials in
            # the private runtime; tests/demo never inherit external secrets.
            for name in ('CA_AUTH_API_ORIGIN', 'CA_AUTH_UI_ORIGIN', 'CA_SOCIAL_PROVIDERS',
                         'GOOGLE_CLIENT_ID', 'GOOGLE_CLIENT_SECRET', 'APPLE_CLIENT_ID',
                         'APPLE_TEAM_ID', 'APPLE_KEY_ID', 'APPLE_PRIVATE_KEY',
                         'FACEBOOK_CLIENT_ID', 'FACEBOOK_CLIENT_SECRET'):
                if name in os.environ:
                    node_env[name] = os.environ[name]
        # Keys are consumed only by the server, never printed or sent to Flutter.
        if not testing and os.environ.get('BETTER_AUTH_DASHBOARD_ENABLED') == 'true':
            node_env['BETTER_AUTH_DASHBOARD_ENABLED'] = 'true'
            node_env['BETTER_AUTH_API_KEY'] = os.environ.get('BETTER_AUTH_API_KEY', '')
        if args == ['--directory-demo']:
            node_env['CA_DIRECTORY_DEMO'] = 'true'
        if args in (['--test-access'], ['--access-demo']):
            # Owner-operated bootstrap is a separate process; HTTP never runs DDL.
            subprocess.run(['node', 'server/bootstrap_access.mjs'], cwd=ROOT, env=node_env, check=True, timeout=60)
            inspect("CREATE ROLE auth_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;")
            command('psql', '-X', '-v', 'ON_ERROR_STOP=1', '-h', str(socket), '-p', '55440',
                    '-U', 'fixture_admin', '-d', 'community_auth', sql="""
                REVOKE CREATE ON SCHEMA public FROM PUBLIC;
                GRANT USAGE ON SCHEMA public TO auth_app;
                GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO auth_app;
                GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO auth_app;
                REVOKE INSERT, UPDATE, DELETE ON ca_team, ca_access_migration FROM auth_app;
            """)
            node_env.update({'CA_DATABASE_USER': 'auth_app', 'CA_AUTH_BOOTSTRAP': 'false'})
        if args in (['--test-ticketing'], ['--test-v1'], ['--test-private-access'], ['--ticketing-demo'], ['--test-native-ticketing'], ['--native-ticketing-demo']):
            inspect('CREATE DATABASE community_tickets;')
            subprocess.run(['node', 'server/bootstrap_ticketing.mjs'], cwd=ROOT, env=node_env, check=True, timeout=60)
            inspect('CREATE ROLE auth_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS; CREATE ROLE pretix_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS; REVOKE CONNECT ON DATABASE community_auth, community_tickets FROM PUBLIC; GRANT CONNECT ON DATABASE community_auth TO auth_app; GRANT CONNECT ON DATABASE community_tickets TO pretix_app;')
            for database, role in [('community_auth', 'auth_app'), ('community_tickets', 'pretix_app')]:
                sql = 'REVOKE CREATE ON SCHEMA public FROM PUBLIC; GRANT USAGE ON SCHEMA public TO ' + role + '; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ' + role + '; GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ' + role + ';'
                if role == 'auth_app':
                    sql += ' REVOKE INSERT, UPDATE, DELETE ON ca_team, ca_access_migration FROM auth_app;'
                command('psql', '-X', '-v', 'ON_ERROR_STOP=1', '-h', str(socket), '-p', '55440', '-U', 'fixture_admin', '-d', database, sql=sql)
            node_env.update({'CA_DATABASE_USER': 'auth_app', 'CA_AUTH_BOOTSTRAP': 'false', 'CA_TICKETING_SYNTHETIC': 'true', 'CA_PRETIX_TOKEN': secrets.token_hex(32), 'CA_PRETIX_ORIGIN': 'http://127.0.0.1:8400'})
            if args in (['--test-native-ticketing'], ['--native-ticketing-demo']):
                runtime = ROOT / '.local/pretix-2026.8.0/venv/bin/python'
                if not runtime.exists():
                    raise RuntimeError('Approved isolated pretix installation required')
                inspect('CREATE DATABASE community_native; GRANT CONNECT ON DATABASE community_native TO pretix_app; REVOKE CONNECT ON DATABASE community_native FROM PUBLIC;')
                cfg = run / 'pretix.cfg'
                cfg.write_text('[pretix]\nurl=http://127.0.0.1:8400\ndatadir=' + str(run / 'pretix-data') + '\n[database]\nbackend=postgresql\nname=community_native\nuser=fixture_admin\nhost=' + str(socket) + '\nport=55440\n[django]\ndebug=true\nsecret=' + secrets.token_hex(32) + '\n')
                cfg.chmod(0o600)
                native_env = {**node_env,'DJANGO_SETTINGS_MODULE':'community_access_pretix.local_settings','PRETIX_CONFIG_FILE':str(cfg),'CA_NATIVE_PRETIX_TEST':'true','CA_BACKEND_ORIGIN':'http://127.0.0.1:8000'}
                subprocess.run([str(runtime), 'scripts/native_pretix.py', 'bootstrap'], cwd=ROOT,env=native_env,check=True,timeout=120)
                command('psql','-X','-v','ON_ERROR_STOP=1','-h',str(socket),'-p','55440','-U','fixture_admin','-d','community_native',sql='REVOKE CREATE ON SCHEMA public FROM PUBLIC; GRANT USAGE ON SCHEMA public TO pretix_app; GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO pretix_app; GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA public TO pretix_app;')
                cfg.write_text(cfg.read_text().replace('user=fixture_admin','user=pretix_app'))
                node_env['CA_NATIVE_PRETIX_TEST']='true'
                ticket_child = subprocess.Popen([str(runtime),'scripts/native_pretix.py','serve'],cwd=ROOT,env=native_env)
            elif args == ['--ticketing-demo']:

                ticket_child = subprocess.Popen(['node', 'server/start_synthetic_pretix.mjs'], cwd=ROOT, env=node_env)
        if args == ['--test-v1']:
            node_args = ['node', '--test', 'server/v1_scope.integration.test.mjs']
        elif args == ['--test-store']:
            node_args = ['node', '--test', 'server/store_launch.integration.test.mjs']
        elif args == ['--test-native-ticketing']:
            node_args = ['node', '--test', 'server/native_ticketing.test.mjs']
        elif args == ['--test-private-access']:
            node_args = ['node', '--test', 'server/private_access.test.mjs']
        elif args == ['--test-ticketing']:
            node_args = ['node', '--test', 'server/ticketing.test.mjs']
        elif args == ['--test-access']:
            node_args = ['node', '--test', 'server/access.test.mjs']
        elif args == ['--test-social']:
            node_args = ['node', '--test', 'server/social.test.mjs', 'server/social_auth.test.mjs']
        elif args == ['--test-directory']:
            node_args = ['node', '--test', 'server/directory.test.mjs']
        elif args == ['--test-mail']:
            node_args = ['node', '--test', 'server/private_mail.test.mjs']
        elif args == ['--test-persistence']:
            node_env['CA_AUTH_RESTART_TEST_DATA'] = str(data)
            node_args = ['node', '--test', 'server/persistence.test.mjs']
        else:
            node_args = ['node', '--test', 'server/auth.test.mjs'] if testing else ['node', 'server/start.mjs']
        if interrupted_run:
            return 130
        child = subprocess.Popen(node_args, cwd=ROOT, env=node_env)
        try:
            code = child.wait(timeout=120 if testing else None)
        except subprocess.TimeoutExpired:
            child.terminate()
            code = 2
        if args == ['--test-native-ticketing'] and code == 0:
            code = subprocess.run([str(runtime),'scripts/native_pretix.py','verify'],cwd=ROOT,env=native_env,timeout=120).returncode
        return code
    except (OSError, RuntimeError, subprocess.SubprocessError):
        print('Lokaler Auth-Lauf blockiert. Zustand und lokale Voraussetzungen prüfen; keine Daten ersetzt.', file=sys.stderr)
        return 2
    finally:
        if ticket_child is not None:
            if ticket_child.poll() is None:
                ticket_child.terminate()
            ticket_child.wait(timeout=10)
        if child and child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=5)
        if database_started and (data / 'postmaster.pid').exists():
            command('pg_ctl', '-D', str(data), '-m', 'fast', '-w', '-t', '15', 'stop')
        if lock:
            lock.close()
        if not (data / 'postmaster.pid').exists():
            try:
                socket.rmdir()  # Only our empty socket directory, never database contents.
            except OSError:
                pass
        print('Lokale Auth-Datenbank beendet; ' + ('private' if private_mail else 'synthetische') +
              ' Daten erhalten unter: ' + str(run))


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError):
        raise SystemExit('Lokaler Auth-Lauf blockiert. Zustand prüfen; keine Daten automatisch ersetzt.')

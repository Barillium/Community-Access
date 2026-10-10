"""Run installed pretix only against explicitly selected fresh synthetic fixtures."""
import os
import sys
from pathlib import Path

if os.environ.get('CA_NATIVE_PRETIX_TEST') != 'true':
    raise SystemExit('Explicit native synthetic runtime required')
import django
django.setup()
from django.core.management import call_command

if sys.argv[1:] == ['bootstrap']:
    call_command('migrate', verbosity=0, interactive=False)
    import psycopg2
    from django_scopes import scopes_disabled
    from community_access_pretix.service import configure
    from django.db import transaction
    db=psycopg2.connect(host=os.environ['CA_DATABASE_SOCKET'],port=55440,user='fixture_admin',dbname='community_auth')
    with db, db.cursor() as cursor, scopes_disabled(), transaction.atomic():
        cursor.execute('SELECT c.event_id,c.item_name,c.price_cents,c.quota,c.version,e.starts_at FROM ca_ticket_config c JOIN ca_event e ON e.id=c.event_id')
        for key,name,price,quota,version,starts in cursor.fetchall():
            native=configure(dict(id=str(key),item_name=name,price_cents=price,quota=quota,version=version,starts_at=starts.isoformat()))
            cursor.execute('INSERT INTO ca_ticket_native_binding VALUES(%s,%s)',[key,native['item_id']])
    db.close()
elif sys.argv[1:] == ['verify']:
    from community_access_pretix.native_verification import run
    run()
elif sys.argv[1:] == ['serve']:
    from django.core.wsgi import get_wsgi_application
    from django.contrib.staticfiles.handlers import StaticFilesHandler
    from wsgiref.simple_server import make_server, WSGIServer, WSGIRequestHandler
    from socketserver import ThreadingMixIn
    class Server(ThreadingMixIn, WSGIServer):
        daemon_threads = True
    class QuietHandler(WSGIRequestHandler):
        def log_message(self, *args):
            pass
    server=make_server('127.0.0.1',8400,StaticFilesHandler(get_wsgi_application()),server_class=Server,handler_class=QuietHandler)
    print('Native pretix bereit: http://127.0.0.1:8400 · simulierte Zahlungen',flush=True)
    try:server.serve_forever()
    except KeyboardInterrupt:pass
    finally:server.server_close()
else:
    raise SystemExit('Use bootstrap or serve')

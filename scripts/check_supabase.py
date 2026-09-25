"""Local synthetic Auth/API checks. Never accepts a remote URL or credentials."""
import concurrent.futures
import json
from pathlib import Path
import secrets
import subprocess
import urllib.error
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parent.parent
ENV = {'PATH': '/opt/homebrew/bin:/usr/bin:/bin', 'HOME': str(Path.home()),
       'DOCKER_HOST': 'unix://' + str(Path.home()/'.colima/community-access-test/docker.sock')}
API = 'http://127.0.0.1:55431'
DB = 'supabase_db_community-access-test'


def command(args, source=None):
    p = subprocess.run(args, input=source, text=True, capture_output=True,
                       env=ENV, cwd=ROOT, timeout=30)
    if p.returncode:
        raise RuntimeError('Local command failed: ' + args[0])
    return p.stdout


def sql(source):
    return command(['docker', 'exec', '-i', DB, 'psql', '-X', '-U', 'postgres',
                    '-d', 'postgres', '-At', '-v', 'ON_ERROR_STOP=1'], source).strip()


def main():
    bindings = json.loads(command(['docker', 'inspect', '--format', '{{json .NetworkSettings.Ports}}', 'supabase_kong_community-access-test']))
    if any(b['HostIp'] not in ('127.0.0.1', '::1') for items in bindings.values() if items for b in items):
        raise RuntimeError('API port is not loopback-only')
    # Fetch only locally generated test keys into process memory; never print them.
    settings = json.loads(command(['supabase', 'status', '-o', 'json']))
    if settings.get('API_URL') != API:
        raise RuntimeError('Unexpected API target')
    key = settings.get('ANON_KEY') or settings.get('PUBLISHABLE_KEY')
    if not key:
        raise RuntimeError('Local public API key missing')
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    checks = []

    def request(path, token=None, method='GET', body=None):
        headers = {'apikey': key, 'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        data = None if body is None else json.dumps(body).encode()
        req = urllib.request.Request(API+path, data=data, headers=headers, method=method)
        try:
            with opener.open(req, timeout=10) as r:
                payload = r.read()
                return r.status, json.loads(payload) if payload else None
        except urllib.error.HTTPError as exc:
            # Do not expose error bodies, tokens or application data.
            return exc.code, None

    def check(label, condition):
        if not condition:
            raise RuntimeError('Check failed: '+label)
        checks.append(label)

    def rpc(name, token, body):
        return request('/rest/v1/rpc/'+name, token, 'POST', body)[0]

    users = {}
    suffix = uuid.uuid4().hex
    for name in ('host_a','host_b','guest_a','guest_b','outsider'):
        email = name+'.'+suffix+'@example.invalid'
        password = secrets.token_urlsafe(24)
        code, result = request('/auth/v1/signup', method='POST', body={'email': email, 'password': password})
        check('synthetic signup '+name, code == 200 and bool(result.get('user',{}).get('id')))
        code, result = request('/auth/v1/token?grant_type=password', method='POST', body={'email': email,'password':password})
        check('password login '+name, code == 200 and bool(result.get('access_token')))
        users[name] = (str(uuid.UUID(result['user']['id'])), result['access_token'])
    ca, cb, event, aa, ab = [str(uuid.uuid4()) for _ in range(5)]
    ha,hb,ga,gb,out = [users[n][0] for n in ('host_a','host_b','guest_a','guest_b','outsider')]
    ta,tb,tga,tgb,to = [users[n][1] for n in ('host_a','host_b','guest_a','guest_b','outsider')]
    sql(f"""INSERT INTO public.communities VALUES ('{ca}','Synthetisch A'),('{cb}','Synthetisch B');
    INSERT INTO public.community_hosts VALUES ('{ca}','{ha}'),('{cb}','{hb}');
    INSERT INTO public.applications(id,community_id,user_id) VALUES ('{aa}','{ca}','{ga}'),('{ab}','{ca}','{gb}');
    INSERT INTO public.events VALUES ('{event}','{ca}','Synthetisches Event',1,18);
    INSERT INTO public.event_locations VALUES ('{event}','Erfundener Testort');""")
    path='/rest/v1/applications?id=eq.'+aa
    check('anonymous denied', request(path)[0] in (401,403))
    check('owner sees application', len(request(path,tga)[1] or []) == 1)
    check('foreign guest sees no application', request(path,to) == (200,[]))
    check('foreign host sees no application', request(path,tb) == (200,[]))
    check('own host sees application', len(request(path,ta)[1] or []) == 1)
    check('self admission denied', rpc('decide_application',tga,{'application_id':aa,'approve':True}) == 403)
    check('foreign host admission denied', rpc('decide_application',tb,{'application_id':aa,'approve':True}) == 403)
    check('direct membership forgery denied', request('/rest/v1/memberships',tga,'POST',{'community_id':ca,'user_id':ga,'active':True})[0] == 403)
    check('event request before admission denied', rpc('request_event',tga,{'event_id':event,'age_confirmed':True}) == 403)
    for table, payload in [
        ('community_hosts', {'community_id':ca,'user_id':ga}),
        ('applications', {'id':aa,'status':'approved'}),
        ('event_requests', {'event_id':event,'user_id':ga,'status':'confirmed','age_confirmed':True}),
        ('event_locations', {'event_id':event,'location':'Synthetischer Manipulationsversuch'}),
    ]:
        check('direct write denied '+table, request('/rest/v1/'+table,tga,'POST',payload)[0]==403)
    # Inject a fixture-only failure after the application status update.
    sql("""create function access_private.test_abort_membership() returns trigger language plpgsql as $$
    begin raise exception 'synthetic rollback test'; end $$;
    create trigger test_abort_membership before insert on public.memberships for each row execute function access_private.test_abort_membership();""")
    try:
        check('admission transaction fails atomically',rpc('decide_application',ta,{'application_id':aa,'approve':True})>=400)
        check('application remains pending after failure',sql(f"select status from public.applications where id='{aa}';")=='pending')
        check('failed admission creates no membership',sql(f"select count(*) from public.memberships where community_id='{ca}' and user_id='{ga}';")=='0')
    finally:
        sql('drop trigger test_abort_membership on public.memberships; drop function access_private.test_abort_membership();')
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        codes=list(pool.map(lambda _: rpc('decide_application',ta,{'application_id':aa,'approve':True}),range(2)))
    check('concurrent repeated admission safe',codes==[204,204])
    for app in (aa,ab):
        check('manual admission '+app, rpc('decide_application',ta,{'application_id':app,'approve':True}) == 204)
    check('repeat admission safe', rpc('decide_application',ta,{'application_id':aa,'approve':True}) == 204)
    check('exactly one membership',sql(f"select count(*) from public.memberships where community_id='{ca}' and user_id='{ga}';")=='1')
    location='/rest/v1/event_locations?event_id=eq.'+event
    check('member has no location',request(location,tga)==(200,[]))
    check('foreign host has no location',request(location,tb)==(200,[]))
    check('own host sees location',len(request(location,ta)[1] or [])==1)
    check('age acknowledgement required',rpc('request_event',tga,{'event_id':event,'age_confirmed':False})>=400)
    for token in (tga,tgb):
        check('member requests event',rpc('request_event',token,{'event_id':event,'age_confirmed':True})==204)
    check('repeat event request safe',rpc('request_event',tga,{'event_id':event,'age_confirmed':True})==204)
    check('pending request has no location',request(location,tga)==(200,[]))
    check('self event confirmation denied',rpc('confirm_event',tga,{'target_event':event,'target_user':ga})==403)
    check('foreign host confirmation denied',rpc('confirm_event',tb,{'target_event':event,'target_user':ga})==403)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results=list(pool.map(lambda u: rpc('confirm_event',ta,{'target_event':event,'target_user':u}),[ga,gb]))
    check('only one concurrent confirmation',sum(c==204 for c in results)==1)
    winner=sql(f"select user_id from public.event_requests where event_id='{event}' and status='confirmed';")
    check('one confirmed database row',winner in (ga,gb))
    tw = tga if winner==ga else tgb
    check('confirmed guest sees location',len(request(location,tw)[1] or [])==1)
    check('repeat confirmation safe',rpc('confirm_event',ta,{'target_event':event,'target_user':winner})==204)
    # Administrative fixture change, not a product revocation endpoint.
    sql(f"update public.memberships set active=false where community_id='{ca}' and user_id='{winner}';")
    check('revoked guest with existing JWT loses location',request(location,tw)==(200,[]))
    check('revoked guest cannot request again',rpc('request_event',tw,{'event_id':event,'age_confirmed':True})==403)
    report={'status':'passed','checks':checks,'not_tested':['invitation redemption','collective onboarding','application fields','retention','product revocation endpoint','Flutter integration'],'fixture_id':suffix}
    target=ROOT/'.local'/'supabase-tests';target.mkdir(exist_ok=True)
    file=target/(suffix+'.json');file.write_text(json.dumps(report,indent=2)+'\n')
    print('PASS:',len(checks),'Auth/API assertions. Report:',file)


if __name__=='__main__':
    try:
        main()
    except Exception as exc:
        print('BLOCKED:',str(exc) if isinstance(exc,RuntimeError) else type(exc).__name__)
        raise SystemExit(2)

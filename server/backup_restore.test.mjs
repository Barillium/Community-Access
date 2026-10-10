import {test} from 'node:test';
import assert from 'node:assert/strict';
import {request} from 'node:http';
import {execFileSync} from 'node:child_process';
import {readFileSync,writeFileSync,lstatSync,realpathSync,copyFileSync,constants} from 'node:fs';
import {randomBytes,createCipheriv,createDecipheriv,createHash} from 'node:crypto';
import {Pool} from 'pg';
import {createAuth} from './auth.mjs';
import {createApp} from './http.mjs';
import {seedAccess} from './access_fixtures.mjs';

test('encrypted synthetic backup restores into a distinct cluster with access controls',async t=>{
  const run=process.env.CA_BACKUP_FIXTURE;
  assert.match(run??'',/^\/private\/tmp\/ca-backup-test-[^/]+$/);
  assert.equal(realpathSync(run),run);
  assert.equal(lstatSync(run).uid,process.getuid());
  assert.equal(readFileSync(run+'/synthetic-state','utf8'),'community-access-synthetic-backup-v1\n');
  const sockets=[process.env.CA_BACKUP_SOURCE_SOCKET,process.env.CA_BACKUP_RESTORE_SOCKET];
  assert.notEqual(sockets[0],sockets[1]);
  for(const socket of sockets){assert.match(socket??'',/^\/private\/tmp\/ca-auth-[^/]+$/);assert.equal(realpathSync(socket),socket);}
  const admins=sockets.map(host=>new Pool({host,port:55440,user:'fixture_admin',database:'community_auth',connectionTimeoutMillis:3000}));
  const env=socket=>({CA_DATABASE_SOCKET:socket,BETTER_AUTH_SECRET:process.env.BETTER_AUTH_SECRET,
    BETTER_AUTH_TELEMETRY:'0',NODE_ENV:'development',CA_DATABASE_USER:'auth_app',CA_AUTH_BOOTSTRAP:'false'});
  const servers=[],pools=[];
  const tokens={};
  const call=(server,path,body,key)=>new Promise((resolve,reject)=>{
    const req=request({hostname:'127.0.0.1',port:server.address().port,path:'/api/'+path,
      method:body===undefined?'GET':'POST',headers:{Host:'127.0.0.1:8000',Origin:'http://127.0.0.1:8300',
        Connection:'close','Content-Type':'application/json',...(tokens[key]?{Authorization:'Bearer '+tokens[key]}:{})}},res=>{
      let text='';res.setEncoding('utf8');res.on('data',chunk=>text+=chunk);
      res.on('end',()=>resolve({status:res.statusCode,headers:res.headers,data:JSON.parse(text)}));
    });req.on('error',reject);req.end(body===undefined?undefined:JSON.stringify(body));
  });
  const start=async state=>{const server=createApp(state);servers.push(server);await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));return server;};
  const roleSQL=`CREATE ROLE auth_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
    REVOKE CONNECT ON DATABASE community_auth FROM PUBLIC;
    GRANT CONNECT ON DATABASE community_auth TO auth_app;`;
  const magic=Buffer.from('CA-SYNTH-BACKUP-1\n'),key=randomBytes(32);
  const decode=(archive,secret)=>{
    assert.ok(archive.length>magic.length+28);
    assert.ok(archive.subarray(0,magic.length).equals(magic));
    const decrypt=createDecipheriv('aes-256-gcm',secret,archive.subarray(magic.length,magic.length+12));
    decrypt.setAAD(magic);decrypt.setAuthTag(archive.subarray(magic.length+12,magic.length+28));
    return Buffer.concat([decrypt.update(archive.subarray(magic.length+28)),decrypt.final()]);
  };
  try{
    for(const [index,admin] of admins.entries()){
      assert.equal((await admin.query('SHOW data_directory')).rows[0].data_directory,run+'/'+(index?'restore':'source'));
      assert.equal((await admin.query('SHOW listen_addresses')).rows[0].listen_addresses,'');
      assert.equal((await admin.query("SELECT count(*)::int AS n FROM pg_tables WHERE schemaname='public'")).rows[0].n,0);
    }
    const bootstrap=await createAuth({env:{CA_DATABASE_SOCKET:sockets[0],BETTER_AUTH_SECRET:process.env.BETTER_AUTH_SECRET}});
    pools.push(bootstrap.pool);
    const fixture=await seedAccess(bootstrap);
    await admins[0].query(roleSQL+`
      REVOKE CREATE ON SCHEMA public FROM PUBLIC;
      GRANT USAGE ON SCHEMA public TO auth_app;
      GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO auth_app;
      GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA public TO auth_app;
      REVOKE INSERT,UPDATE,DELETE ON ca_team,ca_access_migration FROM auth_app;`);
    const source=await createAuth({env:env(sockets[0])});pools.push(source.pool);
    const sourceServer=await start(source);
    for(const person of ['team','organizer','guest.a','guest.b']){
      const login=await call(sourceServer,'auth/sign-in/email',{email:person+'@example.invalid',password:fixture.password});
      assert.equal(login.status,200);tokens[person]=login.headers['set-auth-token'];assert.ok(tokens[person]);
    }
    const submitted=await call(sourceServer,'access/organizer-applications',{name:'Synthetic restore collective',description:'Synthetic test only.',event_types:'Music',awareness_concept:true,awareness_team:false},'organizer');
    assert.equal(submitted.status,200);
    const approved=await call(sourceServer,`access/organizer-applications/${submitted.data.id}/decide`,{status:'approved'},'team');assert.equal(approved.status,200);
    const community=approved.data.community_id,profile=approved.data.profile_id;
    assert.equal((await call(sourceServer,`access/communities/${community}/form`,{fields:[{key:'interest',label:'Was interessiert dich an unserem Programm?',required:true}],version:1,host_contact:'Synthetic host'},'organizer')).status,200);
    const invitation=await call(sourceServer,`access/communities/${community}/invite`,{email:'guest.a@example.invalid'},'organizer');assert.equal(invitation.status,200);
    const application=await call(sourceServer,'access/applications',{token:invitation.data.token,version:2,answers:{interest:'Synthetic music'}},'guest.a');assert.equal(application.status,200);
    assert.equal((await call(sourceServer,`access/applications/${application.data.id}/decide`,{status:'approved'},'organizer')).status,200);
    const saved=await call(sourceServer,'directory/manage/event',{profile_id:profile,community_id:community,title:'Synthetic recovery event',status:'published',is_public:false,starts_at:new Date(Date.now()+86400000).toISOString(),starts_public:true,public_location:'Synthetic general area',location_public:true,access_mode:'private',review_method:'manual',membership_required:true,capacity:1,exact_location:'Protected synthetic restore location',event_content:{description:'Synthetic only.',minimum_age:18,ends_at:new Date(Date.now()+90000000).toISOString()}},'organizer');assert.equal(saved.status,200);
    const event=saved.data.id;
    assert.equal((await call(sourceServer,`directory/events/${event}/interest`,{answers:{},age_acknowledged:true},'guest.a')).status,200);
    const interest=(await admins[0].query('SELECT version FROM ca_event_interest WHERE event_id=$1 AND user_id=$2',[event,fixture.users['guest.a'].id])).rows[0];
    assert.equal((await call(sourceServer,'directory/manage/interest',{event_id:event,user_id:fixture.users['guest.a'].id,version:interest.version,status:'approved'},'organizer')).status,200);
    await admins[0].query('DELETE FROM session WHERE "userId"=$1',[fixture.users['guest.b'].id]);
    assert.equal((await call(sourceServer,'account/me',undefined,'guest.b')).status,401);
    const args=socket=>['-h',socket,'-p','55440','-U','fixture_admin','--no-password'];
    const childEnv={PATH:'/opt/homebrew/bin:/usr/bin:/bin',HOME:run,LC_ALL:'C',PGPASSFILE:run+'/unused-password-file'};
    const plain=execFileSync('/opt/homebrew/opt/postgresql@17/bin/pg_dump',[...args(sockets[0]),'-Fc','community_auth'],{env:childEnv,timeout:30000,maxBuffer:8*1024*1024});
    const nonce=randomBytes(12),cipher=createCipheriv('aes-256-gcm',key,nonce);cipher.setAAD(magic);
    const encrypted=Buffer.concat([cipher.update(plain),cipher.final()]);
    const archive=Buffer.concat([magic,nonce,cipher.getAuthTag(),encrypted]);
    const file=run+'/synthetic-backup.aesgcm';writeFileSync(file,archive,{flag:'wx',mode:0o600});
    await t.test('authenticated encrypted archive: round trip, corruption and wrong key',async()=>{
      assert.equal(lstatSync(file).mode&0o777,0o600);
      assert.ok(!archive.includes(Buffer.from('guest.a@example.invalid')));
      assert.equal(createHash('sha256').update(decode(readFileSync(file),key)).digest('hex'),createHash('sha256').update(plain).digest('hex'));
      const corrupt=Buffer.from(archive);corrupt[corrupt.length-1]^=1;
      assert.throws(()=>decode(corrupt,key));assert.throws(()=>decode(archive,randomBytes(32)));
    });
    let restoreArchive=archive;
    if(process.env.CA_BACKUP_SSD_FIXTURE){
      await t.test('encrypted copy on the selected external SSD supplies the restore archive',async()=>{
        const external=process.env.CA_BACKUP_SSD_FIXTURE;
        assert.match(external,/^\/Volumes\/SanDisk\/Community Access Backups\/synthetic-restore-test-[^/]+$/);
        assert.equal(realpathSync(external),external);
        const destination=external+'/synthetic-backup.aesgcm';
        copyFileSync(file,destination,constants.COPYFILE_EXCL);
        restoreArchive=readFileSync(destination);
        assert.equal(createHash('sha256').update(restoreArchive).digest('hex'),createHash('sha256').update(archive).digest('hex'));
      });
    }
    await admins[1].query(roleSQL);
    execFileSync('/opt/homebrew/opt/postgresql@17/bin/pg_restore',[...args(sockets[1]),'--exit-on-error','--single-transaction','--dbname=community_auth'],{input:decode(restoreArchive,key),env:childEnv,timeout:30000,maxBuffer:8*1024*1024});
    plain.fill(0);
    const restored=await createAuth({env:env(sockets[1])});pools.push(restored.pool);
    const targetServer=await start(restored);
    await t.test('all public tables retain row counts and identity',async()=>{
      const tables=(await admins[0].query("SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename")).rows;
      for(const {tablename} of tables){
        assert.match(tablename,/^[A-Za-z_][A-Za-z0-9_]*$/);
        const query=`SELECT count(*)::int AS n,md5(COALESCE(string_agg(to_jsonb(t)::text,'|' ORDER BY to_jsonb(t)::text),'')) AS checksum FROM "${tablename}" t`;
        assert.deepEqual((await admins[1].query(query)).rows,(await admins[0].query(query)).rows,tablename);
      }
    });
    await t.test('restored runtime keeps restricted role and restored ACLs',async()=>{
      assert.equal(restored.databaseRestricted,true);
      for(const sql of ['CREATE ROLE forbidden_recovery','CREATE TABLE forbidden_recovery(id int)','DELETE FROM ca_team','DELETE FROM ca_access_migration'])await assert.rejects(()=>restored.pool.query(sql));
      const flags=(await admins[1].query("SELECT rolsuper,rolcreatedb,rolcreaterole,rolreplication,rolbypassrls FROM pg_roles WHERE rolname='auth_app'")).rows[0];assert.ok(Object.values(flags).every(value=>value===false));
    });
    await t.test('restored valid sessions and previous session revocation are distinct',async()=>{
      assert.equal((await call(targetServer,'account/me',undefined,'guest.a')).status,200);
      assert.equal((await call(targetServer,'account/me',undefined,'guest.b')).status,401);
    });
    await t.test('membership, participation and exact location remain separate after restore',async()=>{
      assert.equal((await call(targetServer,`access/events/${event}/location`)).status,401);
      assert.equal((await call(targetServer,`access/events/${event}/location`,undefined,'team')).status,404);
      const location=await call(targetServer,`access/events/${event}/location`,undefined,'guest.a');assert.equal(location.status,200);assert.equal(location.headers['cache-control'],'no-store');
      assert.equal((await call(targetServer,`directory/events/${event}`,undefined,'guest.a')).data.exact_location,undefined);
      const membership=(await admins[1].query('SELECT id FROM ca_membership WHERE user_id=$1',[fixture.users['guest.a'].id])).rows[0].id;
      assert.equal((await call(targetServer,`access/memberships/${membership}/revoke`,{},'organizer')).status,200);
      assert.equal((await call(targetServer,`access/events/${event}/location`,undefined,'guest.a')).status,404);
    });
    await t.test('owner recovery invalidates restored sessions and account recovery links',async()=>{
      assert.ok((await admins[1].query('SELECT 1 FROM local_account_link')).rowCount>0);
      await admins[1].query('BEGIN; DELETE FROM session; DELETE FROM verification; DELETE FROM local_account_link; COMMIT;');
      assert.equal((await call(targetServer,'account/me',undefined,'organizer')).status,401);
      assert.equal((await admins[1].query('SELECT 1 FROM local_account_link')).rowCount,0);
      const fresh=await call(targetServer,'auth/sign-in/email',{email:'organizer@example.invalid',password:fixture.password});assert.equal(fresh.status,200);
    });
  }finally{
    key.fill(0);
    await Promise.all(servers.map(server=>new Promise(resolve=>server.close(resolve))));
    await Promise.all([...pools,...admins].map(pool=>pool.end()));
  }
});

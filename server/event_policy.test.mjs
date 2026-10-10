import assert from 'node:assert/strict';

// Integrated into the existing real-HTTP, fresh-PostgreSQL directory suite.
export async function eventPolicyTests(t,state,f,call,tokens){
 const host=tokens['host.b'],guest=tokens['guest.c'];
 const user=f.users['guest.c'];
 const when=h=>new Date(Date.now()+h*3600000).toISOString();
 const profileBody={create:true,name:'Demo Policy Privatprofil',description:'Synthetischer Regeltest.',
  awareness_concept:true,awareness_team:false,is_public:false,allow_application:false,allow_form:false,allow_link:false,form:[],community_ids:[f.community]};
 const profile=(await call('directory/manage/profile',profileBody,host)).data.id;
 const body={profile_id:profile,title:'Demo Policy Werbeabend',community_id:f.community,status:'published',
  is_public:true,access_mode:'semi_public',review_method:'manual',starts_at:when(24),starts_public:false,
  public_location:'Demo Policy Geheimort',location_public:false,time_release_at:when(-1),location_release_at:when(-1),
  request_deadline_at:when(12),
  exact_location:'Demo Policy Exaktgeschützter Ort',
  access_details:{awareness_notes:'Demo Policy Geheiminformation'},
  event_content:{description:'Synthetischer beworbener Abend.',genres:['PolicyGenre'],ends_at:when(48)}};
 const event=(await call('directory/manage/event',body,host)).data.id;
 const read=(id,token)=>call(`directory/events/${id}`,undefined,token);
 const upcoming=(q='',token)=>call('directory/events?scope=upcoming&q='+encodeURIComponent(q),undefined,token);
 const item=(r,id=event)=>r.data.events.find(e=>e.id===id);
 const fields=['title','starts_at','location','organizer_id','organizer','series_id','series','event_content','access_details','request_deadline_at','interest_count'];
 function same(a,b){for(const key of fields)assert.deepEqual(a[key],b[key],key);}
 try {
  await t.test('unified policy: anonymous semi-public detail, preview and home mask identical fields',async()=>{
   const detail=await read(event);assert.equal(detail.status,200);
   const preview=await call('directory/manage/preview',{id:event,audience:'anonymous'},host);
   assert.equal(preview.data.visible,true);same(preview.data,detail.data);
   same(item(await call('directory/home')),detail.data);
   same(item(await upcoming('Policy Werbeabend')),detail.data);
   assert.equal(detail.data.organizer_id,null);assert.equal(detail.data.location,'');
   assert.equal(JSON.stringify(detail.data).includes('Policy Geheim'),false);
  });
  await t.test('unified policy: semi-public bookmark stays visible without granting profile or participation',async()=>{
   const saved=await call('directory/bookmark',{kind:'event',id:event,saved:true},guest);assert.equal(saved.status,200);
   const bookmark=item(await call('directory/bookmarks',undefined,guest));assert.equal(bookmark.id,event);
   assert.equal((await call(`directory/organizers/${profile}`,undefined,guest)).status,404);
   assert.equal((await state.pool.query('SELECT 1 FROM ca_event_interest WHERE event_id=$1 AND user_id=$2',[event,user.id])).rowCount,0);
   const detail=(await read(event)).data;assert.equal(detail.interest_count,1);
   for(const key of fields.filter(k=>!['event_content','access_details'].includes(k)))assert.deepEqual(bookmark[key],detail[key],key);
   assert.equal(item(await call('directory/home')).interest_count,1);
   assert.equal(item(await upcoming('Policy Werbeabend')).interest_count,1);
  });
  await t.test('unified policy: search cannot match protected profiles, places or awareness notes',async()=>{
   for(const q of ['Policy Privatprofil','Policy Geheimort','Policy Geheiminformation'])assert.equal(item(await upcoming(q)),undefined,q);
   assert.equal(item(await upcoming('PolicyGenre')).id,event);
  });
  await t.test('unified policy: hidden start does not change ordering or upcoming inclusion',async()=>{
   const second=(await call('directory/manage/event',{...body,title:'Demo Policy Zweiter Abend',starts_at:when(36)},host)).data.id;
   const ids=r=>r.data.events.filter(e=>[event,second].includes(e.id)).map(e=>e.id);
   const before=ids(await call('directory/home'));
   await state.pool.query('UPDATE ca_event SET starts_at=$2 WHERE id=$1',[event,when(-2)]);
   assert.deepEqual(ids(await call('directory/home')),before);
   assert.deepEqual(ids(await upcoming('Demo Policy')),before);
   assert.equal((await read(event)).data.starts_at,null);
   await state.pool.query('UPDATE ca_event SET starts_at=$2 WHERE id=$1',[event,body.starts_at]);
  });
  await t.test('unified policy: explicit event visibility still cannot unlock semi-public time or location',async()=>{
   assert.equal((await call('directory/manage/grant',{kind:'event',id:event,email:user.email},host)).status,200);
   const detail=(await read(event,guest)).data;
   assert.equal(detail.starts_at,null);assert.equal(detail.location,'');
   same((await call('directory/manage/preview',{id:event,audience:'event'},host)).data,detail);
   assert.equal((await call(`access/events/${event}/location`,undefined,guest)).status,404);
   assert.equal((await call(`directory/events/${event}/interest`,{answers:{}},guest)).status,200);
   assert.equal((await call('directory/manage/interest',{event_id:event,user_id:user.id,version:1,status:'approved'},host)).status,200);
   const confirmed=(await read(event,guest)).data;
   assert.equal(confirmed.starts_at,body.starts_at);assert.equal(confirmed.location,body.public_location);
   assert.equal((await call(`access/events/${event}/location`,undefined,guest)).data.location,body.exact_location);
   assert.equal((await call('directory/manage/preview',{id:event,audience:'confirmed'},host)).data.exact_location_available,true);
   assert.equal(JSON.stringify(confirmed).includes(body.exact_location),false);
   same((await call('directory/manage/preview',{id:event,audience:'confirmed'},host)).data,confirmed);
   same(item(await call('directory/home',undefined,guest)),confirmed);
  });
  await t.test('unified policy: profile revocation masks all future reads and forbids renewed grants',async()=>{
   assert.equal((await state.pool.query('SELECT 1 FROM ca_profile_request WHERE profile_id=$1 AND user_id=$2',[profile,user.id])).rowCount,0);
   await state.pool.query("INSERT INTO ca_profile_request(profile_id,user_id,method,status) VALUES($1,$2,'application','approved')",[profile,user.id]);
   const request=(await state.pool.query('SELECT id FROM ca_profile_request WHERE profile_id=$1 AND user_id=$2',[profile,user.id])).rows[0];
   assert.equal((await call(`directory/requests/${request.id}/decide`,{status:'revoked'},host)).status,200);
   const detail=(await read(event,guest)).data;
   assert.equal(detail.organizer_id,null);assert.equal(detail.location,'');assert.equal(detail.starts_at,null);
   same(item(await call('directory/home',undefined,guest)),detail);
   same(item(await upcoming('Policy Werbeabend',guest)),detail);
   assert.equal((await call('directory/manage/grant',{kind:'event',id:event,email:user.email,version:1},host)).status,403);
   assert.equal((await upcoming('Policy Privatprofil',guest)).data.events.length,0);
  });
  await t.test('unified policy: final public mode is checked, including updates with an omitted mode',async()=>{
   const invalid=await call('directory/manage/event',{...body,access_mode:'public',is_public:false,starts_public:true,location_public:true},host);
   assert.equal(invalid.status,422);assert.equal(invalid.data.code,'PUBLIC_PROFILE_REQUIRED');
   const p=(await call(`directory/manage?profile_id=${profile}`,undefined,host)).data.profile;
   assert.equal((await call('directory/manage/profile',{...p,is_public:true},host)).status,200);
   const created=await call('directory/manage/event',{...body,title:'Demo Policy Public',access_mode:'public',is_public:false,starts_public:true,location_public:true},host);
   assert.equal(created.status,200);
   const current=(await call(`directory/manage?profile_id=${profile}`,undefined,host)).data;
   assert.equal((await call('directory/manage/profile',{...current.profile,is_public:false},host)).status,200);
   const update={...current.events.find(e=>e.id===created.data.id),is_public:false};delete update.access_mode;
   assert.equal((await call('directory/manage/event',update,host)).data.code,'PUBLIC_PROFILE_REQUIRED');
  });
  await t.test('unified policy: upcoming search matches public organizer and venue, excludes past and cancelled events',async()=>{
   const publicName=(await call('directory/manage',undefined,tokens['host.a'])).data.profiles.find(p=>p.id===f.profiles['host.a'].id).name;
   assert.ok((await upcoming(publicName)).data.events.length>0);
   assert.ok((await upcoming('Kulturhalle')).data.events.length>0);
   assert.equal((await upcoming('Vergangener')).data.events.length,0);
   assert.equal((await upcoming('Abgesagter')).data.events.length,0);
   assert.equal((await call('directory/events?q=Vergangener')).data.events.length,1);
   assert.equal((await call('directory/events?scope=unknown')).status,422);
  });
  await t.test('unified policy: private events remain searchable only for their currently authorized viewer',async()=>{
   const id=(await call('directory/manage/event',{...body,title:'Demo Policy Private Suche',access_mode:'private',is_public:false},host)).data.id;
   assert.equal((await call('directory/manage/grant',{kind:'event',id,email:f.users['guest.d'].email},host)).status,200);
   const token=tokens['guest.d'];
   assert.equal(item(await upcoming('Private Suche'),id),undefined);
   assert.equal(item(await upcoming('Private Suche',token),id).id,id);
   assert.equal((await call('directory/bookmark',{kind:'event',id,saved:true},token)).status,200);
   const grant=(await state.pool.query('SELECT id,version FROM ca_event_grant WHERE event_id=$1',[id])).rows[0];
   assert.equal((await call('directory/manage/revoke',{kind:'event',...grant},host)).status,200);
   assert.equal((await read(id,token)).status,404);
   assert.equal(item(await upcoming('Private Suche',token),id),undefined);
   assert.equal((await call('directory/bookmarks',undefined,token)).data.events.some(e=>e.id===id),false);
   assert.equal((await call('directory/home',undefined,token)).data.events.some(e=>e.id===id),false);
  });
  await t.test('unified policy: membership can show an event without revealing its private profile or granting participation',async()=>{
   const uid=f.users['guest.b'].id,token=tokens['guest.b'];
   const id=(await call('directory/manage/event',{...body,title:'Demo Policy Mitgliederabend',access_mode:'private',is_public:false,membership_required:true},host)).data.id;
   const membership=(await state.pool.query('INSERT INTO ca_membership(community_id,user_id) VALUES($1,$2) RETURNING id',[f.community,uid])).rows[0];
   try{
    const detail=(await read(id,token)).data;assert.equal(detail.id,id);assert.equal(detail.organizer_id,null);
    const preview=(await call('directory/manage/preview',{id,audience:'member'},host)).data;
    assert.equal(preview.visible,true);same(preview,detail);
    same(item(await upcoming('Mitgliederabend',token),id),detail);
    assert.equal((await call('directory/bookmark',{kind:'event',id,saved:true},token)).status,200);
    assert.equal((await call('directory/bookmarks',undefined,token)).data.events.some(e=>e.id===id),true);
    assert.equal((await call(`access/events/${id}/location`,undefined,token)).status,404);
    await state.pool.query('UPDATE ca_membership SET active=false WHERE id=$1',[membership.id]);
    assert.equal((await read(id,token)).status,404);
    assert.equal(item(await upcoming('Mitgliederabend',token),id),undefined);
    assert.equal((await call('directory/bookmarks',undefined,token)).data.events.some(e=>e.id===id),false);
   }finally{await state.pool.query('DELETE FROM ca_membership WHERE id=$1',[membership.id]);}
  });
 }finally{await state.pool.query('DELETE FROM ca_organizer WHERE id=$1',[profile]);}
}

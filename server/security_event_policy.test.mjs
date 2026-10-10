import assert from 'node:assert/strict';

// Negative security cases run through real HTTP and the suite's fresh PostgreSQL.
export async function securityEventPolicyTests(t,state,f,call,tokens){
 const host=tokens['host.b'],guest=tokens['guest.d'],uid=f.users['guest.d'].id;
 const when=h=>new Date(Date.now()+h*3600000).toISOString();
 const profile=(await call('directory/manage/profile',{create:true,name:'Demo Security Privatprofil',
  description:'Synthetische Sicherheitsprüfung.',awareness_concept:true,awareness_team:false,
  is_public:false,allow_application:false,allow_form:false,allow_link:false,form:[],community_ids:[f.community]},host)).data.id;
 const body={profile_id:profile,title:'Demo Security Abend',community_id:f.community,status:'published',
  is_public:true,access_mode:'semi_public',review_method:'manual',starts_at:when(24),starts_public:false,
  public_location:'Demo geschützter Ort',location_public:false,time_release_at:when(36),location_release_at:when(48),
  request_deadline_at:when(12),event_content:{description:'Synthetische öffentliche Werbung.',ends_at:when(28)}};
 const create=async overrides=>{const r=await call('directory/manage/event',{...body,...overrides},host);assert.equal(r.status,200,JSON.stringify(r.data));return r.data.id;};
 const read=(id,token=guest)=>call(`directory/events/${id}`,undefined,token);
 const access=(id,token=guest)=>call(`directory/events/${id}/access`,undefined,token);
 const request=id=>call(`directory/events/${id}/interest`,{answers:{}},guest);
 const withdraw=(id,token=guest)=>call(`directory/events/${id}/withdraw`,{},token);
 const home=async id=>(await call('directory/home',undefined,guest)).data.events.find(e=>e.id===id);
 const search=async id=>(await call('directory/events?scope=upcoming&q=Demo%20Security',undefined,guest)).data.events.find(e=>e.id===id);
 const shift=async (id,start,end)=>state.pool.query("UPDATE ca_event SET starts_at=$2,event_content=jsonb_set(event_content,'{ends_at}',to_jsonb($3::text)) WHERE id=$1",[id,when(start),when(end)]);
 try{
  await t.test('security: public deadline is explicit, validated, persisted and not inferred for old events',async()=>{
   for(const deadline of [null,'',false,'2026-10-05']){
    const r=await call('directory/manage/event',{...body,request_deadline_at:deadline},host);assert.equal(r.status,422);
   }
   const id=await create({});assert.equal((await read(id)).data.request_deadline_at,body.request_deadline_at);
   const current=(await call(`directory/manage?profile_id=${profile}`,undefined,host)).data.events.find(e=>e.id===id);
   delete current.request_deadline_at;
   assert.equal((await call('directory/manage/event',current,host)).status,200);
   assert.equal((await read(id)).data.request_deadline_at,body.request_deadline_at);
   // Simulate an existing row. Schema reapplication must not manufacture a date.
   await state.pool.query('UPDATE ca_event SET request_deadline_at=NULL WHERE id=$1',[id]);
   const old=(await access(id)).data;assert.equal(old.request_deadline_at,null);assert.equal(old.before_start,null);assert.equal(old.can_request,false);
   assert.equal((await request(id)).data.code,'REQUEST_CLOSED');
  });
  await t.test('security: hidden begin and end cannot change access metadata or request responses',async()=>{
   const id=await create({});
   const beforeAnon=(await access(id,null)).data,before=(await access(id)).data;
   assert.equal(before.before_start,null);assert.equal(before.can_visit,false);assert.equal(before.can_request,true);
   assert.equal((await request(id)).status,200);assert.equal((await withdraw(id)).status,200);
   // Ignore only the viewer's own request history when comparing static metadata.
   await state.pool.query('DELETE FROM ca_event_interest WHERE event_id=$1',[id]);
   await shift(id,-2,-1);
   assert.deepEqual((await access(id,null)).data,beforeAnon);assert.deepEqual((await access(id)).data,before);
   assert.equal((await read(id)).data.starts_at,null);assert.equal((await read(id)).data.event_content.ends_at,null);
   assert.equal((await request(id)).status,200);
   const decision=await call('directory/manage/interest',{event_id:id,user_id:uid,version:1,status:'approved'},host);
   assert.equal(decision.status,409);assert.equal(decision.data.code,'EVENT_STARTED'); // owner knows the actual begin
   assert.equal((await withdraw(id)).status,200); // protected begin is not the public withdrawal cutoff
  });
  await t.test('security: public deadline closes requests and protected withdrawals independently of begin',async()=>{
   const id=await create({});assert.equal((await request(id)).status,200);
   await state.pool.query('UPDATE ca_event SET request_deadline_at=$2 WHERE id=$1',[id,when(-1)]);
   const before=(await access(id)).data;
   assert.equal(before.before_start,null);assert.equal(before.can_request,false);assert.equal(before.can_withdraw,false);
   assert.equal((await request(id)).data.code,'REQUEST_CLOSED');assert.equal((await withdraw(id)).data.code,'REQUEST_CLOSED');
   await shift(id,-2,-1);assert.deepEqual((await access(id)).data,before);
   assert.equal((await request(id)).data.code,'REQUEST_CLOSED');assert.equal((await withdraw(id)).data.code,'REQUEST_CLOSED');
  });
  await t.test('security: withdrawal denies private, unknown, draft and foreign targets uniformly',async()=>{
   const id=await create({access_mode:'private',is_public:false});
   assert.equal((await read(id)).status,404);
   for(const [start,end] of [[24,28],[-2,-1]]){
    await shift(id,start,end);const r=await withdraw(id);assert.equal(r.status,404);assert.equal(r.data.code,'NOT_FOUND');
   }
   const stranger=tokens['guest.c'];
   const visible=await create({});assert.equal((await request(visible)).status,200);
   const future=await withdraw(visible,stranger);await shift(visible,-2,-1);const past=await withdraw(visible,stranger);
   assert.deepEqual(past.data,future.data);assert.equal(past.status,404);
   const unknown=await withdraw('00000000-0000-4000-8000-000000000099');assert.equal(unknown.status,404);assert.deepEqual(unknown.data,future.data);
   const draft=await create({status:'draft'});assert.equal((await withdraw(draft)).status,404);
   assert.equal((await withdraw(visible)).status,200);
   const duplicate=await withdraw(visible);assert.equal(duplicate.status,404);assert.deepEqual(duplicate.data,future.data);
  });
  await t.test('security: a hidden end cannot enable visits even for confirmed attendance until release',async()=>{
   const id=await create({});assert.equal((await request(id)).status,200);
   assert.equal((await call('directory/manage/interest',{event_id:id,user_id:uid,version:1,status:'approved'},host)).status,200);
   await shift(id,-2,-1);
   assert.equal((await access(id)).data.can_visit,false);
   assert.equal((await call(`directory/events/${id}/visit`,{},guest)).status,403);
   await state.pool.query('UPDATE ca_event SET time_release_at=$2 WHERE id=$1',[id,when(-3)]);
   assert.equal((await access(id)).data.can_visit,true);
   assert.equal((await call(`directory/events/${id}/visit`,{},guest)).status,200);
   assert.equal((await access(id,tokens['guest.c'])).data.can_visit,false);
  });
  await t.test('security: revoked series bookmarks cannot change home/search reasons or ordering',async()=>{
   await state.pool.query("INSERT INTO ca_profile_request(profile_id,user_id,method,status) VALUES($1,$2,'application','approved') ON CONFLICT(profile_id,user_id) DO NOTHING",[profile,f.users['guest.d'].id]);
   const series=(await call('directory/manage/series',{profile_id:profile,title:'Demo Security Reihe',description:'Synthetische private Reihe.',community_id:f.community,is_public:false},host)).data.id;
   const id=await create({series_id:series});
   assert.equal((await call('directory/manage/grant',{kind:'event',id,email:f.users['guest.d'].email},host)).status,200);
   const grant=(await call('directory/manage/grant',{kind:'series',id:series,email:f.users['guest.d'].email},host)).data;
   assert.equal((await call('directory/bookmark',{kind:'series',id:series,saved:true},guest)).status,200);
   assert.ok((await home(id)).reasons.includes('bookmark'));
   assert.equal((await call('directory/manage/revoke',{kind:'series',...grant},host)).status,200);
   assert.equal((await call(`directory/series/${series}`,undefined,guest)).status,404);
   assert.equal((await read(id)).data.series_id,null);
   const ids=async()=> (await call('directory/home',undefined,guest)).data.events.map(e=>e.id);
   const before=await ids(),reasons=(await home(id)).reasons;
   assert.equal(reasons.includes('bookmark'),false);assert.deepEqual((await search(id)).reasons,reasons);
   assert.equal((await call('directory/bookmark',{kind:'series',id:series,saved:false},guest)).status,200);
   assert.deepEqual(await ids(),before);assert.deepEqual((await home(id)).reasons,reasons);
   assert.equal((await call('directory/bookmark',{kind:'event',id,saved:true},guest)).status,200);
   assert.ok((await home(id)).reasons.includes('bookmark')); // the independent event bookmark remains effective
  });
  await t.test('security: hidden profiles and their visit/bookmark history cannot influence recommendations',async()=>{
   const id=await create({});
   await state.pool.query('INSERT INTO ca_bookmark(user_id,profile_id) VALUES($1,$2) ON CONFLICT DO NOTHING',[uid,profile]);
   await state.pool.query('INSERT INTO ca_organizer_visit VALUES($1,$2) ON CONFLICT DO NOTHING',[uid,profile]);
   // Explicitly revoked profile access; its public advert remains viewable.
   await state.pool.query("UPDATE ca_profile_request SET status='revoked' WHERE profile_id=$1 AND user_id=$2",[profile,uid]);
   const after=await home(id);assert.equal(after.organizer_id,null);
   assert.equal(after.reasons.includes('bookmark'),false);assert.equal(after.reasons.includes('visited_organizer'),false);
   assert.deepEqual((await search(id)).reasons,after.reasons);
   await state.pool.query('DELETE FROM ca_bookmark WHERE user_id=$1 AND profile_id=$2',[uid,profile]);
   await state.pool.query('DELETE FROM ca_organizer_visit WHERE user_id=$1 AND profile_id=$2',[uid,profile]);
   assert.deepEqual((await home(id)).reasons,after.reasons);
  });
 }finally{await state.pool.query('DELETE FROM ca_organizer WHERE id=$1',[profile]);}
}

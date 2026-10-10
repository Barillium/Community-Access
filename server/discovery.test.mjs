import assert from 'node:assert/strict';

// Called by directory.test with its real, fresh, synthetic database and HTTP server.
export async function discoveryTests(t,state,f,call,tokens){
 const host=tokens['host.a'],guest=tokens['guest.c'];
 const when=hours=>new Date(Date.now()+hours*3600000).toISOString();
 const profileBody={create:true,name:'Demo Discovery Veranstalter',description:'Synthetische Selbstdarstellung',awareness_concept:true,awareness_team:false,is_public:false,allow_application:false,allow_form:false,allow_link:false,form:[],community_ids:[f.community]};
 let profile;
 await t.test('discovery: forms, timed semi-public release, preferences and retention',async t=>{
  const created=await call('directory/manage/profile',profileBody,host);assert.equal(created.status,200);profile=created.data.id;
  try{
   await t.test('mandatory awareness facts and description, including an explicit no',async()=>{
    assert.equal((await call('directory/manage/profile',{...profileBody,awareness_concept:null},host)).status,422);
    assert.equal((await call('directory/manage/profile',{...profileBody,description:''},host)).status,422);
    const m=(await call('directory/manage',undefined,host)).data.profiles.find(p=>p.id===profile);
    assert.equal(m.awareness_team,false);
    assert.equal((await call(`directory/organizers/${profile}`)).status,404);
   });
   const formBody={profile_id:profile,title:'Demo Eventfragen',fields:[{key:'music',label:'Welche Musik möchtest du hören?',required:true}]};
   const saved=await call('directory/manage/form',formBody,host);assert.equal(saved.status,200);
   await t.test('form enforcement is server-side, scoped and versioned',async()=>{
    for(const label of ['Welche Religion hast du?','Telefonnummer?','Which health conditions do you have?','Beliebige noch nicht geprüfte Frage'])assert.equal((await call('directory/manage/form',{...formBody,fields:[{key:'music',label,required:true}]},host)).status,422);
    assert.equal((await call('directory/manage/form',formBody,guest)).status,404);
    assert.equal((await call('directory/manage/form',{...formBody,fields:[...formBody.fields,...formBody.fields]},host)).status,422);
    const concurrent=await Promise.all([0,1].map(()=>call('directory/manage/form',{...formBody,id:saved.data.id,version:1},host)));
    assert.deepEqual(concurrent.map(r=>r.status).sort(),[200,409]);
   });
   const eventBody={profile_id:profile,title:'Demo Secret Ambient',community_id:f.community,status:'published',is_public:true,access_mode:'semi_public',review_method:'form',form_id:saved.data.id,starts_at:when(24),starts_public:false,public_location:'Demo geschützter Treffpunkt',location_public:false,time_release_at:when(12),location_release_at:when(18),request_deadline_at:when(10),event_content:{description:'Synthetischer öffentlich beworbener Abend.',genres:['Ambient'],ends_at:when(28)}};
   const createdEvent=await call('directory/manage/event',eventBody,host);assert.equal(createdEvent.status,200);const event=createdEvent.data.id;
   await t.test('semi-public advert is public while the profile and details stay protected',async()=>{
    const detail=await call(`directory/events/${event}`);assert.equal(detail.status,200);
    assert.equal(detail.data.starts_at,null);assert.equal(detail.data.location,'');assert.equal(detail.data.organizer_id,null);
    assert.equal(detail.data.event_content.ends_at,null);assert.equal(detail.data.event_content.venue_name,'');
    assert.equal(JSON.stringify(detail.data).includes('geschützter Treffpunkt'),false);
    assert.equal((await call('directory/home')).data.events.some(e=>e.id===event),true);
    assert.equal((await call('directory/venues?q=Treffpunkt')).data.items.length,0);
    assert.equal((await call(`directory/events/${event}/interest`,{answers:{music:'Ambient'},form_version:2})).status,401);
    assert.equal((await call(`directory/events/${event}/interest`,{answers:{music:'Ambient'},form_version:2},tokens.unverified)).status,403);
    assert.equal((await call('directory/manage/event',{...eventBody,starts_at:when(-180),event_content:{...eventBody.event_content,ends_at:when(-169)}},host)).status,422);
    const current=(await call('directory/manage',undefined,host)).data.events.find(e=>e.id===event);
    for(const overrides of [{time_release_at:null},{starts_public:true},{location_public:true},{event_content:{...eventBody.event_content,ends_at:null}}])assert.equal((await call('directory/manage/event',{...current,...overrides},host)).status,422);
   });
   await t.test('interest validates snapshots, concurrent requests and organizer decisions',async()=>{
    assert.equal((await call(`directory/events/${event}/interest`,{answers:{music:'Ambient'},form_version:1},guest)).status,409);
    assert.equal((await call(`directory/events/${event}/interest`,{answers:{music:''},form_version:2},guest)).status,422);
    const interests=await Promise.all([0,1].map(()=>call(`directory/events/${event}/interest`,{answers:{music:'Ambient'},form_version:2},guest)));
    assert.deepEqual(interests.map(r=>r.status).sort(),[200,409]);
    const decision={event_id:event,user_id:f.users['guest.c'].id,version:1,status:'approved'};
    assert.equal((await call('directory/manage/interest',decision,tokens['host.b'])).status,404);
    const decisions=await Promise.all([0,1].map(()=>call('directory/manage/interest',decision,host)));
    assert.deepEqual(decisions.map(r=>r.status).sort(),[200,409]);
    assert.equal((await call(`directory/organizers/${profile}`,undefined,guest)).status,404);
    await state.pool.query("INSERT INTO ca_profile_request(profile_id,user_id,method,status) VALUES($1,$2,'application','approved')",[profile,f.users['guest.c'].id]);
    const visible=await call(`directory/organizers/${profile}`,undefined,guest);assert.equal(visible.status,200);assert.equal(visible.data.awareness_team,false);
    assert.equal(visible.data.members,undefined);assert.equal(visible.data.owner_id,undefined);
    assert.equal((await call(`directory/events/${event}`,undefined,guest)).data.starts_at,null);
   });
   await t.test('time and location release independently; profile revocation defeats admission',async()=>{
    await state.pool.query('UPDATE ca_event SET time_release_at=$2 WHERE id=$1',[event,when(-1)]);
    const timeOnly=(await call(`directory/events/${event}`,undefined,guest)).data;assert.equal(timeOnly.starts_at,eventBody.starts_at);assert.equal(timeOnly.location,'');
    await state.pool.query('UPDATE ca_event SET location_release_at=$2 WHERE id=$1',[event,when(-1)]);
    assert.equal((await call(`directory/events/${event}`,undefined,guest)).data.location,eventBody.public_location);
    assert.equal((await call(`directory/events/${event}`)).data.location,'');
    const preview=(await call('directory/manage/preview',{id:event,audience:'anonymous'},host)).data;assert.equal(preview.starts_at,null);assert.equal(preview.location,'');
    const accepted=(await call('directory/manage/preview',{id:event,audience:'confirmed'},host)).data;assert.equal(accepted.location,eventBody.public_location);
    const request=(await state.pool.query('SELECT id FROM ca_profile_request WHERE profile_id=$1 AND user_id=$2',[profile,f.users['guest.c'].id])).rows[0];
    assert.equal((await call(`directory/requests/${request.id}/decide`,{status:'revoked'},host)).status,200);
    assert.equal((await call(`directory/organizers/${profile}`,undefined,guest)).status,404);
    assert.equal((await call(`directory/events/${event}`,undefined,guest)).data.location,'');
    assert.equal((await call('directory/manage/grant',{kind:'event',id:event,email:f.users['guest.c'].email},host)).status,403);
    // Restore only this isolated synthetic fixture, to test the independent retention path.
    await state.pool.query("UPDATE ca_profile_request SET status='approved' WHERE id=$1",[request.id]);
   });
   await t.test('private preferences and follows influence ranking without revealing protected fields',async()=>{
    assert.equal((await call('directory/preferences')).status,401);
    assert.equal((await call('directory/preferences',{music:['Ambient'],event_types:['Clubnacht'],favorites:[],leisure:[]},guest)).status,200);
    assert.equal((await call('directory/preferences',{music:Array(13).fill('Ambient')},guest)).status,422);
    assert.equal((await call('directory/preferences',{music:['x'.repeat(81)]},guest)).status,422);
    assert.equal((await call('directory/follow',{id:f.privateCommunity,following:true},guest)).status,404);
    assert.equal((await call('directory/follow',{id:f.community,following:true},guest)).status,200);
    const home=(await call('directory/home',undefined,guest)).data;assert.equal(home.signed_in,true);
    const recommended=home.events.find(e=>e.id===event);assert.ok(recommended.reasons.includes('preferences'));assert.ok(recommended.reasons.includes('community'));
    const anonymous=(await call('directory/home')).data;assert.deepEqual(home.hero,anonymous.hero);assert.equal(anonymous.signed_in,false);assert.deepEqual(anonymous.events.find(e=>e.id===event).reasons,[]);
    assert.equal(JSON.stringify(anonymous).includes('guest.c'),false);
    const privateEvent=await call('directory/manage/event',{...eventBody,title:'Demo persönlich freigeschalteter Abend',access_mode:'private',is_public:false,review_method:'manual',form_id:null},host);assert.equal(privateEvent.status,200);
    assert.equal((await call('directory/manage/grant',{kind:'event',id:privateEvent.data.id,email:f.users['guest.c'].email},host)).status,200);
    assert.equal((await call('directory/home',undefined,guest)).data.events.some(e=>e.id===privateEvent.data.id),true);
    assert.equal((await call('directory/home')).data.events.some(e=>e.id===privateEvent.data.id),false);
   });
   await t.test('deleting a synthetic guest account removes every independent profile and preference access',async()=>{
    const signup=await state.auth.api.signUpEmail({body:{name:'Demo gelöschter Gast',email:'deleted.discovery@example.invalid',password:f.password}});
    const uid=signup.user.id;
    try{
     await state.pool.query('UPDATE "user" SET "emailVerified"=true WHERE id=$1',[uid]);
     const token=(await call('auth/sign-in/email',{email:'deleted.discovery@example.invalid',password:f.password})).headers['set-auth-token'];
     const e=await call('directory/manage/event',{...eventBody,title:'Demo Kontolöschung',access_mode:'private',is_public:false,review_method:'manual',form_id:null},host);assert.equal(e.status,200);
     assert.equal((await call('directory/manage/grant',{kind:'event',id:e.data.id,email:'deleted.discovery@example.invalid'},host)).status,200);
     assert.equal((await call(`directory/organizers/${profile}`,undefined,token)).status,404);
     await state.pool.query("INSERT INTO ca_profile_request(profile_id,user_id,method,status) VALUES($1,$2,'application','approved')",[profile,uid]);
     assert.equal((await call(`directory/organizers/${profile}`,undefined,token)).status,200);
     assert.equal((await call('directory/preferences',{music:['Ambient']},token)).status,200);
     await state.pool.query('INSERT INTO ca_organizer_visit VALUES($1,$2)',[uid,profile]);
     await state.pool.query('DELETE FROM "user" WHERE id=$1',[uid]);
     assert.equal((await call(`directory/organizers/${profile}`,undefined,token)).status,401);
     for(const table of ['ca_event_grant','ca_profile_request','ca_guest_preferences','ca_organizer_visit'])assert.equal((await state.pool.query(`SELECT 1 FROM ${table} WHERE user_id=$1`,[uid])).rowCount,0);
    }finally{await state.pool.query('DELETE FROM "user" WHERE id=$1',[uid]);}
   });
   await t.test('attendance records only an organizer association; seven-day expiry cascades every event link',async()=>{
    assert.equal((await call(`directory/events/${event}/visit`,{},guest)).status,409);
    await state.pool.query("UPDATE ca_event SET starts_at=$2,event_content=jsonb_set(event_content,'{ends_at}',to_jsonb($3::text)) WHERE id=$1",[event,when(-5),when(-1)]);
    assert.equal((await call(`directory/events/${event}/visit`,{},guest)).status,200);
    assert.equal((await call(`directory/events/${event}/visit`,{},guest)).status,200);
    assert.deepEqual((await state.pool.query('SELECT * FROM ca_organizer_visit WHERE profile_id=$1',[profile])).rows,[{user_id:f.users['guest.c'].id,profile_id:profile}]);
    assert.equal((await call('directory/bookmark',{kind:'event',id:event,saved:true},guest)).status,200);
    await state.pool.query("UPDATE ca_event SET event_content=jsonb_set(event_content,'{ends_at}',to_jsonb($2::text)) WHERE id=$1",[event,when(-168)]);
    const purges=await Promise.all([state.directory.discovery.purge(),state.directory.discovery.purge()]);assert.equal(purges.reduce((n,r)=>n+r.deleted,0),1);
    for(const table of ['ca_event_interest','ca_event_grant','ca_bookmark'])assert.equal((await state.pool.query(`SELECT 1 FROM ${table} WHERE event_id=$1`,[event])).rowCount,0);
    assert.equal((await call(`directory/events/${event}`,undefined,guest)).status,404);
    assert.equal((await call(`directory/organizers/${profile}`,undefined,guest)).status,200);
    assert.equal((await state.pool.query('SELECT 1 FROM ca_organizer_visit WHERE profile_id=$1',[profile])).rowCount,1);
    assert.equal((await call('directory/preferences',undefined,guest)).data.visited_organizers[0].id,profile);
    assert.equal((await call('directory/forget-visit',{id:profile},tokens['guest.d'])).status,200);
    assert.equal((await state.pool.query('SELECT 1 FROM ca_organizer_visit WHERE profile_id=$1',[profile])).rowCount,1);
    assert.equal((await call('directory/forget-visit',{id:profile},guest)).status,200);
    assert.equal((await state.pool.query('SELECT 1 FROM ca_organizer_visit WHERE profile_id=$1',[profile])).rowCount,0);
    assert.equal(JSON.stringify((await call('directory/manage',undefined,host)).data).includes('Demo Secret Ambient'),false);
   });
  }finally{
   await state.pool.query('DELETE FROM ca_organizer WHERE id=$1',[profile]);
   await state.pool.query('DELETE FROM ca_guest_preferences WHERE user_id=$1',[f.users['guest.c'].id]);
   await state.pool.query('DELETE FROM ca_community_follow WHERE user_id=$1',[f.users['guest.c'].id]);
  }
 });
}

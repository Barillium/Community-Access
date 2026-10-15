import assert from 'node:assert/strict';

// Invoked only inside the existing fresh synthetic PostgreSQL/HTTP suite.
export async function communityCountTests(t,state,f,call,tokens){
 await t.test('community counts respect current visibility, dates and approved assignments',async()=>{
  const ids=[];
  const extra=(await state.pool.query("INSERT INTO ca_community(name,is_public) VALUES('Demo Zählgemeinschaft',true) RETURNING id")).rows[0].id;
  const count=async(community,token)=>{
   const response=await call('directory/communities',undefined,token);
   assert.equal(response.status,200);
   const item=response.data.items.find(c=>c.id===community);
   assert.ok(Number.isInteger(item?.event_count));return item.event_count;
  };
  const base=await count(f.community);
  const guest=tokens['guest.a'];const guestBase=await count(f.community,guest);
  try{
   assert.equal(await count(extra),0);
   for(const [name,mode,status,hours] of [
    ['kommend','public','published',24],['geschützt','private','published',24],
    ['Entwurf','public','draft',24],['abgesagt','public','cancelled',24],
    ['vergangen','public','published',-24]]){
    const starts=new Date(Date.now()+hours*3600000).toISOString();
    const event=await state.directory.saveEvent(f.users['host.a'],{
     profile_id:f.profiles['host.a'].id,community_id:f.community,
     title:`Demo Zähler ${name}`,access_mode:mode,is_public:mode==='public',status,
     starts_at:starts,starts_public:true,location_public:true,public_location:'Demo Zählort',
     event_content:{description:'Synthetische Zählprüfung.',ends_at:new Date(Date.parse(starts)+4*3600000).toISOString()}
    });ids.push(event.id);
   }
   assert.equal(await count(f.community),base+1);
   assert.equal(await count(f.community,guest),guestBase+1);
   await state.pool.query('INSERT INTO ca_event_grant(event_id,user_id) VALUES($1,$2)',[ids[1],f.users['guest.a'].id]);
   assert.equal(await count(f.community,guest),guestBase+2);
   assert.equal(await count(f.community),base+1,'private counts must not leak to anonymous viewers');
   await state.pool.query('UPDATE ca_event_grant SET active=false WHERE event_id=$1',[ids[1]]);
   assert.equal(await count(f.community,guest),guestBase+1);
   await state.pool.query('INSERT INTO ca_event_community_access VALUES($1,$2,false,false)',[ids[0],extra]);
   assert.equal(await count(extra),0,'pending associations are not assigned publications');
   await state.pool.query('UPDATE ca_event_community_access SET approved=true WHERE event_id=$1 AND community_id=$2',[ids[0],extra]);
   assert.equal(await count(extra),1);
   assert.equal(await count(f.community),base+1,'primary assignment plus approved link does not double count');
   await state.pool.query("UPDATE ca_event SET legal_state='blocked' WHERE id=$1",[ids[0]]);
   assert.equal(await count(extra),0);
   assert.equal(await count(f.community),base);
   const list=(await call('directory/communities')).data.items;
   assert.equal(list.some(c=>c.id===f.privateCommunity),false);
  }finally{
   for(const id of ids)await state.pool.query('DELETE FROM ca_event WHERE id=$1',[id]);
   await state.pool.query('DELETE FROM ca_community WHERE id=$1',[extra]);
  }
 });
}

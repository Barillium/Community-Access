import {extendedProduct} from './product_scope.mjs';
// Legacy authorization fixtures now also supply real synthetic ends for retention.
export function datedEventFixture(body){
 if(body.id||body.access_mode||body.status==='draft'||body.event_content)return body;
 const start=body.starts_at??new Date(Date.now()+24*3600000).toISOString();
 const parsed=Date.parse(start);
 return {...body,starts_at:start,event_content:{description:'Synthetische Veranstaltungsbeschreibung.',ends_at:new Date(Number.isFinite(parsed)?parsed+4*3600000:Date.now()+28*3600000).toISOString()}};
}
// Explicit synthetic fixtures. Never invoked by ordinary account creation.
export async function seedDirectory(state) {
  if (state.privateMail || !state.directory) throw new Error('Synthetic directory required.');
  if ((await state.pool.query('SELECT 1 FROM ca_community LIMIT 1')).rowCount) throw new Error('Fixture catalog must be empty.');
  const password='Synthetic-2026!';
  const users={};
  for(const key of ['host.a','host.b','guest.a','guest.b','guest.c','guest.d','unverified']) {
    const email=`${key}@example.invalid`;
    const result=await state.auth.api.signUpEmail({body:{name:`Demo ${key}`,email,password}});
    if(key!=='unverified') await state.pool.query('UPDATE "user" SET "emailVerified"=true WHERE id=$1',[result.user.id]);
    users[key]={...result.user,emailVerified:key!=='unverified'};
  }
  const community=(await state.pool.query("INSERT INTO ca_community(name,is_public) VALUES('Demo Musik & Clubkultur',true) RETURNING id")).rows[0].id;
  const privateCommunity=(await state.pool.query("INSERT INTO ca_community(name,is_public) VALUES('Private Demo-Community',false) RETURNING id")).rows[0].id;
  for(const key of ['host.a','host.b']) await state.pool.query('INSERT INTO ca_host VALUES($1,$2)',[users[key].id,community]);
  await state.pool.query('INSERT INTO ca_host VALUES($1,$2)',[users['host.b'].id,privateCommunity]);
  // Explicit test moderator appointments; ca_host alone conveys no administration.
  for(const [key,c] of [['host.a',community],['host.b',community],['host.b',privateCommunity]])await state.pool.query("INSERT INTO ca_community_staff VALUES($1,$2,NOW()+INTERVAL '30 days')",[c,users[key].id]);
  const profiles={};
  for(const key of ['host.a','host.b']) profiles[key]=await state.directory.save(users[key],{
    name:key==='host.a'?'Demo Veranstalter Wolkenwinkel':'Demo Veranstalter Abendlicht',description:'Synthetisches Veranstalterprofil für die lokale Prüfung.',
    awareness_concept:true,awareness_team:false,is_public:key==='host.a',allow_application:extendedProduct,allow_form:extendedProduct,allow_link:extendedProduct,
    form:[{key:'interest',label:'Was interessiert dich an unserem Programm?',required:true}],
    community_ids:key==='host.a'?[community]:[community,privateCommunity],
  });
  for(const event of [
    {title:'Demo: Nächste Clubnacht',start:'2026-10-31T20:00:00Z',public:true,location:true,status:'published'},
    {title:'Demo: Vergangener Konzertabend',start:new Date(Date.now()-24*3600000).toISOString(),public:true,location:true,status:'published'},
    {title:'Demo: Abgesagter Abend',start:'2026-10-30T18:00:00Z',public:true,location:true,status:'cancelled'},
    {title:'Private Demo-Veranstaltung',start:'2026-10-31T18:00:00Z',public:false,location:true,status:'published'},
    {title:'Demo mit geschütztem Ort',start:'2026-10-31T18:00:00Z',public:true,location:false,status:'published'},
  ]) await state.directory.saveEvent(users['host.a'],datedEventFixture({title:event.title,community_id:community,
    status:event.status,is_public:event.public,starts_at:event.start,starts_public:true,
    public_location:event.location?'Demo Kulturhalle':'Verborgener Demo-Ort',location_public:event.location}));
  const series=!extendedProduct?null:await state.directory.catalog.saveSeries(users['host.a'],{title:'Demo Nebelreihe',description:'Synthetische Reihe für einen gesondert freigegebenen Gästekreis.',community_id:community,is_public:false});
  const hiddenEvent=!extendedProduct?null:await state.directory.saveEvent(users['host.a'],datedEventFixture({title:'Demo Nebelabend',community_id:community,series_id:series.id,
    status:'published',is_public:true,starts_at:'2026-11-14T20:00:00Z',starts_public:true,public_location:'Demo Nebelort',location_public:true}));
  return {users,profiles,community,privateCommunity,password,series,hiddenEvent};
}

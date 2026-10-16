// Isolated, explicitly synthetic associations. Real events receive no inferred affiliations.
export function createCommunityPreview(now=Date.now()) {
 const communities=[
  {id:'10000000-0000-4000-8000-000000000001',name:'Studio Zwischenraum'},
  {id:'10000000-0000-4000-8000-000000000002',name:'Raum für Alle'},
  {id:'10000000-0000-4000-8000-000000000003',name:'Nachbarschaft Jetzt'},
 ].map(c=>({...c,synthetic:true,following:false}));
 const start=new Date(now);start.setUTCHours(18,0,0,0);start.setUTCDate(start.getUTCDate()+1);
 const entry=(suffix,title,days,assigned,categories,priceDe,priceEn)=>({
  id:`20000000-0000-4000-8000-${suffix.padStart(12,'0')}`,title,status:'published',
  access_mode:'public',is_public:true,ticket_mode:'none',external:true,synthetic:true,signed_in:false,
  starts_at:new Date(start.getTime()+days*86400000).toISOString(),
  communities:assigned.map(i=>({id:communities[i].id,name:communities[i].name})),
  organizer:'Demo Kulturkollektiv',organizer_id:null,location:'Demo Kulturraum · synthetischer Ort',
  event_content:{description:'Synthetische Beispielveranstaltung zum Prüfen der Communityprogramme. Keine reale Ankündigung.',
   genres:[],line_up:[],categories,venue_name:'Demo Kulturraum',admission:'Synthetische Eintrittsangabe.',
   ticket_price_label_de:priceDe,ticket_price_label_en:priceEn,
   flyer_data:'/assets/assets/images/kulturraum.webp',flyer_aspect_ratio:1942/809,
   flyer_alt:'Synthetisches Kulturmotiv'},access_details:{},
 });
 const events=[
  entry('1','Demo Nachtlinie',0,[0],['party'],'12 € · Demo','€12 · demo'),
  entry('2','Demo Offenes Atelier',1,[1],['culture','workshop'],'Eintritt frei · Demo','Free admission · demo'),
  entry('3','Demo Druckmarkt',2,[0,1],['culture'],'Eintritt frei · Demo','Free admission · demo'),
 ];
 return {communities:communities.map(c=>({...c,event_count:events.filter(e=>e.communities.some(a=>a.id===c.id)).length})),events};
}

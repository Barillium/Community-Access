import {DirectoryError} from './directory.mjs';
const invalid=()=>{throw new DirectoryError(422,'INVALID_EVENT_CONTENT');};
const string=(value,max)=>{if(typeof value!=='string'||value.length>max)invalid();return value.trim();};
// Bounded raster media only. No remote URLs, SVG, HTML or automatic external requests.
export function eventContent(value){
 if(!value||typeof value!=='object'||Array.isArray(value))invalid();
 const allowed=['description','line_up','genres','admission','minimum_age','venue_name','ends_at','flyer_data','flyer_alt'];
 if(Object.keys(value).some(k=>!allowed.includes(k)))invalid();
 const out={};
 for(const [key,max] of Object.entries({description:6000,admission:1200,venue_name:240,flyer_alt:240}))out[key]=string(value[key]??'',max);
 for(const [key,max,count] of [['line_up',180,40],['genres',40,8]]){
  const list=value[key]??[];if(!Array.isArray(list)||list.length>count)invalid();
  out[key]=list.map(v=>string(v,max));if(out[key].some(v=>!v))invalid();
 }
 out.minimum_age=value.minimum_age??null;
 if(out.minimum_age!==null&&(!Number.isInteger(out.minimum_age)||out.minimum_age<0||out.minimum_age>99))invalid();
 out.ends_at=value.ends_at??null;
 if(out.ends_at!==null){
  if(typeof out.ends_at!=='string'||out.ends_at.length>40||!/^\d{4}-\d\d-\d\dT\d\d:\d\d(?::\d\d(?:\.\d{1,3})?)?(?:Z|[+-]\d\d:\d\d)$/.test(out.ends_at)||!Number.isFinite(Date.parse(out.ends_at)))invalid();
  out.ends_at=new Date(out.ends_at).toISOString();
 }
 out.flyer_data=string(value.flyer_data??'',350000);
 if(out.flyer_data){
  if(typeof out.flyer_data!=='string'||out.flyer_data.length>350000||!/^data:image\/jpeg;base64,[A-Za-z0-9+/]+={0,2}$/.test(out.flyer_data))invalid();
  const encoded=out.flyer_data.split(',')[1],bytes=Buffer.from(encoded,'base64');
  if(bytes.length>256*1024||bytes.toString('base64')!==encoded||bytes[0]!==255||bytes[1]!==216||bytes.at(-2)!==255||bytes.at(-1)!==217)invalid();
  let offset=2,dimensions=false;
  while(offset+4<bytes.length){
   if(bytes[offset++]!==255)invalid();while(bytes[offset]===255)offset++;
   if(offset+3>bytes.length)invalid();
   const marker=bytes[offset++];if([225,254].includes(marker))invalid();if(marker===218)break;
   const length=bytes.readUInt16BE(offset);if(length<2||offset+length>bytes.length)invalid();
   if([192,193,194].includes(marker)){
    if(length<8)invalid();const height=bytes.readUInt16BE(offset+3),width=bytes.readUInt16BE(offset+5);
    if(!height||!width||height>1600||width>1600)invalid();dimensions=true;
   }
   offset+=length;
  }
  if(!dimensions||!out.flyer_alt)invalid();
 }
 return out;
}
// The same field masking is used for detail reads and host audience previews.
export const visibleEventContent=`(e.event_content - 'ends_at' - 'venue_name') || jsonb_build_object(
 'ends_at',CASE WHEN e.starts_public THEN e.event_content->'ends_at' ELSE 'null'::jsonb END,
 'venue_name',CASE WHEN e.location_public THEN COALESCE(e.event_content->'venue_name','""'::jsonb) ELSE '""'::jsonb END)`;

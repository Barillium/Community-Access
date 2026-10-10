import {extendedProduct,productEventScope} from './product_scope.mjs';
import {activeMembership,confirmedParticipation,profileNotRevoked,eventNotRestricted} from './access_policy.mjs';
import {bookmarkCount} from './interest_counts.mjs';
import {organizerManager} from './organizer_access.mjs';

// SQL expressions use e (event), p (profile), c (community), s (series), and
// $1 exclusively for the viewer. Preview supplies explicit hypothetical rights.
export const eventJoins=`FROM ca_event e JOIN ca_community c ON c.id=e.community_id
 LEFT JOIN ca_organizer p ON p.id=e.profile_id LEFT JOIN ca_series s ON s.id=e.series_id`;
export const retainedEvent=`(e.event_content->>'ends_at' IS NULL OR (e.event_content->>'ends_at')::timestamptz + INTERVAL '168 hours' > NOW())`;
export const ownerCurrent=`EXISTS(SELECT 1 FROM ca_host h WHERE h.user_id=p.owner_id AND h.community_id=c.id) AND EXISTS(SELECT 1 FROM ca_profile_community pc WHERE pc.profile_id=p.id AND pc.community_id=c.id) AND EXISTS(SELECT 1 FROM ca_community_publisher cp WHERE cp.profile_id=p.id AND cp.community_id=c.id AND cp.enabled)`;
export const communityPublication=`(e.profile_id IS NULL OR EXISTS(SELECT 1 FROM ca_event_community_access pub WHERE pub.event_id=e.id AND pub.community_id=e.community_id AND pub.approved))`;
export const publicEventBase=`${communityPublication} AND ${retainedEvent} AND e.is_public AND c.is_public AND (
 (e.profile_id IS NULL AND e.series_id IS NULL AND EXISTS(SELECT 1 FROM ca_host h WHERE h.community_id=e.community_id))
 OR ((p.is_public OR e.access_mode='semi_public') AND (e.series_id IS NULL OR s.is_public) AND ${ownerCurrent}))`;
export const publicEvent=`${productEventScope} AND (${publicEventBase})`;
export const eventInterest=`CASE WHEN (${publicEvent}) AND e.status IN ('published','cancelled') THEN ${bookmarkCount('event_id','e.id')} END`;
export const previewAudiences=['anonymous','profile','series','event','member','confirmed'];

export function eventPolicy(audience=null,{extended=extendedProduct}={}){
 const scope=extended?'TRUE':productEventScope;
 const publicRule=extended?publicEventBase:publicEvent;
 if(audience!==null&&!previewAudiences.includes(audience))throw new RangeError('Unknown preview audience');
 const hypothetical=audience!==null;
 const owns=hypothetical?'false':organizerManager();
 const unblocked=hypothetical?'true':profileNotRevoked;
 const member=hypothetical?String(['member','confirmed'].includes(audience)):activeMembership;
 const profileGrant=!extended?'false':hypothetical?String(['profile','series'].includes(audience)):
  `EXISTS(SELECT 1 FROM ca_profile_request pr WHERE pr.profile_id=p.id AND pr.user_id=$1 AND pr.status='approved')`;
 const seriesGrant=!extended?'false':hypothetical?String(audience==='series'):
  `EXISTS(SELECT 1 FROM ca_series_grant sg WHERE sg.series_id=s.id AND sg.user_id=$1 AND sg.active)`;
 const eventGrant=hypothetical?String(['event','confirmed'].includes(audience)):
  `EXISTS(SELECT 1 FROM ca_event_grant eg WHERE eg.event_id=e.id AND eg.user_id=$1 AND eg.active AND eg.revoked_at IS NULL AND (eg.expires_at IS NULL OR eg.expires_at>NOW()))`;
 const confirmed=hypothetical?String(audience==='confirmed'):confirmedParticipation;
 const profile=`(p.is_public OR (${unblocked} AND (${owns} OR ${profileGrant})))`;
 const series=!extended?'false':`(s.is_public AND c.is_public AND p.is_public OR ${seriesGrant} OR ${owns})`;
 const personal=`((${profile} OR ${eventGrant} OR ${confirmed} OR (e.membership_required AND ${member})) AND ${ownerCurrent} AND ${unblocked}
  AND (${owns} OR ${eventGrant} OR ${confirmed} OR (e.membership_required AND ${member}) OR (e.series_id IS NOT NULL AND ${seriesGrant})))`;
 const visible=`COALESCE((${scope} AND e.status IN('published','cancelled') AND ${retainedEvent} AND (${communityPublication} OR ${owns}) AND ((${publicRule}) OR ${personal}) AND (e.legal_state<>'blocked' OR ${owns}) AND ${hypothetical?'true':eventNotRestricted}),false)`;
 const time=`(e.access_mode<>'semi_public' AND e.starts_public OR e.access_mode='semi_public' AND ${visible} AND (${owns} OR (${confirmed} AND e.time_release_at<=NOW())))`;
 const location=`(e.access_mode<>'semi_public' AND e.location_public OR e.access_mode='semi_public' AND ${visible} AND (${owns} OR (${confirmed} AND e.location_release_at<=NOW())))`;
 const content=`CASE WHEN e.access_mode='semi_public' THEN jsonb_build_object(
  'description',e.event_content->'description','genres',e.event_content->'genres',
  'minimum_age',e.event_content->'minimum_age','admission',e.event_content->'admission','line_up',e.event_content->'line_up',
  'ends_at',CASE WHEN ${time} THEN e.event_content->'ends_at' ELSE 'null'::jsonb END,
  'venue_name',CASE WHEN ${location} THEN e.event_content->'venue_name' ELSE '\"\"'::jsonb END)
  ELSE (e.event_content-'ends_at'-'venue_name') || jsonb_build_object(
  'ends_at',CASE WHEN ${time} THEN e.event_content->'ends_at' ELSE 'null'::jsonb END,
  'venue_name',CASE WHEN ${location} THEN e.event_content->'venue_name' ELSE '\"\"'::jsonb END) END`;
 const exactLocation=`(e.status='published' AND ${retainedEvent} AND ${ownerCurrent}
  AND ${visible} AND (${owns} OR (${confirmed} AND (e.access_mode<>'semi_public' OR e.location_release_at<=NOW()))))`;
 const requestWindow=`COALESCE((e.status='published'
  AND (e.request_deadline_at IS NULL OR e.request_deadline_at>NOW())
  AND CASE WHEN ${time} THEN e.starts_at>NOW() ELSE e.request_deadline_at IS NOT NULL END),false)`;
 const withdrawalWindow=`COALESCE((e.status='published' AND CASE WHEN ${time}
  THEN e.starts_at>NOW() ELSE e.request_deadline_at>NOW() END),false)`;
 const visitWindow=`COALESCE((e.status='published' AND ${confirmed} AND ${time}
  AND (e.event_content->>'ends_at')::timestamptz<=NOW()),false)`;
 return {profile,series,personal,visible,time,location,content,confirmed,exactLocation,requestWindow,withdrawalWindow,visitWindow,
  upcoming:`(e.status='published' AND ${visible} AND (NOT COALESCE(${time},false) OR e.starts_at IS NULL OR e.starts_at>=NOW()))`,
  order:`CASE WHEN ${time} THEN e.starts_at END ASC NULLS LAST,e.id`};
}

// The same masked projection is used everywhere. Lists can omit heavy content;
// previews additionally blank the entire row when the event is not visible.
export function eventColumns(rules=eventPolicy(),{content=true,guard=false}={}){
 const field=(value,name,fallback='NULL')=>`${guard?`CASE WHEN ${rules.visible} THEN ${value} ELSE ${fallback} END`:value} AS ${name}`;
 const columns=[field('e.id','id'),field('e.title','title'),field('e.status','status'),
  field(`CASE WHEN ${rules.time} THEN e.starts_at END`,'starts_at'),
  field(`CASE WHEN ${rules.location} THEN e.public_location ELSE '' END`,'location',"''"),
  field("CASE WHEN c.is_public THEN c.name ELSE '' END",'community',"''"),
  field(`CASE WHEN ${rules.series} THEN s.id END`,'series_id'),
  field(`CASE WHEN ${rules.series} THEN s.title ELSE '' END`,'series',"''"),
  field(`CASE WHEN ${rules.profile} THEN p.id END`,'organizer_id'),
  field(`CASE WHEN ${rules.profile} THEN p.display_name ELSE '' END`,'organizer',"''"),
  field('e.access_mode','access_mode'),field('e.request_deadline_at','request_deadline_at'),field(eventInterest,'interest_count')];
 if(content)columns.push(field(rules.content,'event_content',"'{}'::jsonb"),
  field(`CASE WHEN e.access_mode='semi_public' AND NOT COALESCE(${rules.location},false)
   THEN e.access_details-'access_notes'-'awareness_notes'-'awareness_contact' ELSE e.access_details END`,'access_details',"'{}'::jsonb"));
 return columns.join(',\n');
}

export function eventSearch(){
 // Search projected values, never the hidden source fields.
 return `strpos(lower(concat_ws(' ',title,community,organizer,location,event_content->>'description',
  event_content->>'genres',event_content->>'venue_name')),lower($2))>0`;
}

export function rankEvents(rows,preferences={},signedIn=false){
 const words=Object.values(preferences).flat().map(v=>v.toLocaleLowerCase('de'));
 return rows.map(e=>{
  const hay=[e.title,e.community,e.organizer,e.event_content?.description,...(e.event_content?.genres??[])].filter(Boolean).join(' ').toLocaleLowerCase('de');
  const reasons=[];let score=0;
  if(signedIn){
   if(e.bookmarked){score+=8;reasons.push('bookmark');}
   if(e.followed){score+=4;reasons.push('community');}
   if(e.visited){score+=3;reasons.push('visited_organizer');}
   if(words.some(w=>hay.includes(w))){score+=2;reasons.push('preferences');}
  }
  return {...e,score,reasons};
 }).sort((a,b)=>b.score-a.score||(Date.parse(a.starts_at??'9999-01-01')-Date.parse(b.starts_at??'9999-01-01'))||a.id.localeCompare(b.id))
 .map(({score,bookmarked,followed,visited,...e})=>e);
}

export function eventPublication(body,existing=null){
 const mode=body.access_mode??existing?.access_mode??'legacy';
 if(!['legacy','public','private','semi_public'].includes(mode)||(!extendedProduct&&mode==='semi_public'))return null;
 if(mode==='legacy'&&typeof body.is_public!=='boolean')return null;
 return {mode,isPublic:mode==='legacy'?body.is_public:mode!=='private'};
}

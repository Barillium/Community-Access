import {test} from 'node:test';
import assert from 'node:assert/strict';
import worker from '../deploy/development/worker.mjs';
import {readCatalogFilters} from './catalog_query.mjs';
const request=async path=>{const response=await worker.fetch(new Request('https://preview.invalid/api/directory/'+path),{});return {status:response.status,data:await response.json()};};
test('community/date filters validate identifiers and ranges',()=>{
 assert.deepEqual(readCatalogFilters(new URLSearchParams()),{community:null,from:null,before:null});
 for(const query of ['community=Musikbunker','from=tomorrow','from=2026-10-19T00:00:00Z&before=2026-10-18T00:00:00Z'])assert.throws(()=>readCatalogFilters(new URLSearchParams(query)),RangeError);
});
test('preview community counts match explicit assignments, including overlaps and empty pages',async()=>{
 const {data}=await request('communities');
 assert.equal(data.signed_in,false);assert.equal(data.items.length,3);
 const programs=[];
 for(const community of data.items){
  const result=await request('events?scope=upcoming&community='+community.id);
  assert.equal(result.status,200);assert.equal(result.data.events.length,community.event_count);
  assert.ok(result.data.events.every(e=>e.synthetic&&e.communities.some(c=>c.id===community.id)));
  assert.equal(new Set(result.data.events.map(e=>e.id)).size,result.data.events.length);
  programs.push(result.data.events);
 }
 assert.equal(programs[2].length,0);
 const shared=programs[0].find(e=>e.title==='Demo Druckmarkt');
 assert.ok(programs[1].some(e=>e.id===shared.id));
 const selected=await request('events?community='+data.items[0].id+'&q=Druckmarkt&from='+encodeURIComponent(shared.starts_at)+'&before='+encodeURIComponent(new Date(Date.parse(shared.starts_at)+1000).toISOString()));
 assert.deepEqual(selected.data.events.map(e=>e.id),[shared.id]);
 assert.equal((await request('events?community=30000000-0000-4000-8000-000000000009')).data.events.length,0);
 assert.equal((await request('events?community=Musikbunker')).status,422);
});

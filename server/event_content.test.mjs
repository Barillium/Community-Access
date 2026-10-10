import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {eventContent} from './event_content.mjs';

test('bounded event media reject external, active, oversized and malformed raster content',()=>{
 for(const flyer_data of ['https://example.invalid/flyer.jpg','data:image/svg+xml;base64,PHN2Zy8+','data:image/jpeg;base64,aGVsbG8=',false,'data:image/jpeg;base64,'+'A'.repeat(350000)]) {
  assert.throws(()=>eventContent({flyer_data,flyer_alt:'Demo Bild'}),{code:'INVALID_EVENT_CONTENT'});
 }
 assert.throws(()=>eventContent({line_up:['a'.repeat(181)]}),{code:'INVALID_EVENT_CONTENT'});
 assert.throws(()=>eventContent({minimum_age:'18'}),{code:'INVALID_EVENT_CONTENT'});
 const truncated=Buffer.from([255,216,255,255,255,255,255,255,217]);
 assert.throws(()=>eventContent({flyer_data:'data:image/jpeg;base64,'+truncated.toString('base64'),flyer_alt:'Demo'}),{code:'INVALID_EVENT_CONTENT'});
 assert.deepEqual(eventContent({}).line_up,[]);
 assert.equal(eventContent({}).minimum_age,null);
});

test('the browser-normalized synthetic flyer passes bounded media validation and rejects embedded EXIF',()=>{
 const bytes=readFileSync(new URL('../docs/demo-assets/event-flyer-normalized.jpg',import.meta.url));
 const data='data:image/jpeg;base64,'+bytes.toString('base64');
 assert.equal(eventContent({flyer_data:data,flyer_alt:'Demo Nachtlinie'}).flyer_data,data);
 const exif=Buffer.concat([bytes.subarray(0,2),Buffer.from([255,225,0,8,69,120,105,102,0,0]),bytes.subarray(2)]);
 assert.throws(()=>eventContent({flyer_data:'data:image/jpeg;base64,'+exif.toString('base64'),flyer_alt:'Demo'}),{code:'INVALID_EVENT_CONTENT'});
 assert.throws(()=>eventContent({flyer_data:data,flyer_alt:''}),{code:'INVALID_EVENT_CONTENT'});
});

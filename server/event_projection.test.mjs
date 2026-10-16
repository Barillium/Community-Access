import {test} from 'node:test';
import assert from 'node:assert/strict';
import {eventColumns} from './event_policy.mjs';

test('visible event projections carry explicit visibility and ticket configuration', () => {
 const columns = eventColumns();
 assert.ok(columns.includes('e.ticket_mode AS ticket_mode'));
 assert.ok(columns.includes('e.is_public AS is_public'));
});
test('audience previews mask admission metadata together with hidden events', () => {
 const columns = eventColumns(undefined,{guard:true});
 assert.ok(columns.includes('THEN e.ticket_mode ELSE NULL END AS ticket_mode'));
 assert.ok(columns.includes('THEN e.is_public ELSE NULL END AS is_public'));
 assert.ok(!columns.includes('e.exact_location AS'));
});

test('hero metadata includes only public assigned communities and matching ticket configuration', () => {
 const columns = eventColumns();
 assert.ok(columns.includes('listed.is_public AND (listed.id=e.community_id OR EXISTS('));
 assert.ok(columns.includes('linked.community_id=listed.id AND linked.approved'));
 assert.ok(columns.includes('tc.event_id=e.id AND tc.mode=e.ticket_mode'));
 const guarded = eventColumns(undefined,{guard:true});
 assert.ok(guarded.includes("ELSE '[]'::jsonb END AS communities"));
 assert.ok(guarded.includes('ELSE NULL END AS ticket_price_cents'));
});

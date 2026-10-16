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

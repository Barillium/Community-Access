import {test} from 'node:test';
import assert from 'node:assert/strict';
import {productEdition} from './product_scope.mjs';
test('edition defaults to V1 and rejects unknown configuration',()=>{
 assert.equal(productEdition({}),'v1');assert.equal(productEdition({CA_PRODUCT_EDITION:'extended'}),'extended');
 for(const value of ['', 'production','V1'])assert.throws(()=>productEdition({CA_PRODUCT_EDITION:value}));
});

import {createAuth} from './auth.mjs';
import {seedAccess} from './access_fixtures.mjs';
const state=await createAuth();
try { await seedAccess(state); }
finally { await state.pool.end(); }

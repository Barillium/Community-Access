// Only the explicitly selected, fresh synthetic test/demo startup invokes this.
export async function seedAccess(state) {
  if(state.privateMail || !state.directory)throw new Error('Synthetic access fixtures required.');
  if((await state.pool.query('SELECT 1 FROM "user" LIMIT 1')).rowCount)throw new Error('Fresh fixture database required.');
  const users={},password='Synthetic-2026!';
  for(const key of ['team','organizer','other.host','guest.a','guest.b','guest.c','guest.d','unverified']){
    const r=await state.auth.api.signUpEmail({body:{name:`Demo ${key}`,email:`${key}@example.invalid`,password}});
    if(key!=='unverified')await state.pool.query('UPDATE "user" SET "emailVerified"=true WHERE id=$1',[r.user.id]);
    users[key]={...r.user,emailVerified:key!=='unverified'};
  }
  await state.pool.query('INSERT INTO ca_team VALUES($1)',[users.team.id]);
  return {users,password};
}

import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createAccountDeletion} from './account_deletion.mjs';
import {accountAgePolicy,validateAccountAge} from './account_age.mjs';
import {createAuth} from './auth.mjs';
import {createApp} from './http.mjs';
import {request} from 'node:http';

test('production synthetic runtime fails before opening a database or sending mail',async()=>{
  await assert.rejects(createAuth({env:{NODE_ENV:'production'}}),/Production product runtime/);
});
test('minimum account age must be an exact reviewed policy',()=>{
  assert.deepEqual(accountAgePolicy({CA_MINIMUM_ACCOUNT_AGE:'16'}),{minimumAccountAge:16,accountAgeReviewed:false});
  for(const value of ['0','19','16.0','-1','16 years'])assert.throws(()=>accountAgePolicy({CA_MINIMUM_ACCOUNT_AGE:value}));
  const policy={minimumAccountAge:16,accountAgeReviewed:true};
  for(const body of [{},{age_acknowledged:false,minimum_age:16},{age_acknowledged:true,minimum_age:14}])assert.equal(validateAccountAge(body,policy).code,'ACCOUNT_AGE_REQUIRED');
  assert.equal(validateAccountAge({age_acknowledged:true,minimum_age:16},policy),null);
});
test('deletion rejects stale sessions and false password verification without writing',async()=>{
  let writes=0;
  const deletion=createAccountDeletion({query:async()=>{writes++;throw Error();}}, {api:{verifyPassword:async()=>({status:false})}},{now:()=>1000000});
  for(const session of [null,{user:{id:'synthetic'},session:{createdAt:new Date(0)}}]) {
    await assert.rejects(deletion.request(session,new Headers(),{confirmation:'DELETE_ACCOUNT'}));
  }
  await assert.rejects(deletion.request({user:{id:'synthetic'}},new Headers(),{confirmation:'DELETE_ACCOUNT',password:'synthetic-password'}));
  assert.equal(writes,0);
});
test('HTTP account age protection cannot be bypassed by omitting or changing metadata',async()=>{
 let authenticated=0;
 const server=createApp({auth:{handler:async()=>{authenticated++;return Response.json({});}},mailbox:[],minimumAccountAge:16,accountAgeReviewed:true});
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const call=body=>new Promise((resolve,reject)=>{
  const req=request(`http://127.0.0.1:${server.address().port}/api/auth/sign-up/email`,{method:'POST',headers:{Host:'127.0.0.1:8000',Origin:'http://127.0.0.1:8300','Content-Type':'application/json',Connection:'close'}},res=>{let raw='';res.on('data',c=>raw+=c);res.on('end',()=>resolve({status:res.statusCode,data:JSON.parse(raw)}));});req.on('error',reject);req.end(JSON.stringify({name:'Synthetic',email:'age@example.invalid',password:'Synthetic-2026!',...body}));
 });
 try {
  for(const body of [{},{age_acknowledged:false,minimum_age:16},{age_acknowledged:true,minimum_age:14}])assert.equal((await call(body)).data.code,'ACCOUNT_AGE_REQUIRED');
  assert.equal(authenticated,0);
  assert.equal((await call({age_acknowledged:true,minimum_age:16})).status,200);assert.equal(authenticated,1);
 }finally{await new Promise(resolve=>server.close(resolve));}
});

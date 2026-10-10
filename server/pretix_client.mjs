import {DirectoryError} from './directory.mjs';

// Loopback client for the contract double or native pretix test bridge.
// Both require explicit synthetic payment mode; no live fallback.
export function syntheticPretixClient(origin,token,{fetchImpl=fetch,native=false}={}){
  if(!/^http:\/\/127\.0\.0\.1:[0-9]{1,5}$/.test(origin??'')||!/^[a-f0-9]{64}$/.test(token??''))throw new Error('Explicit synthetic pretix connection required.');
  async function call(path,body){
    const r=await fetchImpl(origin+path,{method:body===undefined?'GET':'POST',redirect:'error',signal:AbortSignal.timeout(5000),
      headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},...(body===undefined?{}:{body:JSON.stringify(body)})});
    const raw=await r.text();if(raw.length>8192)throw new Error('Invalid ticket response.');
    const data=JSON.parse(raw);
    if(!r.ok)throw new DirectoryError(r.status,[ 'EVENT_FULL','TICKET_EXISTS','CATALOG_CHANGED','CAPACITY_BELOW_CONFIRMED','INVALID_FEE','INVALID_REFUND','NOT_FOUND'].includes(data.code)?data.code:'TICKET_SERVICE_UNAVAILABLE');
    return data;
  }
  return {synthetic:true,native,checkoutEntry:event=>origin+'/demo/e'+event.replaceAll('-','')+'/community-access/entry/',serviceCredential:token,configureType:b=>call('/types',b),typeInventory:id=>call('/types/'+id),configure:b=>call('/events',b),reserve:b=>call('/orders',b),read:id=>call('/orders/'+id),
    block:id=>call('/orders/'+id+'/block',{}),refund:(id,b)=>call('/orders/'+id+'/refund',b),
    settle:(id,b)=>call('/orders/'+id+'/settle',b),inventory:id=>call('/events/'+id)};
}

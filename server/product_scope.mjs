// Deployment scope is fixed for the process, never selected by a client request.
export function productEdition(env=process.env){
 const value=env.CA_PRODUCT_EDITION??'v1';
 if(!['v1','extended'].includes(value))throw new Error('Unknown product edition');
 return value;
}
export const extendedProduct=productEdition()==='extended';
export const productEventScope=extendedProduct?'TRUE':"(e.access_mode<>'semi_public' AND e.series_id IS NULL)";
export function directoryRouteEnabled(route,method,body={}){
 if(extendedProduct)return true;
 if(['venues','venue','preferences','forget-visit','follow','bookmark','bookmarks','manage/series','manage/link'].includes(route))return false;
 if(/^events\/[^/]+\/visit$/.test(route)||/^(venues|venue)\//.test(route)||/^series\//.test(route)||/^organizers\/[^/]+\/(apply|redeem)$/.test(route)||/^(requests|links)\//.test(route))return false;
 if(['manage/grant','manage/revoke'].includes(route)&&body.kind!=='event')return false;
 return true;
}

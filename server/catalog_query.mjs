// Filters operate on the already authorized, masked event projection.
export function readCatalogFilters(params) {
 const community=params?.get('community')||null;
 if(community&&!/^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/.test(community))throw new RangeError('INVALID_COMMUNITY');
 const date=key=>{
  const value=params?.get(key)||null;
  if(value===null)return null;
  if(value.length>40||!/^\d{4}-\d\d-\d\dT\d\d:\d\d(?::\d\d(?:\.\d{1,3})?)?(?:Z|[+-]\d\d:\d\d)$/.test(value)||!Number.isFinite(Date.parse(value)))throw new RangeError('INVALID_DATE_RANGE');
  return new Date(value).toISOString();
 };
 const from=date('from'),before=date('before');
 if(from&&before&&from>=before)throw new RangeError('INVALID_DATE_RANGE');
 return {community,from,before};
}
export const projectedCatalogFilters=`($3::text IS NULL OR EXISTS(SELECT 1 FROM jsonb_array_elements(communities) assigned WHERE assigned->>'id'=$3))
 AND ($4::timestamptz IS NULL OR starts_at >= $4)
 AND ($5::timestamptz IS NULL OR starts_at < $5)`;

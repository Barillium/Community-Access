// No retention deadline is approved. These classes only participate in preview.
export const retentionClasses=Object.freeze(Object.fromEntries([
 'private_addresses','application_text','links','participations','checkins','media','moderation_cases','financial_records',
].map(name=>[name,Object.freeze({retention_days:null,execution_enabled:false})])));

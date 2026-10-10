export function accountAgePolicy(env = {}) {
  const raw = env.CA_MINIMUM_ACCOUNT_AGE;
  if (raw === undefined || raw === '') return { minimumAccountAge: 0, accountAgeReviewed: false };
  if (!/^[1-9][0-9]?$/.test(raw) || Number(raw) > 18) throw new Error('Invalid account age policy.');
  return { minimumAccountAge: Number(raw), accountAgeReviewed: env.CA_ACCOUNT_AGE_REVIEWED === 'true' };
}

export function validateAccountAge(body, policy) {
  if (!policy.minimumAccountAge) return null;
  if (!policy.accountAgeReviewed) return {status: 503, code: 'ACCOUNT_AGE_REVIEW_REQUIRED'};
  if (body.age_acknowledged !== true || body.minimum_age !== policy.minimumAccountAge) {
    return {status: 422, code: 'ACCOUNT_AGE_REQUIRED'};
  }
  return null;
}

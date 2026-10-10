"""Pure validation; no credentials, network requests, or pretix imports."""
import re
from decimal import Decimal, ROUND_HALF_UP


class AccessDenied(ValueError):
    pass


def validate_grant(grant, event_id, *, now):
    if not isinstance(grant, dict):
        raise AccessDenied('CHECKOUT_AUTHORIZATION_REQUIRED')
    if grant.get('event_id') != event_id or grant.get('expires_at', 0) <= now:
        raise AccessDenied('CHECKOUT_AUTHORIZATION_EXPIRED')
    if grant.get('authorized') is not True or grant.get('quantity') != 1:
        raise AccessDenied('CHECKOUT_AUTHORIZATION_REQUIRED')
    for key in ('total_cents', 'fee_cents', 'item_id'):
        if type(grant.get(key)) is not int:
            raise AccessDenied('INVALID_CHECKOUT_AMOUNT')
    if not 0 < grant['total_cents'] <= 100000000 or not 0 <= grant['fee_cents'] < grant['total_cents']:
        raise AccessDenied('INVALID_CHECKOUT_AMOUNT')
    if not re.fullmatch(r'acct_[A-Za-z0-9_]+', grant.get('account_id', '')):
        raise AccessDenied('INVALID_CONNECTED_ACCOUNT')
    if not re.fullmatch(r'[a-f0-9-]{36}', grant.get('order_id', '')):
        raise AccessDenied('INVALID_ORDER_REFERENCE')
    return grant


def validate_positions(grant, positions):
    positions = list(positions)
    if len(positions) != 1 or positions[0].item_id != grant['item_id']:
        raise AccessDenied('ONE_PERSONAL_TICKET_ONLY')
    if getattr(positions[0], 'addon_to_id', None) is not None:
        raise AccessDenied('ONE_PERSONAL_TICKET_ONLY')
    if (positions[0].price * 100).quantize(Decimal('1'), rounding=ROUND_HALF_UP) != grant['total_cents']:
        raise AccessDenied('CHECKOUT_PRICE_CHANGED')


def direct_charge(grant):
    # Deliberately no transfer_data or on_behalf_of: seller is the connected account.
    return {'application_fee_amount': grant['fee_cents']} if grant['fee_cents'] else {}


def fee_refund_target(fee_cents, cumulative_refund, total_cents):
    if not 0 <= cumulative_refund <= total_cents or total_cents <= 0:
        raise AccessDenied('INVALID_REFUND')
    return int((Decimal(fee_cents) * cumulative_refund / total_cents).quantize(Decimal('1'), rounding=ROUND_HALF_UP))

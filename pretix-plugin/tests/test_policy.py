import importlib.util
from pathlib import Path
from decimal import Decimal
from types import SimpleNamespace
import unittest

spec = importlib.util.spec_from_file_location('policy', Path(__file__).parents[1] / 'community_access_pretix' / 'policy.py')
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)


class PolicyTests(unittest.TestCase):
    def setUp(self):
        self.grant = dict(event_id='event', expires_at=1000, authorized=True, quantity=1, total_cents=1250,
                          fee_cents=63, item_id=7, account_id='acct_TestConnected', order_id='00000000-0000-4000-8000-000000000001')

    def test_expired_foreign_and_unverified_grants(self):
        for changed in [dict(expires_at=0), dict(event_id='foreign'), dict(authorized=False), dict(quantity=2), dict(total_cents=True), dict(fee_cents=1250)]:
            with self.subTest(changed=changed), self.assertRaises(policy.AccessDenied):
                policy.validate_grant({**self.grant, **changed}, 'event', now=10)

    def test_one_position_at_verified_discounted_price(self):
        p = SimpleNamespace(item_id=7, price=Decimal('12.50'), addon_to_id=None)
        policy.validate_positions(self.grant, [p])
        for positions in [[], [p, p], [SimpleNamespace(item_id=8, price=p.price)], [SimpleNamespace(item_id=7, price=Decimal('0.01'))]]:
            with self.assertRaises(policy.AccessDenied):
                policy.validate_positions(self.grant, positions)

    def test_direct_charge_keeps_seller_and_exact_fee(self):
        self.assertEqual(policy.direct_charge(self.grant), {'application_fee_amount': 63})
        self.assertNotIn('transfer_data', policy.direct_charge(self.grant))

    def test_cumulative_refund_rounding_has_no_double_refund(self):
        self.assertEqual(policy.fee_refund_target(63, 625, 1250), 32)
        self.assertEqual(policy.fee_refund_target(63, 1250, 1250), 63)
        with self.assertRaises(policy.AccessDenied):
            policy.fee_refund_target(63, 1251, 1250)


if __name__ == '__main__':
    unittest.main()

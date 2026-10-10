import time
import os
from decimal import Decimal
from django.dispatch import receiver
from pretix.base.signals import register_payment_providers, validate_order, validate_cart, order_placed
from pretix.presale.signals import order_api_meta_from_request, process_request
from pretix.base.services.cart import CartError
from pretix.base.services.orders import OrderError
from pretix.plugins.stripe.payment import StripeCC
from .backend import authorize
from .policy import AccessDenied, validate_grant, validate_positions, direct_charge
from .models import CartBinding
from .service_context import service_grant
from django.utils.html import format_html
from pretix.base.payment import BasePaymentProvider


def checked(request, event):
    if not event.testmode:
        raise AccessDenied('TEST_MODE_REQUIRED')
    grant = request.session.get('communityaccess_grant')
    if not isinstance(grant,dict):
        raise AccessDenied('CHECKOUT_AUTHORIZATION_REQUIRED')
    current = authorize(grant['order_id'], request.session.get('communityaccess_nonce'))
    validate_grant(current, event.settings.get('communityaccess_event_id'), now=time.time())
    if any(current[k] != grant[k] for k in ('account_id', 'item_id', 'total_cents', 'fee_cents')):
        raise AccessDenied('CHECKOUT_PRICE_CHANGED')
    return current


@receiver(validate_cart, dispatch_uid='communityaccess.validate_cart')
def cart(sender, positions, **kwargs):
    try:
        grant = checked_positions(sender, positions)
        if service_grant.get() and service_grant.get().get('reserving') and len(positions)==1:
            grant={**grant,'total_cents':int(positions[0].price*100)}
        validate_positions(grant, positions)
    except AccessDenied:
        raise CartError('Community Access: erneute Kaufberechtigung erforderlich.') from None


@receiver(validate_order, dispatch_uid='communityaccess.validate_order')
def order(sender, positions, payments, **kwargs):
    try:
        grant = checked_positions(sender, positions)
        validate_positions(grant, positions)
        if len(payments) != 1 or payments[0]['provider'] != 'communityaccess_stripe':
            raise AccessDenied('DIRECT_CHARGE_REQUIRED')
    except AccessDenied:
        raise OrderError('Community Access: erneute Kaufberechtigung erforderlich.') from None


def checked_positions(event, positions):
    private = service_grant.get()
    if private is not None:
        return validate_grant(private, event.settings.get('communityaccess_event_id'), now=time.time())
    positions = list(positions)
    if not positions or len({p.cart_id for p in positions}) != 1 or not event.testmode:
        raise AccessDenied('ONE_PERSONAL_TICKET_ONLY')
    binding = CartBinding.objects.filter(event=event, cart_id=positions[0].cart_id).first()
    if binding is None:
        raise AccessDenied('CHECKOUT_AUTHORIZATION_REQUIRED')
    grant = authorize(str(binding.order_id), binding.browser_nonce)
    return validate_grant(grant, event.settings.get('communityaccess_event_id'), now=time.time())


@receiver(order_api_meta_from_request, dispatch_uid='communityaccess.order_meta')
def metadata(sender, request, **kwargs):
    return {'communityaccess': checked(request, sender)}


@receiver(order_placed,dispatch_uid='communityaccess.native_order_binding')
def bind_native_order(sender,order,**kwargs):
    from .models import ServiceOrder
    grant=(order.api_meta or {}).get('communityaccess')
    validate_grant(grant,sender.settings.get('communityaccess_event_id'),now=time.time())
    row=ServiceOrder.objects.select_for_update().get(pk=grant['order_id'],catalog__event=sender,state='pending',blocked=False)
    validate_positions(grant,order.positions.all())
    if row.account_id!=grant['account_id'] or row.total_cents!=grant['total_cents'] or row.fee_cents!=grant['fee_cents']:
        raise AccessDenied('CHECKOUT_PRICE_CHANGED')
    # Native checkout may create an unpaid order before executing the card
    # provider. It retains the original 15-minute deadline and bridge identity.
    order.expires=row.expires_at;order.save(update_fields=['expires'])
    row.order=order;row.save(update_fields=['order'])


class CommunityAccessStripe(StripeCC):
    """Native Stripe implementation, with server-authorized fee snapshots.

    Native rendering and webhook handling require the pinned pretix runtime
    integration test before activation; never register this as a live provider.
    """
    identifier = 'communityaccess_stripe'

    def calculate_fee(self,price):
        return Decimal('0.00')

    @property
    def local_simulation(self):
        return os.environ.get('CA_NATIVE_PRETIX_TEST')=='true' and self.event.testmode

    @property
    def test_mode_message(self):
        return 'Synthetische Kartenzahlung · es wird kein Geld bewegt' if self.local_simulation else super().test_mode_message

    @property
    def is_enabled(self):
        return self.local_simulation or super().is_enabled

    @property
    def walletqueries(self):
        return [] if self.local_simulation else super().walletqueries

    def is_allowed(self,request,total=None):
        try:
            checked(request,self.event)
            return BasePaymentProvider.is_allowed(self,request,total)
        except AccessDenied:
            return False

    def payment_form_render(self,request,total,order=None):
        if self.local_simulation:
            checked(request,self.event)
            return format_html('<p>Synthetische Kartenzahlung · kein Geldfluss</p><label><input type="checkbox" name="communityaccess_test_payment" value="yes" required> Erfolgreiche Testzahlung simulieren</label>')
        return super().payment_form_render(request,total,order)

    def checkout_prepare(self,request,cart):
        if self.local_simulation:
            checked(request,self.event)
            request.session['communityaccess_test_payment']=request.POST.get('communityaccess_test_payment')=='yes'
            return request.session['communityaccess_test_payment']
        return super().checkout_prepare(request,cart)

    def checkout_confirm_render(self,request,**kwargs):
        if self.local_simulation:
            checked(request,self.event)
            return 'Synthetische Kartenzahlung · kein Geldfluss'
        return super().checkout_confirm_render(request,**kwargs)

    def _grant(self, payment):
        grant = (payment.order.api_meta or {}).get('communityaccess')
        validate_grant(grant, self.event.settings.get('communityaccess_event_id'), now=time.time())
        if not self.event.testmode or payment.amount * 100 != grant['total_cents']:
            raise AccessDenied('TEST_MODE_REQUIRED')
        return grant

    def _connect_kwargs(self, payment):
        return direct_charge(self._grant(payment))

    def payment_is_valid_session(self, request):
        try:
            checked(request, self.event)
            return request.session.get('communityaccess_test_payment',False) if self.local_simulation else super().payment_is_valid_session(request)
        except AccessDenied:
            return False

    @property
    def api_kwargs(self):
        # Native stripe_account comes only from owner-operated event settings.
        # It must be checked against the grant immediately before intent creation.
        kwargs = super().api_kwargs
        if not self.event.testmode or '_test_' not in kwargs.get('api_key', '') or not kwargs.get('stripe_account'):
            raise AccessDenied('DIRECT_TEST_ACCOUNT_REQUIRED')
        return kwargs

    def payment_prepare(self, request, payment):
        grant = self._grant(payment)
        if self.local_simulation:
            return self.checkout_prepare(request,None)
        if self.api_kwargs['stripe_account'] != grant['account_id']:
            raise AccessDenied('CONNECTED_ACCOUNT_MISMATCH')
        checked(request, self.event)
        return super().payment_prepare(request, payment)

    def execute_payment(self, request, payment):
        grant = self._grant(payment)
        if self.local_simulation:
            checked(request,self.event)
            if not self.payment_is_valid_session(request):
                raise AccessDenied('SIMULATION_CONFIRMATION_REQUIRED')
            from .models import ServiceOrder
            row=ServiceOrder.objects.get(pk=grant['order_id'],blocked=False,state='pending')
            validate_positions(grant,payment.order.positions.all())
            payment.info_data={'synthetic':True,'stripe_account':grant['account_id'],'application_fee_amount':grant['fee_cents'],'idempotency_key':grant['order_id']}
            payment.save()
            payment.confirm(send_mail=False,generate_invoice=False)
            payment.order.refresh_from_db()
            row.order=payment.order;row.state='paid';row.valid_payment=payment.order.status=='p';row.save()
            return None
        if self.api_kwargs['stripe_account'] != grant['account_id']:
            raise AccessDenied('CONNECTED_ACCOUNT_MISMATCH')
        checked(request, self.event)
        return super().execute_payment(request, payment)


@receiver(register_payment_providers, dispatch_uid='communityaccess.stripe')
def providers(sender, **kwargs):
    if sender.testmode:
        return CommunityAccessStripe


@receiver(process_request,dispatch_uid="communityaccess.bound_views")
def bound_views(sender,request,**kwargs):
    from .session_middleware import protect_native_session
    return protect_native_session(request,sender)

import secrets
import time
import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from pretix.presale.views.cart import get_or_create_cart_id
from .models import CartBinding, ServiceOrder
from pretix.multidomain.urlreverse import eventreverse
from .backend import authorize
from .policy import AccessDenied, validate_grant


@csrf_exempt
def entry(request, **kwargs):
    """Native-session challenge; forwarded links cannot establish another session.

    GET exposes only a fresh browser challenge. The platform must authenticate
    the guest and obtain their handoff code; POST consumes that code server-side.
    Secrets travel in POST bodies, never URLs. A closed integration keeps this
    entry test-only until the native checkout/cart bridge is verified.
    """
    if not request.event.testmode:
        return JsonResponse({'code': 'TEST_MODE_REQUIRED'}, status=403)
    if request.method == 'GET':
        nonce = secrets.token_hex(32)
        request.session['communityaccess_nonce'] = nonce
        return JsonResponse({'browser_nonce': nonce, 'test_only': True})
    if request.method != 'POST':
        return JsonResponse({'code': 'METHOD_DENIED'}, status=405)
    try:
        if len(request.body)>4096:
            raise AccessDenied('BODY_TOO_LARGE')
        data = json.loads(request.body)
        nonce = request.session.get('communityaccess_nonce')
        if not nonce or data.get('browser_nonce') != nonce:
            raise AccessDenied('BROWSER_SESSION_REQUIRED')
        grant = authorize(data.get('order_id'), nonce, data.get('code'))
        validate_grant(grant, request.event.settings.get('communityaccess_event_id'), now=time.time())
        row=ServiceOrder.objects.select_related('order').get(pk=grant['order_id'],catalog__event=request.event,state__in=['pending','paid'],blocked=False)
        if row.account_id!=grant['account_id'] or row.total_cents!=grant['total_cents'] or row.fee_cents!=grant['fee_cents']:
            raise AccessDenied('CHECKOUT_PRICE_CHANGED')
        request.session['current_cart_event_{}'.format(request.event.pk)]=row.cart_id
        carts=request.session.get('carts',{})
        carts[row.cart_id]={}
        request.session['carts']=carts
        request.session['communityaccess_grant'] = grant
        CartBinding.objects.update_or_create(event=request.event, cart_id=get_or_create_cart_id(request), defaults={
            'order_id': grant['order_id'], 'browser_nonce': nonce, 'grant': grant,
        })
        url=eventreverse(request.event,'presale:event.order',kwargs={'order':row.order.code,'secret':row.order.secret}) if row.state=='paid' and row.order_id else eventreverse(request.event,'presale:event.checkout.start')
        return JsonResponse({'authorized': True, 'test_only': True,'checkout_url':url})
    except (AccessDenied, ValueError, TypeError, AttributeError, ServiceOrder.DoesNotExist):
        return JsonResponse({'code': 'CHECKOUT_DENIED'}, status=403)

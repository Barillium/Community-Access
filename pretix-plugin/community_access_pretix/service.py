"""Local integration adapter over actual pretix models/services, simulated Stripe only."""
import hmac
import json
import os
import re
import secrets
from decimal import Decimal
from decimal import ROUND_HALF_UP
from datetime import timedelta
from uuid import UUID
from contextlib import contextmanager
from django.db import transaction, connection
from django.http import JsonResponse
from django.utils.timezone import now
from django.utils.dateparse import parse_datetime
from django.views.decorators.csrf import csrf_exempt
from django_scopes import scopes_disabled
from pretix.base.models import Organizer, Event, Item, Quota, CartPosition, Order, OrderPayment
from pretix.base.services.cart import CartManager, CartError
from pretix.base.services.orders import _perform_order, OrderError, mark_order_expired
from .models import ServiceEvent, ServiceOrder, ServiceRefund, ServiceType
from .policy import fee_refund_target
from .service_context import service_grant


class ServiceError(ValueError):
    def __init__(self, code, status=409):
        self.code, self.status = code, status


def integer(value, lower, upper):
    if type(value) is not int or not lower <= value <= upper:
        raise ServiceError('INVALID_FIELDS', 422)
    return value


def expire():
    for row in ServiceOrder.objects.select_related('order','catalog','catalog__event').filter(state='pending',expires_at__lte=now()):
        output(row)
        if row.state=='paid':continue
        CartPosition.objects.filter(event=row.catalog.event,cart_id=row.cart_id).delete()
        if row.order_id and row.order.status==Order.STATUS_PENDING:
            mark_order_expired(row.order)
        row.state='expired';row.save(update_fields=['state'])


def grant(row):
    return dict(authorized=True, quantity=1, event_id=str(row.catalog_id), order_id=str(row.id),
                item_id=row.service_type.item_id if row.service_type_id else row.catalog.item_id, account_id=row.account_id, total_cents=row.total_cents,
                fee_cents=row.fee_cents, expires_at=int(row.expires_at.timestamp()))


def output(row):
    if not row.order_id:
        recovered=Order.objects.filter(event=row.catalog.event,api_meta__communityaccess__order_id=str(row.id)).first()
        if recovered:
            row.order=recovered
            row.save(update_fields=['order'])
    if row.order_id:
        row.order.refresh_from_db()
        if row.order.status == 'p' and row.state not in ('refunded',):
            row.state = 'paid'
            paid=row.order.payments.filter(state=OrderPayment.PAYMENT_STATE_CONFIRMED).first()
            row.valid_payment=bool(paid and paid.payment_date and paid.payment_date<=row.expires_at)
            row.blocked=row.blocked or not row.valid_payment
            row.save(update_fields=['state','valid_payment','blocked'])
    return dict(id=str(row.id), event_id=str(row.catalog_id), subject=row.subject, account_id=row.account_id,
                state=row.state, blocked=row.blocked, valid_payment=row.valid_payment,currency=row.catalog.event.currency,
                total_cents=row.total_cents, fee_cents=row.fee_cents, refunded_cents=row.refunded_cents,
                fee_refunded_cents=row.fee_refunded_cents, expires_at=row.expires_at.isoformat(),
                type_id=str(row.service_type_id) if row.service_type_id else None, native_pretix=True, item_id=row.service_type.item_id if row.service_type_id else row.catalog.item_id)


@transaction.atomic
def configure(body):
    key=UUID(body['id']);price=integer(body['price_cents'],1,100000000);quota=integer(body['quota'],1,1000000)
    version=integer(body['version'],1,2147483647);name=body['item_name']
    if not isinstance(name,str) or not name.strip() or len(name)>120:raise ServiceError('INVALID_FIELDS',422)
    row=ServiceEvent.objects.filter(pk=key).first()
    if row and row.version>version:raise ServiceError('CATALOG_CHANGED')
    if row and row.version==version:
        if row.item.default_price!=Decimal(price)/100 or row.quota.size!=quota:raise ServiceError('CATALOG_CHANGED')
        return {'configured':True,'item_id':row.item_id}
    if row:
        row.item.default_price=Decimal(price)/100;row.item.name=name;row.item.save()
        row.quota.size=quota;row.quota.save();row.version=version;row.save()
    else:
        org,_=Organizer.objects.get_or_create(slug='demo',defaults={'name':'Community Access · synthetischer Test'})
        starts=parse_datetime(body['starts_at']) if body.get('starts_at') else now()+timedelta(days=2)
        if not starts or starts.utcoffset() is None:raise ServiceError('INVALID_FIELDS',422)
        event=Event.objects.create(organizer=org,slug='e'+key.hex,name=name,date_from=starts,
                                   currency='EUR',live=True,testmode=True,plugins='community_access_pretix,pretix.plugins.stripe,pretix.plugins.ticketoutputpdf')
        event.settings.set('communityaccess_event_id',str(key));event.settings.set('reservation_time',15)
        event.settings.set('invoice_generate','False');event.settings.set('ticket_download',True)
        event.settings.set('ticketoutput_pdf__enabled',True)
        event.settings.set('invoice_address_asked',False)
        event.settings.set('allow_modifications','no')
        event.settings.set('payment_communityaccess_stripe_enabled',True)
        event.settings.set('payment_communityaccess_stripe_method_card',True)
        item=Item.objects.create(event=event,name=name,default_price=Decimal(price)/100,admission=True)
        q=Quota.objects.create(event=event,name='Persönliches Ticketkontingent',size=quota);q.items.add(item)
        row=ServiceEvent.objects.create(id=key,event=event,item=item,quota=q,version=version)
    return {'configured':True,'item_id':row.item_id}


@transaction.atomic
def configure_type(body):
    catalog=ServiceEvent.objects.get(pk=UUID(body['event_id']))
    key=UUID(body['id']);price=integer(body['price_cents'],1,100000000);size=integer(body['quota'],1,1000000);version=integer(body['version'],1,2147483647)
    row=ServiceType.objects.filter(pk=key).first()
    if row and (row.catalog_id!=catalog.id or row.version>version):raise ServiceError('CATALOG_CHANGED')
    if row and row.version==version:
        if row.item.default_price!=Decimal(price)/100 or row.quota.size!=size:raise ServiceError('CATALOG_CHANGED')
        return {'configured':True,'item_id':row.item_id}
    if row:
        if row.quota.size-row.quota.availability()[1]>size:raise ServiceError('CAPACITY_BELOW_CONFIRMED')
        row.item.default_price=Decimal(price)/100;row.item.save()
        row.quota.size=size;row.quota.save();row.version=version;row.save()
    else:
        item=Item.objects.create(event=catalog.event,name='Persönliches Testticket',default_price=Decimal(price)/100,admission=True)
        quota=Quota.objects.create(event=catalog.event,name='Kategorie-Testkontingent',size=size);quota.items.add(item)
        catalog.quota.items.add(item)
        row=ServiceType.objects.create(id=key,catalog=catalog,item=item,quota=quota,version=version)
    return {'configured':True,'item_id':row.item_id}


def reserve(body):
    key=UUID(body['id']);catalog=ServiceEvent.objects.get(pk=UUID(body['event_id']))
    category=ServiceType.objects.get(pk=UUID(body['type_id']),catalog=catalog) if body.get('type_id') else None
    item=category.item if category else catalog.item
    row=ServiceOrder.objects.filter(pk=key).first()
    if row:
        if row.subject!=body['subject'] or row.account_id!=body['account_id'] or row.catalog_id!=catalog.id or row.service_type_id!=(category.id if category else None):raise ServiceError('ORDER_MISMATCH')
        if row.state!='pending' or row.order_id or CartPosition.objects.filter(event=catalog.event,cart_id=row.cart_id).exists():
            return output(row)
    if not re.fullmatch(r'[a-f0-9]{64}',body.get('subject','')) or not re.fullmatch(r'acct_demo_[a-f0-9]{32}',body.get('account_id','')):raise ServiceError('INVALID_FIELDS',422)
    if ServiceOrder.objects.filter(catalog=catalog,subject=body['subject'],state__in=['pending','paid']).exclude(pk=key).exists():raise ServiceError('TICKET_EXISTS')
    if int(item.default_price*100)!=body['total_cents']:raise ServiceError('CATALOG_CHANGED')
    row=row or ServiceOrder.objects.create(id=key,catalog=catalog,service_type=category,subject=body['subject'],account_id=body['account_id'],
         cart_id=secrets.token_urlsafe(24),total_cents=body['total_cents'],fee_cents=integer(body['fee_cents'],0,body['total_cents']-1),fee_basis_points=integer(body['fee_basis_points'],0,9999),expires_at=now()+timedelta(minutes=15))
    token=service_grant.set({**grant(row),'reserving':True})
    try:
        cm=CartManager(event=catalog.event,cart_id=row.cart_id,sales_channel=catalog.event.organizer.sales_channels.get(identifier='web'),reservation_time=timedelta(minutes=15))
        cm.add_new_items([{'item':item.pk,'variation':None,'count':1,'custom_price':None,'voucher':None}]);cm.commit()
        position=CartPosition.objects.get(event=catalog.event,cart_id=row.cart_id)
        row.total_cents=int(position.price*100)
        row.fee_cents=int((Decimal(row.total_cents)*row.fee_basis_points/10000).quantize(Decimal('1'),rounding=ROUND_HALF_UP))
        if not 0<row.total_cents or row.fee_cents>=row.total_cents:
            CartPosition.objects.filter(pk=position.pk).delete();row.delete();raise ServiceError('INVALID_FEE',422)
        row.expires_at=position.expires;row.save(update_fields=['expires_at','total_cents','fee_cents'])
    except CartError as error:
        row.delete()
        raise ServiceError('EVENT_FULL') from error
    finally:service_grant.reset(token)
    return output(row)


def settle(row,body):
    outcome=body.get('outcome')
    if outcome not in ['success','failed','late']:raise ServiceError('INVALID_FIELDS',422)
    output(row)
    if row.state in ['paid','refunded']:return output(row)
    positions=list(CartPosition.objects.filter(event=row.catalog.event,cart_id=row.cart_id))
    if outcome=='failed':
        CartPosition.objects.filter(event=row.catalog.event,cart_id=row.cart_id).delete();row.state='failed';row.save();return output(row)
    valid=row.state=='pending' and not row.blocked and row.expires_at>now() and outcome!='late'
    if (not positions and not row.order_id) or not valid:
        # Record simulated late receipt separately; never manufacture a native admission.
        row.state='paid';row.valid_payment=False;row.blocked=True;row.save();return output(row)
    token=service_grant.set(grant(row))
    try:
        result={'order_id':row.order_id} if row.order_id else _perform_order(row.catalog.event,[{'provider':'communityaccess_stripe','amount':Decimal(row.total_cents)/100,'info_data':{}}],
           [p.pk for p in positions],None,'de',None,api_meta={'communityaccess':grant(row)},cart_id=row.cart_id)
        # The native pipeline owns the payment and paid status. No external Stripe call.
        native=Order.objects.get(pk=result['order_id'])
        payment=native.payments.get(provider='communityaccess_stripe')
        payment.info_data={'synthetic':True,'stripe_account':row.account_id,'application_fee_amount':row.fee_cents,'idempotency_key':str(row.id)};payment.save()
        payment.confirm(send_mail=False,generate_invoice=False)
        row.order=native;row.state='paid';row.valid_payment=True;row.save()
    finally:service_grant.reset(token)
    return output(row)


@transaction.atomic
def block(row):
    row.blocked=True
    if row.state=='pending':
        row.state='expired';CartPosition.objects.filter(event=row.catalog.event,cart_id=row.cart_id).delete()
    if row.order_id:
        row.order.positions.update(canceled=True,blocked=True)
    row.save();return output(row)


@transaction.atomic
def refund(row,body):
    key=UUID(body['id']);amount=integer(body['amount_cents'],1,row.total_cents)
    old=ServiceRefund.objects.filter(pk=key).first()
    if old:
        if old.order_id!=row.id or old.amount_cents!=amount:raise ServiceError('REFUND_MISMATCH')
        return output(row)
    if row.state!='paid' or amount>row.total_cents-row.refunded_cents:raise ServiceError('INVALID_REFUND')
    target=fee_refund_target(row.fee_cents,row.refunded_cents+amount,row.total_cents)
    if row.order_id and row.valid_payment:
        payment=row.order.payments.get(provider='communityaccess_stripe')
        native=row.order.refunds.create(payment=payment,provider='communityaccess_stripe',amount=Decimal(amount)/100,
                source='admin',info=json.dumps({'synthetic':True,'explicit_application_fee_refund_cents':target-row.fee_refunded_cents,'idempotency_key':str(key)}))
        native.done()
        ServiceRefund.objects.create(id=key,order=row,refund=native,amount_cents=amount,fee_cents=target-row.fee_refunded_cents)
    else:
        # A late simulated receipt has no admission/order. Keep its financial
        # refund mapping without creating a paid native ticket after expiry.
        ServiceRefund.objects.create(id=key,order=row,refund=None,amount_cents=amount,fee_cents=target-row.fee_refunded_cents)
    row.refunded_cents+=amount;row.fee_refunded_cents=target;row.blocked=True
    if row.refunded_cents==row.total_cents:row.state='refunded'
    row.save();return output(row)


@contextmanager
def serialized():
    # pretix CartManager uses durable transactions; never nest its reservation in
    # an outer atomic block. A session advisory lock serializes bridge intents.
    with scopes_disabled():
        with connection.cursor() as cursor:cursor.execute('SELECT pg_advisory_lock(73100527)')
        try:yield
        finally:
            with connection.cursor() as cursor:cursor.execute('SELECT pg_advisory_unlock(73100527)')


@csrf_exempt
def service(request):
    credential=os.environ.get('CA_PRETIX_TOKEN','')
    if os.environ.get('CA_NATIVE_PRETIX_TEST')!='true' or len(credential)!=64 or request.META.get('REMOTE_ADDR') not in ['127.0.0.1','::1'] or not hmac.compare_digest(request.headers.get('Authorization',''),'Bearer '+credential):
        return JsonResponse({'code':'UNAUTHENTICATED'},status=401)
    try:
        if len(request.body)>4096:raise ServiceError('BODY_TOO_LARGE',413)
        body=json.loads(request.body or '{}')
        with serialized():
            expire();path=request.path.strip('/').split('/')
            if path==['types'] and request.method=='POST':data=configure_type(body)
            elif len(path)==2 and path[0]=='types' and request.method=='GET':
                row=ServiceType.objects.get(pk=UUID(path[1]));data={'available':max(0,min(row.quota.availability()[1],row.catalog.quota.availability()[1]))}
            elif path==['events'] and request.method=='POST':data=configure(body)
            elif path==['orders'] and request.method=='POST':data=reserve(body)
            elif len(path)==2 and path[0]=='events' and request.method=='GET':
                row=ServiceEvent.objects.get(pk=UUID(path[1]));available=row.quota.availability()[1];data={'available':max(0,available),'quota':row.quota.size}
            elif len(path)>=2 and path[0]=='orders':
                row=ServiceOrder.objects.select_related('catalog','catalog__event','order').get(pk=UUID(path[1]))
                if len(path)==2 and request.method=='GET':data=output(row)
                elif len(path)==3 and request.method=='POST':
                    if path[2]=='settle':data=settle(row,body)
                    elif path[2]=='block':data=block(row)
                    elif path[2]=='refund':data=refund(row,body)
                    else:raise ServiceError('NOT_FOUND',404)
                else:raise ServiceError('NOT_FOUND',404)
            else:raise ServiceError('NOT_FOUND',404)
        return JsonResponse(data)
    except ServiceError as error:return JsonResponse({'code':error.code},status=error.status)
    except (ServiceEvent.DoesNotExist,ServiceOrder.DoesNotExist,ServiceType.DoesNotExist):return JsonResponse({'code':'NOT_FOUND'},status=404)
    except (ValueError,KeyError,TypeError):return JsonResponse({'code':'INVALID_FIELDS'},status=422)
    except Exception:return JsonResponse({'code':'NATIVE_SERVICE_UNAVAILABLE'},status=503)

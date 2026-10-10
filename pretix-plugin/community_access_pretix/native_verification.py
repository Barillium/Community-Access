"""Explicit native runtime checks; never imported by the web application."""
import hashlib
import json
from uuid import uuid4
from decimal import Decimal
from io import BytesIO
from datetime import timedelta
from django_scopes import scopes_disabled
from django.utils.timezone import now
from pretix.base.models import Discount, CheckinList, CartPosition, Order
from pretix.base.services.checkin import perform_checkin, CheckInError
from pretix.plugins.ticketoutputpdf.ticketoutput import PdfTicketOutput
from pypdf import PdfReader
from .service import configure,reserve,settle,block,refund,serialized,expire,grant
from .service_context import service_grant
from pretix.base.services.orders import _perform_order
from .models import ServiceEvent,ServiceOrder


def run():
    checks=[]
    with serialized():
        event_id=uuid4()
        configure(dict(id=str(event_id),item_name='Synthetische Ermäßigung',price_cents=1250,quota=2,version=1))
        catalog=ServiceEvent.objects.get(pk=event_id)
        Discount.objects.create(event=catalog.event,internal_name='Test 20 Prozent',condition_min_count=1,benefit_discount_matching_percent=Decimal('20.00'))
        key=uuid4()
        body=dict(id=str(key),event_id=str(event_id),subject=hashlib.sha256(b'native-artifact-fixture').hexdigest(),account_id='acct_demo_'+'0'*32,total_cents=1250,fee_cents=63,fee_basis_points=500)
        quote=reserve(body)
        assert quote['total_cents']==1000 and quote['fee_cents']==50,quote
        row=ServiceOrder.objects.select_related('catalog','catalog__event').get(pk=key)
        settle(row,dict(outcome='success'))
        assert row.order.total==Decimal('10.00') and row.order.status=='p'
        assert row.order.payments.get().info_data['application_fee_amount']==50
        checks.append('Native Ermäßigung: 12,50 -> 10,00 EUR, Gebühr 50 Cent')
        # Forget only the bridge ACK, preserving native payment/order: recover once.
        native_id=row.order_id
        row.order=None;row.state='pending';row.save()
        settle(row,dict(outcome='success'))
        assert row.order_id==native_id and Order.objects.filter(event=catalog.event).count()==1
        checks.append('Native Bestellbestätigung nach verlorenem ACK wiederholbar')
        _,mime,pdf=PdfTicketOutput(catalog.event).generate_order(row.order)
        assert mime=='application/pdf' and pdf.startswith(b'%PDF-')
        reader=PdfReader(BytesIO(pdf));assert len(reader.pages)==1
        text=' '.join(p.extract_text() or '' for p in reader.pages)
        assert 'Synthetische Ermäßigung' in text
        assert not any(x in text for x in ['Hintereingang','application_fee_amount','native-artifact-fixture','purchase_eligible'])
        checks.append('Native PDF: eine Seite, keine geschützte Location oder Antragsantworten')
        clist=CheckinList.objects.create(event=catalog.event,name='Synthetischer Einlass')
        position=row.order.positions.get()
        perform_checkin(position,clist,{},simulate=True)
        block(row);position.refresh_from_db()
        try:perform_checkin(position,clist,{},simulate=True)
        except CheckInError:pass
        else:raise AssertionError('Blocked native admission remained valid')
        checks.append('Native Einlassprüfung akzeptiert Zahlung und verweigert gesperrtes Ticket')
        refund(row,dict(id=str(uuid4()),amount_cents=400))
        assert row.fee_refunded_cents==20
        refund(row,dict(id=str(uuid4()),amount_cents=600))
        assert row.fee_refunded_cents==50 and row.state=='refunded'
        checks.append('Ermäßigte Bestellung: Teil- und Rest-Erstattung einschließlich kompletter Gebühr')
        # A late receipt never creates another native ticket, but stays refundable.
        body['id']=str(uuid4());body['subject']=hashlib.sha256(b'native-late-fixture').hexdigest()
        reserve(body);late=ServiceOrder.objects.select_related('catalog','catalog__event').get(pk=body['id'])
        late.expires_at=now()-timedelta(seconds=1);late.save()
        CartPosition.objects.filter(cart_id=late.cart_id).update(expires=late.expires_at)
        result=settle(late,dict(outcome='late'))
        assert result['blocked'] and not result['valid_payment'] and not late.order_id
        refund(late,dict(id=str(uuid4()),amount_cents=late.total_cents))
        assert late.state=='refunded' and late.fee_refunded_cents==late.fee_cents
        checks.append('Verspätete simulierte Zahlung: kein Einlass, explizite Gebühren-Erstattung')
        body['id']=str(uuid4());body['subject']=hashlib.sha256(b'native-unpaid-fixture').hexdigest()
        reserve(body);unpaid=ServiceOrder.objects.select_related('catalog','catalog__event').get(pk=body['id'])
        token=service_grant.set(grant(unpaid))
        try:
            _perform_order(catalog.event,[{'provider':'communityaccess_stripe','amount':Decimal(unpaid.total_cents)/100,'info_data':{}}],
                list(CartPosition.objects.filter(cart_id=unpaid.cart_id).values_list('pk',flat=True)),None,'de',None,
                api_meta={'communityaccess':grant(unpaid)},cart_id=unpaid.cart_id)
        finally:service_grant.reset(token)
        unpaid.refresh_from_db();assert unpaid.order_id and unpaid.order.expires==unpaid.expires_at
        unpaid.expires_at=now()-timedelta(seconds=1);unpaid.save()
        expire();unpaid.refresh_from_db();unpaid.order.refresh_from_db()
        assert unpaid.state=='expired' and unpaid.order.status==Order.STATUS_EXPIRED
        assert catalog.quota.availability()[1]==2
        checks.append('Unbezahlte native Bestellung übernimmt 15-Minuten-Frist und gibt Kontingent nach Ablauf frei')
    print(json.dumps({'native_verification':'passed','checks':checks},ensure_ascii=False),flush=True)

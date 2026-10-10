"""Protect native checkout/order/download views with the current platform grant."""
from django.http import JsonResponse
from .policy import AccessDenied
from .models import ServiceOrder


def protect_native_session(request,event):
    from .signals import checked
    segments=request.path.strip('/').split('/')
    if event and 'community_access_pretix' in event.get_plugins() and not request.path.endswith('/community-access/entry/'):
        try:
            grant=checked(request,event)
            if 'order' in segments or 'ticket' in segments:
                part='order' if 'order' in segments else 'ticket'
                code=segments[segments.index(part)+1]
                row=ServiceOrder.objects.select_related('order').get(pk=grant['order_id'],catalog__event=event)
                if not row.order_id:
                    from .service import output
                    output(row)
                if not row.order_id or row.order.code.upper()!=code.upper():
                    raise AccessDenied('ACCOUNT_BOUND_ORDER_REQUIRED')
        except (AccessDenied,ServiceOrder.DoesNotExist,IndexError):
            return JsonResponse({'code':'CHECKOUT_DENIED'},status=403)
    return None

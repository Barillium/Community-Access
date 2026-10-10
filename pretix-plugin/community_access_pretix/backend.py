"""Private service channel. Never forward a browser-supplied URL or key."""
import json
import os
import urllib.request
from urllib.parse import urlsplit
from .policy import AccessDenied


def authorize(order_id, nonce, code=None):
    origin = os.environ.get('CA_BACKEND_ORIGIN', '')
    url = urlsplit(origin)
    # Initial integration is loopback-only, test mode only.
    if url.scheme != 'http' or url.hostname != '127.0.0.1' or url.port != 8000 or url.path or url.query or url.fragment or url.username:
        raise AccessDenied('PRIVATE_BACKEND_REQUIRED')
    credential = os.environ.get('CA_PRETIX_TOKEN', '')
    if len(credential) != 64:
        raise AccessDenied('PRIVATE_BACKEND_REQUIRED')
    body = {'order_id': order_id, 'browser_nonce': nonce}
    if code is not None:
        body['code'] = code
    request = urllib.request.Request(origin + '/api/ticketing/internal/' + ('redeem' if code is not None else 'validate'),
                                     data=json.dumps(body).encode(), headers={'Authorization': 'Bearer ' + credential, 'Content-Type': 'application/json'})
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *args, **kwargs):
            return None
    try:
        with urllib.request.build_opener(NoRedirect).open(request, timeout=3) as response:
            raw = response.read(8193)
            if len(raw) > 8192:
                raise AccessDenied('INVALID_CHECKOUT_RESPONSE')
            return json.loads(raw)
    except (OSError, ValueError):
        raise AccessDenied('CHECKOUT_UNAVAILABLE') from None

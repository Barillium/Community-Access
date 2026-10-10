from django.urls import set_urlconf
from django.http import JsonResponse, HttpResponse
from django.utils.cache import patch_vary_headers


class LocalServiceMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        entry=request.path.endswith('/community-access/entry/')
        origin=request.headers.get('Origin')
        if entry and origin and origin not in ('http://127.0.0.1:8300','http://127.0.0.1:8400'):
            return JsonResponse({'code':'ORIGIN_DENIED'},status=403)
        if request.path.split('/')[1] in ('events', 'orders', 'types'):
            request.urlconf = 'community_access_pretix.local_urls'
            set_urlconf(request.urlconf)
        response=HttpResponse(status=204) if entry and request.method=='OPTIONS' else self.get_response(request)
        if entry and origin=='http://127.0.0.1:8300':
            response['Access-Control-Allow-Origin']=origin
            response['Access-Control-Allow-Credentials']='true'
            response['Access-Control-Allow-Headers']='Content-Type'
            response['Access-Control-Allow-Methods']='GET, POST, OPTIONS'
            patch_vary_headers(response,('Origin',))
            response['Cache-Control']='no-store'
        if '/order/' in request.path or '/ticket/' in request.path:
            response['Referrer-Policy']='no-referrer'
        return response

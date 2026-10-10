from django.urls import re_path
from pretix.multidomain.maindomain_urlconf import urlpatterns as native_patterns
from .service import service

urlpatterns = [re_path(r'^(?:events|orders|types)(?:/.*)?$', service)] + native_patterns

from django.urls import re_path
from .views import entry

event_patterns = [re_path(r'^community-access/entry/$', entry, name='entry')]

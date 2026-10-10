"""Explicit synthetic runtime only. No external mail, broker or live payment."""
import os
from pretix.settings import *  # noqa: F403,F401

if os.environ.get('CA_NATIVE_PRETIX_TEST') != 'true':
    raise RuntimeError('Explicit native synthetic runtime required')
DEBUG = False
ALLOWED_HOSTS = ['127.0.0.1', 'localhost', 'testserver']
ROOT_URLCONF = 'community_access_pretix.local_urls'
EMAIL_BACKEND = 'django.core.mail.backends.locmem.EmailBackend'
CELERY_TASK_ALWAYS_EAGER = True
CELERY_TASK_EAGER_PROPAGATES = True
CELERY_BROKER_URL = 'memory://'
CELERY_RESULT_BACKEND = 'cache+memory://'
FETCH_ECB_RATES = False
LOGGING = {'version': 1, 'disable_existing_loggers': True}
MIDDLEWARE = list(MIDDLEWARE)  # noqa: F405
MIDDLEWARE.insert(MIDDLEWARE.index('pretix.multidomain.middlewares.MultiDomainMiddleware') + 1,
                  'community_access_pretix.local_middleware.LocalServiceMiddleware')

SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False

# Serve the wheel's precompiled, hashed assets without running npm or modifying vendor files.
STATICFILES_DIRS = [STATIC_ROOT]

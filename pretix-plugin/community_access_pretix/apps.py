from django.apps import AppConfig
from django.utils.translation import gettext_lazy as _


class PluginApp(AppConfig):
    name = 'community_access_pretix'
    verbose_name = 'Community Access'

    class PretixPluginMeta:
        name = _('Community Access')
        author = 'Community Access project'
        description = _('Account-bound checkout for approved Community Access guests.')
        visible = True
        version = '0.1.0'
        compatibility = 'pretix>=2026.8.0,<2026.9'

    def ready(self):
        from . import signals  # noqa: F401

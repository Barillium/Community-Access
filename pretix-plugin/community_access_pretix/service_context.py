from contextvars import ContextVar

# Only set by the authenticated, loopback-only service controller.
service_grant = ContextVar('communityaccess_service_grant', default=None)

import 'access_api.dart';

abstract interface class TicketingApi {
  Future<Map<String, dynamic>> ticketing(
    String path, {
    Map<String, dynamic>? body,
  });
}

/// Optional identity revision for flows with HTTP calls outside [TicketingApi].
/// A revision changes whenever the account session is replaced or revoked.
abstract interface class TicketingSessionContext {
  int get sessionRevision;
}

/// Keeps a multi-request UI action bound to the identity that started it.
class TicketingSessionGuard {
  final Object _api;
  final int? _revision;
  TicketingSessionGuard(Object api)
    : _api = api,
      _revision = api is TicketingSessionContext ? api.sessionRevision : null;

  void check() {
    final api = _api;
    if (api is TicketingSessionContext && _revision != api.sessionRevision) {
      throw const ApiFailure(
        'Die Sitzung wurde geändert. Bitte lade den aktuellen Stand erneut.',
        accessDenied: true,
      );
    }
  }
}

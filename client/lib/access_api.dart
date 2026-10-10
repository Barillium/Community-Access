import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiFailure implements Exception {
  final String message;
  final bool unauthenticated;
  final bool accessDenied;
  const ApiFailure(
    this.message, {
    this.unauthenticated = false,
    this.accessDenied = false,
  });
}

abstract class AccessApi {
  Future<void> login(String email, String password);
  Future<void> forgotPassword(String email);
  Future<void> resetPassword(
    String email,
    String token,
    String password,
    String confirmation,
  );
  Future<void> verifyEmail(String email, String token);
  Future<void> resendVerification();
  Future<Map<String, dynamic>> invitation(String token);
  Future<void> register(
    String invitation,
    String name,
    String email,
    String password,
    String confirmation,
  );
  Future<void> apply(
    String invitation,
    Object formId,
    Map<String, String> answers,
  );
  Future<Map<String, dynamic>> snapshot();
  Future<Map<String, dynamic>> event(Object id);
  Future<void> requestEvent(Object id);
  Future<void> withdrawApplication(Object id);
  Future<String> location(Object id);
  Future<void> logout();
  void close();
}

// Erhaltener HTTP-Vertrag des bisherigen Prototyps.
// Better Auth und das neue Produkt-Backend sind noch nicht angebunden.
class HttpAccessApi implements AccessApi {
  final http.Client _client;
  final Uri _base;
  String? _token;

  HttpAccessApi({
    http.Client? client,
    String baseUrl = const String.fromEnvironment(
      'API_URL',
      defaultValue: 'http://127.0.0.1:8000',
    ),
  }) : _client = client ?? http.Client(),
       _base = Uri.parse(baseUrl) {
    if (_base.scheme != 'http' ||
        _base.host != '127.0.0.1' ||
        _base.port != 8000 ||
        _base.userInfo.isNotEmpty) {
      throw ArgumentError('Only the local prototype API is supported.');
    }
  }

  Future<Map<String, dynamic>> _call(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
    try {
      final uri = _base.resolve('/api/$path');
      final response =
          await (body == null
                  ? _client.get(uri, headers: headers)
                  : _client.post(uri, headers: headers, body: jsonEncode(body)))
              .timeout(const Duration(seconds: 10));
      if (response.statusCode >= 400) {
        if (response.statusCode == 422 &&
            (path == 'verify-email' || path == 'reset-password')) {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          if ((error['errors'] as Map?)?.containsKey('token') == true) {
            throw const ApiFailure(
              'Der Link ist ungültig oder abgelaufen. Fordere einen neuen Link an.',
            );
          }
        }
        throw ApiFailure(switch (response.statusCode) {
          401 => 'Bitte melde dich erneut an.',
          403 => 'Für diese Aktion fehlt die aktuelle Berechtigung.',
          404
              when path == 'register' ||
                  path == 'invitations/preview' ||
                  path == 'applications' =>
            'Diese Einladung ist nicht verfügbar. Bitte frage die Gastgeber nach einem neuen Link.',
          404 => 'Dieser Eintrag ist nicht mehr verfügbar.',
          409 => 'Diese Aktion ist im aktuellen Zustand nicht möglich.',
          422 => 'Prüfe deine Angaben und die erforderlichen Bestätigungen.',
          429 => 'Zu viele Versuche. Bitte warte kurz.',
          _ => 'Die Anfrage konnte nicht abgeschlossen werden.',
        });
      }
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on ApiFailure {
      rethrow;
    } catch (_) {
      throw const ApiFailure('Der lokale Dienst ist gerade nicht erreichbar.');
    }
  }

  @override
  Future<void> login(String email, String password) async {
    final result = await _call(
      'login',
      body: {'email': email.trim().toLowerCase(), 'password': password},
    );
    _token = result['token'] as String;
  }

  @override
  Future<void> forgotPassword(String email) async {
    await _call('forgot-password', body: {'email': email.trim().toLowerCase()});
  }

  @override
  Future<void> resetPassword(
    String email,
    String token,
    String password,
    String confirmation,
  ) async {
    await _call(
      'reset-password',
      body: {
        'email': email.trim().toLowerCase(),
        'token': token,
        'password': password,
        'password_confirmation': confirmation,
      },
    );
    _token = null;
  }

  @override
  Future<void> verifyEmail(String email, String token) async {
    await _call(
      'verify-email',
      body: {'email': email.trim().toLowerCase(), 'token': token},
    );
  }

  @override
  Future<void> resendVerification() async {
    await _call('email/verification-notification', body: {});
  }

  @override
  Future<Map<String, dynamic>> invitation(String token) =>
      _call('invitations/preview', body: {'invitation': token});
  @override
  Future<void> register(
    String invitation,
    String name,
    String email,
    String password,
    String confirmation,
  ) async {
    final result = await _call(
      'register',
      body: {
        'invitation': invitation,
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': confirmation,
      },
    );
    _token = result['token'] as String;
  }

  @override
  Future<void> apply(
    String invitation,
    Object formId,
    Map<String, String> answers,
  ) async {
    await _call(
      'applications',
      body: {'invitation': invitation, 'form_id': formId, 'answers': answers},
    );
  }

  @override
  Future<Map<String, dynamic>> snapshot() => _call('me');
  @override
  Future<Map<String, dynamic>> event(Object id) => _call('events/$id');
  @override
  Future<void> requestEvent(Object id) async {
    await _call('events/$id/requests', body: {'age_confirmed': true});
  }

  @override
  Future<void> withdrawApplication(Object id) async {
    await _call('applications/$id/withdraw', body: {'confirm_withdraw': true});
  }

  @override
  Future<String> location(Object id) async =>
      (await _call('events/$id/location'))['location'] as String;
  @override
  Future<void> logout() async {
    try {
      if (_token != null) await _call('logout', body: {});
    } finally {
      _token = null;
    }
  }

  @override
  void close() => _client.close();
}

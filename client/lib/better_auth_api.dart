import 'dart:convert';

import 'package:http/http.dart' as http;

import 'access_api.dart';
import 'account_deletion_api.dart';
import 'store_release.dart';
import 'access_flow_api.dart';
import 'auth_mode.dart';
import 'directory_api.dart';
import 'ticketing_api.dart';
import 'legal_api.dart';
import 'event_drafts.dart';
import 'auth_http_client.dart'
    if (dart.library.js_interop) 'auth_http_client_web.dart';

abstract interface class SocialAuthApi {
  Future<List<String>> socialProviders();
  Future<Uri> startSocial(String provider, {bool link = false});
  Future<void> completeSocial();
}

abstract interface class AccountApi {
  Future<void> createAccount(String name, String email, String password);
}

class BetterAuthAccessApi
    implements
        AccessApi,
        AccountApi,
        AccountDeletionApi,
        AgeAwareAccountApi,
        DirectoryApi,
        SocialAuthApi,
        AccessFlowApi,
        TicketingApi,
        TicketingSessionContext,
        LegalApi {
  final http.Client _client;
  final Uri _base;
  String? _token;
  int _sessionEpoch = 0;
  @override
  int get sessionRevision => _sessionEpoch;
  // A navigation hint only; snapshot still verifies the session on the server.
  bool get hasSession => _token != null;
  final _invitationVersions = <String, int>{};

  BetterAuthAccessApi({
    http.Client? client,
    String baseUrl = const String.fromEnvironment(
      'CA_AUTH_API_ORIGIN',
      defaultValue: 'http://127.0.0.1:8000',
    ),
  }) : _client = client ?? createAuthClient(),
       _base = Uri.parse(baseUrl) {
    const configured = String.fromEnvironment(
      'CA_AUTH_API_ORIGIN',
      defaultValue: 'http://127.0.0.1:8000',
    );
    if (baseUrl != configured ||
        _base.host.isEmpty ||
        _base.origin != baseUrl ||
        _base.userInfo.isNotEmpty ||
        _base.path.isNotEmpty ||
        _base.hasQuery ||
        _base.hasFragment ||
        (_base.scheme != 'https' && baseUrl != 'http://127.0.0.1:8000')) {
      throw ArgumentError(
        'Only the explicitly configured auth origin is supported.',
      );
    }
  }

  Future<Map<String, dynamic>> _call(
    String path, {
    Map<String, dynamic>? body,
    bool adoptSession = false,
  }) async {
    final epoch = _sessionEpoch;
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };
      final response =
          await (body == null
                  ? _client.get(_base.resolve(path), headers: headers)
                  : _client.post(
                      _base.resolve(path),
                      headers: headers,
                      body: jsonEncode(body),
                    ))
              .timeout(const Duration(seconds: 10));
      if (epoch != _sessionEpoch) {
        throw const ApiFailure(
          'Die Sitzung wurde geändert. Bitte lade den aktuellen Stand erneut.',
          accessDenied: true,
        );
      }
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 &&
            (!adoptSession || path == '/api/account/me')) {
          _sessionEpoch++;
          EventDrafts.forApi(this).clear();
          _invitationVersions.clear();
          _token = null;
          throw const ApiFailure(
            'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.',
            unauthenticated: true,
          );
        }
        if (response.statusCode == 429) {
          final seconds = int.tryParse(response.headers['retry-after'] ?? '');
          throw ApiFailure(
            seconds != null && seconds > 0 && seconds <= 3600
                ? 'Zu viele Anfragen. Bitte warte $seconds Sekunden und versuche es erneut.'
                : 'Zu viele Anfragen. Bitte warte einen Moment und versuche es erneut.',
          );
        }
        String? code;
        try {
          code =
              (jsonDecode(response.body) as Map<String, dynamic>)['code']
                  as String?;
        } catch (_) {}
        if (code == 'REAUTHENTICATION_REQUIRED') {
          throw const ApiFailure(
            'Bitte melde dich erneut an oder bestätige dein aktuelles Passwort.',
          );
        }
        if (code == 'ACCOUNT_AGE_REQUIRED') {
          throw const ApiFailure(
            'Bitte bestätige das erforderliche Mindestalter für dein Konto.',
          );
        }
        if (code == 'ACCOUNT_AGE_REVIEW_REQUIRED') {
          throw const ApiFailure('Die Kontoanlage ist noch nicht verfügbar.');
        }
        if (code == 'LINK_STATUS_UNKNOWN') {
          throw const ApiFailure(
            'Der Status der Linkanfrage ist unklar. Prüfe zuerst dein Postfach und einen vorhandenen Link, bevor du einen neuen anforderst.',
          );
        }
        if (code == 'MAIL_UNAVAILABLE') {
          throw const ApiFailure(
            'Der Link konnte gerade nicht versendet werden. Ein bisher gültiger Link bleibt verwendbar. Versuche es später erneut.',
          );
        }
        if (code == 'PLATFORM_BLOCKED') {
          EventDrafts.forApi(this).clear();
          throw const ApiFailure(
            'Dein Konto ist für Plattformaktionen gesperrt. Eigene Bestellbelege und Beschwerden bleiben erreichbar.',
            accessDenied: true,
          );
        }
        if (path.startsWith('/api/account/social/')) {
          throw ApiFailure(switch (code) {
            'SOCIAL_REAUTH_REQUIRED' => 'Bestätige deine E-Mail-Adresse und melde dich vor dem Verbinden erneut an.',
            'SOCIAL_NOT_CONFIGURED' =>
              'Dieser Anbieter ist noch nicht eingerichtet.',
            _ => 'Die Anbieteranmeldung konnte nicht abgeschlossen werden. Bitte versuche es erneut.',
          });
        }
        if (path.startsWith('/api/directory/') ||
            path.startsWith('/api/access/') ||
            path.startsWith('/api/ticketing/') ||
            path.startsWith('/api/legal/')) {
          throw ApiFailure(
            switch (code) {
              'SALES_PAUSED' || 'PRIVATE_TICKETS_PAUSED' => 'Neue Ticketkäufe sind vorübergehend pausiert. Bestehende Bestellungen bleiben abrufbar.',
              'PRIVATE_COMMUNITIES_PAUSED' => 'Neue Communityaufnahmen und Freigaben sind vorübergehend pausiert.',
              'OWNER_REQUIRED' =>
                'Diese Aktion ist dem verantwortlichen Konto vorbehalten.',
              'OWNER_PROTECTED' =>
                'Das verantwortliche Konto kann hier nicht entfernt werden.',
              'INVITATION_UNAVAILABLE' =>
                'Die Einladung ist abgelaufen oder nicht mehr verfügbar.',
              'RULES_CHANGED' => 'Die Communityregeln wurden geändert. Bitte die Einladung erneut prüfen.',
              'SALES_CLOSED' =>
                'Dieses Ticketangebot ist derzeit nicht im Verkauf.',
              'ALREADY_CHECKED_IN' =>
                'Dieses Ticket wurde bereits beim Einlass verwendet.',
              'INDEPENDENT_REVIEW_REQUIRED' => 'Diese Entscheidung braucht eine andere zuständige Moderationsperson.',
              'FEE_REQUIRED' =>
                'Das Plattformteam muss zuerst einen Provisionssatz festlegen.',
              'FEE_CHANGED' => 'Der Provisionssatz wurde geändert. Bitte den aktuellen Stand laden.',
              'CONNECT_REQUIRED' => 'Zuerst das Veranstalterkonto verbinden.',
              'PURCHASE_APPROVAL_REQUIRED' =>
                'Der Veranstalter muss deinen Ticketkauf zuerst freigeben.',
              'TICKET_CONFIG_LOCKED' => 'Bei bestehenden Bestellungen oder Zusagen ist diese Ticketkonfiguration gesperrt.',
              'PUBLIC_TICKETING_REQUIRED' => 'Öffentlicher Verkauf braucht ein öffentliches Event ohne Mitgliedschaftspflicht.',
              'TICKET_QUOTA_MANAGED_BY_PRETIX' =>
                'Die Ticketplätze werden in der Ticketverwaltung festgelegt.',
              'TICKET_BLOCKED' => 'Dieses Ticket ist gesperrt. Eine Erstattung wird gegebenenfalls geprüft.',
              'INVALID_REFUND' =>
                'Der Erstattungsbetrag überschreitet den noch offenen Betrag.',
              'REFUND_MISMATCH' => 'Diese Erstattung wurde bereits mit einem anderen Betrag verarbeitet.',
              'TICKET_SERVICE_UNAVAILABLE' => 'Der Ticketdienst ist gerade nicht erreichbar. Bitte erneut prüfen.',
              'MEMBERSHIP_REQUIRED' => 'Für dieses Event ist eine aktive Communitymitgliedschaft nötig.',
              'TEAM_REQUIRED' =>
                'Dieser Bereich ist dem berechtigten Projektteam vorbehalten.',
              'INVALID_INVITATION' => 'Diese persönliche Einladung ist ungültig, abgelaufen oder gehört zu einem anderen Konto.',
              'ACCESS_BLOCKED' => 'Der Zugang wurde gesperrt. Bitte nutze den angegebenen Kontaktweg.',
              'EVENT_FULL' => 'Die Veranstaltung hat keine freien Plätze mehr.',
              'EVENT_STARTED' => 'Die Veranstaltung hat bereits begonnen. Neue Anfragen oder Zusagen sind nicht mehr möglich.',
              'AGE_ACKNOWLEDGEMENT_REQUIRED' =>
                'Bitte bestätige das vom Veranstalter angegebene Mindestalter.',
              'CAPACITY_BELOW_CONFIRMED' =>
                'Die Kapazität darf bestehende Zusagen nicht unterschreiten.',
              'ACCESS_POLICY_LOCKED' => 'Die Mitgliedschaftspflicht kann bei bestehenden Zusagen nicht geändert werden.',
              'FORM_REVIEW_REQUIRED' => 'Die Frage ist nicht geprüft oder fragt unzulässige Angaben ab. Verwende den Fragenkatalog.',
              'INVALID_DATE' =>
                'Bitte ein gültiges Datum und eine Uhrzeit angeben.',
              'EMPTY_FORM' || 'INVALID_FORM' => 'Bitte ein vorhandenes Formular auswählen oder zuerst erstellen.',
              'LEGAL_SALES_PAUSED' => 'Ticketverkauf zur Klärung pausiert',
              'LEGAL_EVENT_BLOCKED' =>
                'Veranstaltung gesperrt · Einlass angehalten',
              'LEGAL_DECLARATION_REQUIRED' || 'SELLER_REQUIRED' => 'Verkäuferangaben oder aktuelle Veranstalterbestätigung fehlen.',
              'SELLER_CHANGED' || 'DECLARATION_CHANGED' || 'REVIEW_CHANGED' =>
                'Der Prüfstand wurde geändert. Bitte neu laden.',
              'PRIVATE_LINK_DENIED' =>
                'Keine privaten Einladungslinks oder Zugangscodes eintragen.',
              'STATEMENT_EXISTS' =>
                'Deine Stellungnahme wurde bereits eingereicht.',
              'INVALID_FIELDS' => 'Bitte die Pflichtangaben und Zahlen prüfen.',
              'INVALID_PREFERENCES' =>
                'Bitte höchstens 12 kurze Angaben pro Präferenzfeld eintragen.',
              'EXPIRED_EVENT' => 'Die Löschfrist dieser Veranstaltung ist bereits abgelaufen. Sie kann nicht erneut gespeichert werden.',
              'END_REQUIRED' => 'Eine Endzeit ist erforderlich, damit die Löschfrist von exakt 168 Stunden nach Veranstaltungsende berechnet werden kann.',
              'PUBLIC_INFO_REQUIRED' => 'Öffentliche Veranstaltungen brauchen Beschreibung, Beginn und einen öffentlich auffindbaren Ort.',
              'RELEASE_REQUIRED' => 'Bitte beide Freigabezeitpunkte festlegen.',
              'REQUEST_DEADLINE_REQUIRED' => 'Bitte eine öffentliche Anfragefrist unabhängig vom Eventbeginn festlegen.',
              'REQUEST_CLOSED' => 'Die veröffentlichte Anfragefrist oder der sichtbare Beginn erlaubt diese Aktion nicht mehr.',
              'SEMI_PUBLIC_CONTENT' => 'Semi-öffentliche Events dürfen Zeit und Ort nicht öffentlich freigeben. Entferne den Flyer und verwende die geplante Freigabe.',
              'EVENT_ENDED' => 'Diese Veranstaltung ist bereits beendet.',
              'EVENT_NOT_ENDED' =>
                'Ein Besuch kann erst nach dem Ende eingetragen werden.',
              'INVALID_EVENT_CONTENT' => 'Bitte Eventinhalte prüfen: Ende nach Beginn, Line-up und Genres innerhalb der Grenzen sowie ein gültiger Flyer mit Bildbeschreibung.',
              'BODY_TOO_LARGE' =>
                'Die Eventangaben sind zu groß. Bitte den Flyer verkleinern.',
              'PUBLIC_PROFILE_REQUIRED' => 'Öffentliche Events und Reihen benötigen ein öffentliches Veranstalterprofil.',
              'PROFILE_REQUIRED' =>
                'Bitte ein Veranstalterprofil auswählen oder zuerst speichern.',
              'CATALOG_CHANGED' => 'Der Eintrag wurde inzwischen geändert. Lade den aktuellen Stand und prüfe die Freigaben erneut.',
              'SERIES_COMMUNITY_LOCKED' => 'Eine Reihe mit Events kann nicht in eine andere verantwortliche Community verschoben werden.',
              'VERIFY_EMAIL' => 'Bitte bestätige zuerst deine E-Mail-Adresse.',
              'HOST_REQUIRED' =>
                'Für diesen Bereich brauchst du zugeordnete Gastgeberrechte.',
              'NOT_FOUND' => 'Dieser Eintrag ist nicht verfügbar oder nicht für dich freigegeben.',
              'REQUEST_EXISTS' => 'Eine erneute Anfrage ist gesperrt. Bitte kontaktiere den Gastgeber über euren bestehenden Kontaktweg.',
              'FORM_CHANGED' => 'Das Formular wurde geändert. Lade die Seite neu und prüfe deine Angaben.',
              'INVALID_LINK' => 'Der Zugangslink ist ungültig, abgelaufen oder für ein anderes Konto bestimmt.',
              'ACCESS_DISABLED' =>
                'Dieser Zugangsweg ist momentan nicht freigegeben.',
              'INVALID_TRANSITION' => 'Diese Anfrage wurde bereits bearbeitet. Lade den aktuellen Stand.',
              'INVALID_RECIPIENT' => 'Der Empfänger braucht ein bestehendes Konto mit bestätigter E-Mail-Adresse.',
              _ => 'Die Aktion konnte nicht abgeschlossen werden. Prüfe deine Angaben und versuche es erneut.',
            },
            accessDenied:
                response.statusCode == 403 || response.statusCode == 404,
          );
        }
        final invalidLink =
            (path == '/api/account/verify' || path == '/api/account/reset');
        throw ApiFailure(switch (response.statusCode) {
          401 => 'E-Mail oder Passwort stimmen nicht überein.',
          403 => 'Für diese Aktion fehlt die aktuelle Berechtigung.',
          429 => 'Zu viele Versuche. Bitte warte kurz.',
          400 || 422 when invalidLink => 'Der Link ist ungültig oder abgelaufen. Fordere einen neuen Link an.',
          400 || 409 || 422 =>
            privateMailMode
                ? 'Prüfe deine Angaben.'
                : 'Prüfe deine Angaben. Verwende ein synthetisches Testkonto.',
          _ => 'Der lokale Auth-Dienst ist gerade nicht erreichbar.',
        });
      }
      if (adoptSession) {
        final token = response.headers['set-auth-token'];
        if ((token == null || token.isEmpty) &&
            (path != '/api/account/me' || _token == null)) {
          throw const ApiFailure(
            'Die Anmeldung konnte nicht abgeschlossen werden.',
          );
        }
        if (token != null && token.isNotEmpty) _token = token;
      }
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on ApiFailure {
      rethrow;
    } catch (_) {
      throw const ApiFailure(
        'Der lokale Auth-Dienst ist gerade nicht erreichbar.',
      );
    }
  }

  static const _socialOrder = ['google', 'apple', 'facebook'];
  @override
  Future<List<String>> socialProviders() async {
    final data = await _call('/api/account/social/providers');
    final active = data['providers'];
    if (active is! List || active.any((id) => !_socialOrder.contains(id))) {
      throw const ApiFailure(
        'Die Anmeldemethoden sind gerade nicht verfügbar.',
      );
    }
    return _socialOrder.where(active.contains).toList();
  }

  @override
  Future<Uri> startSocial(String provider, {bool link = false}) async {
    if (!_socialOrder.contains(provider)) {
      throw const ApiFailure('Unbekannte Anmeldemethode.');
    }
    final data = await _call(
      '/api/account/social/start',
      body: {'provider': provider, 'link': link},
    );
    final url = Uri.tryParse(
      data['url'] is String ? data['url'] as String : '',
    );
    const hosts = {
      'google': ['accounts.google.com'],
      'apple': ['appleid.apple.com'],
      'facebook': ['facebook.com', 'www.facebook.com'],
    };
    if (url == null ||
        url.scheme != 'https' ||
        url.userInfo.isNotEmpty ||
        !hosts[provider]!.contains(url.host) ||
        (url.hasPort && url.port != 443)) {
      throw const ApiFailure(
        'Die Anbieteranmeldung konnte nicht gestartet werden.',
      );
    }
    return url;
  }

  @override
  Future<void> completeSocial() async {
    _sessionEpoch++;
    EventDrafts.forApi(this).clear();
    _invitationVersions.clear();
    _token = null;
    await _call('/api/account/social/session', body: {}, adoptSession: true);
  }

  @override
  Future<Map<String, dynamic>> legal(
    String path, {
    Map<String, dynamic>? body,
  }) => _call('/api/legal/$path', body: body);

  @override
  Future<Map<String, dynamic>> ticketing(
    String path, {
    Map<String, dynamic>? body,
  }) => _call('/api/ticketing/$path', body: body);

  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) => _call(
    Uri(path: '/api/directory/$path', queryParameters: query).toString(),
    body: body,
  );

  @override
  Future<void> login(String email, String password) async {
    _sessionEpoch++;
    EventDrafts.forApi(this).clear();
    _invitationVersions.clear();
    _token = null;
    await _call(
      '/api/auth/sign-in/email',
      body: {'email': email.trim().toLowerCase(), 'password': password},
      adoptSession: true,
    );
  }

  @override
  Future<Map<String, dynamic>> accountDeletionStatus() =>
      _call('/api/account/deletion');

  @override
  Future<Map<String, dynamic>> requestAccountDeletion({String? password}) =>
      _call(
        '/api/account/deletion',
        body: {
          'confirmation': 'DELETE_ACCOUNT',
          if (password != null && password.isNotEmpty) 'password': password,
        },
      );

  @override
  Future<void> createAccountWithAge(
    String name,
    String email,
    String password, {
    required bool ageAcknowledged,
  }) => _createAccount(name, email, password, ageAcknowledged: ageAcknowledged);

  @override
  Future<void> createAccount(String name, String email, String password) =>
      _createAccount(name, email, password);

  Future<void> _createAccount(
    String name,
    String email,
    String password, {
    bool ageAcknowledged = false,
  }) async {
    _sessionEpoch++;
    EventDrafts.forApi(this).clear();
    _token = null;
    await _call(
      '/api/auth/sign-up/email',
      body: {
        if (storeBuild) 'age_acknowledged': ageAcknowledged,
        if (storeBuild) 'minimum_age': minimumAccountAge,
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );
  }

  @override
  Future<Map<String, dynamic>> snapshot() async {
    final result = await _call('/api/account/me', adoptSession: true);
    for (final e in result['events'] as List? ?? []) {
      if (e['request_status'] == 'approved') e['request_status'] = 'confirmed';
    }
    return result;
  }

  @override
  Future<void> forgotPassword(String email) async {
    await _call(
      '/api/auth/request-password-reset',
      body: {'email': email.trim().toLowerCase()},
    );
  }

  @override
  Future<void> verifyEmail(String email, String token) async {
    await _call('/api/account/verify', body: {'email': email, 'token': token});
  }

  @override
  Future<void> resendVerification() async {
    final user = (await snapshot())['user'] as Map<String, dynamic>;
    await _call(
      '/api/auth/send-verification-email',
      body: {'email': user['email']},
    );
  }

  @override
  Future<void> resetPassword(
    String email,
    String token,
    String password,
    String confirmation,
  ) async {
    if (password != confirmation) {
      throw const ApiFailure('Die Passwörter stimmen nicht überein.');
    }
    await _call(
      '/api/account/reset',
      body: {'email': email, 'token': token, 'newPassword': password},
    );
    _sessionEpoch++;
    EventDrafts.forApi(this).clear();
    _invitationVersions.clear();
    _token = null;
  }

  @override
  Future<void> logout() async {
    _sessionEpoch++;
    EventDrafts.forApi(this).clear();
    try {
      await _call('/api/auth/sign-out', body: {});
    } finally {
      _token = null;
      _invitationVersions.clear();
    }
  }

  @override
  Future<Map<String, dynamic>> access(
    String path, {
    Map<String, dynamic>? body,
  }) {
    if (_token == null) {
      throw const ApiFailure(
        'Bitte melde dich erneut an.',
        unauthenticated: true,
      );
    }
    return _call('/api/access/$path', body: body);
  }

  @override
  Future<Map<String, dynamic>> invitation(String token) async {
    final result = await access('invitations/preview', body: {'token': token});
    final form = result['form'] as Map<String, dynamic>;
    _invitationVersions[token] = form['version'] as int;
    form['questions'] = [
      for (final f in form['questions'] as List) {...f as Map, 'id': f['key']},
    ];
    return result;
  }

  @override
  Future<void> register(
    String invitation,
    String name,
    String email,
    String password,
    String confirmation,
  ) async {
    throw const ApiFailure(
      'Persönliche Einladungen gelten für ein bestehendes bestätigtes Konto. Bitte melde dich damit an.',
    );
  }

  @override
  Future<void> apply(
    String invitation,
    Object formId,
    Map<String, String> answers,
  ) async {
    final version = _invitationVersions[invitation];
    if (version == null) {
      throw const ApiFailure('Bitte öffne die Einladung erneut.');
    }
    await access(
      'applications',
      body: {'token': invitation, 'version': version, 'answers': answers},
    );
    _invitationVersions.remove(invitation);
  }

  @override
  Future<Map<String, dynamic>> event(Object id) async {
    final detail = await directory('events/$id');
    final state = await directory('events/$id/access');
    return {
      ...detail,
      ...state,
      'can_request':
          state['before_start'] == true &&
          state['request'] == null &&
          (state['membership_required'] != true || state['is_member'] == true),
      'can_location': state['request']?['status'] == 'approved',
      'request_status': state['request']?['status'] == 'approved'
          ? 'confirmed'
          : state['request']?['status'],
    };
  }

  @override
  Future<void> requestEvent(Object id) async {
    await directory(
      'events/$id/interest',
      body: {'answers': {}, 'age_acknowledged': true},
    );
  }

  @override
  Future<void> withdrawApplication(Object id) async {
    await access('applications/$id/withdraw', body: {});
  }

  @override
  Future<String> location(Object id) async =>
      (await access('events/$id/location'))['location'] as String;
  @override
  void close() {
    _sessionEpoch++;
    EventDrafts.forApi(this).clear();
    _token = null;
    _invitationVersions.clear();
    _client.close();
  }
}

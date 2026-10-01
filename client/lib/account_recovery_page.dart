import 'dart:convert';

import 'package:flutter/material.dart';

import 'access_api.dart';
import 'design_system.dart';
import 'local_mailbox_stub.dart'
    if (dart.library.js_interop) 'local_mailbox_web.dart';

class AccountLinkData {
  final String kind;
  final String? email;
  final String? token;
  const AccountLinkData(this.kind, {this.email, this.token});
}

AccountLinkData? accountLink(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'http' ||
      uri.host != '127.0.0.1' ||
      uri.port != 8300 ||
      uri.path != '/' ||
      uri.userInfo.isNotEmpty ||
      uri.query.isNotEmpty) {
    return null;
  }
  if (uri.fragment == 'forgot') return const AccountLinkData('forgot');
  final pieces = uri.fragment.split('&');
  if (pieces.length != 2) return null;
  try {
    final parts = Uri.splitQueryString(uri.fragment);
    final kind = parts.containsKey('verify') ? 'verify' : 'reset';
    if (parts.length != 2 ||
        !parts.containsKey(kind) ||
        !parts.containsKey('email')) {
      return null;
    }
    final token = parts[kind]!;
    final email = parts['email']!;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(token) ||
        email.length > 255 ||
        !RegExp(r'^[^@\s]+@example\.invalid$').hasMatch(email)) {
      return null;
    }
    return AccountLinkData(kind, email: email, token: token);
  } catch (_) {
    return null;
  }
}

String? syntheticEmail(String? value) =>
    RegExp(r'^[^@\s]+@example\.invalid$')
        .hasMatch((value ?? '').trim().toLowerCase())
    ? null
    : 'Verwende eine Adresse mit @example.invalid.';
String? newPassword(String? value) =>
    (value ?? '').length >= 12 &&
        value!.length <= 72 &&
        utf8.encode(value).length <= 72
    ? null
    : 'Verwende 12 bis 72 Zeichen und höchstens 72 UTF-8-Bytes.';

class LocalMailboxButton extends StatelessWidget {
  const LocalMailboxButton({super.key});
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () {
      if (!openLocalMailbox()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Das Testpostfach ist während der Backend-Umstellung noch nicht verfügbar.',
            ),
          ),
        );
      }
    },
    child: const Text('Lokales Testpostfach öffnen'),
  );
}

class VerificationNotice extends StatefulWidget {
  final AccessApi api;
  final String? email;
  final Future<void> Function() onRefresh;
  const VerificationNotice({
    super.key,
    required this.api,
    this.email,
    required this.onRefresh,
  });
  @override
  State<VerificationNotice> createState() => _VerificationNoticeState();
}

class _VerificationNoticeState extends State<VerificationNotice> {
  bool _busy = false;
  String? _message;
  Future<void> _resend() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.api.resendVerification();
      if (mounted) {
        setState(
          () => _message =
              'Prüfe dein Postfach. Der neueste Link ersetzt den bisherigen.',
        );
      }
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Der Link konnte nicht angefordert werden.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        widget.email == null
            ? 'Bestätige zuerst deine E-Mail-Adresse.'
            : 'Bestätige ${widget.email}, bevor du dich bewirbst.',
        style: const TextStyle(height: 1.6),
      ),
      const SizedBox(height: 16),
      const Text(
        'Der Link gilt 60 Minuten. Die Bestätigung ist keine Aufnahme oder Eventzusage.',
        style: TextStyle(height: 1.6),
      ),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Semantics(
            liveRegion: true,
            child: Text(_message!, style: const TextStyle(height: 1.6)),
          ),
        ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _busy ? null : _resend,
        child: const Text('Bestätigungslink erneut anfordern'),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                try {
                  await widget.onRefresh();
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
        child: const Text('Bestätigung prüfen'),
      ),
      const LocalMailboxButton(),
    ],
  );
}

class AccountRecoveryPage extends StatefulWidget {
  final AccessApi api;
  final AccountLinkData link;
  final VoidCallback? onPasswordReset;
  const AccountRecoveryPage({
    super.key,
    required this.api,
    required this.link,
    this.onPasswordReset,
  });
  @override
  State<AccountRecoveryPage> createState() => _AccountRecoveryPageState();
}

class _AccountRecoveryPageState extends State<AccountRecoveryPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _done = false;
  String? _error;
  late String? _token;
  @override
  void initState() {
    super.initState();
    _email.text = widget.link.email ?? '';
    _token = widget.link.token;
  }

  Future<void> _submit() async {
    if (_busy || _done || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      switch (widget.link.kind) {
        case 'verify':
          await widget.api.verifyEmail(_email.text, _token!);
        case 'reset':
          await widget.api.resetPassword(
            _email.text,
            _token!,
            _password.text,
            _confirmation.text,
          );
          widget.onPasswordReset?.call();
        default:
          await widget.api.forgotPassword(_email.text);
      }
      if (mounted) {
        setState(() {
          _done = true;
          _token = null;
          _password.clear();
          _confirmation.clear();
        });
      }
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Die Aktion konnte nicht abgeschlossen werden.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    _token = null;
    super.dispose();
  }

  Widget _passwordField(
    TextEditingController controller,
    String label,
    String? Function(String?) validator,
  ) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: TextFormField(
      controller: controller,
      enabled: !_busy,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [AutofillHints.newPassword],
      decoration: InputDecoration(labelText: label),
      validator: validator,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final kind = widget.link.kind;
    final title = kind == 'verify'
        ? 'E-Mail bestätigen.'
        : kind == 'reset'
        ? 'Neues Passwort festlegen.'
        : 'Passwort vergessen?';
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AccessTopBar(
          title: const Text('Dein Konto'),
          leading: IconButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            tooltip: 'Zur Anmeldung',
            icon: const AccessIcon(Icons.arrow_back),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final intro = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    headingLevel: 1,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w500,
                        height: 1.15,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Dein Zugang bleibt persönlich. Communityaufnahme und Eventzusage werden separat entschieden.',
                    style: TextStyle(height: 1.6),
                  ),
                ],
              );
              final content = AccessSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_busy)
                      const LinearProgressIndicator(
                        semanticsLabel: 'Anfrage wird bearbeitet',
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFA63028),
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
                    if (_done) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          kind == 'verify'
                              ? 'E-Mail-Adresse bestätigt. Melde dich an oder aktualisiere deine Gastübersicht.'
                              : kind == 'reset'
                              ? 'Passwort geändert. Bitte melde dich erneut an. Bisherige Sitzungen sind ungültig.'
                              : 'Wenn ein Konto mit dieser Adresse existiert, findest du einen Link im Postfach. Der Link gilt 60 Minuten.',
                          style: const TextStyle(fontSize: 18, height: 1.6),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, kind),
                        child: const Text('Zur Anmeldung'),
                      ),
                      if (kind == 'forgot') const LocalMailboxButton(),
                    ] else
                      Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (kind != 'forgot')
                              const Padding(
                                padding: EdgeInsets.only(bottom: 20),
                                child: Text(
                                  'Der Link gilt 60 Minuten und kann einmal verwendet werden.',
                                  style: TextStyle(height: 1.6),
                                ),
                              ),
                            TextFormField(
                              controller: _email,
                              enabled: !_busy,
                              readOnly: kind != 'forgot',
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              decoration: InputDecoration(
                                labelText: 'E-Mail',
                                counterText: kind == 'forgot' ? null : '',
                              ),
                              validator: syntheticEmail,
                              maxLength: 255,
                            ),
                            if (kind == 'reset') ...[
                              _passwordField(
                                _password,
                                'Neues Passwort',
                                newPassword,
                              ),
                              _passwordField(
                                _confirmation,
                                'Passwort bestätigen',
                                (value) => value == _password.text ? null : 'Die beiden Passwörter stimmen nicht überein.',
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Mindestens 12 Zeichen. Nach dem Wechsel werden bisherige Anmeldungen ungültig.',
                                style: TextStyle(height: 1.6),
                              ),
                            ],
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: Text(
                                kind == 'verify'
                                    ? 'E-Mail-Adresse bestätigen'
                                    : kind == 'reset'
                                    ? 'Passwort speichern'
                                    : 'Wiederherstellungslink anfordern',
                              ),
                            ),
                            if (kind == 'forgot') const LocalMailboxButton(),
                            if (kind == 'reset')
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => AccountRecoveryPage(
                                            api: widget.api,
                                            onPasswordReset:
                                                widget.onPasswordReset,
                                            link: const AccountLinkData(
                                              'forgot',
                                            ),
                                          ),
                                        ),
                                      ),
                                child: const Text('Passwort vergessen?'),
                              ),
                            if (kind == 'verify')
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.pop(context),
                                child: const Text('Zur Anmeldung'),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    const Text(
                      'Lokaler Prototyp · Nur erfundene Adressen mit @example.invalid. Nachrichten werden im lokalen Testpostfach abgelegt.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: Color(0xFF55514F),
                      ),
                    ),
                  ],
                ),
              );
              if (constraints.maxWidth >= 1000 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 18) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: intro),
                    const SizedBox(width: 48),
                    Expanded(flex: 3, child: content),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [intro, const SizedBox(height: 32), content],
              );
            },
          ),
        ),
      ),
    );
  }
}

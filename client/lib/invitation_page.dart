import 'dart:convert';

import 'package:flutter/material.dart';

import 'access_api.dart';
import 'design_system.dart';
import 'contact_button.dart';
import 'account_recovery_page.dart';
import 'auth_mode.dart';

String? invitationToken(String value) {
  final text = value.trim();
  if (RegExp(r'^[0-9a-f]{64}$').hasMatch(text)) return text;
  final uri = Uri.tryParse(text);
  if (uri == null ||
      !configuredAuthPageOrigin(uri) ||
      uri.userInfo.isNotEmpty ||
      uri.path != '/' ||
      uri.query.isNotEmpty) {
    return null;
  }
  final fragment = uri.fragment;
  if (!fragment.startsWith('invite=')) return null;
  final token = fragment.substring(7);
  return RegExp(r'^[0-9a-f]{64}$').hasMatch(token) ? token : null;
}

class InvitationPage extends StatefulWidget {
  final AccessApi api;
  final bool authenticated;
  final String? initialInvitation;
  final VoidCallback? onAuthenticated;
  const InvitationPage({
    super.key,
    required this.api,
    required this.authenticated,
    this.initialInvitation,
    this.onAuthenticated,
  });
  @override
  State<InvitationPage> createState() => _InvitationPageState();
}

class _InvitationPageState extends State<InvitationPage> {
  final _applicationForm = GlobalKey<FormState>();
  final _answers = <String, TextEditingController>{};
  String? _status;
  bool _statusChecked = false;
  bool _emailVerified = false;
  String? _accountEmail;
  final _form = GlobalKey<FormState>();
  final _link = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  Map<String, dynamic>? _invitation;
  String? _token;
  String? _error;
  bool _busy = false;
  bool _register = true;
  late bool _authenticated;

  @override
  void initState() {
    super.initState();
    _authenticated = widget.authenticated;
    final initial = widget.initialInvitation;
    if (initial != null) {
      _link.text = initial;
      _lookup();
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Der Einstieg konnte nicht abgeschlossen werden.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _lookup({String? currentToken}) => _run(() async {
    setState(() {
      _invitation = null;
      _token = null;
      _status = null;
      _statusChecked = false;
      for (final answer in _answers.values) {
        answer.clear();
      }
    });
    final token = currentToken ?? invitationToken(_link.text);
    if (token == null) {
      throw const ApiFailure('Füge einen gültigen lokalen Einladungslink ein.');
    }
    final data = await widget.api.invitation(token);
    if (mounted) {
      setState(() {
        _token = token;
        _invitation = data;
        _link.clear();
        for (final question in (data['form']?['questions'] as List? ?? [])) {
          _answers.putIfAbsent(
            question['id'] as String,
            TextEditingController.new,
          );
        }
      });
      if (_authenticated) await _checkStatus();
    }
  });

  Future<void> _authenticate() => _run(() async {
    if (!_form.currentState!.validate()) return;
    if (_register) {
      await widget.api.register(
        _token!,
        _name.text.trim(),
        _email.text.trim().toLowerCase(),
        _password.text,
        _confirmation.text,
      );
    } else {
      await widget.api.login(_email.text.trim().toLowerCase(), _password.text);
    }
    if (mounted) {
      setState(() {
        _authenticated = true;
        _password.clear();
        _confirmation.clear();
      });
    }
    if (!mounted) return;
    widget.onAuthenticated?.call();
    await _checkStatus();
  });

  Future<void> _checkStatus() async {
    final snapshot = await widget.api.snapshot();
    if (!mounted) return;
    final community = _invitation?['community_id'];
    String? status;
    for (final application in snapshot['applications'] as List? ?? []) {
      if (application['community_id'] == community && community != null) {
        final candidate = application['status'] as String;
        if (candidate != 'withdrawn' || status == null) status = candidate;
      }
    }
    for (final block in snapshot['application_blocks'] as List? ?? []) {
      if (block['community_id'] == community) {
        final reason = block['reason'] as String;
        if (reason != 'withdrawn' || status == null) status = reason;
      }
    }
    for (final member in snapshot['memberships'] as List? ?? []) {
      if (member['community_id'] == community && community != null) {
        status = member['active'] == true ? 'approved' : 'revoked';
      }
    }
    setState(() {
      _emailVerified = snapshot['user']?['email_verified'] == true;
      _accountEmail = snapshot['user']?['email'] as String?;
      _status = status;
      _statusChecked = true;
    });
  }

  Future<void> _apply() => _run(() async {
    if (!_applicationForm.currentState!.validate()) return;
    final form = _invitation!['form'] as Map<String, dynamic>;
    final answers = <String, String>{
      for (final question in form['questions'] as List)
        question['id'] as String: _answers[question['id']]!.text.trim(),
    };
    await widget.api.apply(_token!, form['id'] as Object, answers);
    if (mounted) {
      setState(() {
        _status = 'pending';
        for (final answer in _answers.values) {
          answer.clear();
        }
      });
    }
  });

  Widget _application() {
    if (!_statusChecked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Dein Bewerbungsstatus wird geprüft.',
            style: TextStyle(height: AccessTypography.readingHeight),
          ),
          const SizedBox(height: AccessSpacing.s16),
          OutlinedButton(
            onPressed: _busy ? null : () => _run(_checkStatus),
            child: const Text('Bewerbungsstatus aktualisieren'),
          ),
        ],
      );
    }
    if (_status != null && _status != 'withdrawn') {
      final text = switch (_status) {
        'pending' => 'Deine Bewerbung ist offen. Die Gastgeber entscheiden über deine Aufnahme.',
        'approved' =>
          'Du wurdest bereits aufgenommen. Eine Eventzusage erfolgt separat.',
        'revoked' => 'Deine Mitgliedschaft wurde entzogen. Eine erneute Bewerbung ist gesperrt.',
        'rejected' => 'Deine Bewerbung wurde abgelehnt. Eine erneute Bewerbung ist gesperrt.',
        _ => 'Eine erneute Bewerbung ist aktuell nicht möglich.',
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(
            _status == 'pending'
                ? 'Bewerbung eingereicht.'
                : 'Dein Bewerbungsstatus',
          ),
          const SizedBox(height: AccessSpacing.s16),
          Semantics(
            liveRegion: true,
            child: Text(
              text,
              style: const TextStyle(height: AccessTypography.readingHeight),
            ),
          ),
          const SizedBox(height: AccessSpacing.s24),
          if (['rejected', 'revoked'].contains(_status))
            ContactButton(contact: _invitation!['host_contact'] as String?),
          const SizedBox(height: AccessSpacing.s24),
          FilledButton(
            onPressed: _busy
                ? null
                : () => Navigator.of(context).pop(_authenticated),
            child: const Text('Zur Gastübersicht'),
          ),
        ],
      );
    }
    if (!_emailVerified) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading('E-Mail bestätigen'),
          const SizedBox(height: AccessSpacing.s16),
          VerificationNotice(
            api: widget.api,
            email: _accountEmail,
            onRefresh: () => _run(_checkStatus),
          ),
        ],
      );
    }
    final form = _invitation!['form'] as Map<String, dynamic>?;
    if (form == null) {
      return const Text(
        'Das Bewerbungsformular ist noch nicht verfügbar. Kontaktiere die Gastgeber.',
      );
    }
    return Form(
      key: _applicationForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading('Deine Bewerbung'),
          const SizedBox(height: AccessSpacing.s16),
          if (_status == 'withdrawn') ...[
            Semantics(
              liveRegion: true,
              child: const Text(
                'Du hast deine Bewerbung zurückgezogen. Du kannst dich mit dieser gültigen Einladung erneut bewerben.',
                style: TextStyle(height: AccessTypography.readingHeight),
              ),
            ),
            const SizedBox(height: AccessSpacing.s16),
          ],
          Text(
            'Deine Antworten gehen an die Gastgeber von ${_invitation!["community"]}. Sie entscheiden über deine Aufnahme.',
            style: const TextStyle(height: AccessTypography.readingHeight),
          ),
          const SizedBox(height: AccessSpacing.s16),
          const Text(
            'Verwende in dieser Demo ausschließlich erfundene Angaben. Teile keine intimen Angaben oder persönlichen Informationen über andere Personen.',
            style: TextStyle(height: AccessTypography.readingHeight),
          ),
          const SizedBox(height: AccessSpacing.s24),
          for (final (index, question) in (form['questions'] as List).indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AccessSpacing.s24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    headingLevel: 3,
                    child: Text(
                      question['label'] as String,
                      style: const TextStyle(
                        fontSize: AccessTypography.bodySize,
                        height: AccessTypography.bodyHeight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: AccessSpacing.s12),
                  AccessField(
                    decoration: InputDecoration(
                      labelText: 'Antwort auf Frage ${index + 1}',
                      helperText: question['required'] == true
                          ? 'Pflichtfeld'
                          : 'Optional',
                    ),
                    builder: (decoration) => TextFormField(
                      controller: _answers[question['id']],
                      enabled: !_busy,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 2000,
                      decoration: decoration,
                      validator: question['required'] == true
                          ? _required
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          const Text(
            'Die Aufnahme reserviert keinen Eventplatz. Nach freiwilligem Rückzug kannst du dich erneut bewerben. Nach Ablehnung oder Entzug ist eine erneute Bewerbung gesperrt; du kannst die Gastgeber kontaktieren.',
            style: TextStyle(
              fontSize: AccessTypography.captionSize,
              height: AccessTypography.readingHeight,
            ),
          ),
          const SizedBox(height: AccessSpacing.s24),
          FilledButton(
            onPressed: _busy ? null : _apply,
            child: const Text('Bewerbung einreichen'),
          ),
          TextButton(
            onPressed: _busy ? null : () => _lookup(currentToken: _token),
            child: const Text('Einladung aktualisieren'),
          ),
        ],
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Bitte ausfüllen.' : null;
  Widget _heading(String text) => Semantics(
    headingLevel: 2,
    child: Text(
      text,
      style: const TextStyle(
        fontSize: AccessTypography.sectionTitleSize,
        height: AccessTypography.titleHeight,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
  Widget _field(
    TextEditingController controller,
    String label, {
    bool password = false,
    String? Function(String?)? validate,
    int? maxLength,
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AccessSpacing.s20),
    child: AccessField(
      decoration: InputDecoration(labelText: label, counterText: ''),
      builder: (decoration) => TextFormField(
        controller: controller,
        enabled: !_busy,
        obscureText: password,
        maxLength: maxLength,
        keyboardType: keyboardType,
        validator: validate ?? _required,
        decoration: decoration,
        autocorrect: !password,
        enableSuggestions: !password,
      ),
    ),
  );

  @override
  void dispose() {
    for (final controller in [
      _link,
      _name,
      _email,
      _password,
      _confirmation,
      ..._answers.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _entryContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_busy)
        const Padding(
          padding: EdgeInsets.only(bottom: AccessSpacing.s20),
          child: LinearProgressIndicator(
            semanticsLabel: 'Einladung wird bearbeitet',
          ),
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: AccessSpacing.s20),
          child: Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFA63028),
                height: AccessTypography.readingHeight,
              ),
            ),
          ),
        ),
      if (_invitation == null) ...[
        AccessField(
          decoration: const InputDecoration(
            labelText: 'Einladungslink',
            helperText: 'Nur lokale Links dieses Prototyps.',
          ),
          builder: (decoration) => TextField(
            controller: _link,
            enabled: !_busy,
            autocorrect: false,
            enableSuggestions: false,
            decoration: decoration,
            onSubmitted: (_) => _lookup(),
          ),
        ),
        const SizedBox(height: AccessSpacing.s20),
        FilledButton(
          onPressed: _busy ? null : _lookup,
          child: const Text('Einladung prüfen'),
        ),
      ] else ...[
        _heading(_invitation!['community'] as String),
        const SizedBox(height: AccessSpacing.s24),
        if (!_authenticated) ...[
          _heading(
            _register ? 'Gastkonto anlegen' : 'Mit deinem Konto anmelden',
          ),
          const SizedBox(height: AccessSpacing.s16),
          const Text(
            'Im lokalen Prototyp nur erfundene Namen und Adressen mit @example.invalid verwenden.',
            style: TextStyle(
              fontSize: AccessTypography.captionSize,
              height: AccessTypography.readingHeight,
            ),
          ),
          const SizedBox(height: AccessSpacing.s24),
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_register) _field(_name, 'Name', maxLength: 80),
                _field(
                  _email,
                  'E-Mail',
                  keyboardType: TextInputType.emailAddress,
                  maxLength: 255,
                  validate: (value) =>
                      RegExp(r'^[^@\s]+@example\.invalid$')
                          .hasMatch((value ?? '').trim().toLowerCase())
                      ? null
                      : 'Verwende eine Adresse mit @example.invalid.',
                ),
                _field(
                  _password,
                  'Passwort',
                  password: true,
                  maxLength: 72,
                  validate: (value) =>
                      _register && utf8.encode(value ?? '').length > 72
                      ? 'Maximal 72 Bytes für dieses Passwort.'
                      : _register && (value ?? '').length < 12
                      ? 'Mindestens 12 Zeichen.'
                      : _required(value),
                ),
                if (_register)
                  _field(
                    _confirmation,
                    'Passwort wiederholen',
                    password: true,
                    maxLength: 72,
                    validate: (value) => value == _password.text
                        ? null
                        : 'Die Passwörter stimmen nicht überein.',
                  ),
                FilledButton(
                  onPressed: _busy ? null : _authenticate,
                  child: Text(_register ? 'Konto anlegen' : 'Anmelden'),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _register = !_register;
                    _password.clear();
                    _confirmation.clear();
                    _form.currentState?.reset();
                  }),
            child: Text(
              _register
                  ? 'Ich habe bereits ein Konto'
                  : 'Neues Gastkonto anlegen',
            ),
          ),
        ] else ...[
          _application(),
        ],
      ],
    ],
  );

  Widget _intro() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AccessHeading(
        'Dein Zugang zur Community.',
        level: 1,
        role: AccessHeadingRole.page,
      ),
      const SizedBox(height: AccessSpacing.s16),
      const Text(
        'Einladung – Bewerbung – manuelle Aufnahme. Ein Link allein gibt dir noch keinen Eventplatz.',
        style: TextStyle(
          fontSize: AccessTypography.captionSize,
          height: AccessTypography.readingHeight,
        ),
      ),
      const SizedBox(height: AccessSpacing.s24),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AccessTopBar(
        leading: IconButton(
          tooltip: 'Zur Gastübersicht',
          onPressed: _busy
              ? null
              : () => Navigator.of(context).pop(_authenticated),
          icon: const AccessIcon(Icons.arrow_back),
        ),
        title: const Text(
          'Einladung',
          style: TextStyle(fontSize: AccessTypography.leadSize),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: AccessPageFrame(
              width: AccessPageWidth.content,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AccessColumns(
                    minWidth: AccessLayout.accountColumnsMinWidth,
                    gap: AccessSpacing.s64,
                    stackedGap: 0,
                    flex: const [3, 5],
                    children: [
                      _intro(),
                      AccessSurface(child: _entryContent()),
                    ],
                  ),
                  const SizedBox(height: AccessSpacing.s32),
                  const Text(
                    'Alle Konten, Veranstalter und Orte sind erfunden.',
                    style: TextStyle(
                      fontSize: AccessTypography.labelSize,
                      height: AccessTypography.readingHeight,
                      color: Color(0xFF55514F),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

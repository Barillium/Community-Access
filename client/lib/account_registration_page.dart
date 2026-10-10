import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'access_api.dart';
import 'account_deletion_api.dart';
import 'store_release.dart';
import 'app_language.dart';
import 'auth_mode.dart';
import 'better_auth_api.dart';
import 'account_recovery_page.dart';
import 'design_system.dart';
import 'site_information_page.dart';

class AccountRegistrationPage extends StatefulWidget {
  final AccountApi api;
  const AccountRegistrationPage({super.key, required this.api});
  @override
  State<AccountRegistrationPage> createState() =>
      _AccountRegistrationPageState();
}

class _AccountRegistrationPageState extends State<AccountRegistrationPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false, _accountCreated = false, _ageAcknowledged = false;
  final _focus = List.generate(4, (_) => FocusNode());
  final _fieldKeys = List.generate(4, (_) => GlobalKey());
  String? _error;

  Future<void> _submit() async {
    if (_busy || _accountCreated) return;
    if (storeBuild && !_ageAcknowledged) {
      setState(
        () => _error = localText(
          context,
          'Bitte bestätige, dass du mindestens $minimumAccountAge Jahre alt bist.',
          'Please confirm that you are at least $minimumAccountAge years old.',
        ),
      );
      return;
    }
    if (!_form.currentState!.validate()) {
      final invalid = [
        _name.text.trim().isEmpty,
        syntheticEmail(_email.text) != null,
        newPassword(_password.text) != null,
        _confirmation.text != _password.text,
      ].indexOf(true);
      if (invalid >= 0) {
        _focus[invalid].requestFocus();
        final target = _fieldKeys[invalid].currentContext;
        if (target != null) await Scrollable.ensureVisible(target);
      }
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_accountCreated) {
        final api = widget.api;
        if (storeBuild && api is AgeAwareAccountApi) {
          await (api as AgeAwareAccountApi).createAccountWithAge(
            _name.text,
            _email.text,
            _password.text,
            ageAcknowledged: _ageAcknowledged,
          );
        } else {
          await api.createAccount(_name.text, _email.text, _password.text);
        }
        _accountCreated = true;
        _password.clear();
        _confirmation.clear();
      }
      TextInput.finishAutofillContext(shouldSave: false);
      if (mounted) setState(() {});
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Das Konto konnte nicht angelegt werden.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _email, _password, _confirmation]) {
      controller.dispose();
    }
    for (final node in _focus) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AccessTopBar(
        title: const LocalText(
          privateMailMode ? 'Dein Konto' : 'Dein Testkonto',
        ),
        leading: IconButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          tooltip: 'Zur Anmeldung',
          icon: const AccessIcon(Icons.arrow_back),
        ),
      ),
      body: SingleChildScrollView(
        child: AccessPageFrame(
          width: AccessPageWidth.form,
          child: AccessSurface(
            child: AutofillGroup(
              onDisposeAction: AutofillContextAction.cancel,
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AccessHeading(
                      privateMailMode ? 'Konto anlegen.' : 'Testkonto anlegen.',
                      role: AccessHeadingRole.page,
                      level: 1,
                    ),
                    const SizedBox(height: AccessSpacing.s20),
                    const LocalText(
                      privateMailMode
                          ? 'Verwende eine erreichbare E-Mail-Adresse. Dein Konto ist keine Communityaufnahme oder Eventzusage.'
                          : 'Verwende ausschließlich erfundene Angaben und eine E-Mail mit @example.invalid. Dein Konto ist keine Communityaufnahme oder Eventzusage.',
                      style: TextStyle(height: AccessTypography.readingHeight),
                    ),
                    if (_busy) const LinearProgressIndicator(),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AccessSpacing.s16),
                        child: Semantics(
                          liveRegion: true,
                          child: LocalText(_error!),
                        ),
                      ),
                    const SizedBox(height: AccessSpacing.s20),
                    if (!_accountCreated)
                      AccessField(
                        decoration: const InputDecoration(
                          labelText: privateMailMode ? 'Name' : 'Testname',
                        ),
                        builder: (decoration) => TextFormField(
                          key: _fieldKeys[0],
                          focusNode: _focus[0],
                          controller: _name,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          enabled: !_busy && !_accountCreated,
                          decoration: decoration,
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? privateMailMode
                                    ? localText(
                                        context,
                                        'Trage deinen Namen ein.',
                                      )
                                    : localText(
                                        context,
                                        'Trage einen erfundenen Namen ein.',
                                      )
                              : null,
                        ),
                      ),
                    const SizedBox(height: AccessSpacing.s20),
                    if (!_accountCreated)
                      AccessField(
                        decoration: const InputDecoration(labelText: 'E-Mail'),
                        builder: (decoration) => TextFormField(
                          key: _fieldKeys[1],
                          focusNode: _focus[1],
                          controller: _email,
                          enabled: !_busy && !_accountCreated,
                          decoration: decoration,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          autocorrect: false,
                          enableSuggestions: false,
                          validator: (v) {
                            final error = syntheticEmail(v);
                            return error == null
                                ? null
                                : localText(context, error);
                          },
                        ),
                      ),
                    const SizedBox(height: AccessSpacing.s20),
                    if (!_accountCreated)
                      AccessField(
                        decoration: const InputDecoration(
                          labelText: 'Passwort',
                        ),
                        builder: (decoration) => TextFormField(
                          key: _fieldKeys[2],
                          focusNode: _focus[2],
                          controller: _password,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          enabled: !_busy && !_accountCreated,
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: decoration,
                          validator: (v) {
                            final error = _accountCreated
                                ? null
                                : newPassword(v);
                            return error == null
                                ? null
                                : localText(context, error);
                          },
                        ),
                      ),
                    const SizedBox(height: AccessSpacing.s20),
                    if (!_accountCreated)
                      AccessField(
                        decoration: const InputDecoration(
                          labelText: 'Passwort bestätigen',
                        ),
                        builder: (decoration) => TextFormField(
                          key: _fieldKeys[3],
                          focusNode: _focus[3],
                          controller: _confirmation,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          onFieldSubmitted: (_) => _submit(),
                          enabled: !_busy && !_accountCreated,
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: decoration,
                          validator: (value) =>
                              _accountCreated || value == _password.text
                              ? null
                              : localText(
                                  context,
                                  'Die Passwörter stimmen nicht überein.',
                                ),
                        ),
                      ),
                    const SizedBox(height: AccessSpacing.s24),
                    if (storeBuild && !_accountCreated)
                      CheckboxListTile(
                        value: _ageAcknowledged,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          localText(
                            context,
                            'Ich bin mindestens $minimumAccountAge Jahre alt.',
                            'I am at least $minimumAccountAge years old.',
                          ),
                        ),
                        onChanged: _busy
                            ? null
                            : (value) => setState(
                                () => _ageAcknowledged = value == true,
                              ),
                      ),
                    if (_accountCreated) ...[
                      Semantics(
                        liveRegion: true,
                        child: LocalText(
                          'Wenn diese Adresse für ein neues Konto verwendet werden kann, erhältst du einen Bestätigungslink. Bestätige deine E-Mail-Adresse und melde dich danach an. Bei einem bestehenden Konto kannst du dich anmelden oder dein Passwort zurücksetzen.',
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const LocalText('Zur Anmeldung'),
                      ),
                      const LocalMailboxButton(),
                    ] else
                      AccessAction(
                        kind: AccessActionKind.primary,
                        onPressed: _busy ? null : _submit,
                        child: const LocalText(
                          privateMailMode
                              ? 'Konto anlegen'
                              : 'Testkonto anlegen',
                        ),
                      ),
                    const SiteInformationLinks(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import 'access_api.dart';
import 'account_deletion_api.dart';
import 'app_language.dart';
import 'design_system.dart';

class AccountDeletionPage extends StatefulWidget {
  final AccountDeletionApi api;
  const AccountDeletionPage({super.key, required this.api});
  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  final _password = TextEditingController();
  bool _confirmed = false, _busy = false, _loading = true;
  Map<String, dynamic>? _request;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.api.accountDeletionStatus();
      if (mounted) {
        setState(() => _request = data['request'] as Map<String, dynamic>?);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Der Status konnte nicht geladen werden. Bitte erneut versuchen.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_confirmed || _busy || _loading || _request != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.api.requestAccountDeletion(
        password: _password.text,
      );
      _password.clear();
      if (mounted) {
        setState(() => _request = data['request'] as Map<String, dynamic>);
      }
    } on ApiFailure catch (e) {
      _password.clear();
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      _password.clear();
      if (mounted) {
        setState(
          () => _error = 'Der Eingang ist unklar. Prüfe vor einer erneuten Anfrage den Status.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: accessAppBar(context, 'Konto löschen'),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        title: 'Konto löschen',
        width: AccessPageWidth.form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LocalText(
              localText(
                context,
                'Kontolöschung anfragen',
                'Request account deletion',
              ),
            ),
            const SizedBox(height: 16),
            LocalText(
              localText(
                context,
                'Du kannst hier die Löschung deines Kontos und deiner zugehörigen personenbezogenen Daten anfragen. Die Löschung wird vom Team bearbeitet. Offene Bestellungen, Erstattungen und gesetzlich erforderliche Finanznachweise müssen dabei gesondert behandelt werden.',
                'You can request deletion of your account and associated personal data here. The team processes the request. Pending orders, refunds and legally required financial records need separate handling.',
              ),
            ),
            if (_loading || _busy) const LinearProgressIndicator(),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(localText(context, _error!)),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() => _loading = true);
                        _load();
                      },
                child: LocalText(
                  localText(
                    context,
                    'Status erneut prüfen',
                    'Check status again',
                  ),
                ),
              ),
            ],
            if (_request != null) ...[
              const SizedBox(height: 24),
              Semantics(
                liveRegion: true,
                child: LocalText(
                  localText(
                    context,
                    'Deine Löschanfrage ist gespeichert. Dein Konto ist noch nicht gelöscht.',
                    'Your deletion request is saved. Your account has not been deleted yet.',
                  ),
                ),
              ),
              SelectableText(
                '${localText(context, 'Vorgang', 'Reference')}: ${_request!['id']}',
              ),
            ] else ...[
              const SizedBox(height: 24),
              TextField(
                controller: _password,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                enabled: !_busy && !_loading,
                decoration: InputDecoration(
                  labelText: localText(
                    context,
                    'Aktuelles Passwort',
                    'Current password',
                  ),
                  helperText: localText(
                    context,
                    'Bei einer Anmeldung innerhalb der letzten fünf Minuten kannst du das Feld leer lassen.',
                    'You can leave this empty if you signed in within the last five minutes.',
                  ),
                  helperMaxLines: 4,
                ),
              ),
              CheckboxListTile(
                value: _confirmed,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  localText(
                    context,
                    'Ich möchte die Löschung meines Kontos anfragen.',
                    'I want to request deletion of my account.',
                  ),
                ),
                onChanged: _busy || _loading
                    ? null
                    : (value) => setState(() => _confirmed = value == true),
              ),
              const SizedBox(height: 16),
              AccessAction(
                kind: AccessActionKind.primary,
                onPressed: _confirmed && !_busy && !_loading ? _submit : null,
                child: LocalText(
                  localText(
                    context,
                    'Löschanfrage senden',
                    'Submit deletion request',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

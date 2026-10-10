import 'package:flutter/material.dart';

import 'access_api.dart';
import 'access_flow_api.dart';
import 'app_language.dart';
import 'design_system.dart';
import 'legal_api.dart';
import 'legal_pages.dart';
import 'ticketing_api.dart';

/// Only the authenticated account's own cases; no management workspace.
class AccountComplaintsPage extends StatefulWidget {
  final AccessFlowApi api;
  const AccountComplaintsPage({super.key, required this.api});
  @override
  State<AccountComplaintsPage> createState() => _AccountComplaintsPageState();
}

class _AccountComplaintsPageState extends State<AccountComplaintsPage> {
  List<dynamic> cases = [];
  String? notice;
  bool busy = false;
  bool loaded = false;
  final submitted = <String>{};
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(AccountComplaintsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      generation++;
      cases = [];
      loaded = false;
      busy = false;
      notice = null;
      submitted.clear();
      load();
    }
  }

  @override
  void dispose() {
    generation++;
    super.dispose();
  }

  Future<void> load() async {
    if (busy) return;
    final epoch = generation;
    final session = TicketingSessionGuard(widget.api);
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      final result = await widget.api.access('policy/complaints');
      session.check();
      if (mounted && epoch == generation) {
        setState(() {
          cases = result['cases'] as List;
          loaded = true;
        });
      }
    } catch (e) {
      if (mounted && epoch == generation) {
        setState(() {
          cases = [];
          loaded = false;
          notice = e is ApiFailure
              ? e.message
              : 'Prüfungen konnten nicht geladen werden.';
        });
      }
    } finally {
      if (mounted && epoch == generation) setState(() => busy = false);
    }
  }

  Future<void> appeal(String id) async {
    if (busy || submitted.contains(id)) return;
    final epoch = generation;
    final session = TicketingSessionGuard(widget.api);
    final details = await showDialog<String>(
      context: context,
      builder: (_) => const _ComplaintDialog(),
    );
    if (details == null || !mounted || epoch != generation) return;
    setState(() => busy = true);
    try {
      session.check();
      final result = await widget.api.access(
        'policy/cases/$id/appeal',
        body: {'details': details},
      );
      session.check();
      if (mounted && epoch == generation) {
        setState(() {
          submitted.add(id);
          notice = result['already_submitted'] == true
              ? 'Beschwerde bereits eingereicht.'
              : 'Beschwerde eingereicht.';
        });
      }
    } catch (e) {
      if (mounted && epoch == generation) {
        setState(() {
          if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
            cases = [];
            loaded = false;
          }
          notice = e is ApiFailure
              ? e.message
              : 'Der Vorgang wurde nicht übernommen.';
        });
      }
    } finally {
      if (mounted && epoch == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const LocalText('Meine Beschwerden')),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        width: AccessPageWidth.form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (busy) const LinearProgressIndicator(),
            if (notice != null)
              Semantics(liveRegion: true, child: LocalText(notice!)),
            if (widget.api is LegalApi)
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              LegalReportPage(api: widget.api as LegalApi),
                        ),
                      ),
                child: const LocalText(
                  'Weitere Beschwerde oder Meldung einreichen',
                ),
              ),
            OutlinedButton(
              onPressed: busy ? null : load,
              child: const LocalText('Aktualisieren'),
            ),
            if (loaded && cases.isEmpty)
              const LocalText('Keine eigenen Moderationsfälle vorhanden.'),
            for (final item in cases)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const LocalText('Fallreferenz'),
                    SelectableText(item['id'] as String),
                    if (item['created_at'] != null) ...[
                      const LocalText('Erstellt am'),
                      Text(_caseDate(item['created_at'])),
                    ],
                    if (item['appeal_submitted_at'] != null) ...[
                      const LocalText('Beschwerde eingereicht am'),
                      Text(_caseDate(item['appeal_submitted_at'])),
                    ],
                    OutlinedButton(
                      onPressed:
                          busy ||
                              submitted.contains(item['id']) ||
                              item['appeal_submitted'] == true
                          ? null
                          : () => appeal(item['id'] as String),
                      child: LocalText(
                        submitted.contains(item['id']) ||
                                item['appeal_submitted'] == true
                            ? 'Beschwerde bereits eingereicht.'
                            : 'Erneute Prüfung verlangen',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

String _caseDate(dynamic value) {
  final date = DateTime.tryParse(value.toString())?.toLocal();
  if (date == null) return '—';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _ComplaintDialog extends StatefulWidget {
  const _ComplaintDialog();
  @override
  State<_ComplaintDialog> createState() => _ComplaintDialogState();
}

class _ComplaintDialogState extends State<_ComplaintDialog> {
  final controller = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const LocalText('Erneute Prüfung verlangen'),
    content: Form(
      key: form,
      child: TextFormField(
        controller: controller,
        maxLength: 4000,
        maxLines: 5,
        decoration: InputDecoration(
          labelText: localText(context, 'Begründung'),
        ),
        validator: (value) => (value ?? '').trim().isEmpty
            ? localText(context, 'Bitte ausfüllen.')
            : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const LocalText('Abbrechen'),
      ),
      TextButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, controller.text.trim());
          }
        },
        child: const LocalText('Einreichen'),
      ),
    ],
  );
}

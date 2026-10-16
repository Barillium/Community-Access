import 'product_scope.dart';

import 'package:flutter/material.dart';

import 'app_language.dart';
import 'access_api.dart';
import 'directory_api.dart';
import 'ticketing_api.dart';
import 'ticketing_pages.dart';
import 'design_system.dart';
import 'event_editorial_view.dart' show eventDay, eventTime;

class EventInterestPanel extends StatefulWidget {
  final DirectoryApi api;
  final String id;
  final Future<void> Function()? openAccount;
  final VoidCallback onChanged;
  const EventInterestPanel({
    super.key,
    required this.api,
    required this.id,
    this.openAccount,
    required this.onChanged,
  });
  @override
  State<EventInterestPanel> createState() => _EventInterestPanelState();
}

class _EventInterestPanelState extends State<EventInterestPanel> {
  Map<String, dynamic>? data;
  final answers = <String, TextEditingController>{};
  final form = GlobalKey<FormState>();
  bool busy = false;
  bool ageAcknowledged = false;
  int generation = 0;
  String? notice;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    generation++;
    for (final c in answers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(EventInterestPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.api != widget.api) {
      generation++;
      for (final c in answers.values) {
        c.dispose();
      }
      answers.clear();
      data = null;
      notice = null;
      ageAcknowledged = false;
      load();
    }
  }

  Future<void> load() async {
    final epoch = ++generation;
    try {
      final r = await widget.api.directory('events/${widget.id}/access');
      if (!mounted || epoch != generation) return;
      for (final f in r['form'] as List? ?? []) {
        answers.putIfAbsent(f['key'] as String, () => TextEditingController());
      }
      setState(() => data = r);
    } catch (e) {
      if (mounted && epoch == generation) {
        setState(() {
          data = null;
          notice = e is ApiFailure
              ? e.message
              : 'Die Anfrage ist derzeit nicht verfügbar.';
        });
      }
    }
  }

  Future<void> run(bool visit) async {
    if (busy || (!visit && !form.currentState!.validate())) return;
    setState(() => busy = true);
    try {
      await widget.api.directory(
        'events/${widget.id}/${visit ? 'visit' : 'interest'}',
        body: visit
            ? {}
            : {
                'answers': {
                  for (final a in answers.entries) a.key: a.value.text.trim(),
                },
                'form_version': data?['form_version'],
                'age_acknowledged': ageAcknowledged,
              },
      );
      if (mounted) {
        setState(
          () => notice = visit
              ? 'Besuch als allgemeine Veranstalterpräferenz gespeichert.'
              : 'Interesse gesendet.',
        );
        await load();
        widget.onChanged();
      }
    } catch (e) {
      if (e is ApiFailure && (e.unauthenticated || e.accessDenied) && mounted) {
        setState(() {
          data = null;
          ageAcknowledged = false;
          for (final c in answers.values) {
            c.clear();
          }
        });
      }
      if (mounted) {
        setState(
          () => notice = e is ApiFailure
              ? e.message
              : 'Die Aktion ist derzeit nicht möglich.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> withdrawTicket() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.api.directory('events/${widget.id}/withdraw', body: {});
      if (mounted) {
        await load();
        widget.onChanged();
      }
    } on ApiFailure catch (e) {
      if (mounted) setState(() => notice = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> showLocation() async {
    if (busy || widget.api is! AccessApi) return;
    setState(() => busy = true);
    try {
      final location = await (widget.api as AccessApi).location(widget.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const LocalText('Geschützte Location'),
          content: Text(location),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const LocalText('Schließen'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (e is ApiFailure && (e.unauthenticated || e.accessDenied) && mounted) {
        setState(() {
          data = null;
          ageAcknowledged = false;
          for (final c in answers.values) {
            c.clear();
          }
        });
      }
      if (mounted) {
        setState(
          () => notice = e is ApiFailure
              ? e.message
              : 'Die Location ist derzeit nicht verfügbar.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (notice != null)
          Semantics(liveRegion: true, child: LocalText(notice!)),
        if (data == null && notice != null && widget.openAccount != null)
          TextButton(
            onPressed: () async {
              await widget.openAccount!();
              if (mounted) await load();
            },
            child: const LocalText('Erneut anmelden'),
          ),
        if (data != null) ...[
          if (data!['request_deadline_at'] != null)
            LocalText(
              localText(
                context,
                'Öffentliche Anfragefrist: ${eventDay(data!['request_deadline_at'])} · ${eventTime(data!['request_deadline_at'])}',
                'Public request deadline: ${eventDay(data!['request_deadline_at'])} · ${eventTime(data!['request_deadline_at'])}',
              ),
            ),
          if (data!['signed_in'] != true)
            TextButton(
              onPressed: widget.openAccount == null
                  ? null
                  : () async {
                      await widget.openAccount!();
                      if (mounted) await load();
                    },
              child: const LocalText('Anmelden'),
            )
          else if (data!['ticket_mode'] == 'public')
            Text(
              localText(
                context,
                'Eintritt mit gültigem Ticket.',
                'Admission requires a valid ticket.',
              ),
            )
          else if (data!['request'] != null &&
              data!['request']['status'] != 'withdrawn') ...[
            Text(
              attendanceStatus(context, data!['request']['status'] as String),
            ),
            if (data!['can_withdraw'] == true &&
                [
                  'pending',
                  'approved',
                  'purchase_eligible',
                ].contains(data!['request']['status']))
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          await widget.api.directory(
                            'events/${widget.id}/withdraw',
                            body: {},
                          );
                          await load();
                          widget.onChanged();
                        } on ApiFailure catch (e) {
                          if (mounted) setState(() => notice = e.message);
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                child: Text(
                  localText(
                    context,
                    'Teilnahme zurückziehen',
                    'Withdraw attendance',
                  ),
                ),
              ),
            LocalText(
              localText(
                context,
                'Eine Zusage schaltet Informationen erst zum festgelegten Zeitpunkt frei.',
                'Approval releases details only at the scheduled times.',
              ),
            ),
          ] else if (data!['membership_required'] == true &&
              data!['is_member'] != true)
            Text(
              localText(
                context,
                'Für diese Veranstaltung ist eine aktive Communitymitgliedschaft nötig.',
                'An active community membership is required for this event.',
              ),
            )
          else if (data!['method'] == 'invite' &&
              data!['personally_invited'] != true)
            LocalText(
              localText(
                context,
                'Zugang nur über persönliche Freigabe des Veranstalters.',
                'Access requires a personal organizer invitation.',
              ),
            )
          else ...[
            if (data!['can_request'] != true)
              LocalText(
                localText(
                  context,
                  data!['request_deadline_at'] == null &&
                          data!['before_start'] == null
                      ? 'Eine öffentliche Anfragefrist wurde noch nicht festgelegt.'
                      : 'Anfragen sind derzeit geschlossen.',
                  data!['request_deadline_at'] == null &&
                          data!['before_start'] == null
                      ? 'A public request deadline has not been set yet.'
                      : 'Requests are currently closed.',
                ),
              ),
            LocalText(
              localText(
                context,
                'Dein Interesse wird vom Veranstalter geprüft. Eine Anfrage ist noch keine Zusage.',
                'The organizer reviews your interest. A request is not an approval.',
              ),
            ),
            for (final f in data!['form'] as List? ?? [])
              Padding(
                padding: const EdgeInsets.only(top: AccessSpacing.s16),
                child: AccessField(
                  decoration: InputDecoration(labelText: f['label'] as String),
                  builder: (d) => TextFormField(
                    controller: answers[f['key']],
                    maxLength: 500,
                    enabled: !busy,
                    decoration: d,
                    validator: (v) =>
                        f['required'] == true && (v ?? '').trim().isEmpty
                        ? localText(
                            context,
                            'Bitte beantworten.',
                            'Please answer.',
                          )
                        : null,
                  ),
                ),
              ),
            const SizedBox(height: AccessSpacing.s16),
            if (data!['minimum_age'] != null)
              CheckboxListTile(
                title: Text(
                  localText(
                    context,
                    'Ich bestätige, mindestens ${data!['minimum_age']} Jahre alt zu sein.',
                    'I confirm that I am at least ${data!['minimum_age']} years old.',
                  ),
                ),
                value: ageAcknowledged,
                onChanged: busy
                    ? null
                    : (v) => setState(() => ageAcknowledged = v ?? false),
              ),
            AccessAction(
              kind: AccessActionKind.primary,
              onPressed:
                  busy ||
                      (data!['minimum_age'] != null && !ageAcknowledged) ||
                      data!['can_request'] != true
                  ? null
                  : () => run(false),
              child: const LocalText('Interesse bekunden'),
            ),
          ],
          if (data!['signed_in'] == true &&
              widget.api is TicketingApi &&
              ['public', 'approval'].contains(data!['ticket_mode']))
            TicketPurchasePanel(
              api: widget.api as TicketingApi,
              eventId: widget.id,
              onChanged: () {
                load();
                widget.onChanged();
              },
            ),
          if (data!['ticket_mode'] == 'public' && data!['can_withdraw'] == true)
            TextButton(
              onPressed: busy ? null : withdrawTicket,
              child: const LocalText('Teilnahme zurückziehen'),
            ),
          if (data!['can_location'] == true &&
              widget.api is AccessApi &&
              ['public', 'approval'].contains(data!['ticket_mode']))
            OutlinedButton(
              onPressed: busy ? null : showLocation,
              child: const LocalText('Geschützte Location abrufen'),
            ),
          if (ProductScope.extended && data!['can_visit'] == true) ...[
            const SizedBox(height: AccessSpacing.s16),
            OutlinedButton(
              onPressed: busy ? null : () => run(true),
              child: const LocalText('Ich war dort'),
            ),
          ],
        ] else
          TextButton(
            onPressed: load,
            child: const LocalText('Erneut versuchen'),
          ),
      ],
    ),
  );
}

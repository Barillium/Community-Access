import 'dart:convert';

import 'package:flutter/material.dart';

import 'design_system.dart';
import 'app_language.dart';
import 'event_datetime_field.dart';

/// Copy editable content only. IDs, versions, guests and grants stay at source.
Map<String, dynamic> eventCopy(Map<String, dynamic> source, {int? afterDays}) {
  final copy = <String, dynamic>{
    for (final key in [
      'title',
      'community_id',
      'series_id',
      'access_mode',
      'is_public',
      'review_method',
      'form_id',
      'membership_required',
      'capacity',
      'exact_location',
      'public_location',
      'location_public',
      'starts_public',
      'access_details',
      'event_content',
    ])
      if (source.containsKey(key)) key: source[key],
    'status': 'draft',
  };
  final out = jsonDecode(jsonEncode(copy)) as Map<String, dynamic>;
  final content = Map<String, dynamic>.from(out['event_content'] as Map? ?? {});
  String? shift(dynamic raw) {
    final date = eventDate(raw as String?);
    if (date == null || afterDays == null) return null;
    return DateTime(
      date.year,
      date.month,
      date.day + afterDays,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    ).toUtc().toIso8601String();
  }

  out['starts_at'] = shift(source['starts_at']);
  content['ends_at'] = shift(content['ends_at']);
  out['event_content'] = content;
  for (final key in [
    'request_deadline_at',
    'time_release_at',
    'location_release_at',
  ]) {
    out[key] = shift(source[key]);
  }
  if (afterDays == null) {
    final title = source['title'] as String? ?? '';
    out['title'] =
        '${title.length > 170 ? title.substring(0, 170) : title} – Kopie';
  }
  return out;
}

Future<Map<String, dynamic>?> nextEventDraft(
  BuildContext context,
  Map<String, dynamic> event,
) async {
  final days = await showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const LocalText('Folgetermin vorbereiten'),
      children: [
        const Padding(
          padding: EdgeInsets.all(24),
          child: LocalText(
            'Der nächste Termin wird als eigener Entwurf geöffnet. Prüfe Datum, Fristen und Inhalte. Zusagen und Freigaben werden nicht übernommen.',
          ),
        ),
        for (final option in {
          7: 'In einer Woche',
          14: 'In zwei Wochen',
          28: 'In vier Wochen',
        }.entries)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, option.key),
            child: LocalText(option.value),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context),
          child: const LocalText('Abbrechen'),
        ),
      ],
    ),
  );
  return days == null ? null : eventCopy(event, afterDays: days);
}

class EventManagementList extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  final bool busy;
  final bool profilePublic;
  final List<Map<String, dynamic>> series;
  final ValueChanged<Map<String, dynamic>> onEdit,
      onDuplicate,
      onNext,
      onPreview;
  const EventManagementList({
    super.key,
    required this.events,
    required this.busy,
    this.profilePublic = false,
    this.series = const [],
    required this.onEdit,
    required this.onDuplicate,
    required this.onNext,
    required this.onPreview,
  });
  @override
  State<EventManagementList> createState() => _EventManagementListState();
}

class _EventManagementListState extends State<EventManagementList> {
  String _query = '', _status = 'all';
  @override
  Widget build(BuildContext context) {
    final events = widget.events
        .where(
          (e) =>
              (_status == 'all' || e['status'] == _status) &&
              (e['title'] as String).toLowerCase().contains(
                _query.toLowerCase(),
              ),
        )
        .toList();
    return AccessContent(
      width: AccessPageWidth.content,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AccessSpacing.s16),
          AccessContent(
            width: AccessPageWidth.form,
            child: AccessField(
              decoration: const InputDecoration(
                labelText: 'Eigene Events suchen',
              ),
              builder: (d) => TextField(
                enabled: !widget.busy,
                decoration: d,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ),
          const SizedBox(height: AccessSpacing.s16),
          AccessContent(
            width: AccessPageWidth.form,
            child: AccessField(
              decoration: const InputDecoration(
                labelText: 'Eventstatus filtern',
              ),
              builder: (d) => DropdownButtonFormField<String>(
                initialValue: _status,
                isExpanded: true,
                itemHeight: null,
                decoration: d,
                items: [
                  for (final s in {
                    'all': 'Alle Events',
                    'draft': 'Entwürfe',
                    'published': 'Veröffentlicht',
                    'cancelled': 'Abgesagt',
                  }.entries)
                    DropdownMenuItem(
                      value: s.key,
                      child: AccessOptionText(s.value),
                    ),
                ],
                onChanged: widget.busy
                    ? null
                    : (v) => setState(() => _status = v!),
              ),
            ),
          ),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: LocalText('Keine passenden Events.'),
            ),
          for (final e in events) _row(context, e),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> e) {
    final palette = AushangPalette.of(context);
    final public =
        widget.profilePublic &&
        e['is_public'] == true &&
        (e['series_id'] == null ||
            widget.series.any(
              (s) => s['id'] == e['series_id'] && s['is_public'] == true,
            ));
    final status = switch (e['status']) {
      'draft' => 'Entwurf',
      'cancelled' => 'Abgesagt',
      _ => 'Veröffentlicht',
    };
    final access = public
        ? (e['access_mode'] == 'semi_public'
              ? 'Semi-öffentlich'
              : 'Frei sichtbar')
        : 'Nur freigegebener Gästekreis';
    final heading = Text(
      e['title'] as String,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        fontVariations: [FontVariation('wdth', 100)],
      ),
    );
    final date = LocalText(eventDateLabel(e['starts_at'] as String?));
    final state = LocalText(status);
    final visibility = LocalText(access);
    final place = LocalText(
      e['location_public'] == true
          ? e['public_location'] as String? ?? ''
          : 'Ort nicht öffentlich',
      style: TextStyle(color: palette.muted),
    );
    final numbers = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (e.containsKey('pending_count') &&
            e.containsKey('confirmed_count')) ...[
          LocalText(
            '${e['pending_count']} offene Anfragen · ${e['confirmed_count']} Zusagen',
          ),
          LocalText(
            e['ticket_mode'] != null && e['ticket_mode'] != 'none'
                ? 'Ticketplätze werden von pretix verwaltet'
                : e['capacity'] == null
                ? 'Kapazität unbegrenzt'
                : '${e['available_places']} freie Plätze von ${e['capacity']}',
          ),
        ] else
          const LocalText('Platzübersicht noch nicht verfügbar.'),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.hair)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (AccessLayout.columns(
              context,
              constraints.maxWidth,
              minWidth: 900,
            ))
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [heading, const SizedBox(height: 8), place],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: date),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [visibility, const SizedBox(height: 8), state],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: numbers),
                ],
              )
            else
              AccessStack(
                gap: 12,
                children: [heading, date, visibility, state, place, numbers],
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: AccessSpacing.s12,
              runSpacing: AccessSpacing.s8,
              children: [
                TextButton(
                  onPressed: widget.busy ? null : () => widget.onEdit(e),
                  child: const LocalText('Event bearbeiten'),
                ),
                TextButton(
                  onPressed: widget.busy ? null : () => widget.onDuplicate(e),
                  child: const LocalText('Event duplizieren'),
                ),
                TextButton(
                  onPressed:
                      widget.busy ||
                          eventDate(e['starts_at'] as String?) == null
                      ? null
                      : () => widget.onNext(e),
                  child: const LocalText('Folgetermin vorbereiten'),
                ),
                TextButton(
                  onPressed: widget.busy ? null : () => widget.onPreview(e),
                  child: const LocalText('Wer sieht was?'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

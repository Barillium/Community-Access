import 'package:ca_design/ca_design.dart' show EmbossedLock;

import 'flyer_design.dart';
import 'event_participation.dart';
import 'event_hero_metadata.dart';

import 'app_language.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'event_access_details.dart';
import 'design_system.dart';

String eventDay(dynamic value) {
  final date = value is String ? DateTime.tryParse(value)?.toLocal() : null;
  if (date == null) return '';
  const days = ['Mo.', 'Di.', 'Mi.', 'Do.', 'Fr.', 'Sa.', 'So.'];
  const months = [
    'Jan.',
    'Feb.',
    'März',
    'Apr.',
    'Mai',
    'Juni',
    'Juli',
    'Aug.',
    'Sept.',
    'Okt.',
    'Nov.',
    'Dez.',
  ];
  return '${days[date.weekday - 1]}, ${date.day}. ${months[date.month - 1]} ${date.year}';
}

String eventTime(dynamic value) {
  final date = value is String ? DateTime.tryParse(value)?.toLocal() : null;
  if (date == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.hour)}:${two(date.minute)}';
}

/// A single rendering for saved events, audience previews and unsaved host drafts.
class EventEditorialView extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback? onOrganizer;
  final Widget? interestControl, participation, reportAction;
  final bool edgeToEdge;
  const EventEditorialView({
    super.key,
    required this.event,
    this.onOrganizer,
    this.interestControl,
    this.participation,
    this.reportAction,
    this.edgeToEdge = false,
  });
  @override
  Widget build(BuildContext context) {
    final content = Map<String, dynamic>.from(
      event['event_content'] as Map? ?? {},
    );
    final lineup = content['line_up'] as List? ?? [];
    final genres = content['genres'] as List? ?? [];
    final title = event['title'] as String? ?? '';
    final organizer = event['organizer'] as String? ?? '';
    final venue = content['venue_name'] as String? ?? '';
    final location = event['location'] as String? ?? '';
    final startDay = eventDay(event['starts_at']);
    final startDate = DateTime.tryParse(event['starts_at'] as String? ?? '')
        ?.toLocal();
    const weekdaysDe = [
      'Montag',
      'Dienstag',
      'Mittwoch',
      'Donnerstag',
      'Freitag',
      'Samstag',
      'Sonntag',
    ];
    const weekdaysEn = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final endDay = eventDay(content['ends_at']);
    final endTime = eventTime(content['ends_at']);
    final flyer = content['flyer_data'] as String? ?? '';
    final rawRatio = content['flyer_aspect_ratio'];
    final flyerRatio =
        rawRatio is num && rawRatio.isFinite && rawRatio >= .1 && rawRatio <= 10
        ? rawRatio.toDouble()
        : 3 / 4;
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final facts = <Widget>[
          if (event['request_deadline_at'] != null)
            _EventFact(
              label: 'Öffentliche Anfragefrist',
              value: eventDay(event['request_deadline_at']),
              detail: eventTime(event['request_deadline_at']),
            ),
          _EventFact(
            label: 'Veranstaltungsort',
            locked: venue.isEmpty && location.isEmpty,
            value: venue.isNotEmpty
                ? venue
                : location.isNotEmpty
                ? location
                : 'Noch nicht freigegeben',
            detail: venue.isNotEmpty && location != venue ? location : '',
          ),
        ];
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if ((content['description'] as String? ?? '').isNotEmpty) ...[
              Text(
                content['description'] as String,
                style: AccessTypography.lead,
              ),
              const SizedBox(height: AccessSpacing.s32),
            ],
            if (lineup.isNotEmpty) ...[
              const _EventHeading('Line-up'),
              const SizedBox(height: AccessSpacing.s20),
              Divider(color: colors.onSurface),
              for (final artist in lineup) _LineupRow(artist as String),
              const SizedBox(height: AccessSpacing.s32),
            ],
            if (genres.isNotEmpty) ...[
              Wrap(
                spacing: AccessSpacing.s12,
                runSpacing: AccessSpacing.s12,
                children: [
                  for (final genre in genres)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AccessSpacing.s16,
                        vertical: AccessSpacing.s8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.outline),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Text(genre as String),
                    ),
                ],
              ),
              const SizedBox(height: AccessSpacing.s32),
            ],
            if ((content['admission'] as String? ?? '').isNotEmpty ||
                content['minimum_age'] != null) ...[
              const _EventHeading('Einlass'),
              const SizedBox(height: AccessSpacing.s16),
              if (content['minimum_age'] != null)
                Text(
                  'Mindestalter: ${content['minimum_age']} Jahre',
                  style: const TextStyle(
                    fontSize: AccessTypography.bodySize,
                    height: AccessTypography.readingHeight,
                  ),
                ),
              if ((content['admission'] as String? ?? '').isNotEmpty)
                Text(
                  content['admission'] as String,
                  style: const TextStyle(
                    fontSize: AccessTypography.bodySize,
                    height: AccessTypography.readingHeight,
                  ),
                ),
              const SizedBox(height: AccessSpacing.s32),
            ],
            EventAccessDetails(
              details: Map<String, dynamic>.from(
                event['access_details'] as Map? ?? {},
              ),
            ),
          ],
        );
        final editorial = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if ((event['series'] as String? ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AccessSpacing.s16),
                child: Text(
                  event['series'] as String,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: AccessTypography.bodySize,
                  ),
                ),
              ),
            Padding(
              padding: edgeToEdge && flyer.isEmpty
                  ? EdgeInsets.all(
                      AccessLayout.gutter(context, constraints.maxWidth),
                    )
                  : EdgeInsets.zero,
              child: FlyerScene(
                minHeight: 540,
                showImage: flyer.isNotEmpty,
                posterAspectRatio: flyerRatio,
                image: flyer.isEmpty
                    ? null
                    : EventFlyer(
                        data: flyer,
                        fit: BoxFit.contain,
                        aspectRatio: flyerRatio,
                        backgroundColor: FlyerStyle.ink,
                        alt: content['flyer_alt'] as String? ?? title,
                      ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FlyerTitle(
                      title.isEmpty
                          ? localText(context, 'Veranstaltung', 'Event')
                          : title,
                      size: AccessTypography.page(
                        MediaQuery.sizeOf(context).width,
                      ),
                      italic: true,
                    ),
                    const SizedBox(height: 24),
                    if (startDay.isNotEmpty)
                      Wrap(
                        spacing: 24,
                        runSpacing: 16,
                        children: [
                          if (startDate != null)
                            Text(
                              localText(
                                context,
                                weekdaysDe[startDate.weekday - 1],
                                weekdaysEn[startDate.weekday - 1],
                              ),
                            ),
                          FlyerMark(
                            kind: FlyerMarkKind.circle,
                            child: Text(
                              '${startDate?.day.toString().padLeft(2, '0')}.${startDate?.month.toString().padLeft(2, '0')}.${startDate?.year}',
                            ),
                          ),
                          Text(
                            '${eventTime(event['starts_at'])}${endTime.isEmpty ? '' : ' – $endTime'}${endDay != startDay && endDay.isNotEmpty ? ' · $endDay' : ''}',
                          ),
                        ],
                      )
                    else
                      const LocalText('Wird bekannt gegeben'),
                    if (organizer.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Text(
                        localText(context, 'Veranstalter', 'Organizer'),
                        style: const TextStyle(
                          fontSize: AccessTypography.labelSize,
                        ),
                      ),
                      if (onOrganizer != null)
                        TextButton(
                          onPressed: onOrganizer,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                          ),
                          child: Text(
                            organizer,
                            style: const TextStyle(
                              fontSize: AccessTypography.leadSize,
                            ),
                          ),
                        )
                      else
                        Text(
                          organizer,
                          style: const TextStyle(
                            fontSize: AccessTypography.leadSize,
                          ),
                        ),
                    ],
                    const SizedBox(height: 28),
                    EventHeroMetadata(event: event),
                  ],
                ),
              ),
            ),
            AccessPageFrame(
              mainLandmark: false,
              width: AccessPageWidth.detail,
              edgeToEdge: !edgeToEdge,
              verticalPadding: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (reportAction != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AccessSpacing.s12),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: reportAction!,
                      ),
                    ),
                  const SizedBox(height: 32),
                  if (event['status'] == 'cancelled')
                    const Padding(
                      padding: EdgeInsets.only(top: AccessSpacing.s16),
                      child: Text(
                        'Dieses Event ist abgesagt.',
                        style: TextStyle(
                          fontSize: AccessTypography.cardTitleSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: AccessSpacing.s32),
                  AccessColumns(
                    minWidth: 600,
                    gap: 48,
                    flex: participation == null ? const [1] : const [5, 4],
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Divider(color: colors.onSurface),
                          ...facts,
                        ],
                      ),
                      if (participation != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Divider(color: colors.onSurface),
                            const SizedBox(height: 20),
                            AccessHeading(
                              isPublicEvent(event) &&
                                      [
                                        'public',
                                        'approval',
                                      ].contains(event['ticket_mode'])
                                  ? 'Tickets'
                                  : 'Dein Stand',
                              role: AccessHeadingRole.card,
                              level: 2,
                            ),
                            const SizedBox(height: 16),
                            participation!,
                          ],
                        ),
                    ],
                  ),
                  if (interestControl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AccessSpacing.s24),
                      child: interestControl,
                    ),
                  const SizedBox(height: AccessSpacing.s32),
                  Divider(color: colors.outlineVariant),
                  const SizedBox(height: AccessSpacing.s32),
                  AccessContent(width: AccessPageWidth.reading, child: body),
                  const SizedBox(height: AccessSpacing.s40),
                  if (!isPublicEvent(event))
                    Text(
                      'Profilzugang und Eventfreigabe bestätigen keine Teilnahme.',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: AccessTypography.readingHeight,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
        return editorial;
      },
    );
  }
}

class _EventHeading extends StatelessWidget {
  final String text;
  const _EventHeading(this.text);
  @override
  Widget build(BuildContext context) =>
      AccessHeading(text, role: AccessHeadingRole.section, level: 2);
}

class _EventFact extends StatelessWidget {
  final String label, value, detail;
  final bool locked;
  const _EventFact({
    required this.label,
    required this.value,
    this.detail = '',
    this.locked = false,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16),

    child: LayoutBuilder(
      builder: (context, constraints) {
        final valueWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (locked)
              EmbossedLock(
                label: localText(
                  context,
                  'Noch nicht freigegeben',
                  'Not released yet',
                ),
                fill: true,
              )
            else
              LocalText(
                value,
                style: const TextStyle(
                  fontSize: AccessTypography.bodySize,
                  fontWeight: FontWeight.w500,
                  height: 1.55,
                ),
              ),
            if (detail.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  detail,
                  style: const TextStyle(
                    fontSize: AccessTypography.bodySize,
                    height: 1.55,
                  ),
                ),
              ),
          ],
        );
        final labelWidget = LocalText(
          label,
          style: TextStyle(
            fontSize: AccessTypography.captionSize,
            color: AushangPalette.of(context).muted,
          ),
        );
        if (constraints.maxWidth < 280 || AccessLayout.largeText(context)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelWidget, const SizedBox(height: 8), valueWidget],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 128, child: labelWidget),
            const SizedBox(width: 16),
            Expanded(child: valueWidget),
          ],
        );
      },
    ),
  );
}

/// Only the already public, content-addressed catalog media on this origin.
/// Arbitrary external URLs, credentials, queries and path traversal are rejected.
Uri? sameOriginEventMedia(String data, Uri base) {
  if (!RegExp(r'^/event-media/[a-f0-9]{20}\.webp$').hasMatch(data) ||
      !{'http', 'https'}.contains(base.scheme) ||
      base.host.isEmpty ||
      base.userInfo.isNotEmpty) {
    return null;
  }
  return Uri.parse(base.origin).resolve(data);
}

class EventFlyer extends StatefulWidget {
  final String data, alt;
  final VoidCallback? onOpen;
  final BoxFit fit;
  final double aspectRatio;
  final Color? backgroundColor;
  const EventFlyer({
    super.key,
    required this.data,
    required this.alt,
    this.onOpen,
    this.fit = BoxFit.contain,
    this.aspectRatio = 3 / 4,
    this.backgroundColor,
  });
  @override
  State<EventFlyer> createState() => _EventFlyerState();
}

class _EventFlyerState extends State<EventFlyer> {
  Uint8List? _bytes;
  void _decode() {
    try {
      _bytes = base64Decode(widget.data.split(',').last);
    } catch (_) {
      _bytes = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(EventFlyer old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) _decode();
  }

  @override
  Widget build(BuildContext context) {
    final media = sameOriginEventMedia(widget.data, Uri.base);
    final ImageProvider? provider = media != null
        ? NetworkImage(media.toString())
        : _bytes != null
        ? MemoryImage(_bytes!)
        : null;
    final image = provider == null
        ? const Text('Der Flyer konnte nicht geladen werden.')
        : Image(
            image: provider,
            width: double.infinity,
            height: widget.fit == BoxFit.cover ? double.infinity : null,
            fit: widget.fit,
            semanticLabel: widget.alt,
            errorBuilder: (_, error, stack) => const Padding(
              padding: EdgeInsets.all(AccessSpacing.s24),
              child: Text('Der Flyer konnte nicht geladen werden.'),
            ),
          );
    final framed = ClipRRect(
      borderRadius: BorderRadius.zero,
      child: widget.fit == BoxFit.cover
          ? image
          : AspectRatio(
              aspectRatio: widget.aspectRatio,
              child: ColoredBox(
                color:
                    widget.backgroundColor ??
                    Theme.of(context).colorScheme.surfaceContainerLow,
                child: image,
              ),
            ),
    );
    if (widget.onOpen == null) return framed;
    return Semantics(
      button: true,
      label: 'Flyer vergrößern',
      child: InkWell(
        onTap: widget.onOpen,
        borderRadius: BorderRadius.zero,
        child: framed,
      ),
    );
  }
}

class _LineupRow extends StatelessWidget {
  const _LineupRow(this.value);
  final String value;
  @override
  Widget build(BuildContext context) {
    final parts = RegExp(r'^(\d{1,2}[:.]\d{2})\s*[·–-]?\s*(.*)$')
        .firstMatch(value);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AushangPalette.of(context).hair),
        ),
      ),
      child: parts == null
          ? Text(value)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    parts[1]!,
                    style: TextStyle(color: AushangPalette.of(context).muted),
                  ),
                ),
                Expanded(child: Text(parts[2]!)),
              ],
            ),
    );
  }
}

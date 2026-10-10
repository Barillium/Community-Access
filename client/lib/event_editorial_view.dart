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
  final Widget? interestControl;
  const EventEditorialView({
    super.key,
    required this.event,
    this.onOrganizer,
    this.interestControl,
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
    final endDay = eventDay(content['ends_at']);
    final endTime = eventTime(content['ends_at']);
    final flyer = content['flyer_data'] as String? ?? '';
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = AccessLayout.columns(context, constraints.maxWidth);
        final facts = <Widget>[
          if (event['request_deadline_at'] != null)
            _EventFact(
              label: 'Öffentliche Anfragefrist',
              value: eventDay(event['request_deadline_at']),
              detail: eventTime(event['request_deadline_at']),
            ),
          _EventFact(
            label: 'Datum',
            value: startDay.isEmpty ? 'Wird bekannt gegeben' : startDay,
            detail: startDay.isEmpty
                ? ''
                : '${eventTime(event['starts_at'])}${endTime.isEmpty
                      ? ''
                      : endDay == startDay
                      ? ' - $endTime'
                      : '\nbis $endDay, $endTime'}',
          ),
          _EventFact(
            label: 'Veranstaltungsort',
            value: venue.isNotEmpty
                ? venue
                : location.isNotEmpty
                ? location
                : 'Noch nicht freigegeben',
            detail: venue.isNotEmpty && location != venue ? location : '',
          ),
          if (organizer.isNotEmpty)
            _EventFact(
              label: 'Veranstalter',
              value: organizer,
              onTap: onOrganizer,
            ),
        ];
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (lineup.isNotEmpty) ...[
              const _EventHeading('Line-up'),
              const SizedBox(height: AccessSpacing.s20),
              for (final artist in lineup)
                Padding(
                  padding: const EdgeInsets.only(bottom: AccessSpacing.s8),
                  child: Text(
                    artist as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: AccessTypography.titleHeight,
                    ),
                  ),
                ),
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
            if ((content['description'] as String? ?? '').isNotEmpty) ...[
              const _EventHeading('Über die Veranstaltung'),
              const SizedBox(height: AccessSpacing.s16),
              Text(
                content['description'] as String,
                style: const TextStyle(
                  fontSize: AccessTypography.bodySize,
                  height: AccessTypography.readingHeight,
                ),
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
        final media = flyer.isEmpty
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: wide ? 940 : 440,
                    child: EventFlyer(
                      data: flyer,
                      fit: BoxFit.cover,
                      alt: content['flyer_alt'] as String? ?? 'Eventflyer',
                      onOpen: () => showDialog<void>(
                        context: context,
                        builder: (context) => Dialog.fullscreen(
                          child: Scaffold(
                            appBar: AppBar(
                              title: const Text('Eventflyer'),
                              leading: IconButton(
                                tooltip: 'Schließen',
                                icon: const AccessIcon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            body: InteractiveViewer(
                              minScale: 0.5,
                              maxScale: 4,
                              child: Center(
                                child: EventFlyer(
                                  data: flyer,
                                  alt:
                                      content['flyer_alt'] as String? ??
                                      'Eventflyer',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AccessSpacing.s12),
                  Text(
                    'Flyer ansehen',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: AccessTypography.captionSize,
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
            AccessHeading(
              title.isEmpty ? 'Veranstaltung' : title,
              role: flyer.isNotEmpty
                  ? AccessHeadingRole.poster
                  : AccessHeadingRole.hero,
              level: 1,
              uppercase: flyer.isNotEmpty,
              weight: FontWeight.w800,
            ),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: facts,
            ),
            if (interestControl != null)
              Padding(
                padding: const EdgeInsets.only(top: AccessSpacing.s24),
                child: interestControl,
              ),
            const SizedBox(height: AccessSpacing.s32),
            Divider(color: colors.outlineVariant),
            const SizedBox(height: AccessSpacing.s32),
            body,
            const SizedBox(height: AccessSpacing.s40),
            Text(
              'Profilzugang und Eventfreigabe bestätigen keine Teilnahme.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                height: AccessTypography.readingHeight,
              ),
            ),
          ],
        );
        if (media == null) return editorial;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: media),
              const SizedBox(width: 64),
              Expanded(flex: 7, child: editorial),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [media, const SizedBox(height: 32), editorial],
        );
      },
    );
  }
}

class _EventHeading extends StatelessWidget {
  final String text;
  const _EventHeading(this.text);
  @override
  Widget build(BuildContext context) => Semantics(
    headingLevel: 2,
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
    ),
  );
}

class _EventFact extends StatelessWidget {
  final String label, value, detail;
  final VoidCallback? onTap;
  const _EventFact({
    required this.label,
    required this.value,
    this.detail = '',
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: AushangPalette.of(context).hair),
      ),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final valueWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onTap == null)
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.55,
                ),
              )
            else
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            if (detail.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  detail,
                  style: const TextStyle(fontSize: 16, height: 1.55),
                ),
              ),
          ],
        );
        final labelWidget = Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AushangPalette.of(context).muted,
          ),
        );
        if (constraints.maxWidth < 360 || AccessLayout.largeText(context)) {
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

class EventFlyer extends StatefulWidget {
  final String data, alt;
  final VoidCallback? onOpen;
  final BoxFit fit;
  const EventFlyer({
    super.key,
    required this.data,
    required this.alt,
    this.onOpen,
    this.fit = BoxFit.contain,
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
    final image = _bytes == null
        ? const Text('Der Flyer konnte nicht geladen werden.')
        : Image.memory(
            _bytes!,
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
              aspectRatio: 3 / 4,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
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

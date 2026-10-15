import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_language.dart';
import 'design_system.dart';
import 'flyer_design.dart';
import 'event_editorial_view.dart';

class EventCarousel extends StatefulWidget {
  const EventCarousel({
    super.key,
    required this.events,
    required this.onOpen,
    this.bookmarkBuilder,
    this.onProgram,
    this.onCommunities,
  });
  final List<Map<String, dynamic>> events;
  final ValueChanged<String> onOpen;
  final Widget Function(Map<String, dynamic>)? bookmarkBuilder;
  final VoidCallback? onProgram, onCommunities;
  @override
  State<EventCarousel> createState() => _EventCarouselState();
}

class _EventCarouselState extends State<EventCarousel> {
  int index = 0;
  @override
  void didUpdateWidget(covariant EventCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (index >= widget.events.length) index = 0;
  }

  void move(int delta) {
    if (widget.events.length < 2) return;
    setState(() => index = (index + delta) % widget.events.length);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) return const SizedBox.shrink();
    final event = widget.events[index];
    final dateValue = DateTime.tryParse(event['starts_at'] as String? ?? '')
        ?.toLocal();
    final date = dateValue == null
        ? ''
        : '${dateValue.day.toString().padLeft(2, '0')}.${dateValue.month.toString().padLeft(2, '0')}.${dateValue.year}';
    final information = Column(
      key: const ValueKey('hero-information-column'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final title = Semantics(
              liveRegion: true,
              child: Text(
                event['title'] as String? ?? '',
                style: const TextStyle(
                  fontSize: AccessTypography.cardTitleSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
            final details = TextButton(
              onPressed: () => widget.onOpen(event['id'] as String),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(localText(context, 'Details', 'Details')),
            );
            if (c.maxWidth < 300) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, details],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: title),
                details,
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 32,
          runSpacing: 20,
          children: [
            if (date.isNotEmpty)
              _fact(
                context,
                Icons.calendar_month,
                localText(context, 'Datum', 'Date'),
                FlyerMark(kind: FlyerMarkKind.circle, child: Text(date)),
              ),
            _fact(
              context,
              Icons.schedule,
              localText(context, 'Beginn', 'Starts'),
              Text(eventTime(event['starts_at'])),
            ),
          ],
        ),
        if ((event['organizer'] as String? ?? '').isNotEmpty) ...[
          const SizedBox(height: 24),
          _fact(
            context,
            Icons.groups_outlined,
            localText(context, 'Veranstalter', 'Organizer'),
            Text(event['organizer'] as String),
          ),
        ],
        const SizedBox(height: 24),
        if ((event['location'] as String? ?? '').isNotEmpty) ...[
          Text(event['location'] as String),
          const SizedBox(height: 12),
        ],
        if (event['access_mode'] == 'semi_public' &&
            (event['location'] as String? ?? '').isEmpty) ...[
          Text(
            localText(context, 'Ort nach Zusage', 'Location after approval'),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          localText(
            context,
            'Teilnahme wird separat bestätigt.',
            'Attendance is confirmed separately.',
          ),
          style: const TextStyle(fontSize: AccessTypography.labelSize),
        ),
        if (widget.bookmarkBuilder != null) widget.bookmarkBuilder!(event),
      ],
    );
    final title = Column(
      key: const ValueKey('hero-title-column'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          headingLevel: 1,
          label: localText(context, 'Das Programm.', 'The program.'),
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FlyerTitle(
                localText(context, 'Das', 'The'),
                marked: false,
                level: null,
                size: MediaQuery.sizeOf(context).width < 768
                    ? AccessTypography.heroMin
                    : AccessTypography.heroMax,
              ),
              FlyerTitle(
                localText(context, 'Programm.', 'Program.'),
                size: MediaQuery.sizeOf(context).width < 768
                    ? AccessTypography.heroMin
                    : AccessTypography.heroMax,
                italic: true,
                level: null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          localText(
            context,
            'Musik, Kunst und Begegnungen.\nFinde deinen nächsten Termin.',
            'Music, art and encounters.\nFind your next event.',
          ),
          style: const TextStyle(fontSize: AccessTypography.leadSize),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AccessAction(
              kind: AccessActionKind.primary,
              onPressed:
                  widget.onProgram ??
                  () => widget.onOpen(event['id'] as String),
              suffix: const AccessIcon(Icons.arrow_forward, decorated: false),
              child: Text(
                localText(context, 'Programm entdecken', 'Explore the program'),
              ),
            ),
            if (widget.onCommunities != null)
              TextButton(
                onPressed: widget.onCommunities,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: Text(
                  localText(
                    context,
                    'Communities kennenlernen',
                    'Meet the communities',
                  ),
                ),
              ),
          ],
        ),
      ],
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => move(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => move(1),
      },
      child: Focus(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FlyerScene(
              information: information,
              minHeight: 720,
              mobileImageHeight: 280,
              mobileInformationFirst: true,
              topRight: widget.events.length > 1 ? _controls(context) : null,
              padding: AccessLayout.gutter(
                context,
                MediaQuery.sizeOf(context).width,
              ),
              child: title,
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls(BuildContext context) => Material(
    color: FlyerStyle.ink.withValues(alpha: .88),
    child: DefaultTextStyle.merge(
      style: const TextStyle(
        color: Colors.white,
        fontSize: AccessTypography.captionSize,
      ),
      child: IconTheme(
        data: const IconThemeData(color: FlyerStyle.orange),
        child: Row(
          key: const ValueKey('hero-carousel-controls'),
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => move(-1),
              tooltip: localText(
                context,
                'Vorherige Veranstaltung',
                'Previous event',
              ),
              icon: const AccessIcon(Icons.arrow_back),
            ),
            IconButton(
              onPressed: () => move(1),
              tooltip: localText(
                context,
                'Nächste Veranstaltung',
                'Next event',
              ),
              icon: const AccessIcon(Icons.arrow_forward),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _fact(
    BuildContext context,
    IconData icon,
    String label,
    Widget value,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AccessIcon(icon, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: AccessTypography.labelSize),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      value,
    ],
  );
}

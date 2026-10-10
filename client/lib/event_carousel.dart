import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_language.dart';
import 'aushang_tokens.dart';
import 'design_system.dart';
import 'event_editorial_view.dart';
import 'program_views.dart';

/// Manual poster carousel: no timer, including with reduced motion enabled.
class EventCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  final ValueChanged<String> onOpen;
  final Widget Function(Map<String, dynamic>)? bookmarkBuilder;
  const EventCarousel({
    super.key,
    required this.events,
    required this.onOpen,
    this.bookmarkBuilder,
  });
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
    final content = event['event_content'] as Map? ?? {};
    final flyer = content['flyer_data'] as String? ?? '';
    final sourceTitle = event['title'] as String;
    final title = sourceTitle.toUpperCase();
    final palette = AushangPalette.of(context);
    // Only an actual supplied flyer gets the inverse overlay. Missing media uses
    // the page palette and the same live catalog data, never invented artwork.
    final hasFlyer = flyer.startsWith('data:image/jpeg;base64,');
    final foreground = hasFlyer ? Colors.white : palette.ink;
    final controls = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        IconButton(
          onPressed: widget.events.length > 1 ? () => move(-1) : null,
          tooltip: localText(
            context,
            'Vorherige Veranstaltung',
            'Previous event',
          ),
          icon: const AccessIcon(Icons.arrow_back),
        ),
        Text(
          '${index + 1} / ${widget.events.length}',
          semanticsLabel: localText(
            context,
            'Veranstaltung ${index + 1} von ${widget.events.length}',
            'Event ${index + 1} of ${widget.events.length}',
          ),
        ),
        IconButton(
          onPressed: widget.events.length > 1 ? () => move(1) : null,
          tooltip: localText(context, 'Nächste Veranstaltung', 'Next event'),
          icon: const AccessIcon(Icons.arrow_forward),
        ),
      ],
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => move(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => move(1),
      },
      child: Focus(
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          label: localText(context, 'Veranstaltungscarousel', 'Event carousel'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxWidth < 768 ||
                      AccessLayout.largeText(context);
                  final inset = AccessLayout.gutter(
                    context,
                    constraints.maxWidth,
                  );
                  final sideBySide = constraints.maxWidth >= 960 && !compact;
                  final columnGap = constraints.maxWidth < 1184 ? 32.0 : 48.0;
                  final informationWidth = AccessLayout.fluid(
                    constraints.maxWidth,
                    300,
                    360,
                    from: 960,
                    to: 1280,
                  );
                  final desiredTitleSize = compact
                      ? 56.0
                      : AccessLayout.fluid(
                          constraints.maxWidth,
                          72,
                          96,
                          from: 768,
                          to: 1184,
                        );
                  final posterStyle = TextStyle(
                    fontFamily: 'Archivo',
                    fontFamilyFallback: const ['Rubik'],
                    color: foreground,
                    fontWeight: FontWeight.w800,
                    fontVariations: const [FontVariation('wdth', 68)],
                    // Match TextPainter; Material body letter spacing would
                    // otherwise push a fitted word onto two lines.
                    letterSpacing: 0,
                    height: .94,
                  );
                  // Fit long words at normal scale; user text enlargement stays intact.
                  double longestWord = 0;
                  for (final word in title.split(RegExp(r'\s+'))) {
                    final painter = TextPainter(
                      text: TextSpan(
                        text: word,
                        style: posterStyle.copyWith(fontSize: desiredTitleSize),
                      ),
                      textDirection: Directionality.of(context),
                    )..layout();
                    if (painter.width > longestWord) {
                      longestWord = painter.width;
                    }
                    painter.dispose();
                  }
                  final availableTitleWidth =
                      constraints.maxWidth -
                      2 * inset -
                      4 -
                      (sideBySide ? informationWidth + columnGap : 0);
                  final titleSize = longestWord > availableTitleWidth
                      ? (desiredTitleSize * availableTitleWidth / longestWord)
                            .clamp(28.0, desiredTitleSize)
                      : desiredTitleSize;
                  final titleBlock = Column(
                    key: const ValueKey('hero-title-column'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (programDate(event['starts_at']).isNotEmpty)
                        CustomPaint(
                          painter: const _DateMarker(),
                          child: Text(
                            _posterDate(event['starts_at']),
                            style: TextStyle(
                              fontSize: compact ? 32 : 40,
                              fontWeight: FontWeight.w800,
                              fontVariations: [FontVariation('wdth', 68)],
                              height: 1,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Semantics(
                        headingLevel: 1,
                        liveRegion: true,
                        child: Text(
                          title,
                          semanticsLabel: sourceTitle,
                          style: posterStyle.copyWith(fontSize: titleSize),
                        ),
                      ),
                    ],
                  );
                  final information = Column(
                    key: const ValueKey('hero-information-column'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (programDate(event['starts_at']).isNotEmpty) ...[
                        Text(
                          programDate(event['starts_at']),
                          style: TextStyle(
                            fontSize: 14,
                            color: compact ? palette.muted : foreground,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if ((event['organizer'] as String? ?? '').isNotEmpty)
                        Text(
                          event['organizer'] as String,
                          style: const TextStyle(fontSize: 20),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 24,
                        runSpacing: 8,
                        children: [
                          EventAccessMark(event: event),
                          if ((event['location'] as String? ?? '').isNotEmpty)
                            Text(event['location'] as String),
                          if (event['access_mode'] == 'semi_public' &&
                              (event['location'] as String? ?? '').isEmpty)
                            LocalText(
                              localText(
                                context,
                                'Ort nach Zusage',
                                'Location after approval',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: AccessAction(
                              kind: AccessActionKind.primary,
                              fullWidth: true,
                              onPressed: () =>
                                  widget.onOpen(event['id'] as String),
                              suffix: const AccessIcon(Icons.arrow_forward),
                              child: const LocalText('Event ansehen'),
                            ),
                          ),
                          if (widget.bookmarkBuilder != null) ...[
                            const SizedBox(width: 8),
                            widget.bookmarkBuilder!(event),
                          ],
                        ],
                      ),
                    ],
                  );
                  final poster = Container(
                    color: hasFlyer ? Colors.black : palette.sunken,
                    child: Stack(
                      children: [
                        if (hasFlyer)
                          Positioned.fill(
                            child: ExcludeSemantics(
                              child: EventFlyer(
                                data: flyer,
                                alt: content['flyer_alt'] as String? ?? title,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        if (hasFlyer)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: .86),
                                  ],
                                  stops: const [.3, 1],
                                ),
                              ),
                            ),
                          ),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: compact ? 360 : 520,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(inset),
                            child: DefaultTextStyle.merge(
                              style: TextStyle(color: foreground),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: DecoratedBox(
                                      key: const ValueKey(
                                        'hero-carousel-controls',
                                      ),
                                      decoration: BoxDecoration(
                                        color: palette.page,
                                        border: Border.all(color: palette.hair),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: DefaultTextStyle.merge(
                                          style: TextStyle(
                                            color: palette.ink,
                                            fontSize: 14,
                                          ),
                                          child: controls,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: compact ? 64 : 96,
                                    ),
                                    child: sideBySide
                                        ? Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Expanded(child: titleBlock),
                                              SizedBox(width: columnGap),
                                              SizedBox(
                                                width: informationWidth,
                                                child: information,
                                              ),
                                            ],
                                          )
                                        : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              titleBlock,
                                              if (!compact) ...[
                                                const SizedBox(height: 32),
                                                information,
                                              ],
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      poster,
                      if (compact)
                        Padding(
                          padding: EdgeInsets.fromLTRB(inset, 24, inset, 8),
                          child: information,
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              AccessPageFrame(
                verticalPadding: false,
                child: Text(
                  event['community'] as String? ?? '',
                  style: TextStyle(color: palette.muted),
                ),
              ),
              if (widget.events.length > 1)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact =
                        constraints.maxWidth < 768 ||
                        AccessLayout.largeText(context);
                    Widget item(int i) => TextButton(
                      onPressed: () => setState(() => index = i),
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(top: 16),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: i == index ? palette.ink : palette.hair,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Semantics(
                          selected: i == index,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(i + 1).toString().padLeft(2, '0')} · ${programDate(widget.events[i]['starts_at'])}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: palette.muted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.events[i]['title'] as String,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  fontVariations: [FontVariation('wdth', 68)],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                    if (compact) return const SizedBox.shrink();
                    return AccessPageFrame(
                      verticalPadding: false,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < widget.events.length; i++) ...[
                            if (i > 0) const SizedBox(width: 24),
                            Expanded(child: item(i)),
                          ],
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _posterDate(dynamic raw) {
  final date = raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
  if (date == null) return '';
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.';
}

/// Static marker from boards/i-start-breit.html; never delays date visibility.
class _DateMarker extends CustomPainter {
  const _DateMarker();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(70, 6)
      ..cubicTo(30, 2, 4, 14, 5, 31)
      ..cubicTo(6, 50, 40, 57, 66, 55)
      ..cubicTo(98, 53, 117, 42, 115, 26)
      ..cubicTo(113, 11, 88, 4, 58, 8);
    canvas.save();
    canvas.translate(-size.width * .14, -size.height * .18);
    canvas.scale(size.width * 1.28 / 120, size.height * 1.36 / 60);
    canvas.drawPath(
      path,
      Paint()
        ..color = AushangTokens.componentMarkerStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DateMarker oldDelegate) => false;
}

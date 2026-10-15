import 'product_scope.dart';
import 'flyer_design.dart';

import 'access_brand.dart';
import 'resource_return_browser.dart'
    if (dart.library.js_interop) 'resource_return_browser_web.dart';
import 'event_interest_panel.dart';
import 'app_language.dart';

import 'package:flutter/material.dart';

import 'legal_api.dart';
import 'legal_pages.dart';

import 'access_api.dart';
import 'directory_api.dart';
import 'directory_pages.dart';
import 'design_system.dart';
import 'bookmark_views.dart';
import 'event_editorial_view.dart';

String programDate(dynamic value) {
  final date = value is String ? DateTime.tryParse(value)?.toLocal() : null;
  if (date == null) return '';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} · ${two(date.hour)}:${two(date.minute)}';
}

/// Visibility labels come from explicit API fields, never from membership.
String eventAccessLabel(Map<String, dynamic> event) =>
    switch (event['access_mode']) {
      'semi_public' => 'Semi-öffentlich',
      'public' => 'Öffentlich',
      'private' => 'Mit Zugang',
      _ => event['is_public'] == true ? 'Öffentlich' : '',
    };

class ProgramList extends StatelessWidget {
  final DirectoryApi api;
  final bool showHeading;
  final bool calendarLayout;
  final Future<void> Function()? openAccount;
  final Map<String, dynamic> program;
  final void Function(int)? onPage;
  final VoidCallback? onRefresh;
  const ProgramList({
    super.key,
    required this.api,
    this.showHeading = true,
    this.calendarLayout = false,
    this.openAccount,
    required this.program,
    this.onPage,
    this.onRefresh,
  });
  Future<void> _open(BuildContext context, String kind, String id) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ProgramDetailPage(
          api: api,
          kind: kind,
          id: id,
          openAccount: openAccount,
        ),
      ),
    );
    if (context.mounted) onRefresh?.call();
  }

  @override
  Widget build(BuildContext context) {
    final series = program['series'] as List? ?? [];
    final events = program['events'] as List? ?? [];
    final page = program['page'] as int? ?? 1;
    if (series.isEmpty && events.isEmpty && page == 1) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeading) const SizedBox(height: AccessSpacing.s32),
        if (showHeading)
          Semantics(
            headingLevel: 2,
            child: const LocalText(
              'Veranstaltungen',
              style: TextStyle(
                fontSize: AccessTypography.sectionTitleSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        for (final s in series)
          Padding(
            padding: const EdgeInsets.only(top: AccessSpacing.s16),
            child: AccessSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocalText(
                    s['title'] as String,
                    style: const TextStyle(
                      fontSize: AccessTypography.cardTitleSize,
                    ),
                  ),
                  if ((s['description'] as String).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AccessSpacing.s8),
                      child: LocalText(s['description'] as String),
                    ),
                  InterestCount(count: s['interest_count'] as int?),
                  const SizedBox(height: AccessSpacing.s12),
                  OutlinedButton(
                    onPressed: () =>
                        _open(context, 'series', s['id'] as String),
                    child: const LocalText('Reihe ansehen'),
                  ),
                ],
              ),
            ),
          ),
        if (calendarLayout)
          _CalendarProgram(
            events: events,
            rowBuilder: (e) => _CalendarEvent(
              event: e,
              onOpen: () => _open(context, 'events', e['id'] as String),
              bookmark: BookmarkButton(
                key: ValueKey('program-bookmark:${e['id']}'),
                compact: true,
                api: api,
                kind: 'event',
                id: e['id'] as String,
                signedIn: program['signed_in'] == true,
                openAccount: openAccount,
              ),
            ),
          ),
        if (!calendarLayout)
          for (final e in events)
            _ProgramRow(
              event: Map<String, dynamic>.from(e as Map),
              onOpen: () => _open(context, 'events', e['id'] as String),
              bookmark: BookmarkButton(
                key: ValueKey('program-bookmark:${e['id']}'),
                compact: true,
                api: api,
                kind: 'event',
                id: e['id'] as String,
                signedIn: program['signed_in'] == true,
                openAccount: openAccount,
              ),
            ),
        if (onPage != null)
          Wrap(
            spacing: AccessSpacing.s12,
            children: [
              if (page > 1)
                TextButton(
                  onPressed: () => onPage!(page - 1),
                  child: const LocalText('Vorherige Programmseite'),
                ),
              if (program['has_more'] == true)
                TextButton(
                  onPressed: () => onPage!(page + 1),
                  child: const LocalText('Weitere Veranstaltungen'),
                ),
            ],
          ),
      ],
    );
  }
}

/// Group only already authorized adjacent events; missing dates reveal nothing.
class _CalendarProgram extends StatelessWidget {
  final List events;
  final Widget Function(Map<String, dynamic>) rowBuilder;
  const _CalendarProgram({required this.events, required this.rowBuilder});
  @override
  Widget build(BuildContext context) {
    final groups = <List<Map<String, dynamic>>>[];
    String day(Map<String, dynamic> e) {
      final date = DateTime.tryParse(e['starts_at'] as String? ?? '')
          ?.toLocal();
      return date == null ? '' : '${date.year}-${date.month}-${date.day}';
    }

    for (final item in events) {
      final event = Map<String, dynamic>.from(item as Map);
      if (groups.isEmpty ||
          day(event).isEmpty ||
          day(groups.last.first) != day(event)) {
        groups.add([]);
      }
      groups.last.add(event);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 900 && !AccessLayout.largeText(context);
        final palette = AushangPalette.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final group in groups)
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: palette.ink)),
                ),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 112,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: _CalendarDate(
                                value: group.first['starts_at'],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                for (int i = 0; i < group.length; i++)
                                  Container(
                                    decoration: BoxDecoration(
                                      border: i == 0
                                          ? null
                                          : Border(
                                              top: BorderSide(
                                                color: Colors.transparent,
                                              ),
                                            ),
                                    ),
                                    child: rowBuilder(group[i]),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          for (int i = 0; i < group.length; i++)
                            Container(
                              decoration: BoxDecoration(
                                border: i == 0
                                    ? null
                                    : Border(
                                        top: BorderSide(
                                          color: Colors.transparent,
                                        ),
                                      ),
                              ),
                              child: rowBuilder(group[i]),
                            ),
                        ],
                      ),
              ),
          ],
        );
      },
    );
  }
}

class _CalendarDate extends StatelessWidget {
  final dynamic value;
  const _CalendarDate({this.value});
  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(value as String? ?? '')?.toLocal();
    if (date == null) return const SizedBox.shrink();
    const de = [
      'Montag',
      'Dienstag',
      'Mittwoch',
      'Donnerstag',
      'Freitag',
      'Samstag',
      'Sonntag',
    ];
    const en = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${date.day}'.padLeft(2, '0'),
          style: const TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.w600,
            fontVariations: [FontVariation('wdth', 100)],
            height: .9,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          localText(context, de[date.weekday - 1], en[date.weekday - 1]),
          style: const TextStyle(
            fontSize: AccessTypography.captionSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Board proportions, while retaining actual visible catalog fields.
class _CalendarEvent extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onOpen;
  final Widget bookmark;
  const _CalendarEvent({
    required this.event,
    required this.onOpen,
    required this.bookmark,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxWidth < 600 || AccessLayout.largeText(context);
      final palette = AushangPalette.of(context);
      final title = event['title'] as String;
      final date = DateTime.tryParse(event['starts_at'] as String? ?? '')
          ?.toLocal();
      final organizer = event['organizer'] as String? ?? '';
      final when = date == null
          ? ''
          : compact
          ? programDate(event['starts_at'])
          : '${date.hour.toString().padLeft(2, "0")}:${date.minute.toString().padLeft(2, "0")}';
      final meta = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AccessHeading(
            title,
            role: AccessHeadingRole.card,
            level: 3,
            uppercase: false,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              if (organizer.isNotEmpty || when.isNotEmpty)
                Text(
                  [organizer, when].where((s) => s.isNotEmpty).join(' · '),
                  style: TextStyle(
                    fontSize: AccessTypography.captionSize,
                    color: palette.muted,
                  ),
                ),
              if (eventAccessLabel(event).isNotEmpty)
                EventAccessMark(event: event),
              if ((event['location'] as String? ?? '').isNotEmpty)
                Text(
                  event['location'] as String,
                  style: TextStyle(
                    fontSize: AccessTypography.captionSize,
                    color: palette.muted,
                  ),
                ),
              if (event['access_mode'] == 'semi_public' &&
                  (event['location'] as String? ?? '').isEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AccessIcon(Icons.lock_outline, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        localText(
                          context,
                          'Ort nach Zusage',
                          'Location after approval',
                        ),
                        style: TextStyle(
                          fontSize: AccessTypography.captionSize,
                          color: palette.muted,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          for (final reason in event['reasons'] as List? ?? [])
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LocalText(
                switch (reason) {
                  'bookmark' => 'Auf deiner Merkliste',
                  'community' => 'Aus einer gefolgten Community',
                  'visited_organizer' => 'Veranstalter bereits besucht',
                  'preferences' => 'Passt zu deinen Präferenzen',
                  _ => '',
                },
                style: TextStyle(
                  fontSize: AccessTypography.labelSize,
                  color: palette.muted,
                ),
              ),
            ),
          if (event['status'] == 'cancelled') const LocalText('Abgesagt'),
          if ((event['interest_count'] as int? ?? 0) > 0)
            InterestCount(count: event['interest_count'] as int?),
        ],
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Semantics(
                button: true,
                explicitChildNodes: true,
                label: localText(
                  context,
                  'Event ansehen: $title',
                  'View event: $title',
                ),
                child: InkWell(
                  onTap: onOpen,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: meta),
                      const SizedBox(width: 16),
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: AccessIcon(Icons.arrow_forward),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (ProductScope.extended) ...[
              const SizedBox(width: 16),
              SizedBox(width: 52, child: bookmark),
            ],
          ],
        ),
      );
    },
  );
}

class EventAccessMark extends StatelessWidget {
  final Map<String, dynamic> event;
  const EventAccessMark({super.key, required this.event});
  @override
  Widget build(BuildContext context) {
    final label = eventAccessLabel(event);
    if (label.isEmpty) return const SizedBox.shrink();
    final color =
        DefaultTextStyle.of(context).style.color ??
        AushangPalette.of(context).ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: CustomPaint(
            size: const Size(12, 12),
            painter: _AccessMark(
              color: color,
              half: event['access_mode'] == 'semi_public',
              filled: event['access_mode'] == 'private',
            ),
          ),
        ),
        const SizedBox(width: 9),
        Flexible(
          child: LocalText(
            label,
            style: TextStyle(
              fontSize: AccessTypography.captionSize,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _AccessMark extends CustomPainter {
  final Color color;
  final bool half, filled;
  const _AccessMark({
    required this.color,
    required this.half,
    required this.filled,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final circle = Path()..addOval(Offset.zero & size);
    canvas.save();
    canvas.clipPath(circle);
    if (filled || half) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, half ? size.width / 2 : size.width, size.height),
        Paint()..color = color,
      );
    }
    canvas.restore();
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2 - 1,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_AccessMark old) =>
      old.color != color || old.half != half || old.filled != filled;
}

class _ProgramRow extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onOpen;
  final Widget bookmark;
  const _ProgramRow({
    required this.event,
    required this.onOpen,
    required this.bookmark,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final palette = AushangPalette.of(context);
      final content = event['event_content'] as Map? ?? {};
      final flyer = content['flyer_data'] as String? ?? '';
      final compact =
          constraints.maxWidth < 768 || AccessLayout.largeText(context);
      final title = event['title'] as String;
      final date = event['starts_at'] is String
          ? DateTime.tryParse(event['starts_at'] as String)?.toLocal()
          : null;
      final openAction = AccessAction(
        onPressed: onOpen,
        kind: AccessActionKind.ghost,
        suffix: const AccessIcon(Icons.arrow_forward),
        child: const LocalText('Event ansehen'),
      );
      final details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AccessHeading(title, role: AccessHeadingRole.card, level: 3),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              if (programDate(event['starts_at']).isNotEmpty)
                LocalText(
                  programDate(event['starts_at']),
                  style: TextStyle(
                    fontSize: AccessTypography.captionSize,
                    color: palette.muted,
                  ),
                ),
              if ((event['organizer'] as String? ?? '').isNotEmpty)
                Text(
                  event['organizer'] as String,
                  style: const TextStyle(
                    fontSize: AccessTypography.captionSize,
                  ),
                ),
              if ((event['location'] as String? ?? '').isNotEmpty)
                LocalText(
                  event['location'] as String,
                  style: const TextStyle(
                    fontSize: AccessTypography.captionSize,
                  ),
                ),
              if (eventAccessLabel(event).isNotEmpty)
                LocalText(
                  eventAccessLabel(event),
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: AccessTypography.captionSize,
                  ),
                ),
            ],
          ),
          for (final reason in event['reasons'] as List? ?? [])
            LocalText(switch (reason) {
              'bookmark' => localText(
                context,
                'Auf deiner Merkliste',
                'Saved by you',
              ),
              'community' => localText(
                context,
                'Aus einer gefolgten Community',
                'From a community you follow',
              ),
              'visited_organizer' => localText(
                context,
                'Veranstalter bereits besucht',
                'Organizer you have visited',
              ),
              'preferences' => localText(
                context,
                'Passt zu deinen Präferenzen',
                'Matches your preferences',
              ),
              _ => '',
            }),
          if (event['status'] == 'cancelled') const LocalText('Abgesagt'),
          InterestCount(count: event['interest_count'] as int?),
          if (compact) ...[const SizedBox(height: 12), openAction],
        ],
      );
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.transparent)),
        ),
        child: compact
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 16),
                  SizedBox(width: 48, child: bookmark),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          date == null ? '—' : '${date.day}'.padLeft(2, '0'),
                          style: const TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w600,
                            fontVariations: [FontVariation('wdth', 100)],
                          ),
                        ),
                        if (date != null)
                          Text(
                            localText(
                              context,
                              const [
                                'JAN',
                                'FEB',
                                'MÄR',
                                'APR',
                                'MAI',
                                'JUN',
                                'JUL',
                                'AUG',
                                'SEP',
                                'OKT',
                                'NOV',
                                'DEZ',
                              ][date.month - 1],
                              const [
                                'JAN',
                                'FEB',
                                'MAR',
                                'APR',
                                'MAY',
                                'JUN',
                                'JUL',
                                'AUG',
                                'SEP',
                                'OCT',
                                'NOV',
                                'DEC',
                              ][date.month - 1],
                            ),
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: AccessTypography.labelSize,
                              letterSpacing: 1.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (flyer.isNotEmpty) ...[
                    SizedBox(
                      width: 96,
                      child: EventFlyer(
                        data: flyer,
                        alt: content['flyer_alt'] as String? ?? title,
                      ),
                    ),
                    const SizedBox(width: 24),
                  ],
                  Expanded(child: details),
                  const SizedBox(width: 24),
                  openAction,
                  const SizedBox(width: 16),
                  SizedBox(width: 48, child: bookmark),
                ],
              ),
      );
    },
  );
}

class ProgramDetailPage extends StatefulWidget {
  final DirectoryApi api;
  final Future<void> Function()? openAccount;
  final String kind, id;
  const ProgramDetailPage({
    super.key,
    required this.api,
    this.openAccount,
    required this.kind,
    required this.id,
  });
  @override
  State<ProgramDetailPage> createState() => _ProgramDetailPageState();
}

class _ProgramDetailPageState extends State<ProgramDetailPage> {
  final _participationKey = GlobalKey(debugLabel: 'event participation');
  Map<String, dynamic>? _data;
  String? _failure;
  bool _busy = false;
  int _page = 1;
  String? _previousTarget;
  int _revision = 0;
  @override
  void dispose() {
    _revision++;
    restoreResourceTarget(_previousTarget);
    super.dispose();
  }

  Future<void> _openAccount() async {
    await widget.openAccount!();
    if (mounted) await _load(page: _page);
  }

  @override
  void initState() {
    super.initState();
    _previousTarget = rememberResourceTarget(
      widget.kind == 'events' ? 'event' : widget.kind,
      widget.id,
    );
    _load();
  }

  Future<void> _load({int? page}) async {
    if (!mounted) return;
    final revision = ++_revision;
    _page = page ?? 1;
    setState(() {
      _busy = true;
      _data = null;
      _failure = null;
    });
    try {
      final data = await widget.api.directory(
        '${widget.kind}/${widget.id}',
        query: widget.kind == 'series' ? {'page': '$_page'} : null,
      );
      if (mounted && revision == _revision) setState(() => _data = data);
    } catch (e) {
      if (mounted && revision == _revision) {
        setState(
          () => _failure = e is ApiFailure
              ? e.message
              : 'Der Eintrag konnte nicht geladen werden.',
        );
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(67),
      child: AccessHeader(
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              if (constraints.maxWidth < 600 ||
                  AccessLayout.largeText(context)) ...[
                IconButton(
                  tooltip: localText(
                    context,
                    'Zurück zum Programm',
                    'Back to program',
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const AccessIcon(Icons.arrow_back),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      label: 'Community Access',
                      child: ExcludeSemantics(child: AccessBrand(width: 112)),
                    ),
                  ),
                ),
              ] else ...[
                Semantics(
                  label: 'Community Access',
                  child: ExcludeSemantics(child: AccessBrand(width: 112)),
                ),
                const SizedBox(width: 48),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FlyerMark(
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const AccessIcon(Icons.arrow_back),
                        label: const LocalText('Programm'),
                      ),
                    ),
                  ),
                ),
              ],
              const FlyerLanguageButton(),
              IconButton(
                tooltip: localText(context, 'Aktualisieren', 'Refresh'),
                onPressed: _busy ? null : () => _load(page: _page),
                icon: const AccessIcon(Icons.refresh),
              ),
            ],
          ),
        ),
      ),
    ),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        width: AccessPageWidth.detail,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_failure != null) ...[
              directoryNotice(_failure!),
              if (widget.openAccount != null)
                TextButton(
                  onPressed: _busy ? null : _openAccount,
                  child: const LocalText('Anmelden und Zugriff erneut prüfen'),
                ),
            ],
            if (_data != null) ...[
              if (widget.kind == 'series')
                directoryHeading(_data!['title'] as String),
              const SizedBox(height: AccessSpacing.s20),
              if (widget.kind == 'series') ...[
                LocalText(_data!['description'] as String),
                if (_data!['signed_in'] == true ||
                    _data!['interest_count'] != null)
                  BookmarkButton(
                    key: ValueKey('series:${widget.id}'),
                    api: widget.api,
                    kind: 'series',
                    id: widget.id,
                    signedIn: _data!['signed_in'] == true,
                    interestCount: _data!['interest_count'] as int?,
                    openAccount: widget.openAccount == null
                        ? null
                        : _openAccount,
                  ),
                ProgramList(
                  api: widget.api,
                  openAccount: widget.openAccount,
                  program: {
                    'series': [],
                    'events': _data!['events'],
                    'page': _data!['page'],
                    'has_more': _data!['has_more'],
                  },
                  onPage: (page) => _load(page: page),
                  onRefresh: () => _load(page: _page),
                ),
              ] else ...[
                if (widget.api is LegalApi)
                  ReportEventButton(
                    api: widget.api as LegalApi,
                    eventId: widget.id,
                  ),
                EventEditorialView(
                  event: _data!,
                  participation: EventInterestPanel(
                    key: _participationKey,
                    api: widget.api,
                    id: widget.id,
                    openAccount: widget.openAccount == null
                        ? null
                        : _openAccount,
                    onChanged: () => _load(),
                  ),
                  interestControl:
                      _data!['signed_in'] == true ||
                          _data!['interest_count'] != null
                      ? BookmarkButton(
                          key: ValueKey('event:${widget.id}'),
                          api: widget.api,
                          kind: 'event',
                          id: widget.id,
                          signedIn: _data!['signed_in'] == true,
                          interestCount: _data!['interest_count'] as int?,
                          openAccount: widget.openAccount == null
                              ? null
                              : _openAccount,
                        )
                      : null,
                  onOrganizer:
                      _data!['organizer_id'] == null ||
                          widget.openAccount == null
                      ? null
                      : () async {
                          final organizerId = _data!['organizer_id'] as String;
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => OrganizerDetailPage(
                                api: widget.api,
                                id: organizerId,
                                openAccount: widget.openAccount!,
                              ),
                            ),
                          );
                          if (mounted) await _load(page: _page);
                        },
                ),
              ],
            ],
            const SizedBox(height: AccessSpacing.s24),
            OutlinedButton(
              onPressed: _busy ? null : _load,
              child: const LocalText('Aktualisieren'),
            ),
          ],
        ),
      ),
    ),
  );
}

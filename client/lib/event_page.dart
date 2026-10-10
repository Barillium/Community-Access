import 'package:flutter/material.dart';

import 'access_api.dart';
import 'design_system.dart';
import 'ticketing_api.dart';
import 'ticketing_pages.dart';

/// The detail page loads a freshly authorized event; no location is cached in it.
class EventPage extends StatefulWidget {
  final AccessApi api;
  final Object eventId;
  const EventPage({super.key, required this.api, required this.eventId});

  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> {
  Map<String, dynamic>? _event;
  String? _location;
  String? _error;
  bool _busy = false;
  bool _age = false;
  int _epoch = 0;
  static const _ink = AccessDesign.ink;
  static const _body = TextStyle(
    fontSize: AccessTypography.bodySize,
    height: AccessTypography.readingHeight,
  );

  @override
  void initState() {
    super.initState();
    _run(_reload);
  }

  @override
  void didUpdateWidget(covariant EventPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId || oldWidget.api != widget.api) {
      _epoch++;
      _event = null;
      _location = null;
      _busy = false;
      _run(_reload);
    }
  }

  @override
  void dispose() {
    _epoch++;
    super.dispose();
  }

  Future<void> _reload() async {
    // Also clear details if a membership was revoked while this route was open.
    if (!mounted) return;
    setState(() {
      _event = null;
      _location = null;
      _age = false;
    });
    final epoch = ++_epoch;
    final event = await widget.api.event(widget.eventId);
    if (mounted && epoch == _epoch) setState(() => _event = event);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _location = null;
    });
    try {
      await action();
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Das Event konnte nicht geladen werden.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _heading(
    String text, {
    int level = 2,
    AccessHeadingRole role = AccessHeadingRole.section,
    Color color = _ink,
  }) => AccessHeading(text, level: level, role: role, color: color);

  // ISO offset is kept from the API; the advertised venue time is independent
  // of the visitor's browser time zone. No external date library is needed.
  String _date(String? iso, {bool dateOnly = false}) {
    if (iso == null) return 'Termin noch nicht hinterlegt';
    final local = DateTime.tryParse(iso.substring(0, 19));
    if (local == null) return 'Termin noch nicht hinterlegt';
    const days = ['Mo.', 'Di.', 'Mi.', 'Do.', 'Fr.', 'Sa.', 'So.'];
    final date =
        '${days[local.weekday - 1]}, ${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
    return dateOnly ? date : '$date · ${iso.substring(11, 16)}';
  }

  Widget _meta(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFFE4DDD8),
          fontSize: AccessTypography.labelSize,
          height: AccessTypography.readingHeight,
        ),
      ),
      const SizedBox(height: AccessSpacing.s8),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: AccessTypography.bodySize,
          height: AccessTypography.bodyHeight,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _hero(Map<String, dynamic> event) => Padding(
    padding: const EdgeInsets.only(top: AccessSpacing.s16),
    child: AccessReveal(
      child: AccessSurface(
        color: _ink,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < AccessLayout.searchMinWidth ||
                AccessLayout.largeText(context);
            final largeText = AccessLayout.largeText(context);
            final columns =
                largeText ||
                    constraints.maxWidth < AccessLayout.metadataMinWidth
                ? 1
                : compact
                ? 2
                : 4;
            final width =
                (constraints.maxWidth - AccessSpacing.s24 * (columns - 1)) /
                columns;
            final date = _date(event['starts_at'] as String?);
            final end = event['ends_at'] as String?;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['status'] == 'cancelled'
                      ? 'EVENT ABGESAGT'
                      : 'COMMUNITY EVENT',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AccessTypography.labelSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AccessSpacing.s20),
                _heading(
                  event['title'] as String,
                  level: 1,
                  role: AccessHeadingRole.hero,
                  color: Colors.white,
                ),
                const SizedBox(height: AccessSpacing.s40),
                Wrap(
                  spacing: AccessSpacing.s24,
                  runSpacing: AccessSpacing.s24,
                  children: [
                    SizedBox(
                      width: width,
                      child: _meta(
                        'Datum · Europe/Berlin',
                        end == null ? date : '$date\nEnde: ${_date(end)}',
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _meta(
                        'Gastgeber',
                        event['community'] as String? ?? '',
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _meta('Veranstaltungsort', 'Geschützte Location'),
                    ),
                    SizedBox(
                      width: width,
                      child: _meta(
                        'Zugang',
                        'Ab ${event['minimum_age']} Jahren · ${event['capacity']} ${event['capacity'] == 1 ? 'Platz' : 'Plätze'}',
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _section(String title, Widget content) => Padding(
    padding: const EdgeInsets.only(bottom: AccessSpacing.s24),
    child: AccessSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(title),
          const SizedBox(height: AccessSpacing.s24),
          content,
        ],
      ),
    ),
  );

  Widget _programme(Map<String, dynamic> event) {
    final lineup = (event['lineup'] as String? ?? '').trim();
    final description = (event['description'] as String? ?? '').trim();
    final genres = (event['genres'] as String? ?? '')
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lineup.isNotEmpty)
          _section(
            'Line-up',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final act
                    in lineup
                        .split('\n')
                        .where((item) => item.trim().isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AccessSpacing.s12),
                    child: Text(
                      act.trim(),
                      style: const TextStyle(
                        fontSize: AccessTypography.cardTitleSize,
                        height: AccessTypography.bodyHeight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (genres.isNotEmpty)
          _section(
            'Genres',
            Wrap(
              spacing: AccessSpacing.s8,
              runSpacing: AccessSpacing.s8,
              children: [
                for (final genre in genres)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AccessSpacing.s16,
                      vertical: AccessSpacing.s8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF807A76)),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Text(
                      genre,
                      style: const TextStyle(
                        fontSize: AccessTypography.captionSize,
                        height: AccessTypography.readingHeight,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (description.isNotEmpty)
          _section(
            'Über das Event',
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AccessLayout.readingWidth,
                ),
                child: Text(description, style: _body),
              ),
            ),
          ),
        _section(
          'Zugang',
          Text(
            event['status'] == 'cancelled'
                ? 'Dieses Event ist abgesagt. Es werden keine weiteren Anfragen oder Zusagen angenommen. Die genaue Location ist für Gäste gesperrt.'
                : 'Die Teilnahme ist für aktive Mitglieder von ${event['community'] ?? 'dieser Community'} vorgesehen. Deine Anfrage wird separat bestätigt. Die genaue Location kannst du erst nach der Zusage abrufen.',
            style: _body,
          ),
        ),
      ],
    );
  }

  Widget _participation(Map<String, dynamic> event) {
    final status = event['request_status'] as String?;
    final cancelled = event['status'] == 'cancelled';
    final label = cancelled
        ? 'Event abgesagt'
        : switch (status) {
            'confirmed' => 'Deine Teilnahme ist bestätigt.',
            'pending' => 'Deine Anfrage ist offen.',
            'purchase_eligible' => 'Dein Ticketkauf ist freigegeben.',
            'rejected' => 'Deine Anfrage wurde abgelehnt.',
            'cancelled' => 'Deine Teilnahme ist aufgehoben.',
            _ => 'Sei dabei.',
          };
    return AccessReveal(
      child: AccessSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'DEINE TEILNAHME',
              style: TextStyle(
                fontSize: AccessTypography.labelSize,
                letterSpacing: 1.2,
                color: Color(0xFF55514F),
              ),
            ),
            const SizedBox(height: AccessSpacing.s16),
            Semantics(
              liveRegion: true,
              child: _heading(label, role: AccessHeadingRole.card),
            ),
            const SizedBox(height: AccessSpacing.s20),
            if (cancelled)
              const Text(
                'Es sind keine neuen Anfragen oder Locationabrufe möglich.',
                style: _body,
              ),
            if (!cancelled &&
                status == null &&
                event['ticket_mode'] != 'public') ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _age,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _age = value ?? false),
                title: Text(
                  'Ich bestätige, mindestens ${event['minimum_age']} Jahre alt zu sein.',
                  style: const TextStyle(
                    fontSize: AccessTypography.captionSize,
                    height: AccessTypography.bodyHeight,
                  ),
                ),
                subtitle: const Text(
                  'Selbstauskunft, keine verifizierte Altersprüfung.',
                  style: TextStyle(
                    fontSize: AccessTypography.labelSize,
                    height: AccessTypography.readingHeight,
                    color: Color(0xFF55514F),
                  ),
                ),
              ),
              const SizedBox(height: AccessSpacing.s16),
              FilledButton(
                onPressed: _busy || !_age
                    ? null
                    : () => _run(() async {
                        await widget.api.requestEvent(widget.eventId);
                        await _reload();
                      }),
                child: const Text('Eventteilnahme anfragen'),
              ),
            ],
            if (widget.api is TicketingApi &&
                ['public', 'approval'].contains(event['ticket_mode']))
              TicketPurchasePanel(
                api: widget.api as TicketingApi,
                eventId: widget.eventId.toString(),
                onChanged: () => _run(_reload),
              ),
            if (!cancelled && status == 'pending')
              const Text(
                'Die Gastgeber entscheiden über deine Anfrage. Die Location bleibt bis zur Zusage geschützt.',
                style: _body,
              ),
            if (!cancelled && status == 'confirmed') ...[
              const Text(
                'Rufe die genaue Location mit deiner aktuellen Berechtigung ab.',
                style: _body,
              ),
              const SizedBox(height: AccessSpacing.s20),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final epoch = _epoch;
                        final location = await widget.api.location(
                          widget.eventId,
                        );
                        if (mounted && epoch == _epoch) {
                          setState(() => _location = location);
                        }
                      }),
                icon: const AccessIcon(
                  Icons.place_outlined,
                  size: AccessLayout.smallIconSize,
                ),
                label: const Text('Location abrufen'),
              ),
              if (_location != null)
                Padding(
                  padding: const EdgeInsets.only(top: AccessSpacing.s20),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(_location!, style: _body),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          AccessHeader(
            child: Theme(
              data: Theme.of(context).copyWith(
                textButtonTheme: TextButtonThemeData(
                  style:
                      TextButton.styleFrom(
                        foregroundColor: AushangPalette.of(context).ink,
                        minimumSize: const Size(48, 48),
                      ).copyWith(
                        side: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.focused)
                              ? const BorderSide(
                                  color: AccessDesign.ink,
                                  width: 2,
                                )
                              : BorderSide.none,
                        ),
                      ),
                ),
              ),
              child: Row(
                children: [
                  Semantics(
                    label: 'Community Access',
                    child: const ExcludeSemantics(
                      child: AccessIcon(Icons.radio_button_checked, size: 24),
                    ),
                  ),
                  const SizedBox(width: AccessSpacing.s16),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const AccessIcon(
                          Icons.arrow_back,
                          size: AccessLayout.smallIconSize,
                        ),
                        label: const Text('Alle Events'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AccessSpacing.s16),
                  IconButton(
                    tooltip: 'Event aktualisieren',
                    onPressed: _busy ? null : () => _run(_reload),
                    icon: const AccessIcon(Icons.refresh),
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: AccessPageFrame(
                width: AccessPageWidth.detail,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_busy)
                      const LinearProgressIndicator(
                        semanticsLabel: 'Event wird geladen',
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(AccessSpacing.s24),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFA63028),
                              fontSize: AccessTypography.captionSize,
                              height: AccessTypography.readingHeight,
                            ),
                          ),
                        ),
                      ),
                    if (_event != null) ...[
                      _hero(_event!),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AccessSpacing.s32,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compact =
                                constraints.maxWidth <
                                    AccessLayout.twoColumnMinWidth ||
                                AccessLayout.largeText(context);
                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _participation(_event!),
                                  const SizedBox(height: AccessSpacing.s32),
                                  _programme(_event!),
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _programme(_event!)),
                                const SizedBox(width: AccessSpacing.s64),
                                SizedBox(
                                  width: AccessLayout.detailSidebarWidth,
                                  child: _participation(_event!),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.all(AccessSpacing.s24),
                      child: Text(
                        'Community Access · Alle Konten, Veranstalter und Orte sind erfunden.',
                        style: TextStyle(
                          color: Color(0xFF55514F),
                          fontSize: AccessTypography.labelSize,
                          height: AccessTypography.readingHeight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

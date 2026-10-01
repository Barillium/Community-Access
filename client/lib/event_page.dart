import 'package:flutter/material.dart';

import 'access_api.dart';
import 'design_system.dart';

/// The detail page loads a freshly authorized event; no location is cached in it.
class EventPage extends StatefulWidget {
  final AccessApi api;
  final int eventId;
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
  static const _ink = AccessDesign.ink;
  static const _coral = AccessDesign.accent;
  static const _body = TextStyle(fontSize: 15, height: 1.65);

  @override
  void initState() {
    super.initState();
    _run(_reload);
  }

  Future<void> _reload() async {
    // Also clear details if a membership was revoked while this route was open.
    if (!mounted) return;
    setState(() {
      _event = null;
      _location = null;
      _age = false;
    });
    final event = await widget.api.event(widget.eventId);
    if (mounted) setState(() => _event = event);
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
    double size = 26,
    Color color = _ink,
  }) => Semantics(
    container: true,
    headingLevel: level,
    child: Text(
      text,
      style: TextStyle(
        fontSize: size,
        height: 1.15,
        fontWeight: FontWeight.w500,
        letterSpacing: -.7,
        color: color,
      ),
    ),
  );

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
          fontSize: 12,
          height: 1.6,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _hero(Map<String, dynamic> event) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
    child: AccessReveal(
      child: AccessSurface(
        color: _ink,
        padding: const EdgeInsets.all(32),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 720 ||
                MediaQuery.textScalerOf(context).scale(14) > 18;
            final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
            final columns = largeText || constraints.maxWidth < 300
                ? 1
                : compact
                ? 2
                : 4;
            final width = (constraints.maxWidth - 24 * (columns - 1)) / columns;
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
                    color: _coral,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 18),
                _heading(
                  event['title'] as String,
                  level: 1,
                  size: compact ? 34 : 64,
                  color: Colors.white,
                ),
                const SizedBox(height: 36),
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
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
    padding: const EdgeInsets.only(bottom: 24),
    child: AccessSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_heading(title), const SizedBox(height: 24), content],
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
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      act.trim(),
                      style: const TextStyle(
                        fontSize: 22,
                        height: 1.4,
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
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final genre in genres)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF807A76)),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      genre,
                      style: const TextStyle(fontSize: 13, height: 1.6),
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
                constraints: const BoxConstraints(maxWidth: 760),
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
                fontSize: 11,
                letterSpacing: 1.2,
                color: Color(0xFF55514F),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(liveRegion: true, child: _heading(label, size: 24)),
            const SizedBox(height: 20),
            if (cancelled)
              const Text(
                'Es sind keine neuen Anfragen oder Locationabrufe möglich.',
                style: _body,
              ),
            if (!cancelled && status == null) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _age,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _age = value ?? false),
                title: Text(
                  'Ich bestätige, mindestens ${event['minimum_age']} Jahre alt zu sein.',
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
                subtitle: const Text(
                  'Selbstauskunft, keine verifizierte Altersprüfung.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: Color(0xFF55514F),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final location = await widget.api.location(
                          widget.eventId,
                        );
                        if (mounted) setState(() => _location = location);
                      }),
                icon: const AccessIcon(Icons.place_outlined, size: 18),
                label: const Text('Location abrufen'),
              ),
              if (_location != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
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
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 48),
                      ).copyWith(
                        side: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.focused)
                              ? const BorderSide(
                                  color: AccessDesign.accentSoft,
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
                      child: AccessIcon(
                        Icons.radio_button_checked,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const AccessIcon(Icons.arrow_back, size: 18),
                        label: const Text('Alle Events'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    tooltip: 'Event aktualisieren',
                    onPressed: _busy ? null : () => _run(_reload),
                    icon: const AccessIcon(Icons.refresh, color: Colors.white),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_busy)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Event wird geladen',
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFA63028),
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                  if (_event != null) ...[
                    _hero(_event!),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact =
                              constraints.maxWidth < 900 ||
                              MediaQuery.textScalerOf(context).scale(14) > 18;
                          if (compact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _participation(_event!),
                                const SizedBox(height: 32),
                                _programme(_event!),
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _programme(_event!)),
                              const SizedBox(width: 64),
                              SizedBox(
                                width: 360,
                                child: _participation(_event!),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Community Access · Alle Konten, Kollektive und Orte sind erfunden.',
                      style: TextStyle(
                        color: Color(0xFF55514F),
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

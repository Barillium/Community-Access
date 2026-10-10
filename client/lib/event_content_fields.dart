import 'package:flutter/material.dart';

import 'design_system.dart';

import 'access_api.dart';
import 'event_editorial_view.dart';
import 'event_flyer_picker.dart';
import 'event_datetime_field.dart';
import 'contact_link_stub.dart'
    if (dart.library.js_interop) 'contact_link_web.dart';

const eventAgeGuidance =
    'Du legst das Mindestalter für dieses Event fest. Gesetzliche Jugendschutzvorgaben und behördliche Auflagen gelten zusätzlich, auch ohne Altersangabe.';
const youthProtectionLawUrl =
    'https://www.gesetze-im-internet.de/juschg/BJNR273000002.html';

class EventContentFields extends StatefulWidget {
  final Map<String, dynamic> initial;
  final bool enabled;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final Future<String?> Function()? chooseFlyer;
  final bool showSchedule;
  final Map<String, String> errors;
  const EventContentFields({
    super.key,
    required this.initial,
    required this.enabled,
    required this.onChanged,
    this.chooseFlyer,
    this.showSchedule = true,
    this.errors = const {},
  });
  @override
  State<EventContentFields> createState() => _EventContentFieldsState();
}

class _EventContentFieldsState extends State<EventContentFields> {
  final _fields = <String, TextEditingController>{};
  String _flyer = '';
  String? _notice;
  bool _picking = false;
  @override
  void initState() {
    super.initState();
    for (final key in [
      'description',
      'admission',
      'venue_name',
      'flyer_alt',
      'ends_at',
      'minimum_age',
      'line_up',
      'genres',
    ]) {
      final value = widget.initial[key];
      _fields[key] = TextEditingController(
        text: value is List
            ? value.join(key == 'genres' ? ', ' : '\n')
            : value?.toString() ?? '',
      );
    }
    _flyer = widget.initial['flyer_data'] as String? ?? '';
    _fields['ends_at']!.addListener(_changed);
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.removeListener(_changed);
      c.dispose();
    }
    super.dispose();
  }

  void _changed() => widget.onChanged({
    for (final key in ['description', 'admission', 'venue_name', 'flyer_alt'])
      key: _fields[key]!.text.trim(),
    'ends_at': _fields['ends_at']!.text.trim().isEmpty
        ? null
        : _fields['ends_at']!.text.trim(),
    'minimum_age': _fields['minimum_age']!.text.trim().isEmpty
        ? null
        : int.tryParse(_fields['minimum_age']!.text.trim()) ?? -1,
    'line_up': _fields['line_up']!.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(),
    'genres': _fields['genres']!.text
        .split(RegExp(r'[,\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(),
    'flyer_data': _flyer,
  });
  Future<void> _choose() async {
    setState(() {
      _picking = true;
      _notice = null;
    });
    try {
      final data = await (widget.chooseFlyer ?? pickEventFlyer)();
      if (!mounted) return;
      if (data != null) {
        setState(() => _flyer = data);
        _changed();
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _notice = e is ApiFailure
              ? e.message
              : 'Das Bild konnte nicht geladen werden.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Widget _field(
    String key,
    String label,
    int max, {
    String? hint,
    int lines = 1,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(top: AccessSpacing.s16),
    child: AccessField(
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: widget.errors[key],
      ),
      builder: (decoration) => TextField(
        controller: _fields[key],
        enabled: widget.enabled && !_picking,
        maxLength: max,
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 3,
        keyboardType: keyboard,
        onChanged: (_) => _changed(),
        decoration: decoration,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: AccessSpacing.s24),
      const Text(
        '3. Inhalte der Eventseite',
        style: TextStyle(
          fontSize: AccessTypography.sectionTitleSize,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: AccessSpacing.s8),
      const Text(
        'Beschreibung ist bei öffentlichen Events erforderlich. Weitere Angaben sind optional und folgen der Eventfreigabe.',
      ),
      _field('description', 'Beschreibung', 6000, lines: 4),
      _field(
        'line_up',
        'Line-up',
        7240,
        hint: 'Ein Act pro Zeile, in der gewünschten Reihenfolge',
        lines: 4,
      ),
      _field(
        'genres',
        'Genres',
        328,
        hint: 'Mit Komma trennen, höchstens acht Genres',
      ),
      _field('venue_name', 'Name des Veranstaltungsorts', 240),
      const Text('Der Ortsname folgt derselben Freigabe wie die Ortsangabe.'),
      if (widget.showSchedule)
        EventDateTimeField(
          controller: _fields['ends_at']!,
          label: 'Ende',
          enabled: widget.enabled,
          errorText: widget.errors['end'],
          helperText:
              'Im Entwurf optional; für die Veröffentlichung erforderlich.',
        ),
      _field(
        'minimum_age',
        'Mindestalter (optional)',
        2,
        keyboard: TextInputType.number,
      ),
      const Text(
        eventAgeGuidance,
        style: TextStyle(height: AccessTypography.readingHeight),
      ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Jugendschutz beachten'),
        children: [
          const Text(
            'Für Veranstaltungen in Deutschland hängen die Regeln auch von Veranstaltungsart, Uhrzeit und Begleitung ab. '
            'Bei öffentlichen Tanzveranstaltungen dürfen unter 16-Jährige ohne personensorgeberechtigte oder erziehungsbeauftragte Begleitung nicht teilnehmen; '
            '16- und 17-Jährige ohne diese Begleitung längstens bis 24 Uhr. Gesetzliche Sonderregeln und behördlich genehmigte Ausnahmen sind gesondert zu prüfen (§ 5 JuSchG).'
            '\n\nIn Nachtbars, Nachtclubs und vergleichbaren Betrieben dürfen sich Minderjährige nicht aufhalten (§ 4 Abs. 3 JuSchG).'
            '\n\nPrüfe die Regeln für dein Event, erläutere nötige Begleitung und Einlasszeiten in den Einlassinformationen und setze sie vor Ort um. '
            'Beachte auch gegebenenfalls geltende Alkoholregeln und Aushangpflichten. Eine Bestätigung in der App ersetzt keine nötige Alters- oder Begleitungsprüfung.',
            style: TextStyle(height: AccessTypography.readingHeight),
          ),
          TextButton(
            onPressed: () async {
              final opened = await openContact(youthProtectionLawUrl);
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: SelectableText(
                      'Gesetzestext: $youthProtectionLawUrl',
                    ),
                  ),
                );
              }
            },
            child: const Text('Jugendschutzgesetz ansehen'),
          ),
        ],
      ),
      _field('admission', 'Einlassinformationen', 1200, lines: 2),
      const SizedBox(height: AccessSpacing.s24),
      const Text(
        'Eventflyer',
        style: TextStyle(
          fontSize: AccessTypography.sectionTitleSize,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: AccessSpacing.s8),
      const Text(
        'JPG oder PNG, bis 10 MB. Das Bild wird verkleinert und als Bestandteil dieses Events gespeichert.',
      ),
      const SizedBox(height: AccessSpacing.s8),
      const Text(
        'Verwende nur Bilder, die du hier zeigen darfst, auch wenn Personen abgebildet sind. Erforderliche Bildnachweise gehören in die Beschreibung. Keine geschützten Adressen im Flyer veröffentlichen.',
        style: TextStyle(height: AccessTypography.readingHeight),
      ),
      if (widget.errors['flyer_data'] != null)
        Text(
          widget.errors['flyer_data']!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (_notice != null)
        Padding(
          padding: const EdgeInsets.only(top: AccessSpacing.s12),
          child: Semantics(liveRegion: true, child: Text(_notice!)),
        ),
      const SizedBox(height: AccessSpacing.s16),
      Wrap(
        spacing: AccessSpacing.s12,
        runSpacing: AccessSpacing.s12,
        children: [
          OutlinedButton.icon(
            onPressed:
                widget.enabled &&
                    !_picking &&
                    (flyerPickerAvailable || widget.chooseFlyer != null)
                ? _choose
                : null,
            icon: const AccessIcon(Icons.add_photo_alternate_outlined),
            label: Text(
              _picking
                  ? 'Bild wird vorbereitet…'
                  : _flyer.isEmpty
                  ? 'Flyer auswählen'
                  : 'Flyer ersetzen',
            ),
          ),
          if (_flyer.isNotEmpty)
            TextButton(
              onPressed: widget.enabled && !_picking
                  ? () {
                      setState(() => _flyer = '');
                      _changed();
                    }
                  : null,
              child: const Text('Flyer entfernen'),
            ),
        ],
      ),
      if (!flyerPickerAvailable && widget.chooseFlyer == null)
        const Text('Die Bildauswahl steht aktuell im Browser zur Verfügung.'),
      if (_flyer.isNotEmpty) ...[
        const SizedBox(height: AccessSpacing.s16),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 240,
            child: EventFlyer(data: _flyer, alt: _fields['flyer_alt']!.text),
          ),
        ),
      ],
      _field(
        'flyer_alt',
        'Bildbeschreibung',
        240,
        hint: 'Beschreibe das Motiv; wichtige Eventangaben auch in die Textfelder eintragen.',
      ),
    ],
  );
}

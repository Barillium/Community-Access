import 'product_scope.dart';

import 'dart:convert';

import 'package:flutter/material.dart';

import 'access_api.dart';
import 'directory_api.dart';
import 'directory_pages.dart';
import 'design_system.dart';
import 'app_language.dart';
import 'event_access_details.dart';
import 'event_content_fields.dart';
import 'event_editorial_view.dart';
import 'event_datetime_field.dart';
import 'event_drafts.dart';
import 'event_leave_guard.dart';

class EventDirectoryEditor extends StatefulWidget {
  final DirectoryApi api;
  final List<Map<String, dynamic>> communities;
  final Map<String, dynamic>? event;
  final List<Map<String, dynamic>> series;
  final List<Map<String, dynamic>> forms;
  final String? profileId;
  final bool profilePublic;
  final Map<String, dynamic>? initialDraft;
  final String? draftKey;
  const EventDirectoryEditor({
    super.key,
    required this.api,
    required this.communities,
    this.event,
    this.series = const [],
    this.forms = const [],
    this.profileId,
    this.profilePublic = false,
    this.initialDraft,
    this.draftKey,
  });
  @override
  State<EventDirectoryEditor> createState() => _EventDirectoryEditorState();
}

class _EventDirectoryEditorState extends State<EventDirectoryEditor> {
  final _title = TextEditingController(),
      _location = TextEditingController(),
      _exactLocation = TextEditingController(),
      _capacity = TextEditingController(),
      _start = TextEditingController(),
      _end = TextEditingController();
  String? _community, _series;
  Map<String, dynamic> _content = {};
  final Map<String, String> _features = {};
  final Map<String, TextEditingController> _accessNotes = {
    for (final key in accessNoteLabels.keys) key: TextEditingController(),
  };
  String _status = 'draft', _accessMode = 'private', _reviewMethod = 'manual';
  String? _formId;
  final _timeRelease = TextEditingController(),
      _locationRelease = TextEditingController(),
      _requestDeadline = TextEditingController();
  bool _membershipRequired = false;
  bool _locationPublic = false, _startsPublic = false, _busy = false;
  String? _notice;
  final _guard = EventLeaveGuard();
  late final EventDrafts _drafts;
  late final String _draftKey, _original;
  late final int _epoch;
  int? _baseVersion;
  bool _dirty = false,
      _allowLeave = false,
      _sessionValid = true,
      _restored = false;
  bool _validationAttempted = false, _leaving = false;
  Map<String, String> _errors = {};
  final _keys = <String, GlobalKey>{};
  GlobalKey _key(String name) => _keys.putIfAbsent(name, () => GlobalKey());
  List<TextEditingController> get _controllers => [
    _title,
    _location,
    _exactLocation,
    _capacity,
    _start,
    _end,
    _timeRelease,
    _locationRelease,
    _requestDeadline,
    ..._accessNotes.values,
  ];

  @override
  void initState() {
    super.initState();
    _drafts = EventDrafts.forApi(widget.api);
    _epoch = _drafts.epoch;
    _draftKey =
        '${widget.profileId ?? widget.communities.firstOrNull?['id'] ?? 'none'}/${widget.event?['id'] ?? widget.draftKey ?? 'new'}';
    final saved = _drafts.read(_draftKey);
    final e = saved ?? widget.event ?? widget.initialDraft;
    _restored = saved != null;
    _baseVersion = (saved?['version'] ?? widget.event?['version']) as int?;

    _title.text = e?['title'] as String? ?? '';
    _content = Map<String, dynamic>.from(e?['event_content'] as Map? ?? {});
    _end.text = _content['ends_at'] as String? ?? '';
    _location.text = e?['public_location'] as String? ?? '';
    _exactLocation.text = e?['exact_location'] as String? ?? '';
    _capacity.text =
        e?['_capacity_input'] as String? ?? e?['capacity']?.toString() ?? '';
    _membershipRequired = e?['membership_required'] == true;
    _start.text = e?['starts_at'] as String? ?? '';
    _community =
        e?['community_id'] as String? ??
        widget.communities.firstOrNull?['id'] as String?;
    _status = e?['status'] as String? ?? 'draft';
    _series = e?['series_id'] as String?;
    _accessMode =
        e?['access_mode'] as String? ??
        (e?['is_public'] == true ? 'public' : 'private');
    if (_accessMode == 'legacy') {
      _accessMode = e?['is_public'] == true ? 'public' : 'private';
    }
    _reviewMethod = e?['review_method'] as String? ?? 'manual';
    _formId = e?['form_id'] as String?;
    _timeRelease.text = e?['time_release_at'] as String? ?? '';
    _locationRelease.text = e?['location_release_at'] as String? ?? '';
    _requestDeadline.text = e?['request_deadline_at'] as String? ?? '';
    _locationPublic = e?['location_public'] == true;
    _startsPublic = e?['starts_public'] == true;
    final details = e?['access_details'] as Map? ?? {};
    for (final key in accessFeatureLabels.keys) {
      _features[key] = details[key] as String? ?? 'unknown';
    }
    for (final entry in _accessNotes.entries) {
      entry.value.text = details[entry.key] as String? ?? '';
    }
    _original = jsonEncode(_payload());
    _dirty = _restored || widget.initialDraft != null;
    if (_dirty) _drafts.write(_draftKey, _payload());
    _guard.setDirty(_dirty);
    for (final controller in _controllers) {
      controller.addListener(_remember);
    }
    _drafts.addListener(_sessionChanged);
    if (saved != null &&
        widget.event != null &&
        saved['version'] != widget.event!['version']) {
      _notice = 'Dein Entwurf basiert auf einem älteren Stand. Vergleiche ihn mit dem aktuellen Event, bevor du speicherst.';
    }
  }

  Map<String, dynamic> _payload() => {
    if (widget.event != null) 'id': widget.event!['id'],
    if (widget.event != null) 'version': _baseVersion,
    if (widget.profileId != null) 'profile_id': widget.profileId,
    'title': _title.text.trim(),
    'community_id': _community,
    'series_id': _series,
    'status': _status,
    'is_public': _accessMode != 'private',
    'access_mode': _accessMode,
    'review_method': _reviewMethod, 'form_id': _formId,
    'request_deadline_at': _requestDeadline.text.isEmpty
        ? null
        : _requestDeadline.text,
    'time_release_at': _timeRelease.text.isEmpty ? null : _timeRelease.text,
    'location_release_at': _locationRelease.text.isEmpty
        ? null
        : _locationRelease.text,
    'starts_at': _start.text.isEmpty ? null : _start.text,
    'starts_public': _startsPublic, 'location_public': _locationPublic,
    'public_location': _location.text.trim(),
    'exact_location': _exactLocation.text.trim(),
    'membership_required': _membershipRequired,
    'capacity': _capacity.text.trim().isEmpty
        ? null
        : int.tryParse(_capacity.text.trim()) ?? -1,
    'event_content': {
      ..._content,
      'ends_at': _end.text.isEmpty ? null : _end.text,
    },
    'access_details': {
      ..._features,
      for (final e in _accessNotes.entries) e.key: e.value.text.trim(),
    },
    // Preserve incomplete numeric input in the session draft; never send these helper values.
    '_capacity_input': _capacity.text,
  };

  void _remember() {
    if (!_sessionValid || _drafts.epoch != _epoch) return;
    final payload = _payload();
    final dirty =
        _restored ||
        widget.initialDraft != null ||
        jsonEncode(payload) != _original;
    if (dirty) {
      _drafts.write(_draftKey, payload);
    } else {
      _drafts.remove(_draftKey);
    }
    _guard.setDirty(dirty);
    if (mounted) {
      setState(() {
        _dirty = dirty;
        if (_validationAttempted) _errors = _validate();
      });
    }
  }

  void _change(VoidCallback action) {
    setState(action);
    _remember();
  }

  void _sessionChanged() {
    if (!mounted || _drafts.epoch == _epoch) return;
    _sessionValid = false;
    _guard.setDirty(false);
    for (final controller in _controllers) {
      controller.clear();
    }
    setState(() {
      _dirty = false;
      _content = {};
      _errors = {};
      _notice = 'Die Anmeldung wurde geändert. Der lokale Entwurf wurde entfernt. Öffne die Gastgeberverwaltung erneut.';
    });
  }

  Map<String, String> _validate() {
    final errors = <String, String>{};
    if (_title.text.trim().isEmpty) {
      errors['title'] = 'Bitte einen Eventtitel eingeben.';
    }
    if (_community == null) {
      errors['community'] = 'Bitte eine verantwortliche Community auswählen.';
    }
    for (final entry in {
      'start': _start,
      'end': _end,
      'deadline': _requestDeadline,
      'time_release': _timeRelease,
      'location_release': _locationRelease,
    }.entries) {
      if (entry.value.text.isNotEmpty && eventDate(entry.value.text) == null) {
        errors[entry.key] =
            'Bitte Datum und Uhrzeit vollständig und gültig eingeben.';
      }
    }
    final published = _status == 'published' || _status == 'cancelled';
    if (published && _end.text.isEmpty) {
      errors['end'] = 'Für die Veröffentlichung ist eine Endzeit erforderlich.';
    }
    final start = eventDate(_start.text), end = eventDate(_end.text);
    if (end != null && start == null) {
      errors['start'] = 'Bitte den Beginn angeben.';
    }
    if (end != null && start != null && !end.isAfter(start)) {
      errors['end'] = 'Das Ende muss nach dem Beginn liegen.';
    }
    if (end != null &&
        end.add(const Duration(hours: 168)).isBefore(DateTime.now())) {
      errors['end'] =
          'Die Aufbewahrungsfrist dieses Termins ist bereits abgelaufen.';
    }
    if (_accessMode != 'private' && !widget.profilePublic) {
      errors['visibility'] = 'Öffentliche und semiöffentliche Events brauchen ein öffentliches Veranstalterprofil.';
    }
    if (_accessMode == 'public' && _status == 'published') {
      if (_start.text.isEmpty) errors['start'] = 'Bitte einen Beginn angeben.';
      if (!_startsPublic) {
        errors['show_start'] =
            'Bei öffentlichen Events muss der Beginn sichtbar sein.';
      }
      if (_location.text.trim().isEmpty) {
        errors['location'] = 'Bitte einen öffentlich auffindbaren Ort angeben.';
      }
      if (!_locationPublic) {
        errors['show_location'] =
            'Bei öffentlichen Events muss die Ortsangabe sichtbar sein.';
      }
      if ((_content['description'] as String? ?? '').trim().isEmpty) {
        errors['description'] =
            'Bitte eine Beschreibung für das öffentliche Event eingeben.';
      }
    }
    if (_locationPublic && _location.text.trim().isEmpty) {
      errors['location'] = 'Bitte eine freigegebene Ortsangabe eingeben.';
    }
    if (_reviewMethod == 'form' &&
        (_formId == null || !widget.forms.any((f) => f['id'] == _formId))) {
      errors['form'] =
          'Bitte zuerst ein Formular erstellen und hier auswählen.';
    }
    if (_accessMode == 'semi_public') {
      if (_status == 'published') {
        if (_timeRelease.text.isEmpty) {
          errors['time_release'] = 'Bitte die Freigabe der Zeitangaben planen.';
        }
        if (_locationRelease.text.isEmpty) {
          errors['location_release'] =
              'Bitte die Freigabe der Ortsangaben planen.';
        }
        if (_requestDeadline.text.isEmpty) {
          errors['deadline'] = 'Bitte die öffentliche Anfragefrist festlegen.';
        }
      }
      if ((_content['flyer_data'] as String? ?? '').isNotEmpty) {
        errors['flyer_data'] =
            'Entferne den Flyer für ein semiöffentliches Event.';
      }
    }
    final cap = int.tryParse(_capacity.text.trim());
    if (_capacity.text.trim().isNotEmpty &&
        (cap == null || cap < 1 || cap > 2147483647)) {
      errors['capacity'] = 'Bitte eine positive ganze Platzzahl eingeben oder das Feld leer lassen.';
    }
    final age = _content['minimum_age'];
    if (age != null && (age is! int || age < 0 || age > 99)) {
      errors['minimum_age'] = 'Bitte ein Mindestalter von 0 bis 99 eingeben.';
    }
    for (final config in [('line_up', 40, 180), ('genres', 8, 40)]) {
      final values = (_content[config.$1] as List? ?? []);
      if (values.length > config.$2 ||
          values.any((v) => (v as String).length > config.$3)) {
        errors[config.$1] =
            'Höchstens ${config.$2} Einträge mit je ${config.$3} Zeichen.';
      }
    }
    if ((_content['flyer_data'] as String? ?? '').isNotEmpty &&
        (_content['flyer_alt'] as String? ?? '').trim().isEmpty) {
      errors['flyer_alt'] =
          'Bitte eine Bildbeschreibung für den Flyer eingeben.';
    }
    return errors;
  }

  Future<void> _leave() async {
    if (_busy || _leaving) return;
    if (!_dirty) {
      setState(() => _allowLeave = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
      return;
    }
    _leaving = true;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const LocalText('Ungespeicherte Eventangaben'),
        content: const LocalText(
          'Den Entwurf während dieser Anmeldung behalten? Er bleibt nur im Arbeitsspeicher. Bei Neuladen, Schließen oder Abmeldung geht er verloren.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'stay'),
            child: const LocalText('Weiter bearbeiten'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const LocalText('Entwurf verwerfen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'keep'),
            child: const LocalText('Entwurf behalten'),
          ),
        ],
      ),
    );
    _leaving = false;
    if (!mounted || choice == null || choice == 'stay') return;
    if (choice == 'discard') _drafts.remove(_draftKey);
    _guard.setDirty(false);
    setState(() => _allowLeave = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _drafts.removeListener(_sessionChanged);
    _guard.dispose();
    for (final controller in _controllers) {
      controller.removeListener(_remember);
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!mounted || _busy || !_sessionValid) return;
    final errors = _validate();
    setState(() {
      _validationAttempted = true;
      _errors = errors;
    });
    if (errors.isNotEmpty) {
      setState(
        () => _notice = 'Bitte die markierten Angaben prüfen. Dein Entwurf bleibt erhalten.',
      );
      final first = errors.keys.first;
      final target = _key(
        [
              'description',
              'line_up',
              'genres',
              'minimum_age',
              'flyer_data',
              'flyer_alt',
            ].contains(first)
            ? 'content'
            : first,
      ).currentContext;
      if (target != null) {
        await Scrollable.ensureVisible(
          target,
          alignment: 0.1,
          duration: const Duration(milliseconds: 250),
        );
      }
      return;
    }
    if (_status == 'published' && widget.event?['status'] != 'published') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const LocalText('Event veröffentlichen?'),
          content: LocalText(
            _accessMode == 'public'
                ? 'Die freigegebenen Angaben sind öffentlich auffindbar. Prüfe sie vor der Veröffentlichung mit „Wer sieht was?“. Eine geschützte Reihe kann den sichtbaren Gästekreis weiterhin begrenzen.'
                : _accessMode == 'semi_public'
                ? 'Beschreibung und Line-up sind öffentlich. Zeit und Ort bleiben nach den gewählten Zugangs- und Freigaberegeln geschützt.'
                : 'Das Event wird für den freigegebenen Gästekreis verfügbar. Sichtbarkeit und Teilnahmezusage bleiben getrennt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const LocalText('Zurück zum Entwurf'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const LocalText('Veröffentlichen'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true || !_sessionValid) return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final body = _payload()..remove('_capacity_input');
      await widget.api.directory('manage/event', body: body);
      if (mounted && _sessionValid) {
        _drafts.remove(_draftKey);
        _guard.setDirty(false);
        setState(() {
          _dirty = false;
          _allowLeave = true;
        });
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _notice = e is ApiFailure ? e.message : 'Die Angaben konnten nicht gespeichert werden. Dein Entwurf bleibt erhalten.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _section(String key, String title, String help) => Padding(
    key: _key(key),
    padding: const EdgeInsets.only(top: 32, bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccessHeading(title, role: AccessHeadingRole.section, level: 2),
        const SizedBox(height: 8),
        LocalText(help),
      ],
    ),
  );
  Widget _anchor(String key, Widget child) => Padding(
    key: _key(key),
    padding: const EdgeInsets.only(bottom: 16),
    child: child,
  );
  Widget _text(
    String key,
    String label,
    TextEditingController controller, {
    int max = 240,
    int lines = 1,
    TextInputType? keyboard,
    String? help,
  }) => _anchor(
    key,
    AccessField(
      decoration: InputDecoration(
        labelText: label,
        errorText: _errors[key],
        helperText: help,
        helperMaxLines: 30,
        errorMaxLines: 30,
      ),
      builder: (d) => TextField(
        controller: controller,
        enabled: !_busy && _sessionValid,
        maxLength: max,
        minLines: lines,
        maxLines: lines + 3,
        keyboardType: keyboard,
        decoration: d,
      ),
    ),
  );
  Widget _choice(
    String key,
    String label,
    String? value,
    Map<String, String> values,
    ValueChanged<String?> change,
  ) => _anchor(
    key,
    AccessField(
      decoration: InputDecoration(labelText: label, errorText: _errors[key]),
      trailingWidth: AccessSpacing.s40,
      builder: (d) => DropdownButtonFormField<String>(
        key: ValueKey('$key:$value'),
        initialValue: values.containsKey(value) ? value : null,
        decoration: d,
        isExpanded: true,
        itemHeight: null,
        items: [
          for (final e in values.entries)
            DropdownMenuItem(value: e.key, child: AccessOptionText(e.value)),
        ],
        onChanged: _busy || !_sessionValid ? null : change,
      ),
    ),
  );
  Widget _date(
    String key,
    String label,
    TextEditingController controller, {
    String? help,
  }) => _anchor(
    key,
    EventDateTimeField(
      controller: controller,
      label: label,
      enabled: !_busy && _sessionValid,
      errorText: _errors[key],
      helperText: help,
    ),
  );
  Widget _toggle(
    String key,
    String label,
    bool value,
    ValueChanged<bool?>? change,
  ) => _anchor(
    key,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: LocalText(label),
          value: value,
          onChanged: _busy || !_sessionValid ? null : change,
        ),
        if (_errors[key] != null)
          Text(
            _errors[key]!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowLeave || (!_dirty && !_busy),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: accessAppBar(
        context,
        widget.initialDraft == null ? 'Event bearbeiten' : 'Neuer Evententwurf',
      ),
      body: SingleChildScrollView(
        child: AccessPageFrame(
          title: widget.initialDraft == null
              ? 'Event bearbeiten'
              : 'Neuer Evententwurf',
          width: AccessPageWidth.form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_notice != null) directoryNotice(_notice!),
              Semantics(
                liveRegion: true,
                child: LocalText(
                  _dirty
                      ? 'Entwurf im Arbeitsspeicher behalten. Noch nicht auf dem Server gespeichert.'
                      : 'Keine ungespeicherten Änderungen.',
                ),
              ),
              const LocalText(
                'Neuladen oder Schließen entfernt den lokalen Entwurf. Speichere ihn ausdrücklich, um ihn dauerhaft zu behalten.',
              ),
              if (_restored)
                const LocalText(
                  'Dein ungespeicherter Entwurf wurde wiederhergestellt.',
                ),
              if (widget.initialDraft != null)
                const LocalText(
                  'Diese Kopie ist ein neuer Entwurf. Anfragen, Zusagen und persönliche Freigaben wurden nicht übernommen.',
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final e in {
                    'basics': 'Grunddaten',
                    'guests': 'Gästezugang',
                    'content': 'Inhalte',
                    'access': 'Zugänglichkeit',
                  }.entries)
                    TextButton(
                      onPressed: () {
                        final target = _key(e.key).currentContext;
                        if (target != null) {
                          Scrollable.ensureVisible(
                            target,
                            duration: const Duration(milliseconds: 250),
                          );
                        }
                      },
                      child: LocalText(e.value),
                    ),
                ],
              ),
              _section(
                'basics',
                '1. Grunddaten und Termin',
                'Pflicht: Eventtitel und verantwortliche Community. Für die Veröffentlichung sind Beginn und Ende erforderlich.',
              ),
              _text(
                'title',
                'Eventtitel',
                _title,
                max: 180,
                help: 'Pflichtfeld',
              ),
              _choice(
                'community',
                'Verantwortliche Community',
                _community,
                {
                  for (final c in widget.communities)
                    c['id'] as String: c['name'] as String,
                },
                (v) => _change(() {
                  _community = v;
                  _series = null;
                }),
              ),
              if (ProductScope.extended)
                _choice('series', 'Veranstaltungsreihe', _series ?? 'none', {
                  'none': 'Einzelnes Event',
                  for (final s in widget.series.where(
                    (s) => s['community_id'] == _community,
                  ))
                    s['id'] as String: s['title'] as String,
                }, (v) => _change(() => _series = v == 'none' ? null : v)),
              _date('start', 'Beginn', _start),
              _date(
                'end',
                'Ende',
                _end,
                help: 'Im Entwurf optional; für veröffentlichte oder abgesagte Events erforderlich. Das Ende muss nach dem Beginn liegen.',
              ),
              const LocalText(
                'Ab exakt 168 Stunden nach dem tatsächlichen Ende sind die Eventdaten nicht mehr abrufbar und werden bei der nächsten Bereinigung gelöscht.',
              ),
              _section(
                'guests',
                '2. Sichtbarkeit und Gästezugang',
                'Sichtbarkeit erlaubt das Ansehen. Eine Teilnahmezusage wird separat erteilt.',
              ),
              _choice('status', 'Veröffentlichungsstatus', _status, {
                'draft': 'Entwurf',
                'published': 'Veröffentlicht',
                'cancelled': 'Abgesagt',
              }, (v) => _change(() => _status = v!)),
              _choice(
                'visibility',
                'Sichtbarkeit',
                _accessMode,
                {
                  'public': 'Öffentlich',
                  if (ProductScope.extended) 'semi_public': 'Semi-öffentlich',
                  'private': 'Privat',
                },
                (v) => _change(() {
                  _accessMode = v!;
                  if (v == 'semi_public') {
                    _startsPublic = false;
                    _locationPublic = false;
                  }
                }),
              ),
              LocalText(switch (_accessMode) {
                'public' => 'Beschreibung, Beginn und freigegebener Ort müssen öffentlich auffindbar sein. Ein öffentliches Veranstalterprofil ist erforderlich.',
                'semi_public' => 'Beschreibung und Line-up sind öffentlich. Zeit und Ort folgen den Freigaberegeln; Flyer sind gesperrt. Ein öffentliches Veranstalterprofil ist erforderlich.',
                _ => 'Das Event ist für den persönlich freigegebenen Gästekreis sichtbar.',
              }),
              _toggle(
                'show_start',
                'Beginn im sichtbaren Event anzeigen',
                _startsPublic,
                _accessMode == 'semi_public'
                    ? null
                    : (v) => _change(() => _startsPublic = v!),
              ),
              _text(
                'location',
                'Freigegebene Ortsangabe',
                _location,
                help: 'Diese Angabe ist bei öffentlichen Events öffentlich auffindbar. Eine geschützte genaue Adresse gehört in das getrennte Feld.',
              ),
              _toggle(
                'show_location',
                'Diese Ortsangabe im sichtbaren Event anzeigen',
                _locationPublic,
                _accessMode == 'semi_public'
                    ? null
                    : (v) => _change(() => _locationPublic = v!),
              ),
              _text(
                'exact_location',
                'Geschützte genaue Location',
                _exactLocation,
                max: 2000,
                help: 'Nur zuständige Gastgeber und aktuell bestätigte berechtigte Gäste können diese Angabe abrufen; bei semiöffentlichen Events zusätzlich erst nach Ortsfreigabe.',
              ),
              _choice('review', 'Gästeprüfung', _reviewMethod, {
                'manual': 'Manuelle Anfrage',
                'form': 'Formular und manuelle Prüfung',
                'invite': 'Nur persönliche Freigabe',
              }, (v) => _change(() => _reviewMethod = v!)),
              if (_reviewMethod == 'form') ...[
                _choice('form', 'Formular', _formId, {
                  for (final f in widget.forms)
                    f['id'] as String: f['title'] as String,
                }, (v) => _change(() => _formId = v)),
                if (widget.forms.isEmpty)
                  const LocalText(
                    'Erstelle zuerst ein Formular in der Gastgeberverwaltung. Du kannst dieses Event zunächst mit manueller Anfrage als Entwurf speichern.',
                  ),
              ],
              _date(
                'deadline',
                'Öffentliche Anfragefrist',
                _requestDeadline,
                help: 'Diese Frist ist öffentlich und unabhängig vom Beginn. Bei verborgenem Beginn ist sie für Anfragen und Rückzug erforderlich.',
              ),
              if (_accessMode == 'semi_public') ...[
                _date('time_release', 'Zeitangaben freigeben ab', _timeRelease),
                _date(
                  'location_release',
                  'Ortsangaben freigeben ab',
                  _locationRelease,
                ),
                const LocalText(
                  'Keine genauen Adressen oder Hinweise auf verborgene Zeiten in Beschreibung und Line-up eintragen.',
                ),
              ],
              _toggle(
                'membership',
                'Aktive Communitymitgliedschaft erforderlich',
                _membershipRequired,
                (v) => _change(() => _membershipRequired = v ?? false),
              ),
              _text(
                'capacity',
                'Platzkapazität (leer = unbegrenzt)',
                _capacity,
                max: 10,
                keyboard: TextInputType.number,
                help: 'Nur aktuelle Teilnahmezusagen belegen Plätze. Offene Anfragen reservieren keinen Platz.',
              ),
              _anchor(
                'content',
                EventContentFields(
                  key: ValueKey(_sessionValid),
                  initial: _content,
                  enabled: !_busy && _sessionValid,
                  showSchedule: false,
                  errors: _errors,
                  onChanged: (value) {
                    _content = value;
                    _remember();
                  },
                ),
              ),
              _section(
                'access',
                '4. Zugänglichkeit und Awareness',
                'Optional. Die Angaben sind für alle sichtbar, die das Event sehen dürfen. Unbekannt ist keine Aussage über vorhandene Ausstattung.',
              ),
              for (final e in accessFeatureLabels.entries)
                _choice(e.key, e.value, _features[e.key], {
                  'unknown': 'Unbekannt',
                  'yes': 'Ja',
                  'no': 'Nein',
                }, (v) => _change(() => _features[e.key] = v!)),
              for (final e in accessNoteLabels.entries)
                _text(
                  e.key,
                  e.value,
                  _accessNotes[e.key]!,
                  max: e.key == 'awareness_contact' ? 240 : 2000,
                  lines: 2,
                ),
              const LocalText(
                'Keine privaten Adressen oder persönlichen Notizen in diesen Angaben hinterlegen.',
              ),
              const SizedBox(height: 24),
              LocalText(
                _status == 'draft'
                    ? 'Speichern legt einen Entwurf auf dem Server ab.'
                    : _status == 'cancelled'
                    ? 'Speichern kennzeichnet das Event als abgesagt.'
                    : 'Speichern übernimmt die gewählte Veröffentlichung und Sichtbarkeit.',
              ),
              FilledButton(
                onPressed: _busy || !_sessionValid ? null : _save,
                child: LocalText(
                  _busy ? 'Wird gespeichert…' : 'Eventangaben speichern',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy || !_sessionValid ? null : _preview,
                child: const LocalText('Seite vorab ansehen'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy ? null : _leave,
                child: const LocalText('Zurück zur Verwaltung'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void _preview() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: accessAppBar(context, 'Entwurfsvorschau'),
        body: SingleChildScrollView(
          child: AccessPageFrame(
            width: AccessPageWidth.detail,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LocalText(
                  'Ungespeicherte Vorschau der Eventangaben. Die serverseitige Zielgruppenprüfung „Wer sieht was?“ steht nach dem Speichern zur Verfügung.',
                ),
                const SizedBox(height: 24),
                EventEditorialView(
                  event: {
                    'title': _title.text,
                    'status': _status,
                    'request_deadline_at': eventDate(_requestDeadline.text)
                        ?.toUtc()
                        .toIso8601String(),
                    'starts_at': _startsPublic
                        ? eventDate(_start.text)?.toUtc().toIso8601String()
                        : null,
                    'location': _locationPublic ? _location.text : '',
                    'event_content': {
                      ..._content,
                      'ends_at': _startsPublic
                          ? eventDate(_end.text)?.toUtc().toIso8601String()
                          : null,
                      'venue_name': _locationPublic
                          ? _content['venue_name']
                          : '',
                      if (_accessMode == 'semi_public') 'flyer_data': '',
                    },
                    'access_details': {
                      ..._features,
                      for (final e in _accessNotes.entries) e.key: e.value.text,
                    },
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

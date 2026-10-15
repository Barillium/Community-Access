import 'package:flutter/material.dart';

import 'app_language.dart';
import 'directory_api.dart';
import 'design_system.dart';
import 'access_api.dart';

const preferenceLabels = {
  'event_types': 'Veranstaltungspräferenzen',
  'music': 'Musikgeschmack',
  'favorites': 'Lieblingsveranstaltungen',
  'leisure': 'Freizeitbeschäftigungen',
};

class PreferenceFields extends StatefulWidget {
  final Map<String, dynamic> initial;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool enabled;
  const PreferenceFields({
    super.key,
    this.initial = const {},
    required this.onChanged,
    this.enabled = true,
  });
  @override
  State<PreferenceFields> createState() => _PreferenceFieldsState();
}

class _PreferenceFieldsState extends State<PreferenceFields> {
  late final fields = {
    for (final key in preferenceLabels.keys)
      key: TextEditingController(
        text: (widget.initial[key] as List? ?? []).join(', '),
      ),
  };
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LocalText(
        localText(
          context,
          'Optional: Hilf uns, passende Veranstaltungen zu zeigen. Du kannst die Angaben später ändern oder löschen. Keine sensiblen oder persönlichen Angaben eintragen.',
          'Optional: Help us show relevant events. You can edit or clear these preferences later. Do not enter sensitive or personal information.',
        ),
      ),
      for (final entry in fields.entries)
        Padding(
          padding: const EdgeInsets.only(top: AccessSpacing.s16),
          child: AccessField(
            decoration: InputDecoration(
              labelText: localText(context, preferenceLabels[entry.key]!),
              helperText: localText(
                context,
                'Mit Kommas trennen; höchstens 12 Einträge mit je 80 Zeichen.',
                'Separate with commas; up to 12 entries of 80 characters each.',
              ),
              helperMaxLines: 4,
            ),
            builder: (decoration) => TextFormField(
              controller: entry.value,
              enabled: widget.enabled,
              decoration: decoration,
              maxLength: 972,
              validator: (v) {
                final a = (v ?? '')
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty);
                return a.length > 12 || a.any((s) => s.length > 80)
                    ? localText(
                        context,
                        'Bitte höchstens 12 kurze Angaben eintragen.',
                        'Please enter at most 12 short preferences.',
                      )
                    : null;
              },
              onChanged: (_) => widget.onChanged({
                for (final e in fields.entries)
                  e.key: e.value.text
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toSet()
                      .toList(),
              }),
            ),
          ),
        ),
    ],
  );
}

class GuestPreferencesPage extends StatefulWidget {
  final DirectoryApi api;
  final bool onboarding;
  const GuestPreferencesPage({
    super.key,
    required this.api,
    this.onboarding = false,
  });
  @override
  State<GuestPreferencesPage> createState() => _GuestPreferencesPageState();
}

class _GuestPreferencesPageState extends State<GuestPreferencesPage> {
  final form = GlobalKey<FormState>();
  Map<String, dynamic>? preferences;
  String? notice;
  List<Map<String, dynamic>> visits = [];
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  int revision = 0;
  bool loading = false;

  @override
  void didUpdateWidget(GuestPreferencesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      revision++;
      preferences = null;
      visits = [];
      notice = null;
      busy = loading = false;
      load();
    }
  }

  @override
  void dispose() {
    revision++;
    super.dispose();
  }

  void fail(Object error, String fallback) {
    if (error is ApiFailure && (error.unauthenticated || error.accessDenied)) {
      preferences = null;
      visits = [];
    }
    notice = error is ApiFailure ? error.message : fallback;
  }

  Future<void> load() async {
    if (busy || loading) return;
    final current = ++revision;
    final api = widget.api;
    setState(() {
      loading = true;
      notice = null;
    });
    try {
      final r = await api.directory('preferences');
      if (mounted && current == revision) {
        setState(() {
          preferences = Map<String, dynamic>.from(
            r['preferences'] as Map? ?? {},
          );
          visits = (r['visited_organizers'] as List? ?? [])
              .cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      if (mounted && current == revision) {
        setState(() {
          preferences = null;
          visits = [];
          fail(e, 'Die Präferenzen konnten nicht geladen werden.');
        });
      }
    } finally {
      if (mounted && current == revision) setState(() => loading = false);
    }
  }

  Future<void> write(
    String path,
    Map<String, dynamic> body,
    VoidCallback onSuccess,
  ) async {
    if (busy || loading) return;
    final current = revision;
    final api = widget.api;
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      await api.directory(path, body: body);
      if (mounted && current == revision) onSuccess();
    } catch (e) {
      if (mounted && current == revision) {
        setState(
          () => fail(
            e,
            'Die Aktion konnte nicht abgeschlossen werden. Bitte prüfe den aktuellen Stand.',
          ),
        );
      }
    } finally {
      if (mounted && current == revision) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (preferences == null || form.currentState?.validate() != true) return;
    await write('preferences', Map<String, dynamic>.from(preferences!), () {
      if (widget.onboarding) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => notice = 'Präferenzen gespeichert.');
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: accessAppBar(context, 'Meine Präferenzen'),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        title: 'Meine Präferenzen',
        width: AccessPageWidth.form,
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (loading || busy) const LinearProgressIndicator(),
              if (notice != null)
                Semantics(liveRegion: true, child: LocalText(notice!)),
              if (preferences == null && !loading)
                TextButton(
                  onPressed: busy ? null : load,
                  child: const LocalText('Erneut versuchen'),
                )
              else if (preferences != null) ...[
                if (widget.onboarding)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => write(
                            'preferences',
                            {},
                            () => Navigator.of(context).pop(true),
                          ),
                    child: LocalText(
                      localText(
                        context,
                        'Weiter ohne Präferenzen',
                        'Continue without preferences',
                      ),
                    ),
                  ),
                if (visits.isNotEmpty) ...[
                  LocalText(
                    localText(
                      context,
                      'Bereits besuchte Veranstalter',
                      'Organizers you have visited',
                    ),
                  ),
                  for (final v in visits)
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          (v['name'] as String? ?? '').isEmpty
                              ? localText(
                                  context,
                                  'Nicht mehr sichtbarer Veranstalter',
                                  'Organizer no longer visible',
                                )
                              : v['name'] as String,
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () =>
                                    write('forget-visit', {'id': v['id']}, () {
                                      setState(
                                        () => visits.removeWhere(
                                          (r) => r['id'] == v['id'],
                                        ),
                                      );
                                    }),
                          child: LocalText(
                            localText(
                              context,
                              'Besuchssignal löschen',
                              'Delete attendance preference',
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
                PreferenceFields(
                  key: ValueKey(revision),
                  initial: preferences!,
                  enabled: !busy,
                  onChanged: (v) => preferences = v,
                ),
                const SizedBox(height: AccessSpacing.s24),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: const LocalText('Präferenzen speichern'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

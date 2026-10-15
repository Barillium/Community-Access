import 'product_scope.dart';
import 'event_form_editor.dart';
import 'organizer_members_page.dart';
import 'access_flow_api.dart';
import 'app_language.dart';

import 'package:flutter/material.dart';

import 'directory_api.dart';
import 'ticketing_api.dart';
import 'ticketing_pages.dart';
import 'access_api.dart';
import 'directory_pages.dart';
import 'design_system.dart';
import 'program_management_page.dart';
import 'visibility_preview_page.dart';
import 'event_directory_editor.dart';
import 'event_management_list.dart';
export 'event_directory_editor.dart';

class OrganizerManagementPage extends StatefulWidget {
  final DirectoryApi api;
  final String? initialProfileId;
  const OrganizerManagementPage({
    super.key,
    required this.api,
    this.initialProfileId,
  });
  @override
  State<OrganizerManagementPage> createState() =>
      _OrganizerManagementPageState();
}

class _Question {
  final String key;
  final TextEditingController label;
  bool required;
  _Question(this.key, String text, this.required)
    : label = TextEditingController(text: text);
}

class _OrganizerManagementPageState extends State<OrganizerManagementPage> {
  final _name = TextEditingController(),
      _description = TextEditingController(),
      _recipient = TextEditingController();
  final List<_Question> _questions = [];
  final Set<String> _communities = {};
  Map<String, dynamic>? _data;
  bool _public = false,
      _application = false,
      _form = false,
      _link = false,
      _busy = false;
  String? _notice, _issuedLink;
  int? _version;
  String? _profileId;
  bool _creating = false;
  int _generation = 0;
  bool? _awarenessConcept, _awarenessTeam;
  @override
  void initState() {
    super.initState();
    _profileId = widget.initialProfileId;
    _load();
  }

  @override
  void didUpdateWidget(covariant OrganizerManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api ||
        oldWidget.initialProfileId != widget.initialProfileId) {
      _generation++;
      _clearPrivateState();
      _profileId = widget.initialProfileId;
      _load();
    }
  }

  void _clearPrivateState() {
    _data = null;
    _issuedLink = null;
    _profileId = null;
    _version = null;
    _creating = false;
    _awarenessConcept = null;
    _awarenessTeam = null;
    _name.clear();
    _description.clear();
    _recipient.clear();
    _communities.clear();
    _public = _application = _form = _link = false;
    for (final q in _questions) {
      q.label.dispose();
    }
    _questions.clear();
  }

  @override
  void dispose() {
    _generation++;
    _name.dispose();
    _description.dispose();
    _recipient.dispose();
    for (final q in _questions) {
      q.label.dispose();
    }
    super.dispose();
  }

  Future<bool> _load({bool replace = true}) async {
    if (!mounted) return false;
    final epoch = ++_generation;
    setState(() {
      _busy = true;
      _notice = null;
      _data = null;
    });
    try {
      final data = await widget.api.directory(
        'manage',
        query: _profileId == null ? null : {'profile_id': _profileId!},
      );
      if (!mounted || epoch != _generation) return false;
      if (replace) {
        final p = data['profile'] as Map<String, dynamic>?;
        _profileId = p?['id'] as String?;
        _creating = false;
        _name.text = p?['name'] as String? ?? '';
        _description.text = p?['description'] as String? ?? '';
        _awarenessConcept = p?['awareness_concept'] as bool?;
        _awarenessTeam = p?['awareness_team'] as bool?;
        _public = p?['is_public'] == true;
        _application = p?['allow_application'] == true;
        _form = p?['allow_form'] == true;
        _link = p?['allow_link'] == true;
        _version = p?['version'] as int?;
        _communities.clear();
        _communities.addAll(
          (p?['community_ids'] as List? ?? []).cast<String>(),
        );
        for (final q in _questions) {
          q.label.dispose();
        }
        _questions.clear();
        for (final f in p?['form'] as List? ?? []) {
          _questions.add(
            _Question(
              f['key'] as String,
              f['label'] as String,
              f['required'] == true,
            ),
          );
        }
      }
      setState(() => _data = data);
      return true;
    } catch (e) {
      if (mounted && epoch == _generation) {
        setState(() {
          _data = null;
          if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
            _clearPrivateState();
          }
          _notice = e is ApiFailure
              ? e.message
              : 'Die Verwaltung konnte nicht geladen werden.';
        });
      }
      return false;
    } finally {
      if (mounted && epoch == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _run(
    Future<void> Function() action,
    String success, {
    bool replace = false,
  }) async {
    if (!mounted || _busy) return;
    final epoch = _generation;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await action();
      if (!mounted || epoch != _generation) return;
      if (await _load(replace: replace)) {
        if (mounted) setState(() => _notice = success);
      }
    } catch (e) {
      if (mounted &&
          epoch == _generation &&
          e is ApiFailure &&
          (e.unauthenticated || e.accessDenied)) {
        setState(_clearPrivateState);
      }
      if (mounted && epoch == _generation) {
        setState(
          () => _notice = e is ApiFailure
              ? e.message
              : 'Die Aktion konnte nicht abgeschlossen werden.',
        );
      }
    } finally {
      if (mounted && epoch == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(
    () async {
      final epoch = _generation;
      final saved = await widget.api.directory(
        'manage/profile',
        body: {
          if (_profileId != null) 'id': _profileId,
          if (_creating) 'create': true,
          'name': _name.text.trim(),
          'description': _description.text.trim(),
          'awareness_concept': _awarenessConcept,
          'awareness_team': _awarenessTeam,
          'is_public': _public,
          'allow_application': _application,
          'allow_form': _form,
          'allow_link': _link,
          'version': _version,
          'community_ids': _communities.toList(),
          'form': [
            for (final q in _questions)
              {
                'key': q.key,
                'label': q.label.text.trim(),
                'required': q.required,
              },
          ],
        },
      );
      if (!mounted || epoch != _generation) return;
      _profileId = saved['id'] as String? ?? _profileId;
      _creating = false;
    },
    'Veranstalterprofil gespeichert.',
    replace: true,
  );
  Widget _box(
    List<Widget> children, {
    AccessPageWidth width = AccessPageWidth.reading,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AccessSpacing.s24),
    child: AccessContent(
      width: width,
      child: AccessSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
  Widget _title(String title) => Semantics(
    headingLevel: 2,
    child: LocalText(
      title,
      style: const TextStyle(
        fontSize: AccessTypography.sectionTitleSize,
        fontWeight: FontWeight.w600,
        fontVariations: [FontVariation('wdth', 100)],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: accessAppBar(context, 'Gastgeberverwaltung'),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        width: AccessPageWidth.content,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            directoryHeading('Deine Veranstalterprofile.'),
            const SizedBox(height: AccessSpacing.s24),
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_notice != null) directoryNotice(_notice!),
            if (_data != null) ...[
              if ((_data!['events'] as List? ?? []).any(
                (e) =>
                    (e['status'] == 'published' ||
                        e['status'] == 'cancelled') &&
                    (e['event_content'] as Map? ?? {})['ends_at'] == null,
              ))
                directoryNotice(
                  localText(
                    context,
                    'Bei vorhandenen Veranstaltungen fehlt eine Endzeit. Ergänze sie, damit die Löschfrist von exakt 168 Stunden nach Veranstaltungsende berechnet werden kann.',
                    'Some existing events have no end time. Add one so the deletion deadline of exactly 168 hours after the event end can be calculated.',
                  ),
                ),
              _box([
                if ((_data!['profiles'] as List? ?? []).isNotEmpty)
                  AccessField(
                    decoration: const InputDecoration(
                      labelText: 'Veranstalterprofil auswählen',
                    ),
                    trailingWidth: AccessSpacing.s40,
                    builder: (decoration) => DropdownButtonFormField<String>(
                      key: ValueKey('profile:$_profileId'),
                      initialValue: _profileId,
                      isExpanded: true,
                      itemHeight: null,
                      decoration: decoration,
                      items: [
                        for (final p in _data!['profiles'] as List)
                          DropdownMenuItem(
                            value: p['id'] as String,
                            child: AccessOptionText(p['name'] as String),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (id) {
                              setState(() {
                                _profileId = id;
                                _issuedLink = null;
                              });
                              _load();
                            },
                    ),
                  ),
                const SizedBox(height: AccessSpacing.s16),
                OutlinedButton(
                  onPressed: _busy || _data!['can_create_profile'] == false
                      ? null
                      : _newProfile,
                  child: const LocalText('Weiteres Veranstalterprofil anlegen'),
                ),
                if (_profileId != null && widget.api is AccessFlowApi)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => OrganizerMembersPage(
                                  api: widget.api as AccessFlowApi,
                                  profileId: _profileId,
                                ),
                              ),
                            );
                            if (mounted) await _load(replace: false);
                          },
                    child: const LocalText('Gemeinsam verwalten'),
                  ),
                const SizedBox(height: AccessSpacing.s12),
                const LocalText(
                  'Ein Profilwechsel lädt den gespeicherten Stand. Jedes Profil hat eigene Zugänge und Veranstaltungen.',
                ),
                if (_creating)
                  const LocalText(
                    'Neues Profil: Erst speichern, dann Veranstaltungen anlegen.',
                  ),
              ], width: AccessPageWidth.form),
              _box([
                AccessField(
                  decoration: const InputDecoration(labelText: 'Profilname'),
                  builder: (decoration) => TextField(
                    controller: _name,
                    enabled: !_busy,
                    maxLength: 120,
                    decoration: decoration,
                  ),
                ),
                const SizedBox(height: AccessSpacing.s16),
                AccessField(
                  decoration: const InputDecoration(
                    labelText: 'Profilbeschreibung',
                  ),
                  builder: (decoration) => TextField(
                    controller: _description,
                    enabled: !_busy,
                    minLines: 3,
                    maxLines: 8,
                    maxLength: 4000,
                    decoration: decoration,
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const LocalText('Profil öffentlich anzeigen'),
                  value: _public,
                  onChanged: _busy ? null : (v) => setState(() => _public = v!),
                ),
                const SizedBox(height: AccessSpacing.s16),
                for (final entry in {
                  'Awarenesskonzept vorhanden?': _awarenessConcept,
                  'Awarenessteam vorhanden?': _awarenessTeam,
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AccessSpacing.s16),
                    child: AccessField(
                      decoration: InputDecoration(
                        labelText: localText(context, entry.key),
                      ),
                      builder: (d) => DropdownButtonFormField<bool>(
                        key: ValueKey('$entry'),
                        initialValue: entry.value,
                        isExpanded: true,
                        decoration: d,
                        items: [
                          DropdownMenuItem(value: true, child: LocalText('Ja')),
                          DropdownMenuItem(
                            value: false,
                            child: LocalText('Nein'),
                          ),
                        ],
                        onChanged: _busy
                            ? null
                            : (v) => setState(() {
                                if (entry.key ==
                                    'Awarenesskonzept vorhanden?') {
                                  _awarenessConcept = v;
                                } else {
                                  _awarenessTeam = v;
                                }
                              }),
                      ),
                    ),
                  ),
                if (_awarenessConcept == null || _awarenessTeam == null)
                  LocalText(
                    localText(
                      context,
                      'Die beiden Awarenessangaben sind verpflichtend. Ein Nein ist eine gültige Angabe.',
                      'Both awareness answers are required. No is a valid answer.',
                    ),
                  ),
                _title('Deine Communities'),
                for (final c in _data!['communities'] as List)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: LocalText(c['name'] as String),
                    value: _communities.contains(c['id']),
                    onChanged: _busy
                        ? null
                        : (v) => setState(() {
                            if (v!) {
                              _communities.add(c['id'] as String);
                            } else {
                              _communities.remove(c['id']);
                            }
                          }),
                  ),
                directoryNotice(
                  'Mindestens eine Community auswählen. Private Communitynamen bleiben für andere verborgen.',
                ),
                if (ProductScope.extended) ...[
                  _title('Zugang zu deinem privaten Profil'),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const LocalText('Bewerbung mit manueller Freigabe'),
                    value: _application,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _application = v!),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const LocalText(
                      'Eigenes Formular mit manueller Freigabe',
                    ),
                    value: _form,
                    onChanged: _busy ? null : (v) => setState(() => _form = v!),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const LocalText('Persönlicher Zugangslink'),
                    value: _link,
                    onChanged: _busy ? null : (v) => setState(() => _link = v!),
                  ),
                  directoryNotice(
                    'Diese Freigaben betreffen ausschließlich dein Profil, keine Mitgliedschaft oder Eventzusage.',
                  ),
                ],
                if (ProductScope.extended && _form) ...[
                  _title('Deine Formularfragen'),
                  const SizedBox(height: AccessSpacing.s16),
                  for (final q in _questions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AccessSpacing.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AccessField(
                            decoration: InputDecoration(
                              labelText: localText(context, 'Formularfrage'),
                              errorText: questionProblem(q.label.text),
                              errorMaxLines: 8,
                            ),
                            builder: (decoration) => TextField(
                              controller: q.label,
                              onChanged: (_) => setState(() {}),
                              enabled: !_busy,
                              maxLength: 180,
                              decoration: decoration,
                            ),
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const LocalText('Pflichtfeld'),
                            value: q.required,
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => q.required = v!),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    setState(() => _questions.remove(q));
                                    q.label.dispose();
                                  },
                            child: const LocalText('Frage entfernen'),
                          ),
                        ],
                      ),
                    ),
                  OutlinedButton(
                    onPressed: _busy || _questions.length >= 12
                        ? null
                        : () => setState(() {
                            int index = 0;
                            while (_questions.any(
                              (q) => q.key == 'field_$index',
                            )) {
                              index++;
                            }
                            _questions.add(
                              _Question(
                                'field_$index',
                                safeQuestions.first,
                                true,
                              ),
                            );
                          }),
                    child: const LocalText('Frage hinzufügen'),
                  ),
                ],
                const SizedBox(height: AccessSpacing.s24),
                FilledButton(
                  onPressed:
                      _busy ||
                          _awarenessConcept == null ||
                          _awarenessTeam == null ||
                          _questions.any(
                            (q) => questionProblem(q.label.text) != null,
                          )
                      ? null
                      : _save,
                  child: const LocalText('Profil speichern'),
                ),
                if (_data!['profile'] != null) ...[
                  const SizedBox(height: AccessSpacing.s24),
                  const LocalText('Profiladresse zum Teilen'),
                  const SizedBox(height: AccessSpacing.s8),
                  Semantics(
                    label:
                        '${localText(context, 'Profiladresse')}: ${_profileAddress(_data!['profile']['id'] as String)}',
                    excludeSemantics: true,
                    child: SelectableText(
                      _profileAddress(_data!['profile']['id'] as String),
                    ),
                  ),
                ],
              ], width: AccessPageWidth.form),
              if (_profileId != null)
                _box([
                  if (_data!['ticketing_available'] == true &&
                      widget.api is TicketingApi)
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              await Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => TicketingManagementPage(
                                    api: widget.api as TicketingApi,
                                    profileId: _profileId!,
                                    events: (_data!['events'] as List)
                                        .cast<Map<String, dynamic>>(),
                                  ),
                                ),
                              );
                              if (mounted) await _load();
                            },
                      child: const LocalText(
                        'Tickets und Erstattungen verwalten',
                      ),
                    ),
                  _title(localText(context, 'Formulare verwalten')),
                  for (final f in _data!['forms'] as List? ?? [])
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () =>
                                _editForm(Map<String, dynamic>.from(f as Map)),
                      child: LocalText(f['title'] as String),
                    ),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _editForm(null),
                    child: const LocalText('Formular erstellen'),
                  ),
                  const SizedBox(height: AccessSpacing.s24),
                  _title(localText(context, 'Anfragen zu Veranstaltungen')),
                  for (final r in _data!['event_requests'] as List? ?? [])
                    Padding(
                      padding: const EdgeInsets.only(top: AccessSpacing.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LocalText('${r['title']} · ${r['guest']}'),
                          Text(
                            attendanceStatus(context, r['status'] as String),
                          ),
                          for (final f in r['form_snapshot'] as List? ?? [])
                            LocalText(
                              '${f['label']}: ${(r['answers'] as Map? ?? {})[f['key']] ?? ''}',
                            ),
                          Wrap(
                            spacing: AccessSpacing.s12,
                            children: [
                              for (final action
                                  in (r['status'] == 'pending'
                                          ? {
                                              'approved':
                                                  r['ticket_mode'] != null &&
                                                      r['ticket_mode'] != 'none'
                                                  ? 'Ticketkauf freigeben'
                                                  : 'Teilnahme zusagen',
                                              'rejected': 'Ablehnen',
                                            }
                                          : [
                                              'approved',
                                              'purchase_eligible',
                                            ].contains(r['status'])
                                          ? {
                                              'revoked':
                                                  'Teilnahmezusage widerrufen',
                                            }
                                          : <String, String>{})
                                      .entries)
                                OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _run(() async {
                                          await widget.api.directory(
                                            'manage/interest',
                                            body: {
                                              'event_id': r['event_id'],
                                              'user_id': r['user_id'],
                                              'version': r['version'],
                                              'status': action.key,
                                            },
                                          );
                                        }, 'Anfrage bearbeitet.'),
                                  child: LocalText(action.value),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ], width: AccessPageWidth.form),
              if (ProductScope.extended)
                _box([
                  _title('Profilanfragen und Freigaben'),
                  const SizedBox(height: AccessSpacing.s20),
                  if ((_data!['requests'] as List).isEmpty)
                    const LocalText('Noch keine Profilanfragen.'),
                  for (final r in _data!['requests'] as List)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LocalText(
                          r['applicant'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        LocalText(switch (r['status']) {
                          'pending' => 'Wartet auf Freigabe',
                          'approved' => 'Profilzugriff freigegeben',
                          'rejected' => 'Abgelehnt',
                          'withdrawn' => 'Zurückgezogen',
                          _ => 'Zugriff entzogen',
                        }),
                        for (final f in r['form_snapshot'] as List)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AccessSpacing.s12,
                            ),
                            child: LocalText(
                              '${f['label']}\n${r['answers'][f['key']] ?? 'Antwort entfernt'}',
                            ),
                          ),
                        const SizedBox(height: AccessSpacing.s16),
                        Wrap(
                          spacing: AccessSpacing.s12,
                          runSpacing: AccessSpacing.s8,
                          children: [
                            if (r['status'] == 'pending')
                              for (final decision in {
                                'approved': 'Freigeben',
                                'rejected': 'Ablehnen',
                              }.entries)
                                OutlinedButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _run(() async {
                                          await widget.api.directory(
                                            'requests/${r['id']}/decide',
                                            body: {'status': decision.key},
                                          );
                                        }, 'Anfrage bearbeitet.'),
                                  child: LocalText(decision.value),
                                ),
                            if ([
                              'approved',
                              'purchase_eligible',
                            ].contains(r['status']))
                              OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run(() async {
                                        await widget.api.directory(
                                          'requests/${r['id']}/decide',
                                          body: {'status': 'revoked'},
                                        );
                                      }, 'Profilzugriff entzogen.'),
                                child: const LocalText('Zugriff entziehen'),
                              ),
                          ],
                        ),
                        const SizedBox(height: AccessSpacing.s16),
                        const Divider(),
                        const SizedBox(height: AccessSpacing.s16),
                      ],
                    ),
                ]),
              if (ProductScope.extended &&
                  _data!['profile']?['allow_link'] == true)
                _box([
                  _title('Persönlicher Zugangslink'),
                  const SizedBox(height: AccessSpacing.s16),
                  const LocalText(
                    'Für ein bestehendes Konto mit bestätigter E-Mail. Einmal nutzbar, sieben Tage gültig.',
                  ),
                  const SizedBox(height: AccessSpacing.s16),
                  AccessField(
                    decoration: const InputDecoration(
                      labelText: 'E-Mail des Empfängers',
                    ),
                    builder: (decoration) => TextField(
                      controller: _recipient,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      decoration: decoration,
                    ),
                  ),
                  const SizedBox(height: AccessSpacing.s16),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            final epoch = _generation;
                            final result = await widget.api.directory(
                              'manage/link',
                              body: {
                                'email': _recipient.text.trim(),
                                'profile_id': _profileId,
                              },
                            );
                            if (!mounted || epoch != _generation) return;
                            _issuedLink = result['url'] as String;
                            _recipient.clear();
                          }, 'Zugangslink erstellt. Teile ihn persönlich.'),
                    child: const LocalText('Link erstellen'),
                  ),
                  if (_issuedLink != null) ...[
                    const SizedBox(height: AccessSpacing.s16),
                    SelectableText(_issuedLink!),
                  ],
                  for (final link in _data!['links'] as List)
                    Padding(
                      padding: const EdgeInsets.only(top: AccessSpacing.s16),
                      child: Wrap(
                        spacing: AccessSpacing.s12,
                        runSpacing: AccessSpacing.s8,
                        children: [
                          LocalText(
                            link['revoked'] == true
                                ? 'Link widerrufen'
                                : link['used_at'] != null
                                ? 'Link eingelöst'
                                : 'Gültig bis ${link['expires_at']}',
                          ),
                          if (link['revoked'] != true &&
                              link['used_at'] == null)
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                      await widget.api.directory(
                                        'links/${link['id']}/revoke',
                                        body: {},
                                      );
                                      _issuedLink = null;
                                    }, 'Link widerrufen.'),
                              child: const LocalText('Link widerrufen'),
                            ),
                        ],
                      ),
                    ),
                ], width: AccessPageWidth.form),
              _box([
                _title('Event- und Ortsangaben'),
                if (_data!['profile'] != null)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => ProgramManagementPage(
                                  api: widget.api,
                                  profileId: _profileId,
                                ),
                              ),
                            );
                            if (mounted) await _load(replace: false);
                          },
                    child: const LocalText(
                      ProductScope.extended
                          ? 'Reihen, Events und Gästekreise verwalten'
                          : 'Events und Einladungen verwalten',
                    ),
                  ),
                const SizedBox(height: AccessSpacing.s16),
                const LocalText(
                  'Das öffentliche Ortsverzeichnis übernimmt nur freigegebene Orte frei sichtbarer Events in öffentlichen Communities. Geschützte Reihen und Events erscheinen dort nicht.',
                ),
                const SizedBox(height: AccessSpacing.s16),
                OutlinedButton(
                  onPressed: _busy || _data!['profile'] == null
                      ? null
                      : () => _event(null),
                  child: const LocalText('Eventangaben hinzufügen'),
                ),
                EventManagementList(
                  events: (_data!['events'] as List)
                      .cast<Map<String, dynamic>>(),
                  busy: _busy,
                  profilePublic: _data!['profile']?['is_public'] == true,
                  series: (_data!['series'] as List? ?? [])
                      .cast<Map<String, dynamic>>(),
                  onEdit: (e) => _event(e),
                  onDuplicate: (e) => _event(
                    null,
                    initialDraft: eventCopy(e),
                    draftKey: 'copy:${e['id']}',
                  ),
                  onNext: (e) async {
                    final draft = await nextEventDraft(context, e);
                    if (mounted && draft != null) {
                      await _event(
                        null,
                        initialDraft: draft,
                        draftKey: 'next:${e['id']}:${draft['starts_at']}',
                      );
                    }
                  },
                  onPreview: (e) => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => VisibilityPreviewPage(
                        api: widget.api,
                        eventId: e['id'] as String,
                      ),
                    ),
                  ),
                ),
              ]),
            ],
            OutlinedButton(
              onPressed: _busy ? null : () => _load(),
              child: const LocalText('Verwaltung neu laden'),
            ),
          ],
        ),
      ),
    ),
  );
  String _profileAddress(String id) {
    final base = Uri.base;
    if (base.scheme == 'http' || base.scheme == 'https') {
      return base.replace(query: '', fragment: 'organizer=$id').toString();
    }
    return '#organizer=$id';
  }

  void _newProfile() {
    setState(() {
      _profileId = null;
      _creating = true;
      _awarenessConcept = null;
      _awarenessTeam = null;
      _version = null;
      _issuedLink = null;
      _name.clear();
      _description.clear();
      _recipient.clear();
      _communities.clear();
      _public = false;
      _application = false;
      _form = false;
      _link = false;
      for (final q in _questions) {
        q.label.dispose();
      }
      _questions.clear();
      _data = {
        ..._data!,
        'profile': null,
        'events': [],
        'series': [],
        'grants': [],
        'requests': [],
        'links': [],
      };
      _notice = null;
    });
  }

  Future<void> _event(
    Map<String, dynamic>? event, {
    Map<String, dynamic>? initialDraft,
    String? draftKey,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EventDirectoryEditor(
          api: widget.api,
          communities: (_data!['communities'] as List)
              .cast<Map<String, dynamic>>()
              .where(
                (c) => (_data!['profile']?['community_ids'] as List? ?? [])
                    .contains(c['id']),
              )
              .toList(),
          event: event,
          initialDraft: initialDraft,
          draftKey: draftKey,
          forms: (_data!['forms'] as List? ?? []).cast<Map<String, dynamic>>(),
          profileId: _profileId,
          profilePublic: _data!['profile']?['is_public'] == true,
          series: (_data!['series'] as List? ?? [])
              .cast<Map<String, dynamic>>(),
        ),
      ),
    );
    if (mounted) await _load(replace: false);
  }

  Future<void> _editForm(Map<String, dynamic>? form) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EventFormEditor(
          api: widget.api,
          profileId: _profileId!,
          form: form,
        ),
      ),
    );
    if (mounted) await _load(replace: false);
  }
}

import 'product_scope.dart';

import 'package:flutter/material.dart';

import 'access_api.dart';
import 'app_language.dart';
import 'directory_api.dart';
import 'directory_pages.dart';
import 'design_system.dart';
import 'organizer_management_page.dart';
import 'visibility_preview_page.dart';
import 'event_management_list.dart';

class ProgramManagementPage extends StatefulWidget {
  final DirectoryApi api;
  final String? profileId;
  const ProgramManagementPage({super.key, required this.api, this.profileId});
  @override
  State<ProgramManagementPage> createState() => _ProgramManagementPageState();
}

class _ProgramManagementPageState extends State<ProgramManagementPage> {
  final _email = TextEditingController();
  Map<String, dynamic>? _data;
  String? _scope, _notice;
  bool _busy = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProgramManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api ||
        oldWidget.profileId != widget.profileId) {
      _generation++;
      _data = null;
      _scope = null;
      _notice = null;
      _email.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    _email.dispose();
    super.dispose();
  }

  Future<bool> _load() async {
    if (!mounted) return false;
    final epoch = ++_generation;
    setState(() {
      _busy = true;
      _data = null;
      _notice = null;
    });
    try {
      final data = await widget.api.directory(
        'manage',
        query: widget.profileId == null
            ? null
            : {'profile_id': widget.profileId!},
      );
      if (!mounted || epoch != _generation) return false;
      setState(() {
        _data = data;
        final scopes = {
          for (final s in data['series'] as List? ?? []) 'series:${s['id']}',
          for (final e in data['events'] as List? ?? []) 'event:${e['id']}',
        };
        if (!scopes.contains(_scope)) _scope = null;
      });
      return true;
    } catch (e) {
      if (mounted && epoch == _generation) {
        setState(() {
          _notice = e is ApiFailure
              ? e.message
              : 'Die Verwaltung konnte nicht geladen werden.';
          if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
            _scope = null;
            _email.clear();
          }
        });
      }
      return false;
    } finally {
      if (mounted && epoch == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _run(
    Map<String, dynamic> body,
    String route,
    String notice,
  ) async {
    if (!mounted || _busy) return;
    final epoch = _generation;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await widget.api.directory(route, body: body);
      if (!mounted || epoch != _generation) return;
      if (await _load()) {
        if (mounted) setState(() => _notice = notice);
      }
    } catch (e) {
      if (mounted && epoch == _generation) {
        setState(() {
          _notice = e is ApiFailure
              ? e.message
              : 'Die Änderung konnte nicht gespeichert werden.';
          if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
            _data = null;
            _scope = null;
            _email.clear();
          }
        });
      }
    } finally {
      if (mounted && epoch == _generation) setState(() => _busy = false);
    }
  }

  List<Map<String, dynamic>> get _communities =>
      ((_data?['communities'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .where(
            (c) => ((_data?['profile']?['community_ids'] as List?) ?? [])
                .contains(c['id']),
          )
          .toList();
  List<Map<String, dynamic>> get _series =>
      ((_data?['series'] as List?) ?? []).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get _events =>
      ((_data?['events'] as List?) ?? []).cast<Map<String, dynamic>>();
  Map<String, dynamic> _grantBody() {
    final kind = _scope!.split(':').first,
        id = _scope!.split(':').last,
        email = _email.text.trim();
    final previous = (_data!['grants'] as List? ?? [])
        .where(
          (g) =>
              g['kind'] == kind &&
              g['scope_id'] == id &&
              (g['email'] as String? ?? '').toLowerCase() ==
                  email.toLowerCase(),
        )
        .firstOrNull;
    return {
      'kind': kind,
      'id': id,
      'email': email,
      if (previous != null) 'version': previous['version'],
    };
  }

  Future<void> _editSeries([Map<String, dynamic>? series]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SeriesEditor(
          api: widget.api,
          communities: _communities,
          series: series,
          profileId: _data?['profile']?['id'] as String?,
          profilePublic: _data?['profile']?['is_public'] == true,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _editEvent(
    Map<String, dynamic>? event, {
    Map<String, dynamic>? initialDraft,
    String? draftKey,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EventDirectoryEditor(
          api: widget.api,
          communities: _communities,
          series: _series,
          event: event,
          initialDraft: initialDraft,
          draftKey: draftKey,
          forms: (_data?['forms'] as List? ?? []).cast<Map<String, dynamic>>(),
          profileId: _data?['profile']?['id'] as String?,
          profilePublic: _data?['profile']?['is_public'] == true,
        ),
      ),
    );
    if (mounted) await _load();
  }

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
  Widget _title(String text) => Semantics(
    headingLevel: 2,
    child: LocalText(
      text,
      style: const TextStyle(
        fontSize: AccessTypography.sectionTitleSize,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: accessAppBar(
      context,
      ProductScope.extended
          ? 'Reihen, Events und Gästekreise'
          : 'Events und Einladungen',
    ),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        width: AccessPageWidth.content,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_notice != null) directoryNotice(_notice!),
            if (_data != null && _data!['profile'] == null)
              const LocalText(
                'Bitte speichere zuerst dein Veranstalterprofil.',
              ),
            if (_data != null && _data!['profile'] != null) ...[
              if (ProductScope.extended)
                _box([
                  _title('Veranstaltungsreihen'),
                  const SizedBox(height: AccessSpacing.s12),
                  const LocalText(
                    'Nicht frei sichtbare Reihen und Events erscheinen nur im freigegebenen Gästekreis. Außenstehende sehen auch keinen Hinweis darauf. Eine Reihenfreigabe umfasst alle veröffentlichten und künftigen Events der Reihe. Profilfreigaben sind davon unabhängig.',
                  ),
                  const SizedBox(height: AccessSpacing.s16),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _editSeries(),
                    child: const LocalText('Reihe anlegen'),
                  ),
                  for (final s in _series)
                    Padding(
                      padding: const EdgeInsets.only(top: AccessSpacing.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s['title'] as String),
                          LocalText(
                            s['is_public'] == true
                                ? 'Frei sichtbar'
                                : 'Nur freigegebener Gästekreis',
                          ),
                          TextButton(
                            onPressed: _busy ? null : () => _editSeries(s),
                            child: const LocalText('Reihe bearbeiten'),
                          ),
                        ],
                      ),
                    ),
                ]),
              _box([
                _title('Events'),
                const SizedBox(height: AccessSpacing.s16),
                LocalText(
                  ProductScope.extended
                      ? 'Eine geschützte Reihe bleibt geschützt, auch wenn du ein Event als frei sichtbar markierst. Eine einzelne Eventfreigabe öffnet nur dieses Event.'
                      : 'Eine persönliche Eventeinladung öffnet nur dieses Event. Bei kostenpflichtigen Events erlaubt sie den Kauf; erst bestätigte Zahlung begründet die Teilnahme.',
                ),
                const SizedBox(height: AccessSpacing.s16),
                OutlinedButton(
                  onPressed: _busy ? null : () => _editEvent(null),
                  child: const LocalText('Event anlegen'),
                ),
                EventManagementList(
                  events: _events,
                  busy: _busy,
                  profilePublic: _data!['profile']?['is_public'] == true,
                  series: (_data!['series'] as List? ?? [])
                      .cast<Map<String, dynamic>>(),
                  onEdit: (e) => _editEvent(e),
                  onDuplicate: (e) => _editEvent(
                    null,
                    initialDraft: eventCopy(e),
                    draftKey: 'copy:${e['id']}',
                  ),
                  onNext: (e) async {
                    final draft = await nextEventDraft(context, e);
                    if (mounted && draft != null) {
                      await _editEvent(
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
              _box([
                _title('Gästekreis freigeben'),
                const SizedBox(height: AccessSpacing.s12),
                const LocalText(
                  'Freigabe zur Sichtbarkeit für ein bestehendes Konto mit bestätigter E-Mail. Dies bestätigt keine Eventteilnahme.',
                ),
                const SizedBox(height: AccessSpacing.s16),
                AccessField(
                  decoration: const InputDecoration(
                    labelText: ProductScope.extended
                        ? 'Reihe oder einzelnes Event'
                        : 'Einzelnes Event',
                  ),
                  trailingWidth: AccessSpacing.s40,
                  builder: (decoration) => DropdownButtonFormField<String>(
                    key: ValueKey(_scope),
                    initialValue: _scope,
                    isExpanded: true,
                    itemHeight: null,
                    decoration: decoration,
                    items: [
                      for (final s
                          in ProductScope.extended
                              ? _series
                              : <Map<String, dynamic>>[])
                        DropdownMenuItem(
                          value: 'series:${s['id']}',
                          child: AccessOptionText(
                            '${localText(context, 'Reihe')}: ${s['title']}',
                          ),
                        ),
                      for (final e in _events)
                        DropdownMenuItem(
                          value: 'event:${e['id']}',
                          child: AccessOptionText(
                            '${localText(context, 'Event')}: ${e['title']}',
                          ),
                        ),
                    ],
                    onChanged: _busy ? null : (v) => setState(() => _scope = v),
                  ),
                ),
                const SizedBox(height: AccessSpacing.s16),
                AccessField(
                  decoration: const InputDecoration(
                    labelText: 'E-Mail des Gastkontos',
                  ),
                  builder: (decoration) => TextField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    maxLength: 255,
                    decoration: decoration,
                  ),
                ),
                const SizedBox(height: AccessSpacing.s16),
                FilledButton(
                  onPressed: _busy || _scope == null
                      ? null
                      : () => _run(
                          _grantBody(),
                          'manage/grant',
                          'Gästekreis erweitert.',
                        ),
                  child: const LocalText('Sichtbarkeit freigeben'),
                ),
              ], width: AccessPageWidth.form),
              _box([
                _title('Freigaben verwalten'),
                if ((_data!['grants'] as List? ?? []).isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: AccessSpacing.s16),
                    child: LocalText('Noch keine Reihen- oder Eventfreigaben.'),
                  ),
                for (final g in _data!['grants'] as List? ?? [])
                  Padding(
                    padding: const EdgeInsets.only(top: AccessSpacing.s20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${g['guest']} · ${g['title']}'),
                        Text(
                          '${localText(context, g['kind'] == 'series' ? 'Reihe' : 'Event')} · ${localText(context, g['active'] == true ? 'Freigegeben' : 'Entzogen')}',
                        ),
                        if (g['active'] == true)
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _run(
                                    {
                                      'kind': g['kind'],
                                      'id': g['id'],
                                      'version': g['version'],
                                    },
                                    'manage/revoke',
                                    'Sichtbarkeit entzogen.',
                                  ),
                            child: const LocalText('Sichtbarkeit entziehen'),
                          ),
                        if (g['active'] != true)
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _run(
                                    {
                                      'kind': g['kind'],
                                      'id': g['scope_id'],
                                      'email': g['email'],
                                      'version': g['version'],
                                    },
                                    'manage/grant',
                                    'Sichtbarkeit erneut freigegeben.',
                                  ),
                            child: const LocalText('Erneut freigeben'),
                          ),
                      ],
                    ),
                  ),
              ]),
            ],
            OutlinedButton(
              onPressed: _busy ? null : _load,
              child: const LocalText('Neu laden'),
            ),
          ],
        ),
      ),
    ),
  );
}

class SeriesEditor extends StatefulWidget {
  final DirectoryApi api;
  final List<Map<String, dynamic>> communities;
  final Map<String, dynamic>? series;
  final String? profileId;
  final bool profilePublic;
  const SeriesEditor({
    super.key,
    required this.api,
    required this.communities,
    this.series,
    this.profileId,
    this.profilePublic = false,
  });
  @override
  State<SeriesEditor> createState() => _SeriesEditorState();
}

class _SeriesEditorState extends State<SeriesEditor> {
  final _title = TextEditingController(),
      _description = TextEditingController();
  String? _community, _notice;
  bool _public = false, _busy = false, _denied = false;
  @override
  void initState() {
    super.initState();
    _title.text = widget.series?['title'] as String? ?? '';
    _description.text = widget.series?['description'] as String? ?? '';
    _community =
        widget.series?['community_id'] as String? ??
        widget.communities.firstOrNull?['id'] as String?;
    if (!widget.communities.any((c) => c['id'] == _community)) {
      _community = null;
    }
    _public = widget.series?['is_public'] == true;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _denied || _community == null) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await widget.api.directory(
        'manage/series',
        body: {
          'id': ?widget.series?['id'],
          'version': ?widget.series?['version'],
          if (widget.profileId != null) 'profile_id': widget.profileId,
          'title': _title.text.trim(),
          'description': _description.text.trim(),
          'community_id': _community,
          'is_public': _public,
        },
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _notice = e is ApiFailure
              ? e.message
              : 'Die Reihe konnte nicht gespeichert werden.';
          if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
            _denied = true;
            _title.clear();
            _description.clear();
            _community = null;
            _public = false;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: accessAppBar(context, 'Veranstaltungsreihe bearbeiten'),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        width: AccessPageWidth.form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_notice != null) directoryNotice(_notice!),
            if (_denied)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const LocalText('Zurück zur Verwaltung'),
              ),
            if (!_denied) ...[
              AccessField(
                decoration: const InputDecoration(labelText: 'Name der Reihe'),
                builder: (decoration) => TextField(
                  controller: _title,
                  enabled: !_busy,
                  maxLength: 180,
                  decoration: decoration,
                ),
              ),
              const SizedBox(height: AccessSpacing.s16),
              AccessField(
                decoration: const InputDecoration(
                  labelText: 'Beschreibung der Reihe',
                ),
                builder: (decoration) => TextField(
                  controller: _description,
                  enabled: !_busy,
                  maxLength: 4000,
                  minLines: 3,
                  maxLines: 8,
                  decoration: decoration,
                ),
              ),
              const SizedBox(height: AccessSpacing.s16),
              AccessField(
                decoration: const InputDecoration(
                  labelText: 'Verantwortliche Community',
                ),
                trailingWidth: AccessSpacing.s40,
                builder: (decoration) => DropdownButtonFormField<String>(
                  initialValue: _community,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: decoration,
                  items: [
                    for (final c in widget.communities)
                      DropdownMenuItem(
                        value: c['id'] as String,
                        child: AccessOptionText(c['name'] as String),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _community = v),
                ),
              ),
              if (_community == null)
                Text(
                  localText(
                    context,
                    'Bitte wähle eine verantwortliche Community aus. Falls keine verfügbar ist, kehre zur Verwaltung zurück und prüfe die Communityzuordnung deines Profils.',
                    'Please choose a responsible community. If none is available, return to management and check your profile’s community assignment.',
                  ),
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const LocalText('Reihe frei sichtbar anzeigen'),
                value: _public,
                onChanged: _busy || (!widget.profilePublic && !_public)
                    ? null
                    : (v) => setState(() => _public = v!),
              ),
              if (!widget.profilePublic)
                const LocalText(
                  'Öffentliche Reihen benötigen ein öffentliches Veranstalterprofil.',
                ),
              if (!_public)
                const LocalText(
                  'Nur der gesondert freigegebene Gästekreis sieht diese Reihe und ihre Events. Eine einzelne Eventfreigabe öffnet ausschließlich das ausgewählte Event.',
                ),
              const SizedBox(height: AccessSpacing.s24),
              FilledButton(
                onPressed: _busy || _community == null ? null : _save,
                child: const LocalText('Reihe speichern'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

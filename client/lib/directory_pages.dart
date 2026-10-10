import 'app_language.dart';

import 'package:flutter/material.dart';

import 'access_api.dart';
import 'directory_api.dart';
import 'design_system.dart';
import 'program_views.dart';
import 'bookmark_views.dart';
import 'site_information_page.dart';

const _status = {
  'pending': 'Wartet auf Freigabe',
  'approved': 'Profilzugriff freigegeben',
  'rejected': 'Abgelehnt',
  'withdrawn': 'Zurückgezogen',
  'revoked': 'Zugriff entzogen',
};
Widget directoryHeading(String title) =>
    AccessHeading(title, level: 1, role: AccessHeadingRole.page);
Widget directoryNotice(String text) => Semantics(
  liveRegion: true,
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: AccessSpacing.s16),
    child: LocalText(
      text,
      style: const TextStyle(height: AccessTypography.readingHeight),
    ),
  ),
);
Widget directoryCommunityTag(String name) => Semantics(
  label: name,
  excludeSemantics: true,
  child: Builder(
    builder: (context) => Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AccessSpacing.s16,
        vertical: AccessSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: AushangPalette.of(context).sunken,
        borderRadius: BorderRadius.zero,
      ),
      child: Text(name),
    ),
  ),
);

String _error(Object error) => error is ApiFailure
    ? error.message
    : 'Die Daten konnten nicht geladen werden. Bitte versuche es erneut.';

class DirectoryBrowser extends StatefulWidget {
  final DirectoryApi? api;
  final bool venues;
  final Future<void> Function() openAccount;
  const DirectoryBrowser({
    super.key,
    required this.api,
    required this.venues,
    required this.openAccount,
  });
  @override
  State<DirectoryBrowser> createState() => _DirectoryBrowserState();
}

class _DirectoryBrowserState extends State<DirectoryBrowser> {
  final _search = TextEditingController();
  String? _community;
  Map<String, dynamic>? _data;
  String? _failure;
  bool _busy = false;
  int _page = 1, _revision = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _revision++;
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    final revision = ++_revision;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _failure = null;
      _page = page;
    });
    try {
      final data =
          await widget.api?.directory(
            widget.venues ? 'venues' : 'organizers',
            query: {
              'q': _search.text.trim(),
              'page': '$page',
              'community': ?_community,
            },
          ) ??
          {'items': [], 'communities': [], 'has_more': false};
      if (mounted && revision == _revision) setState(() => _data = data);
    } catch (e) {
      if (mounted && revision == _revision) {
        setState(() {
          _data = null;
          _failure = _error(e);
        });
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _busy = false);
    }
  }

  Future<void> _accessLink() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profilzugang öffnen'),
        content: AccessField(
          decoration: const InputDecoration(
            labelText: 'Profiladresse oder Zugangslink',
          ),
          builder: (decoration) => TextField(
            controller: controller,
            decoration: decoration,
            maxLength: 500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Öffnen'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || value == null || value.isEmpty) return;
    final uri = Uri.tryParse(value);
    Map<String, String> params = {};
    try {
      params = Uri.splitQueryString(uri?.fragment ?? '');
    } catch (_) {}
    final id = params['organizer'];
    if ((uri?.scheme != 'http' ||
            uri?.host != '127.0.0.1' ||
            uri?.port != 8300) ||
        id == null ||
        !RegExp(r'^[a-f0-9-]{36}$').hasMatch(id)) {
      setState(
        () => _failure = 'Bitte verwende eine gültige lokale Profiladresse.',
      );
      return;
    }
    await _profile(id, token: params['profile_link']);
  }

  Future<void> _profile(String id, {String? token}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OrganizerDetailPage(
          api: widget.api!,
          id: id,
          token: token,
          openAccount: widget.openAccount,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AccessSpacing.s48),
        child: directoryHeading(
          widget.venues ? 'Veranstaltungsorte.' : 'Veranstalter.',
        ),
      ),
      Text(
        widget.venues
            ? 'Orte öffentlicher Veranstaltungen – von kommenden Events bis zu vergangenen Abenden.'
            : 'Entdecke Veranstalter und ihre Veranstaltungen.',
        style: const TextStyle(height: AccessTypography.readingHeight),
      ),
      const SizedBox(height: AccessSpacing.s24),
      AccessSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AccessField(
              decoration: InputDecoration(
                labelText: widget.venues
                    ? 'Veranstaltungsort suchen'
                    : 'Veranstalter nach Namen suchen',
                counterText: '',
                prefixIcon: const AccessIcon(Icons.search),
              ),
              builder: (decoration) => TextField(
                controller: _search,
                maxLength: 180,
                decoration: decoration,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
              ),
            ),
            if (!widget.venues) ...[
              const SizedBox(height: AccessSpacing.s16),
              AccessField(
                decoration: const InputDecoration(
                  labelText: 'Nach Community filtern',
                ),
                trailingWidth: AccessSpacing.s40,
                builder: (decoration) => DropdownButtonFormField<String>(
                  key: ValueKey(_community),
                  initialValue: _community,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: decoration,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: AccessOptionText('Alle Communities'),
                    ),
                    if (_community != null &&
                        !(_data?['communities'] as List? ?? []).any(
                          (c) => c['id'] == _community,
                        ))
                      DropdownMenuItem(
                        value: _community,
                        child: AccessOptionText(
                          localText(context, 'Gewählte Community'),
                        ),
                      ),
                    for (final c in (_data?['communities'] as List? ?? []))
                      DropdownMenuItem(
                        value: c['id'] as String,
                        child: AccessOptionText(c['name'] as String),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          setState(() => _community = value);
                          _load();
                        },
                ),
              ),
            ],
            const SizedBox(height: AccessSpacing.s16),
            Wrap(
              spacing: AccessSpacing.s12,
              runSpacing: AccessSpacing.s8,
              children: [
                FilledButton(
                  onPressed: _busy ? null : () => _load(),
                  child: const Text('Suchen'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          _search.clear();
                          setState(() => _community = null);
                          _load();
                        },
                  child: const Text('Zurücksetzen'),
                ),
                if (!widget.venues && _data?['signed_in'] != true)
                  TextButton(
                    onPressed: () async {
                      await widget.openAccount();
                      if (mounted) _load();
                    },
                    child: const Text('Anmelden'),
                  ),
              ],
            ),
          ],
        ),
      ),
      if (_busy)
        const Padding(
          padding: EdgeInsets.all(AccessSpacing.s24),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (_failure != null) ...[
        directoryNotice(_failure!),
        OutlinedButton(onPressed: _load, child: const Text('Erneut laden')),
      ],
      if (!_busy &&
          _failure == null &&
          (_data?['items'] as List? ?? []).isEmpty)
        directoryNotice(
          widget.venues
              ? 'Noch keine öffentlichen Veranstaltungsorte für diese Auswahl.'
              : 'Keine Veranstalterprofile für diese Auswahl.',
        ),
      if (!_busy && _failure == null)
        for (final item in (_data?['items'] as List? ?? []))
          Padding(
            padding: const EdgeInsets.only(top: AccessSpacing.s20),
            child: AccessSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'] as String,
                    style: const TextStyle(
                      fontSize: AccessTypography.sectionTitleSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AccessSpacing.s16),
                  if (!widget.venues) ...[
                    InterestCount(count: item['interest_count'] as int?),
                    Text(
                      item['description'] as String,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AccessSpacing.s12),
                    Wrap(
                      spacing: AccessSpacing.s8,
                      runSpacing: AccessSpacing.s8,
                      children: [
                        for (final c in item['communities'] as List)
                          directoryCommunityTag(c['name'] as String),
                      ],
                    ),
                  ] else
                    Text('${item['event_count']} öffentliche Veranstaltungen'),
                  const SizedBox(height: AccessSpacing.s16),
                  OutlinedButton(
                    onPressed: widget.api == null
                        ? null
                        : () async {
                            if (widget.venues) {
                              await Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => VenueDetailPage(
                                    api: widget.api!,
                                    name: item['name'] as String,
                                    openAccount: widget.openAccount,
                                  ),
                                ),
                              );
                            } else {
                              await _profile(item['id'] as String);
                            }
                          },
                    child: Text(
                      widget.venues
                          ? 'Veranstaltungen ansehen'
                          : 'Profil ansehen',
                    ),
                  ),
                ],
              ),
            ),
          ),
      if (!_busy && _failure == null)
        Wrap(
          spacing: AccessSpacing.s12,
          children: [
            if (_page > 1)
              TextButton(
                onPressed: () => _load(page: _page - 1),
                child: const Text('Vorherige Seite'),
              ),
            if (_data?['has_more'] == true)
              TextButton(
                onPressed: () => _load(page: _page + 1),
                child: const Text('Nächste Seite'),
              ),
          ],
        ),
      if (!widget.venues && widget.api != null && _data?['signed_in'] == true)
        Padding(
          padding: const EdgeInsets.only(top: AccessSpacing.s24),
          child: OutlinedButton(
            onPressed: _accessLink,
            child: const Text('Profilzugang öffnen'),
          ),
        ),
    ],
  );
}

class OrganizerDetailPage extends StatefulWidget {
  final DirectoryApi api;
  final String id;
  final String? token;
  final Future<void> Function()? openAccount;
  const OrganizerDetailPage({
    super.key,
    required this.api,
    required this.id,
    this.token,
    this.openAccount,
  });
  @override
  State<OrganizerDetailPage> createState() => _OrganizerDetailPageState();
}

class _OrganizerDetailPageState extends State<OrganizerDetailPage> {
  Map<String, dynamic>? _profile, _access, _program;
  final Map<String, TextEditingController> _answers = {};
  final _requestForm = GlobalKey<FormState>();
  bool _busy = false;
  bool _needsRefresh = false;
  int? _formVersion;
  int _revision = 0;
  String? _notice;
  String _method = 'application';
  int _programPage = 1;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _revision++;
    for (final c in _answers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> _load({int? programPage}) async {
    final revision = ++_revision;
    _programPage = programPage ?? 1;
    if (!mounted) return false;
    setState(() {
      _busy = true;
      _profile = null;
      _access = null;
      _program = null;
      _notice = null;
    });
    try {
      Map<String, dynamic>? profile;
      try {
        profile = await widget.api.directory('organizers/${widget.id}');
      } on ApiFailure {
        /* Minimal access entry can be shared independently. */
      }
      final access = await widget.api.directory(
        'organizers/${widget.id}/access',
      );
      final program = profile == null
          ? null
          : await widget.api.directory(
              'organizers/${widget.id}/program',
              query: {'page': '$_programPage'},
            );
      if (!mounted || revision != _revision) return false;
      final formChanged =
          _formVersion != null &&
          _formVersion != access['version'] &&
          _answers.values.any((answer) => answer.text.isNotEmpty);
      final keepAnswers =
          access['signed_in'] == true &&
          access['request'] == null &&
          _formVersion == access['version'];
      for (final key in _answers.keys.toList()) {
        if (!keepAnswers ||
            !(access['form'] as List).any((f) => f['key'] == key)) {
          _answers.remove(key)!.dispose();
        }
      }
      if (access['signed_in'] == true && access['request'] == null) {
        for (final f in access['form'] as List) {
          _answers.putIfAbsent(
            f['key'] as String,
            () => TextEditingController(),
          );
        }
      }
      _formVersion = access['version'] as int?;
      setState(() {
        _profile = profile;
        _access = access;
        _program = program;
        _needsRefresh = false;
        if (formChanged) {
          _notice = 'Das Formular wurde geändert. Bitte beantworte die aktuellen Fragen.';
        }
        if (!keepAnswers ||
            access[_method == 'application'
                    ? 'allow_application'
                    : 'allow_form'] !=
                true) {
          _method = access['allow_application'] == true
              ? 'application'
              : 'form';
        }
      });
      return true;
    } catch (e) {
      if (mounted && revision == _revision) {
        if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
          for (final answer in _answers.values) {
            answer.clear();
          }
          _formVersion = null;
        }
        setState(() => _notice = _error(e));
      }
      return false;
    } finally {
      if (mounted && revision == _revision) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (!mounted || _busy || _needsRefresh) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await action();
      if (!mounted) return;
      for (final answer in _answers.values) {
        answer.clear();
      }
      final refreshed = await _load();
      if (mounted) {
        setState(() {
          _needsRefresh = !refreshed;
          _notice = refreshed ? success : 'Die Aktion wurde bestätigt, aber der aktuelle Status konnte nicht geladen werden. Bitte aktualisiere den Status.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _needsRefresh = true;
          if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
            _profile = null;
            _access = null;
            _program = null;
            for (final answer in _answers.values) {
              answer.clear();
            }
            _formVersion = null;
          }
          _notice =
              '${_error(e)} Aktualisiere den Status, bevor du erneut sendest.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    if (_busy || _needsRefresh) return;
    if (_method == 'form' && !_requestForm.currentState!.validate()) return;
    await _run(() async {
      await widget.api.directory(
        'organizers/${widget.id}/apply',
        body: {
          'method': _method,
          'version': _access!['version'],
          'answers': _method == 'form'
              ? {for (final e in _answers.entries) e.key: e.value.text.trim()}
              : <String, String>{},
        },
      );
    }, 'Anfrage eingereicht. Der Gastgeber entscheidet manuell.');
  }

  Future<void> _openAccount() async {
    // A draft must never be reused after a possible account change.
    for (final answer in _answers.values) {
      answer.clear();
    }
    _formVersion = null;
    await widget.openAccount!();
    if (mounted) await _load(programPage: _programPage);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: accessAppBar(context, 'Veranstalterprofil'),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        width: _profile == null ? AccessPageWidth.form : AccessPageWidth.detail,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_notice != null) directoryNotice(_notice!),
            if (_access != null) ...[
              directoryHeading(_access!['name'] as String),
              const SizedBox(height: AccessSpacing.s24),
              if (_profile != null) ...[
                if (_access!['signed_in'] == true ||
                    _profile!['interest_count'] != null)
                  BookmarkButton(
                    key: ValueKey('profile:${widget.id}'),
                    api: widget.api,
                    kind: 'profile',
                    id: widget.id,
                    signedIn: _access!['signed_in'] == true,
                    interestCount: _profile!['interest_count'] as int?,
                    openAccount: widget.openAccount == null
                        ? null
                        : _openAccount,
                  ),
                AccessContent(
                  child: Text(
                    _profile!['description'] as String,
                    style: const TextStyle(
                      height: AccessTypography.readingHeight,
                    ),
                  ),
                ),
                const SizedBox(height: AccessSpacing.s16),
                LocalText(
                  '${localText(context, 'Awarenesskonzept vorhanden?')} ${_profile!['awareness_concept'] == null
                      ? localText(context, 'Noch keine Angabe', 'Not specified')
                      : _profile!['awareness_concept'] == true
                      ? localText(context, 'Ja')
                      : localText(context, 'Nein')}',
                ),
                LocalText(
                  '${localText(context, 'Awarenessteam vorhanden?')} ${_profile!['awareness_team'] == null
                      ? localText(context, 'Noch keine Angabe', 'Not specified')
                      : _profile!['awareness_team'] == true
                      ? localText(context, 'Ja')
                      : localText(context, 'Nein')}',
                ),
                const SizedBox(height: AccessSpacing.s20),
                Wrap(
                  spacing: AccessSpacing.s8,
                  runSpacing: AccessSpacing.s8,
                  children: [
                    for (final c in _profile!['communities'] as List)
                      directoryCommunityTag(c['name'] as String),
                  ],
                ),
                if (_program != null)
                  ProgramList(
                    api: widget.api,
                    openAccount: widget.openAccount,
                    program: _program!,
                    onPage: (page) => _load(programPage: page),
                    onRefresh: () =>
                        _load(programPage: _program!['page'] as int? ?? 1),
                  ),
              ] else ...[
                directoryNotice(
                  'Eine Profilfreigabe ist keine Communitymitgliedschaft und keine Eventzusage.',
                ),
                if (_access!['signed_in'] != true && widget.openAccount != null)
                  TextButton(
                    onPressed: _busy ? null : _openAccount,
                    child: const Text('Anmelden oder Konto anlegen'),
                  ),
                if (_access!['request'] != null) ...[
                  directoryNotice(
                    _status[_access!['request']['status']] ??
                        'Anfrage vorhanden',
                  ),
                  if (_access!['request']['status'] == 'pending') ...[
                    const Text(
                      'Beim Rückzug werden deine Antworten entfernt. Eine erneute Profilanfrage ist derzeit gesperrt. Nutze bei Fragen deinen bestehenden Kontakt zu den Gastgebern.',
                      style: TextStyle(height: AccessTypography.readingHeight),
                    ),
                    OutlinedButton(
                      onPressed: _busy || _needsRefresh
                          ? null
                          : () => _run(() async {
                              await widget.api.directory(
                                'requests/${_access!['request']['id']}/withdraw',
                                body: {},
                              );
                            }, 'Anfrage zurückgezogen.'),
                      child: const Text('Anfrage zurückziehen'),
                    ),
                  ],
                  if ([
                    'rejected',
                    'withdrawn',
                    'revoked',
                  ].contains(_access!['request']['status']))
                    directoryNotice(
                      'Eine erneute Anfrage ist gesperrt. Kontaktiere den Gastgeber über euren bestehenden Kontaktweg.',
                    ),
                ] else if (_access!['signed_in'] == true &&
                    (_access!['allow_application'] == true ||
                        _access!['allow_form'] == true)) ...[
                  const SizedBox(height: AccessSpacing.s16),
                  const Text(
                    'Deine Anfrage geht an die zuständigen Gastgeber dieses Profils. Sie prüfen sie manuell. Bitte teile keine intimen Angaben oder persönlichen Informationen über andere Personen.',
                    style: TextStyle(height: AccessTypography.readingHeight),
                  ),
                  if (_access!['allow_application'] == true &&
                      _access!['allow_form'] == true)
                    Wrap(
                      spacing: AccessSpacing.s12,
                      children: [
                        ChoiceChip(
                          label: const Text('Bewerbung'),
                          selected: _method == 'application',
                          onSelected: _busy
                              ? null
                              : (_) => setState(() => _method = 'application'),
                        ),
                        ChoiceChip(
                          label: const Text('Formular'),
                          selected: _method == 'form',
                          onSelected: _busy
                              ? null
                              : (_) => setState(() => _method = 'form'),
                        ),
                      ],
                    ),
                  if (_method == 'form')
                    Form(
                      key: _requestForm,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final f in _access!['form'] as List)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AccessSpacing.s16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Semantics(
                                    headingLevel: 3,
                                    child: Text(
                                      f['label'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        height: AccessTypography.readingHeight,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AccessSpacing.s12),
                                  Semantics(
                                    label: f['label'] as String,
                                    child: AccessField(
                                      decoration: InputDecoration(
                                        labelText: f['required'] == true
                                            ? 'Deine Antwort (Pflichtfeld)'
                                            : 'Deine Antwort',
                                        helperText: f['required'] == true
                                            ? null
                                            : 'Optional',
                                      ),
                                      builder: (decoration) => TextFormField(
                                        key: ValueKey(
                                          'profile-answer-${f['key']}',
                                        ),
                                        controller: _answers[f['key']],
                                        enabled: !_busy,
                                        minLines: 2,
                                        maxLines: 5,
                                        maxLength: 2000,
                                        validator: f['required'] == true
                                            ? (value) =>
                                                  value == null ||
                                                      value.trim().isEmpty
                                                  ? 'Bitte beantworte diese Pflichtfrage.'
                                                  : null
                                            : null,
                                        decoration: decoration,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AccessSpacing.s20),
                  FilledButton(
                    onPressed: _busy || _needsRefresh ? null : _apply,
                    child: const Text('Profilzugriff anfragen'),
                  ),
                ],
                if (widget.token != null &&
                    _access!['signed_in'] == true &&
                    _access!['allow_link'] == true)
                  Padding(
                    padding: const EdgeInsets.only(top: AccessSpacing.s20),
                    child: FilledButton(
                      onPressed: _busy || _needsRefresh
                          ? null
                          : () => _run(() async {
                              await widget.api.directory(
                                'organizers/${widget.id}/redeem',
                                body: {'token': widget.token},
                              );
                            }, 'Profilzugriff freigegeben.'),
                      child: const Text('Persönlichen Zugangslink einlösen'),
                    ),
                  ),
              ],
            ],
            if (_access == null && !_busy && widget.openAccount != null)
              TextButton(
                onPressed: _openAccount,
                child: const Text('Anmelden oder Konto anlegen'),
              ),
            if (_needsRefresh)
              directoryNotice(
                'Bis zur Statusprüfung bleibt erneutes Senden gesperrt.',
              ),
            const SizedBox(height: AccessSpacing.s24),
            OutlinedButton(
              onPressed: _busy ? null : _load,
              child: const Text('Aktualisieren'),
            ),
            const SiteInformationLinks(),
          ],
        ),
      ),
    ),
  );
}

class VenueDetailPage extends StatefulWidget {
  final DirectoryApi api;
  final String name;
  final Future<void> Function()? openAccount;
  const VenueDetailPage({
    super.key,
    required this.api,
    required this.name,
    this.openAccount,
  });
  @override
  State<VenueDetailPage> createState() => _VenueDetailPageState();
}

class _VenueDetailPageState extends State<VenueDetailPage> {
  Map<String, dynamic>? _data;
  String? _failure;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _failure = null;
      _data = null;
    });
    try {
      final data = await widget.api.directory(
        'venue',
        query: {'name': widget.name},
      );
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _failure = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: accessAppBar(context, 'Veranstaltungsort'),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        width: AccessPageWidth.detail,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            directoryHeading(widget.name),
            const SizedBox(height: AccessSpacing.s24),
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_failure != null) directoryNotice(_failure!),
            for (final e in (_data?['events'] as List? ?? []))
              Padding(
                padding: const EdgeInsets.only(bottom: AccessSpacing.s20),
                child: AccessSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e['title'] as String,
                        style: const TextStyle(
                          fontSize: AccessTypography.sectionTitleSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AccessSpacing.s12),
                      Text(e['community'] as String),
                      const SizedBox(height: AccessSpacing.s12),
                      Text(
                        e['starts_at'] == null
                            ? 'Beginn nicht öffentlich freigegeben'
                            : _date(e['starts_at'] as String),
                      ),
                      if (e['status'] == 'cancelled') const Text('Abgesagt'),
                      TextButton(
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => ProgramDetailPage(
                              api: widget.api,
                              kind: 'events',
                              id: e['id'] as String,
                              openAccount: widget.openAccount,
                            ),
                          ),
                        ),
                        child: const LocalText('Event ansehen'),
                      ),
                      InterestCount(count: e['interest_count'] as int?),
                    ],
                  ),
                ),
              ),
            OutlinedButton(
              onPressed: _busy ? null : _load,
              child: const Text('Aktualisieren'),
            ),
          ],
        ),
      ),
    ),
  );
}

String _date(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return 'Beginn nicht verfügbar';
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} (lokale Zeit)';
}

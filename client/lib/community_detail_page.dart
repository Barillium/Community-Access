import 'package:flutter/material.dart';

import 'access_api.dart';
import 'access_brand.dart';
import 'app_language.dart';
import 'design_system.dart';
import 'directory_api.dart';
import 'flyer_design.dart';
import 'program_date_filter.dart';
import 'program_views.dart';
import 'resource_return_browser.dart'
    if (dart.library.js_interop) 'resource_return_browser_web.dart';

/// Reads the authorized directory before loading this community's program.
class CommunityDetailPage extends StatefulWidget {
  const CommunityDetailPage({
    super.key,
    required this.api,
    required this.id,
    this.openAccount,
    this.showGlobalFilter = false,
  });
  final DirectoryApi api;
  final String id;
  final Future<void> Function()? openAccount;
  final bool showGlobalFilter;
  @override
  State<CommunityDetailPage> createState() => _CommunityDetailPageState();
}

class _CommunityDetailPageState extends State<CommunityDetailPage> {
  final _search = TextEditingController();
  Map<String, dynamic>? _community, _program;
  String? _failure, _previousTarget;
  bool _loading = true;
  int _revision = 0;
  ProgramDateFilter _date = ProgramDateFilter.all;
  @override
  void initState() {
    super.initState();
    _previousTarget = rememberResourceTarget('community', widget.id);
    _load();
  }

  @override
  void dispose() {
    _revision++;
    _search.dispose();
    restoreResourceTarget(_previousTarget);
    super.dispose();
  }

  Future<void> _load({int page = 1, bool reloadCommunity = false}) async {
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _failure = null;
      _program = null;
      if (reloadCommunity) _community = null;
    });
    try {
      if (_community == null) {
        final directory = await widget.api.directory('communities');
        if (!mounted || revision != _revision) return;
        final matches = (directory['items'] as List).where(
          (c) => c['id'] == widget.id,
        );
        if (matches.isEmpty) {
          throw const ApiFailure('Diese Community ist nicht verfügbar.');
        }
        _community = Map<String, dynamic>.from(matches.single as Map);
      }
      final range = programDateRange(_date);
      final program = await widget.api.directory(
        'events',
        query: {
          'scope': 'upcoming',
          'community': widget.id,
          'q': _search.text.trim(),
          'page': '$page',
          if (range != null) 'from': range.from.toUtc().toIso8601String(),
          if (range != null) 'before': range.before.toUtc().toIso8601String(),
        },
      );
      if (mounted && revision == _revision) setState(() => _program = program);
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(
          () => _failure = localText(
            context,
            'Diese Community oder ihr Programm ist derzeit nicht verfügbar.',
            'This community or its program is currently unavailable.',
          ),
        );
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  String _dateLabel(ProgramDateFilter value) => switch (value) {
    ProgramDateFilter.all => localText(context, 'Alle Termine', 'All dates'),
    ProgramDateFilter.today => localText(context, 'Heute', 'Today'),
    ProgramDateFilter.tomorrow => localText(context, 'Morgen', 'Tomorrow'),
    ProgramDateFilter.thisWeek => localText(
      context,
      'Diese Woche',
      'This week',
    ),
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AccessTopBar(
      title: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          label: 'Community Access',
          child: ExcludeSemantics(child: AccessBrand(width: 112)),
        ),
      ),
      leading: IconButton(
        tooltip: localText(context, 'Zurück', 'Back'),
        onPressed: () => Navigator.pop(context),
        icon: const AccessIcon(Icons.arrow_back),
      ),
    ),
    body: SingleChildScrollView(
      child: AccessHeroLayout(
        hero: FlyerBanner(
          title: _community?['name'] as String? ?? 'Community',
          description: localText(
            context,
            'Ein gemeinsamer Ort im Programm.',
            'A shared place in the program.',
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_community?['synthetic'] == true)
              Text(
                localText(
                  context,
                  'Synthetische Beispiel-Community · keine reale Zugehörigkeit.',
                  'Synthetic example community · no real affiliation.',
                ),
              ),
            if (_community != null) ...[
              const SizedBox(height: 24),
              Text(
                localText(
                  context,
                  _community!['event_count'] is int &&
                          _community!['event_count'] >= 0
                      ? '${_community!['event_count']} aktuell zugeordnete ${_community!['event_count'] == 1 ? 'Veranstaltung' : 'Veranstaltungen'}'
                      : 'Anzahl nicht verfügbar',
                  _community!['event_count'] is int &&
                          _community!['event_count'] >= 0
                      ? '${_community!['event_count']} currently assigned ${_community!['event_count'] == 1 ? 'event' : 'events'}'
                      : 'Event count unavailable',
                ),
              ),
              if (widget.showGlobalFilter)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const AccessIcon(Icons.filter_alt_outlined),
                    label: Text(
                      localText(
                        context,
                        'Im Programm filtern',
                        'Filter the program',
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              AccessHeading(
                localText(
                  context,
                  'Das Communityprogramm.',
                  'The community program.',
                ),
                role: AccessHeadingRole.section,
                level: 2,
              ),
              const SizedBox(height: 24),
              AccessField(
                decoration: InputDecoration(
                  labelText: localText(
                    context,
                    'Veranstaltung suchen',
                    'Search events',
                  ),
                  prefixIcon: const AccessIcon(Icons.search),
                ),
                builder: (decoration) => TextField(
                  controller: _search,
                  decoration: decoration,
                  maxLength: 180,
                  onSubmitted: (_) => _load(),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in ProgramDateFilter.values)
                    Semantics(
                      selected: _date == value,
                      child: TextButton(
                        onPressed: () {
                          setState(() => _date = value);
                          _load();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: _date == value
                              ? FlyerStyle.orange
                              : null,
                          foregroundColor: FlyerStyle.ink,
                          minimumSize: const Size(48, 48),
                        ),
                        child: Text(_dateLabel(value)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_failure != null) ...[
              Semantics(liveRegion: true, child: Text(_failure!)),
              TextButton(
                onPressed: () => _load(reloadCommunity: true),
                child: Text(
                  localText(context, 'Erneut versuchen', 'Try again'),
                ),
              ),
            ],
            if (_program != null && !_loading && _failure == null)
              if ((_program!['events'] as List? ?? []).isEmpty)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    localText(
                      context,
                      'Keine passenden Veranstaltungen in dieser Community.',
                      'No matching events in this community.',
                    ),
                  ),
                )
              else
                ProgramList(
                  api: widget.api,
                  program: _program!,
                  openAccount: widget.openAccount,
                  showHeading: false,
                  calendarLayout: true,
                  onPage: (page) => _load(page: page),
                  onRefresh: _load,
                ),
          ],
        ),
      ),
    ),
  );
}

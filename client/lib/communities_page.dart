import 'flyer_design.dart';

import 'package:flutter/material.dart';

import 'app_language.dart';
import 'community_topics.dart';
import 'design_system.dart';
import 'directory_api.dart';
import 'product_scope.dart';

/// Public entries come exclusively from the server-filtered directory.
class CommunitiesPage extends StatefulWidget {
  const CommunitiesPage({
    super.key,
    required this.api,
    required this.openAccount,
    required this.onOrganizers,
    required this.onFaq,
  });
  final DirectoryApi? api;
  final Future<void> Function() openAccount;
  final void Function(String community) onOrganizers;
  final VoidCallback onFaq;

  @override
  State<CommunitiesPage> createState() => _CommunitiesPageState();
}

class _CommunitiesPageState extends State<CommunitiesPage> {
  final _search = TextEditingController();
  final _pending = <String>{};
  List<Map<String, dynamic>> _items = [];
  String _query = '';
  bool _loading = false, _failed = false, _signedIn = false;
  int _revision = 0;

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

  Future<void> _load() async {
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _failed = false;
      _items = [];
    });
    try {
      final data = await widget.api?.directory('communities');
      if (data == null ||
          data['items'] is! List ||
          data['signed_in'] is! bool) {
        throw const FormatException('Invalid community response');
      }
      if (mounted && revision == _revision) {
        setState(() {
          _items = (data['items'] as List).cast<Map<String, dynamic>>();
          _signedIn = data['signed_in'] == true;
        });
      }
    } catch (_) {
      if (mounted && revision == _revision) setState(() => _failed = true);
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  Future<void> _follow(Map<String, dynamic> item) async {
    if (!_signedIn) {
      await widget.openAccount();
      if (mounted) await _load();
      return;
    }
    final id = item['id'] as String;
    if (_pending.contains(id)) return;
    setState(() => _pending.add(id));
    try {
      await widget.api!.directory(
        'follow',
        body: {'id': id, 'following': item['following'] != true},
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localText(
                context,
                'Folgen konnte nicht gespeichert werden. Bitte prüfe den aktuellen Status.',
                'Following could not be saved. Please check the current status.',
              ),
            ),
          ),
        );
      }
    } finally {
      // A lost response may follow a successful write; reload authoritative state.
      if (mounted) await _load();
      if (mounted) setState(() => _pending.remove(id));
    }
  }

  Widget _heading(String de, String en) => AccessHeading(
    localText(context, de, en),
    role: AccessHeadingRole.section,
    level: 2,
  );

  @override
  Widget build(BuildContext context) {
    final palette = AushangPalette.of(context);
    final visible = _items
        .where((c) => (c['name'] as String).toLowerCase().contains(_query))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AccessSpacing.s48),
        const FlyerBanner(title: 'Communities'),
        const SizedBox(height: AccessSpacing.s20),
        Text(
          localText(
            context,
            'Finde deinen Kreis. Entdecke öffentliche Communities und Themen für gemeinsame Erlebnisse.',
            'Find your people. Discover public communities and topics for shared experiences.',
          ),
          style: TextStyle(
            fontSize: AccessTypography.leadSize,
            height: 1.5,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: AccessSpacing.s24),
        Text(
          localText(
            context,
            'Öffentlich sichtbar heißt nicht automatisch aufgenommen. Mitgliedschaft und Eventteilnahme werden getrennt freigegeben.',
            'Public visibility does not mean automatic membership. Community admission and event attendance are approved separately.',
          ),
          style: TextStyle(height: 1.6, color: palette.muted),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: widget.onFaq,
            child: Text(
              localText(
                context,
                'Fragen zum Zugang? Zur FAQ',
                'Questions about access? Visit the FAQ',
              ),
            ),
          ),
        ),
        const SizedBox(height: AccessSpacing.s24),
        AccessField(
          decoration: InputDecoration(
            labelText: localText(
              context,
              'Community oder Thema suchen',
              'Search communities or topics',
            ),
            prefixIcon: const AccessIcon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: localText(
                      context,
                      'Suche zurücksetzen',
                      'Clear search',
                    ),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                    icon: const AccessIcon(Icons.close),
                  ),
          ),
          builder: (decoration) => TextField(
            controller: _search,
            decoration: decoration,
            maxLength: 180,
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
        ),
        const SizedBox(height: AccessSpacing.s40),
        _heading('Öffentliche Communities', 'Public communities'),
        const SizedBox(height: AccessSpacing.s16),
        if (_loading)
          Semantics(
            liveRegion: true,
            child: Text(
              localText(
                context,
                'Communities werden geladen …',
                'Loading communities …',
              ),
            ),
          )
        else if (_failed) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              localText(
                context,
                'Öffentliche Communities sind derzeit nicht verfügbar.',
                'Public communities are currently unavailable.',
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _load,
              child: Text(localText(context, 'Erneut laden', 'Try again')),
            ),
          ),
        ] else if (visible.isEmpty)
          Semantics(
            liveRegion: true,
            child: Text(
              localText(
                context,
                _query.isEmpty
                    ? 'Noch keine öffentlich freigegebenen Communities.'
                    : 'Keine öffentlichen Communities zu deiner Suche.',
                _query.isEmpty
                    ? 'No publicly listed communities yet.'
                    : 'No public communities match your search.',
              ),
              style: TextStyle(color: palette.muted, height: 1.6),
            ),
          )
        else
          for (final item in visible)
            Container(
              padding: const EdgeInsets.symmetric(vertical: AccessSpacing.s20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.hair)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AccessHeading(
                    item['name'] as String,
                    role: AccessHeadingRole.card,
                    level: 3,
                  ),
                  const SizedBox(height: AccessSpacing.s12),
                  Wrap(
                    spacing: AccessSpacing.s12,
                    runSpacing: AccessSpacing.s8,
                    children: [
                      OutlinedButton(
                        onPressed: () =>
                            widget.onOrganizers(item['id'] as String),
                        child: Text(
                          localText(
                            context,
                            'Veranstalter ansehen',
                            'View organizers',
                          ),
                        ),
                      ),
                      if (ProductScope.extended)
                        TextButton(
                          onPressed: _pending.contains(item['id'])
                              ? null
                              : () => _follow(item),
                          child: Text(
                            item['following'] == true
                                ? localText(
                                    context,
                                    'Nicht mehr folgen',
                                    'Unfollow',
                                  )
                                : localText(context, 'Folgen', 'Follow'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        const SizedBox(height: AccessSpacing.s64),
        CommunityTopics(query: _query),
        const SizedBox(height: AccessSpacing.s48),
      ],
    );
  }
}

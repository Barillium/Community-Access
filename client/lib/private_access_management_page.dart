import 'package:flutter/material.dart';

import 'access_api.dart';
import 'access_flow_api.dart';
import 'app_language.dart';

class PrivateAccessManagementPage extends StatefulWidget {
  final AccessFlowApi api;
  const PrivateAccessManagementPage({super.key, required this.api});
  @override
  State<PrivateAccessManagementPage> createState() =>
      _PrivateAccessManagementPageState();
}

class _PrivateAccessManagementPageState
    extends State<PrivateAccessManagementPage> {
  Map<String, dynamic>? workspace;
  String? event,
      community,
      publicationTarget,
      publisherProfile,
      notice,
      restriction;
  final email = TextEditingController(), details = TextEditingController();
  bool busy = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(PrivateAccessManagementPage old) {
    super.didUpdateWidget(old);
    if (old.api != widget.api) {
      generation++;
      email.clear();
      details.clear();
      busy = false;
      workspace = null;
      event = null;
      community = null;
      publicationTarget = null;
      publisherProfile = null;
      notice = null;
      restriction = null;
      load();
    }
  }

  @override
  void dispose() {
    generation++;
    email.dispose();
    details.dispose();
    super.dispose();
  }

  void clearPrivateState() {
    workspace = null;
    event = community = publicationTarget = publisherProfile = restriction =
        null;
    email.clear();
    details.clear();
  }

  Future<bool> load() async {
    if (!mounted) return false;
    final epoch = ++generation;
    setState(() {
      busy = true;
      workspace = null;
      notice = null;
    });
    try {
      final r = await widget.api.access('policy/workspace');
      if (!mounted || epoch != generation) return false;
      setState(() {
        workspace = r;
        bool contains(String field, String? id) =>
            (r[field] as List? ?? []).any((item) => item['id'] == id);
        if (!contains('events', event)) event = null;
        if (!contains('communities', community)) community = null;
        if (!contains('publication_targets', publicationTarget)) {
          publicationTarget = null;
        }
        if (!contains('publisher_profiles', publisherProfile)) {
          publisherProfile = null;
        }
      });
      return true;
    } catch (e) {
      if (mounted && epoch == generation) {
        setState(() {
          workspace = null;
          if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
            clearPrivateState();
          }
          notice = e is ApiFailure
              ? e.message
              : 'Zuständigkeiten konnten nicht geprüft werden.';
        });
      }
      return false;
    } finally {
      if (mounted && epoch == generation) setState(() => busy = false);
    }
  }

  Future<void> run(Future<void> Function() action, {bool saved = true}) async {
    if (busy || !mounted) return;
    final epoch = generation;
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      await action();
      if (!mounted || epoch != generation) return;
      if (await load()) {
        if (mounted && saved) setState(() => notice = 'Vorgang gespeichert.');
      }
    } catch (e) {
      if (mounted && epoch == generation) {
        setState(() {
          if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
            clearPrivateState();
          }
          notice = e is ApiFailure
              ? e.message
              : 'Der Vorgang wurde nicht übernommen.';
        });
      }
    } finally {
      if (mounted && epoch == generation) setState(() => busy = false);
    }
  }

  Future<void> restrict({required bool inCommunity}) async {
    final epoch = generation;
    await run(() async {
      final r = await widget.api.access(
        'policy/restrictions',
        body: {
          'email': email.text.trim(),
          if (inCommunity) 'community_id': community else 'event_id': event,
          'expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(hours: 24))
              .toIso8601String(),
        },
      );
      if (mounted && epoch == generation) restriction = r['id'] as String;
    });
  }

  Future<void> readCase(String id) async {
    final epoch = generation;
    await run(() async {
      final r = await widget.api.access('policy/cases/$id');
      if (!mounted || epoch != generation) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const LocalText('Vertraulicher Moderationsfall'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LocalText(r['details'] as String),
                for (final appeal in (r['appeals'] as List? ?? const [])) ...[
                  const SizedBox(height: 16),
                  const LocalText('Einspruch'),
                  LocalText((appeal as Map)['details'] as String),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const LocalText('Schließen'),
            ),
          ],
        ),
      );
    }, saved: false);
  }

  Future<void> preview() async {
    final epoch = generation;
    await run(() async {
      final r = await widget.api.access(
        'policy/retention-preview',
        body: {'before': DateTime.now().toUtc().toIso8601String()},
      );
      if (!mounted || epoch != generation) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const LocalText('Aufbewahrungsvorschau'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LocalText(
                  'Es wird nichts gelöscht. Fristen sind noch nicht beschlossen.',
                ),
                for (final entry in (r['counts'] as Map).entries)
                  LocalText(
                    '${localText(context, retentionLabels[entry.key] ?? entry.key.toString())}: ${entry.value}',
                  ),
                const LocalText(
                  'Mitgliedschaften, Sperren und Finanznachweise bleiben erhalten. Externe Kopien sind nicht geprüft.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const LocalText('Schließen'),
            ),
          ],
        ),
      );
    }, saved: false);
  }

  bool get isModerator => (workspace?['communities'] as List? ?? []).any(
    (c) => c['id'] == community && c['moderator'] == true,
  );

  static const retentionLabels = {
    'private_addresses': 'Private Adressen',
    'application_text': 'Abgeschlossene Bewerbungen',
    'links': 'Abgelaufene Einladungen',
    'participations': 'Teilnahmen',
    'checkins': 'Einlassprüfungen',
    'media': 'Eventmedien',
    'moderation_cases': 'Moderationsfälle',
    'financial_records': 'Finanznachweise',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const LocalText('Freigaben und Moderation')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children:
          <Widget>[
                const LocalText(
                  'Lokaler Test. Jede Aktion wird serverseitig auf deine Zuständigkeit geprüft.',
                ),
                if (busy) const LinearProgressIndicator(),
                if (notice != null)
                  Semantics(liveRegion: true, child: LocalText(notice!)),
                OutlinedButton(
                  onPressed: busy ? null : load,
                  child: const LocalText('Aktualisieren'),
                ),
                if (workspace != null) ...[
                  TextField(
                    controller: email,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: localText(context, 'Bestätigte Konto-E-Mail'),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey('event:$event'),
                    initialValue: event,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: localText(context, 'Eigenes Event'),
                    ),
                    items: [
                      for (final e in workspace!['events'] as List)
                        DropdownMenuItem(
                          value: e['id'] as String,
                          child: LocalText(e['title'] as String),
                        ),
                    ],
                    onChanged: busy ? null : (v) => setState(() => event = v),
                  ),
                  FilledButton(
                    onPressed: busy || event == null
                        ? null
                        : () => restrict(inCommunity: false),
                    child: const LocalText('Eventzugang für 24 h sperren'),
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey('community:$community'),
                    initialValue: community,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: localText(context, 'Zuständige Community'),
                    ),
                    items: [
                      for (final c in workspace!['communities'] as List)
                        DropdownMenuItem(
                          value: c['id'] as String,
                          child: LocalText(c['name'] as String),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() => community = v),
                  ),
                  OutlinedButton(
                    onPressed: busy || community == null || !isModerator
                        ? null
                        : () => restrict(inCommunity: true),
                    child: const LocalText(
                      'Communityzugang für 24 h pausieren',
                    ),
                  ),
                  const LocalText(
                    'Eine Communitypause sperrt nur diesen Zugangsweg. Eine dauerhafte Maßnahme braucht eine unabhängige zweite Prüfung.',
                  ),
                  if (workspace!['is_team'] == true)
                    OutlinedButton(
                      onPressed: busy || community == null
                          ? null
                          : () => run(
                              () => widget.api.access(
                                'policy/staff',
                                body: {
                                  'community_id': community,
                                  'email': email.text.trim(),
                                  'expires_at': DateTime.now()
                                      .toUtc()
                                      .add(const Duration(hours: 24))
                                      .toIso8601String(),
                                },
                              ),
                            ),
                      child: const LocalText('Moderation für 24 h zuweisen'),
                    ),
                  DropdownButtonFormField<String>(
                    key: ValueKey('publisherProfile:$publisherProfile'),
                    initialValue: publisherProfile,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: localText(
                        context,
                        'Veranstalterauftritt für Veröffentlichungsrecht',
                      ),
                    ),
                    items: [
                      for (final p
                          in workspace!['publisher_profiles'] as List? ?? [])
                        DropdownMenuItem(
                          value: p['id'] as String,
                          child: LocalText(p['display_name'] as String),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() => publisherProfile = v),
                  ),
                  OutlinedButton(
                    onPressed: busy || !isModerator || publisherProfile == null
                        ? null
                        : () => run(
                            () => widget.api.access(
                              'policy/communities/$community/publishers',
                              body: {
                                'profile_id': publisherProfile,
                                'enabled': true,
                              },
                            ),
                          ),
                    child: const LocalText('Veröffentlichungsrecht vergeben'),
                  ),
                  TextButton(
                    onPressed: busy || !isModerator || publisherProfile == null
                        ? null
                        : () => run(
                            () => widget.api.access(
                              'policy/communities/$community/publishers',
                              body: {
                                'profile_id': publisherProfile,
                                'enabled': false,
                              },
                            ),
                          ),
                    child: const LocalText('Veröffentlichungsrecht entziehen'),
                  ),
                  const LocalText(
                    'Veröffentlichungsrechte verleihen keine Communityverwaltung oder Aufnahmebefugnis.',
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey('publicationTarget:$publicationTarget'),
                    initialValue: publicationTarget,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: localText(
                        context,
                        'Community für Eventfreigabe',
                      ),
                    ),
                    items: [
                      for (final c
                          in workspace!['publication_targets'] as List? ?? [])
                        DropdownMenuItem(
                          value: c['id'] as String,
                          child: LocalText(c['name'] as String),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() => publicationTarget = v),
                  ),
                  OutlinedButton(
                    onPressed:
                        busy || event == null || publicationTarget == null
                        ? null
                        : () => run(
                            () => widget.api.access(
                              'policy/events/$event/share',
                              body: {
                                'community_id': publicationTarget,
                                'grants_visibility': true,
                              },
                            ),
                          ),
                    child: const LocalText(
                      'Communityfreigabe für Event anfragen',
                    ),
                  ),
                  for (final request
                      in workspace!['publication_requests'] as List? ?? [])
                    ListTile(
                      title: LocalText(
                        '${request['title']} · ${request['community']}',
                      ),
                      trailing: TextButton(
                        onPressed: busy
                            ? null
                            : () => run(
                                () => widget.api.access(
                                  'policy/events/${request['id']}/approve-share',
                                  body: {
                                    'community_id': request['community_id'],
                                    'approved': true,
                                  },
                                ),
                              ),
                        child: const LocalText('Als Moderation freigeben'),
                      ),
                    ),
                  for (final r in workspace!['restrictions'] as List? ?? [])
                    ListTile(
                      title: LocalText(
                        r['community_id'] != null
                            ? 'Communitymaßnahme'
                            : 'Zugangsmaßnahme',
                      ),
                      subtitle: LocalText(
                        r['expires_at'] == null
                            ? 'Unabhängig überprüfte Maßnahme'
                            : 'Befristet bis ${r['expires_at']}',
                      ),
                      trailing: TextButton(
                        onPressed: busy
                            ? null
                            : () => run(
                                () => widget.api.access(
                                  'policy/restrictions/${r['id']}/revoke',
                                  body: {},
                                ),
                              ),
                        child: const LocalText('Aufheben'),
                      ),
                    ),
                  TextField(
                    controller: details,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: localText(
                        context,
                        'Vertraulicher Falltext oder eigener Einspruch',
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: busy || community == null || !isModerator
                        ? null
                        : () => run(
                            () => widget.api.access(
                              'policy/cases',
                              body: {
                                'community_id': community,
                                'email': email.text.trim(),
                                'details': details.text.trim(),
                                if (restriction != null)
                                  'restriction_id': restriction,
                              },
                            ),
                          ),
                    child: const LocalText('Moderationsfall anlegen'),
                  ),
                  OutlinedButton(
                    onPressed: busy || community == null || !isModerator
                        ? null
                        : () => run(
                            () => widget.api.access(
                              'policy/communities/$community/rules',
                              body: {
                                'rules': details.text.trim(),
                                'version':
                                    (workspace!['rules'] as List? ?? [])
                                        .where(
                                          (r) => r['community_id'] == community,
                                        )
                                        .firstOrNull?['version'] ??
                                    0,
                              },
                            ),
                          ),
                    child: const LocalText(
                      'Text als neue Communityregeln veröffentlichen',
                    ),
                  ),
                  for (final raw in workspace!['cases'] as List)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LocalText(
                              raw['affected'] == true
                                  ? 'Eigener Moderationsvorgang'
                                  : 'Zugewiesener Communityfall',
                            ),
                            if (raw['affected'] != true)
                              OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => readCase(raw['id'] as String),
                                child: const LocalText(
                                  'Vertraulichen Fall lesen',
                                ),
                              ),
                            if (raw['affected'] != true &&
                                raw['created_by_me'] != true)
                              OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => run(
                                        () => widget.api.access(
                                          'policy/cases/${raw['id']}/review',
                                          body: {},
                                        ),
                                      ),
                                child: const LocalText(
                                  'Dauerhafte Maßnahme unabhängig bestätigen',
                                ),
                              ),
                            if (raw['affected'] == true)
                              OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => run(
                                        () => widget.api.access(
                                          'policy/cases/${raw['id']}/appeal',
                                          body: {
                                            'details': details.text.trim(),
                                          },
                                        ),
                                      ),
                                child: const LocalText(
                                  'Eigenen Einspruch einreichen',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (workspace!['is_team'] == true)
                    OutlinedButton(
                      onPressed: busy ? null : preview,
                      child: const LocalText('Aufbewahrung nur ansehen'),
                    ),
                ],
              ]
              .map(
                (child) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: child,
                ),
              )
              .toList(),
    ),
  );
}

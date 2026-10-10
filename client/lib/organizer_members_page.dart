import 'package:flutter/material.dart';

import 'access_api.dart';
import 'access_flow_api.dart';
import 'app_language.dart';
import 'directory_api.dart';
import 'organizer_management_page.dart';

class OrganizerMembersPage extends StatefulWidget {
  final AccessFlowApi api;
  final String? profileId;
  const OrganizerMembersPage({super.key, required this.api, this.profileId});
  @override
  State<OrganizerMembersPage> createState() => _OrganizerMembersPageState();
}

class _OrganizerMembersPageState extends State<OrganizerMembersPage> {
  final email = TextEditingController();
  Map<String, dynamic>? data;
  String? notice;
  bool busy = false;
  int generation = 0;
  String get path => widget.profileId == null
      ? 'policy/organizer-invitations'
      : 'policy/organizers/${widget.profileId}/members';
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant OrganizerMembersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api ||
        oldWidget.profileId != widget.profileId) {
      generation++;
      data = null;
      notice = null;
      email.clear();
      load();
    }
  }

  @override
  void dispose() {
    generation++;
    email.dispose();
    super.dispose();
  }

  Future<bool> load() async {
    if (!mounted) return false;
    final epoch = ++generation;
    setState(() {
      busy = true;
      data = null;
      notice = null;
    });
    try {
      final result = await widget.api.access(path);
      if (!mounted || epoch != generation) return false;
      setState(() => data = result);
      return true;
    } catch (e) {
      if (!mounted || epoch != generation) return false;
      setState(() {
        if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
          email.clear();
        }
        notice = e is ApiFailure
            ? e.message
            : 'Die gemeinsame Verwaltung ist nicht verfügbar.';
      });
      return false;
    } finally {
      if (mounted && epoch == generation) setState(() => busy = false);
    }
  }

  Future<void> write(String route, Map<String, dynamic> body) async {
    if (busy) return;
    final epoch = generation;
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      await widget.api.access(route, body: body);
      if (!mounted || epoch != generation) return;
      if (await load()) {
        if (mounted) setState(() => notice = 'Vorgang gespeichert.');
      }
    } catch (e) {
      if (!mounted || epoch != generation) return;
      setState(() {
        data = null;
        if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
          email.clear();
        }
        notice = e is ApiFailure
            ? e.message
            : 'Der Vorgang wurde nicht übernommen.';
      });
    } finally {
      if (mounted && epoch == generation) setState(() => busy = false);
    }
  }

  String status(String value) => switch (value) {
    'invited' => localText(context, 'Einladung offen', 'Invitation pending'),
    'active' => localText(context, 'Verwaltung aktiv', 'Management active'),
    _ => localText(context, 'Verwaltung entzogen', 'Management revoked'),
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: LocalText(
        widget.profileId == null
            ? 'Auftritte und Einladungen'
            : 'Gemeinsam verwalten',
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        const LocalText(
          'Gemeinsame Verwaltung gilt nur für diesen Veranstalterauftritt. Sie verleiht keine Communitymoderation. Das verantwortliche Konto verwaltet Einladungen und die Zahlungszuordnung.',
        ),
        if (notice != null)
          Semantics(liveRegion: true, child: LocalText(notice!)),
        if (busy) const LinearProgressIndicator(),
        if (data != null) ...[
          if (data!['name'] != null) LocalText(data!['name'] as String),
          if (data!['owner'] != null)
            Text(
              '${localText(context, 'Verantwortliches Konto')}: ${(data!['owner'] as Map)['name']}',
            ),
          if (data!['is_owner'] == true) ...[
            TextField(
              controller: email,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: localText(context, 'Bestätigte Konto-E-Mail'),
              ),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () {
                      final previous = (data!['items'] as List).where(
                        (m) =>
                            m['email'].toString().toLowerCase() ==
                            email.text.trim().toLowerCase(),
                      );
                      write(path, {
                        'email': email.text.trim(),
                        'version': previous.isEmpty
                            ? 0
                            : previous.first['version'],
                      });
                    },
              child: const LocalText('Zur gemeinsamen Verwaltung einladen'),
            ),
          ],
          if ((data!['items'] as List).isEmpty)
            const LocalText('Keine weiteren Konten oder Einladungen.'),
          for (final raw in data!['items'] as List)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(raw['name'] as String),
                    if (raw['email'] != null) Text(raw['email'] as String),
                    Text(status(raw['status'] as String)),
                    if (widget.profileId == null && raw['status'] == 'invited')
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () => write(
                                'policy/organizer-members/${raw['id']}/accept',
                                {'version': raw['version']},
                              ),
                        child: const LocalText(
                          'Einladung zur Verwaltung annehmen',
                        ),
                      ),
                    if (widget.profileId == null &&
                        raw['status'] == 'active' &&
                        widget.api is DirectoryApi)
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () async {
                                await Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => OrganizerManagementPage(
                                      api: widget.api as DirectoryApi,
                                      initialProfileId:
                                          raw['profile_id'] as String,
                                    ),
                                  ),
                                );
                                if (mounted) await load();
                              },
                        child: const LocalText('Auftritt verwalten'),
                      ),
                    if (data!['is_owner'] == true && raw['status'] != 'revoked')
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => write(
                                'policy/organizer-members/${raw['id']}/revoke',
                                {'version': raw['version']},
                              ),
                        child: const LocalText('Verwaltung entziehen'),
                      ),
                  ],
                ),
              ),
            ),
        ],
        OutlinedButton(
          onPressed: busy ? null : load,
          child: const LocalText('Aktualisieren'),
        ),
      ].map((child) => Padding(padding: const EdgeInsets.only(bottom: 12), child: child)).toList(),
    ),
  );
}

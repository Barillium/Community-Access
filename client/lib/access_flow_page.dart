import 'flyer_design.dart';

import 'package:flutter/material.dart';

import 'access_api.dart';
import 'access_flow_api.dart';
import 'app_language.dart';
import 'design_system.dart';
import 'directory_api.dart';
import 'organizer_management_page.dart';
import 'event_interest_panel.dart';

/// All decisions go through the authenticated API; the UI grants no roles.
class AccessFlowPage extends StatefulWidget {
  final AccessApi api;
  final String? initialInvitation;
  final Future<void> Function()? onReauthenticate;
  const AccessFlowPage({
    super.key,
    required this.api,
    this.initialInvitation,
    this.onReauthenticate,
  });
  @override
  State<AccessFlowPage> createState() => _AccessFlowPageState();
}

class _AccessFlowPageState extends State<AccessFlowPage> {
  AccessFlowApi get access => widget.api as AccessFlowApi;
  Map<String, dynamic>? snapshot, hostData, teamData, invitation;
  String? selectedCommunity, notice, issuedLink;
  String section = 'guest';
  bool busy = false, needsLogin = false;
  int generation = 0, contextGeneration = 0;
  final token = TextEditingController(),
      recipient = TextEditingController(),
      contact = TextEditingController();
  final organizerForm = GlobalKey<FormState>();
  final organizerFields = {
    for (final key in [
      'name',
      'description',
      'event_types',
      'history',
      'venues',
      'organization',
    ])
      key: TextEditingController(),
  };
  final answers = <String, TextEditingController>{};
  final selectedQuestions = <String, bool>{};
  bool? concept, awarenessTeam;
  static const questions = [
    'Was interessiert dich an unserem Programm?',
    'Welche Musik möchtest du hören?',
    'Welche Veranstaltungsformate interessieren dich?',
    'Hast du die Veranstaltungsregeln gelesen?',
  ];
  @override
  void initState() {
    super.initState();
    token.text = widget.initialInvitation ?? '';
    run(refresh, refreshAfter: false);
  }

  @override
  void didUpdateWidget(covariant AccessFlowPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api ||
        oldWidget.initialInvitation != widget.initialInvitation) {
      generation++;
      contextGeneration++;
      snapshot = hostData = teamData = invitation = null;
      selectedCommunity = notice = issuedLink = null;
      section = 'guest';
      busy = needsLogin = false;
      concept = awarenessTeam = null;
      token.text = widget.initialInvitation ?? '';
      recipient.clear();
      contact.clear();
      selectedQuestions.clear();
      for (final c in [...organizerFields.values, ...answers.values]) {
        c.clear();
      }
      run(refresh, refreshAfter: false);
    }
  }

  @override
  void dispose() {
    generation++;
    contextGeneration++;
    for (final c in [
      token,
      recipient,
      contact,
      ...organizerFields.values,
      ...answers.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> refresh() async {
    final epoch = ++generation;
    final result = await widget.api.snapshot();
    if (!mounted || epoch != generation) return;
    setState(() {
      snapshot = result;
      needsLogin = false;
      if (result['is_team'] != true) {
        teamData = null;
        if (section == 'team') section = 'guest';
      }
      final communities = result['moderated_communities'] as List? ?? [];
      if (!communities.any((c) => c['id'] == selectedCommunity)) {
        selectedCommunity = null;
        hostData = null;
        issuedLink = null;
        contact.clear();
        selectedQuestions.clear();
      }
      if (section == 'host' && communities.isEmpty) section = 'guest';
    });
    if (section == 'team' && result['is_team'] == true) {
      final data = await access.access('team');
      if (mounted && epoch == generation) setState(() => teamData = data);
    }
    if (section == 'host' && selectedCommunity != null) {
      final data = await access.access('communities/$selectedCommunity');
      if (!mounted || epoch != generation) return;
      setState(() {
        hostData = data;
        contact.text = data['form']['host_contact'] as String? ?? '';
        selectedQuestions.clear();
        for (final f in data['form']['fields'] as List) {
          selectedQuestions[f['label'] as String] = f['required'] == true;
        }
      });
    }
  }

  Future<void> run(
    Future<void> Function() action, {
    bool refreshAfter = true,
  }) async {
    if (busy || !mounted) return;
    final operationContext = contextGeneration;
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      await action();
      if (!mounted || operationContext != contextGeneration) return;
      if (refreshAfter) await refresh();
    } catch (error) {
      if (mounted && operationContext == contextGeneration) {
        setState(() {
          notice = error is ApiFailure
              ? error.message
              : 'Die Aktion konnte nicht abgeschlossen werden.';
          // Clear private response bodies on denial, including an expired session.
          hostData = null;
          teamData = null;
          invitation = null;
          issuedLink = null;
          if (error is ApiFailure &&
              (error.unauthenticated || error.accessDenied)) {
            needsLogin = error.unauthenticated;
            generation++;
            snapshot = null;
            token.clear();
            recipient.clear();
            contact.clear();
            selectedCommunity = null;
            concept = null;
            awarenessTeam = null;
            for (final c in organizerFields.values) {
              c.clear();
            }
            for (final c in answers.values) {
              c.clear();
            }
          }
        });
      }
    } finally {
      if (mounted && operationContext == contextGeneration) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> post(String path, Map<String, dynamic> body) async {
    await access.access(path, body: body);
  }

  Widget button(
    String de,
    String en,
    Future<void> Function() action, {
    bool refreshAfter = true,
  }) => Padding(
    padding: const EdgeInsets.only(top: AccessSpacing.s12),
    child: OutlinedButton(
      onPressed: busy ? null : () => run(action, refreshAfter: refreshAfter),
      child: Text(localText(context, de, en)),
    ),
  );
  Widget field(
    String label,
    TextEditingController controller, {
    bool required = false,
    int maxLength = 4000,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AccessSpacing.s12),
    child: AccessField(
      decoration: InputDecoration(labelText: label),
      builder: (decoration) => TextFormField(
        controller: controller,
        enabled: !busy,
        maxLength: maxLength,
        decoration: decoration,
        validator: required
            ? (v) => (v ?? '').trim().isEmpty
                  ? localText(context, 'Bitte ausfüllen.', 'Please complete.')
                  : null
            : null,
      ),
    ),
  );

  String status(String value) => switch (value) {
    'pending' => localText(context, 'In Bearbeitung', 'Pending'),
    'approved' => localText(context, 'Angenommen', 'Approved'),
    'rejected' => localText(context, 'Abgelehnt', 'Rejected'),
    'withdrawn' => localText(context, 'Zurückgezogen', 'Withdrawn'),
    'revoked' => localText(context, 'Entzogen', 'Revoked'),
    _ => value,
  };
  Widget card(List<Widget> children) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AccessSpacing.s16),
    child: AccessSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
  Widget organizer() => Form(
    key: organizerForm,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccessHeading(
          localText(context, 'Veranstalteraufnahme', 'Organizer admission'),
          level: 2,
          role: AccessHeadingRole.section,
        ),
        Text(
          localText(
            context,
            'Die Aufnahme wird durch das Projektteam geprüft. Ein Konto allein erteilt keine Gastgeberrechte.',
            'The project team reviews admission. An account alone grants no host rights.',
          ),
        ),
        for (final a in snapshot?['organizer_applications'] as List? ?? [])
          card([
            Text(status(a['status'] as String)),
            if (a['status'] == 'pending')
              button(
                'Bewerbung zurückziehen',
                'Withdraw application',
                () => post('organizer-applications/${a['id']}/withdraw', {}),
              ),
          ]),
        if (snapshot?['organizer_blocked'] == true)
          Text(
            localText(
              context,
              'Erneute Bewerbung gesperrt. Bitte kontaktiere das Projektteam.',
              'Reapplication is blocked. Please contact the project team.',
            ),
          )
        else if (!(snapshot?['organizer_applications'] as List? ?? []).any(
          (a) => ['pending', 'approved'].contains(a['status']),
        )) ...[
          field(
            localText(context, 'Name des Kollektivs', 'Collective name'),
            organizerFields['name']!,
            required: true,
            maxLength: 120,
          ),
          field(
            localText(context, 'Selbstdarstellung', 'About the collective'),
            organizerFields['description']!,
            required: true,
          ),
          field(
            localText(context, 'Veranstaltungstypen', 'Event types'),
            organizerFields['event_types']!,
            required: true,
          ),
          for (final entry in {
            'history': localText(
              context,
              'Bisherige Events (optional)',
              'Previous events (optional)',
            ),
            'venues': localText(
              context,
              'Orte (optional)',
              'Venues (optional)',
            ),
            'organization': localText(
              context,
              'Organisationsbeschreibung (optional)',
              'Organization (optional)',
            ),
          }.entries)
            field(entry.value, organizerFields[entry.key]!),
          AccessField(
            decoration: InputDecoration(
              labelText: localText(
                context,
                'Awarenesskonzept vorhanden?',
                'Awareness concept available?',
              ),
            ),
            builder: (decoration) => DropdownButtonFormField<bool>(
              initialValue: concept,
              decoration: decoration,
              items: [
                DropdownMenuItem(
                  value: true,
                  child: Text(localText(context, 'Ja', 'Yes')),
                ),
                DropdownMenuItem(
                  value: false,
                  child: Text(localText(context, 'Nein', 'No')),
                ),
              ],
              onChanged: busy ? null : (v) => setState(() => concept = v),
              validator: (v) => v == null
                  ? localText(context, 'Bitte beantworten.', 'Please answer.')
                  : null,
            ),
          ),
          const SizedBox(height: AccessSpacing.s16),
          AccessField(
            decoration: InputDecoration(
              labelText: localText(
                context,
                'Awarenessteam vorhanden?',
                'Awareness team available?',
              ),
            ),
            builder: (decoration) => DropdownButtonFormField<bool>(
              initialValue: awarenessTeam,
              decoration: decoration,
              items: [
                DropdownMenuItem(
                  value: true,
                  child: Text(localText(context, 'Ja', 'Yes')),
                ),
                DropdownMenuItem(
                  value: false,
                  child: Text(localText(context, 'Nein', 'No')),
                ),
              ],
              onChanged: busy ? null : (v) => setState(() => awarenessTeam = v),
              validator: (v) => v == null
                  ? localText(context, 'Bitte beantworten.', 'Please answer.')
                  : null,
            ),
          ),
          button(
            'Veranstalterbewerbung einreichen',
            'Submit organizer application',
            () async {
              if (!organizerForm.currentState!.validate()) return;
              await post('organizer-applications', {
                for (final e in organizerFields.entries)
                  e.key: e.value.text.trim(),
                'awareness_concept': concept,
                'awareness_team': awarenessTeam,
              });
              for (final c in organizerFields.values) {
                c.clear();
              }
            },
          ),
        ],
      ],
    ),
  );
  Widget guest() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AccessHeading(
        localText(context, 'Mein Zugang', 'My access'),
        level: 2,
        role: AccessHeadingRole.section,
      ),
      field(
        localText(context, 'Persönliche Einladung', 'Personal invitation'),
        token,
        maxLength: 300,
      ),
      button('Einladung prüfen', 'Check invitation', () async {
        final epoch = generation;
        final raw = token.text.trim();
        final t = raw.contains('#invite=')
            ? Uri.tryParse(raw)?.fragment.replaceFirst('invite=', '')
            : raw;
        if (t == null || !RegExp(r'^[0-9a-f]{64}$').hasMatch(t)) {
          throw const ApiFailure(
            'Bitte einen gültigen lokalen Einladungslink oder Token eintragen.',
          );
        }
        token.text = t;
        final result = await access.access(
          'invitations/preview',
          body: {'token': t},
        );
        if (!mounted || epoch != generation) return;
        for (final c in answers.values) {
          c.dispose();
        }
        answers.clear();
        for (final f in result['form']['questions'] as List) {
          answers[f['key'] as String] = TextEditingController();
        }
        setState(() => invitation = result);
      }),
      if (invitation != null)
        card([
          Text(invitation!['community'] as String),
          if (invitation!['rule'] != null)
            Text(invitation!['rule']['rules'] as String),
          for (final f in invitation!['form']['questions'] as List)
            field(
              '${f['label']}${f['required'] == true ? ' *' : ''}',
              answers[f['key']]!,
              maxLength: 2000,
            ),
          button(
            'Gastbewerbung einreichen',
            'Submit guest application',
            () async {
              await post('applications', {
                'token': token.text,
                'version': invitation!['form']['version'],
                if (invitation!['rule'] != null)
                  'rule_version_id': invitation!['rule']['id'],
                'answers': {
                  for (final e in answers.entries) e.key: e.value.text.trim(),
                },
              });
              if (mounted) setState(() => invitation = null);
              token.clear();
              for (final c in answers.values) {
                c.clear();
              }
            },
          ),
        ]),
      if ((snapshot?['applications'] as List? ?? []).isNotEmpty)
        AccessHeading(
          localText(context, 'Bewerbungsstand', 'Application status'),
          level: 3,
          role: AccessHeadingRole.card,
        ),
      for (final a in snapshot?['applications'] as List? ?? [])
        card([
          Text('${a['community']} · ${status(a['status'] as String)}'),
          if (a['status'] == 'pending')
            button(
              'Gastbewerbung zurückziehen',
              'Withdraw guest application',
              () => post('applications/${a['id']}/withdraw', {}),
            ),
        ]),
      if ((snapshot?['memberships'] as List? ?? []).isNotEmpty)
        AccessHeading(
          localText(
            context,
            'Aktuelle Mitgliedschaften',
            'Current memberships',
          ),
          level: 3,
          role: AccessHeadingRole.card,
        ),
      for (final m in snapshot?['memberships'] as List? ?? [])
        Text(
          '${m['community']} · ${m['active'] == true ? localText(context, 'Mitglied', 'Member') : localText(context, 'Mitgliedschaft entzogen', 'Membership revoked')}',
        ),
      if ((snapshot?['application_blocks'] as List? ?? []).isNotEmpty)
        AccessHeading(
          localText(
            context,
            'Erneute Bewerbung gesperrt',
            'Reapplication blocked',
          ),
          level: 3,
          role: AccessHeadingRole.card,
        ),
      for (final b in snapshot?['application_blocks'] as List? ?? [])
        card([
          Text('${b['community']} · ${status(b['reason'] as String)}'),
          Text(b['host_contact'] as String? ?? ''),
        ]),
      for (final e in snapshot?['events'] as List? ?? [])
        card([
          Text(e['title'] as String),
          if (widget.api is DirectoryApi)
            EventInterestPanel(
              key: ValueKey('${e['id']}:${e['request_status']}:$generation'),
              api: widget.api as DirectoryApi,
              id: e['id'] as String,
              onChanged: () => run(refresh, refreshAfter: false),
            ),
          if (e['confirmed'] == true)
            button(
              'Geschützte Location abrufen',
              'Load protected location',
              () async {
                final epoch = generation;
                final result = await access.access(
                  'events/${e['id']}/location',
                );
                if (mounted && epoch == generation) {
                  await showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(
                        localText(
                          context,
                          'Geschützte Location',
                          'Protected location',
                        ),
                      ),
                      content: Text(result['location'] as String),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(localText(context, 'Schließen', 'Close')),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
        ]),
    ],
  );
  Widget hosts() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(
        initialValue: selectedCommunity,
        decoration: InputDecoration(
          labelText: localText(
            context,
            'Community auswählen',
            'Choose community',
          ),
        ),
        items: [
          for (final c in snapshot?['moderated_communities'] as List? ?? [])
            DropdownMenuItem(
              value: c['id'] as String,
              child: Text(c['name'] as String),
            ),
        ],
        onChanged: busy
            ? null
            : (v) => run(() async {
                setState(() {
                  selectedCommunity = v;
                  hostData = null;
                  issuedLink = null;
                });
              }),
      ),
      if (widget.api is DirectoryApi)
        button(
          'Veranstalterprofile und Events verwalten',
          'Manage organizer profiles and events',
          () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    OrganizerManagementPage(api: widget.api as DirectoryApi),
              ),
            );
          },
        ),
      if (hostData != null) ...[
        card([
          Text(
            localText(
              context,
              'Gastbewerbungsformular',
              'Guest application form',
            ),
          ),
          for (final q in questions)
            CheckboxListTile(
              title: Text(q),
              value: selectedQuestions.containsKey(q),
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      if (v == true) {
                        selectedQuestions[q] = true;
                      } else {
                        selectedQuestions.remove(q);
                      }
                    }),
            ),
          for (final q in selectedQuestions.keys.toList())
            CheckboxListTile(
              title: Text(
                '$q · ${localText(context, 'Pflichtfeld', 'Required')}',
              ),
              value: selectedQuestions[q],
              onChanged: busy
                  ? null
                  : (v) => setState(() => selectedQuestions[q] = v ?? false),
            ),
          field(
            localText(
              context,
              'Kontakttext für abgelehnte Gäste',
              'Contact text for rejected guests',
            ),
            contact,
            maxLength: 1000,
          ),
          button(
            'Formular speichern',
            'Save form',
            () => post('communities/$selectedCommunity/form', {
              'version': hostData!['form']['version'],
              'fields': [
                for (final q in selectedQuestions.keys)
                  {
                    'key': 'q${questions.indexOf(q)}',
                    'label': q,
                    'required': selectedQuestions[q],
                  },
              ],
              'host_contact': contact.text.trim(),
            }),
          ),
        ]),
        card([
          field(
            localText(
              context,
              'E-Mail des bestätigten Gastkontos',
              'Verified guest account email',
            ),
            recipient,
            maxLength: 255,
          ),
          button(
            'Persönliche Einladung erstellen',
            'Create personal invitation',
            () async {
              final epoch = generation;
              final r = await access.access(
                'communities/$selectedCommunity/invite',
                body: {'email': recipient.text.trim()},
              );
              if (mounted && epoch == generation) {
                setState(() => issuedLink = r['url'] as String);
              }
            },
          ),
          if (issuedLink != null) SelectableText(issuedLink!),
          for (final l in hostData!['invitations'] as List)
            if (l['used_at'] == null && l['revoked'] != true)
              button(
                'Einladung widerrufen (${l['id'].toString().substring(0, 8)})',
                'Revoke invitation (${l['id'].toString().substring(0, 8)})',
                () => post('invitations/${l['id']}/revoke', {}),
              ),
        ]),
        for (final a in hostData!['applications'] as List)
          card([
            Text('${a['applicant']} · ${status(a['status'] as String)}'),
            for (final f in a['form_snapshot'] as List)
              Text('${f['label']}: ${a['answers'][f['key']] ?? ''}'),
            if (a['status'] == 'pending') ...[
              button(
                'Gast aufnehmen',
                'Admit guest',
                () => post('applications/${a['id']}/decide', {
                  'status': 'approved',
                }),
              ),
              button(
                'Gastbewerbung ablehnen',
                'Reject guest application',
                () => post('applications/${a['id']}/decide', {
                  'status': 'rejected',
                }),
              ),
            ],
          ]),
        for (final m in hostData!['memberships'] as List)
          if (m['active'] == true)
            card([
              Text(m['guest'] as String),
              button('Mitgliedschaft entziehen', 'Revoke membership', () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      localText(
                        context,
                        'Mitgliedschaft entziehen?',
                        'Revoke membership?',
                      ),
                    ),
                    content: Text(
                      localText(
                        context,
                        'Abhängige Anfragen und Zusagen werden widerrufen; reservierte Plätze werden frei.',
                        'Dependent requests and approvals will be revoked; reserved places will be released.',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(localText(context, 'Abbrechen', 'Cancel')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(localText(context, 'Entziehen', 'Revoke')),
                      ),
                    ],
                  ),
                );
                if (ok == true) await post('memberships/${m['id']}/revoke', {});
              }),
            ]),
      ],
    ],
  );
  String organizerLabel(String key) => localText(
    context,
    const {
          'name': 'Name des Kollektivs',
          'description': 'Selbstdarstellung',
          'event_types': 'Veranstaltungstypen',
          'history': 'Bisherige Events',
          'venues': 'Orte',
          'organization': 'Organisation',
          'awareness_concept': 'Awarenesskonzept',
          'awareness_team': 'Awarenessteam',
        }[key] ??
        key,
    const {
          'name': 'Collective name',
          'description': 'About the collective',
          'event_types': 'Event types',
          'history': 'Previous events',
          'venues': 'Venues',
          'organization': 'Organization',
          'awareness_concept': 'Awareness concept',
          'awareness_team': 'Awareness team',
        }[key] ??
        key,
  );
  Widget team() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final a in teamData?['applications'] as List? ?? [])
        card([
          Text('${a['applicant']} · ${status(a['status'] as String)}'),
          Text(a['contact'] as String? ?? ''),
          for (final e in (a['answers'] as Map).entries)
            Text(
              '${organizerLabel(e.key as String)}: ${e.value is bool ? localText(context, e.value ? 'Ja' : 'Nein', e.value ? 'Yes' : 'No') : e.value}',
            ),
          if (a['status'] == 'pending') ...[
            button(
              'Veranstalter aufnehmen',
              'Admit organizer',
              () => post('organizer-applications/${a['id']}/decide', {
                'status': 'approved',
              }),
            ),
            button(
              'Veranstalter ablehnen',
              'Reject organizer',
              () => post('organizer-applications/${a['id']}/decide', {
                'status': 'rejected',
              }),
            ),
          ],
        ]),
      for (final b in teamData?['blocks'] as List? ?? [])
        button(
          'Sperre aufheben: ${b['name']}',
          'Unblock: ${b['name']}',
          () => post('team/unblock', {'user_id': b['user_id']}),
        ),
      for (final h in teamData?['hosts'] as List? ?? [])
        button(
          'Gastgeberrechte entziehen: ${h['name']} · ${h['community']}',
          'Revoke host rights: ${h['name']} · ${h['community']}',
          () => post('team/revoke-host', {
            'user_id': h['user_id'],
            'community_id': h['community_id'],
          }),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(localText(context, 'Zugang verwalten', 'Manage access')),
      actions: [
        const FlyerLanguageButton(),
        IconButton(
          tooltip: localText(context, 'Aktualisieren', 'Refresh'),
          onPressed: busy ? null : () => run(refresh, refreshAfter: false),
          icon: const AccessIcon(Icons.refresh),
        ),
      ],
    ),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        width: AccessPageWidth.detail,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AccessHeading(
              'Zugang verwalten',
              role: AccessHeadingRole.page,
              level: 1,
            ),
            const SizedBox(height: AccessSpacing.s24),
            if (busy) const LinearProgressIndicator(),
            if (notice != null)
              Semantics(liveRegion: true, child: LocalText(notice!)),
            if (needsLogin)
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (widget.onReauthenticate != null) {
                          await widget.onReauthenticate!();
                          if (mounted) {
                            needsLogin = false;
                            await run(refresh, refreshAfter: false);
                          }
                        } else {
                          Navigator.pop(context);
                        }
                      },
                child: const LocalText('Erneut anmelden'),
              ),
            if (snapshot != null) ...[
              Wrap(
                spacing: AccessSpacing.s12,
                children: [
                  for (final item in {
                    'guest': localText(context, 'Mein Zugang', 'My access'),
                    'organizer': localText(
                      context,
                      'Veranstalteraufnahme',
                      'Organizer admission',
                    ),
                    if ((snapshot!['moderated_communities'] as List? ?? [])
                        .isNotEmpty)
                      'host': localText(
                        context,
                        'Communityverwaltung',
                        'Community management',
                      ),
                    if (snapshot!['is_team'] == true)
                      'team': localText(context, 'Teamprüfung', 'Team review'),
                  }.entries)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => run(() async {
                              setState(() {
                                section = item.key;
                                notice = null;
                              });
                            }),
                      child: Text(item.value),
                    ),
                ],
              ),
              const SizedBox(height: AccessSpacing.s24),
              if (section == 'guest') guest(),
              if (section == 'organizer') organizer(),
              if (section == 'host') hosts(),
              if (section == 'team') team(),
            ] else
              button('Erneut laden', 'Retry', refresh, refreshAfter: false),
          ],
        ),
      ),
    ),
  );
}

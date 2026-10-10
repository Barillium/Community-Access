import 'package:flutter/material.dart';

import 'access_api.dart';
import 'app_language.dart';
import 'design_system.dart';
import 'legal_api.dart';
import 'ticketing_api.dart';

const legalAccessNotice =
    'Eingeschränkter Zugang ist keine rechtliche Einstufung als Privatveranstaltung. Communityaufnahme und Kaufberechtigung ersetzen keine erforderliche Genehmigung.';
const legalDeclarationVersion = 'local-responsibility-draft-20261009';
const legalDeclarationNotice =
    'Ich bestätige, dass ich als Veranstalter und Ticketverkäufer die Verantwortung für die Durchführung dieser Veranstaltung trage. Ich bin dafür verantwortlich, erforderliche Genehmigungen und Nutzungsrechte einzuholen und die geltenden Sicherheitsvorgaben einzuhalten. Community Access vermittelt technisch und führt keine behördliche Genehmigungsprüfung durch. Eigene gesetzliche Pflichten der Plattform bleiben bestehen.';
String legalStateLabel(String? state) => switch (state) {
  'sales_paused' => 'Ticketverkauf zur Klärung pausiert',
  'blocked' => 'Veranstaltung gesperrt · Einlass angehalten',
  'no_action' => 'Meldung geprüft · keine Maßnahme',
  _ => 'Keine Verkaufssperre durch das Plattformteam',
};

String legalActionLabel(String action) => switch (action) {
  'sales_paused' => 'Verkauf pausieren',
  'blocked' => 'Angebot und Einlass sperren',
  'active' => 'Verkauf wieder öffnen',
  _ => 'Keine Maßnahme',
};

String legalBasisLabel(String? basis) => switch (basis) {
  'prohibition' => 'Bestätigtes Verbot',
  'danger' => 'Konkrete Gefahr',
  'cancellation' => 'Absage',
  'resolved' => 'Klärung abgeschlossen',
  'unsubstantiated' => 'Keine ausreichende Grundlage für eine Maßnahme',
  _ => 'Genehmigungslage klären',
};

class SellerInformation extends StatelessWidget {
  final Map<String, dynamic>? seller;
  final Map<String, dynamic>? declaration;
  const SellerInformation({super.key, required this.seller, this.declaration});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const LocalText('Vertragspartner für dein Ticket'),
      if (seller == null || seller!.isEmpty)
        const LocalText(
          'Verkäuferangaben fehlen. Der Verkauf bleibt geschlossen.',
        )
      else ...[
        Text(seller!['legal_name'] as String? ?? ''),
        Text(seller!['address'] as String? ?? ''),
        Text(seller!['contact'] as String? ?? ''),
        LocalText(
          seller!['seller_status'] == 'business'
              ? 'Unternehmerangabe des Verkäufers'
              : 'Privatverkäuferangabe · keine rechtliche Prüfung',
        ),
        const LocalText(
          'Dein Vertragspartner für das Ticket ist der angegebene Veranstalter. Er verantwortet Durchführung, erforderliche Genehmigungen, Nutzungsrechte und Sicherheit. Community Access vermittelt technisch und führt keine behördliche Genehmigungsprüfung durch. Eigene gesetzliche Pflichten der Plattform bleiben bestehen.',
        ),
        if (declaration?['terms_version'] != null)
          Text(
            '${localText(context, 'Bedingungenstand')}: ${declaration!['terms_version']}',
          ),
      ],
    ],
  );
}

class ReportEventButton extends StatelessWidget {
  final LegalApi api;
  final String eventId;
  const ReportEventButton({
    super.key,
    required this.api,
    required this.eventId,
  });
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LegalReportPage(api: api, eventId: eventId),
      ),
    ),
    child: const LocalText('Veranstaltung melden'),
  );
}

class LegalReportPage extends StatefulWidget {
  final LegalApi api;
  final String? eventId;
  const LegalReportPage({super.key, required this.api, this.eventId});
  @override
  State<LegalReportPage> createState() => _LegalReportPageState();
}

class _LegalReportPageState extends State<LegalReportPage> {
  final form = GlobalKey<FormState>();
  final reference = TextEditingController(),
      details = TextEditingController(),
      name = TextEditingController(),
      email = TextEditingController();
  bool faith = false, exception = false, busy = false;
  String? notice;
  bool received = false;
  @override
  void initState() {
    super.initState();
    reference.text = widget.eventId == null ? '' : 'events/${widget.eventId}';
  }

  @override
  void dispose() {
    for (final c in [reference, details, name, email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || received || !form.currentState!.validate() || !faith) return;
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      final r = await widget.api.legal(
        'reports',
        body: {
          if (widget.eventId != null) 'event_id': widget.eventId,
          'reference': reference.text.trim(),
          'details': details.text.trim(),
          'name': name.text.trim(),
          'email': email.text.trim(),
          'good_faith': faith,
          'contact_exception': exception,
        },
      );
      if (mounted) {
        setState(() {
          received = true;
          notice =
              '${localText(context, 'Meldung empfangen')}: ${r['reference']}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => notice = e is ApiFailure
              ? e.message
              : 'Die Meldung konnte nicht gesendet werden.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: accessAppBar(context, 'Veranstaltung melden'),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        width: AccessPageWidth.form,
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LocalText(
                'Lokaler Test: nur erfundene Angaben und E-Mail-Adressen mit @example.invalid verwenden. Es wird keine E-Mail versendet.',
              ),
              const LocalText(
                'Beschreibe den konkreten Verdacht. Eine Meldung allein sperrt die Veranstaltung nicht. Keine Passwörter, Einladungslinks, Gästelisten oder unnötigen persönlichen Angaben senden.',
              ),
              if (notice != null)
                Semantics(liveRegion: true, child: LocalText(notice!)),
              if (!received) ...[
                field(context, reference, 'Inhaltsreferenz', 500),
                field(
                  context,
                  details,
                  'Warum könnte das Angebot rechtswidrig sein?',
                  4000,
                  lines: 5,
                ),
                CheckboxListTile(
                  value: exception,
                  onChanged: busy
                      ? null
                      : (v) => setState(() => exception = v ?? false),
                  title: const LocalText(
                    'Hinweis auf sexuellen Missbrauch von Kindern: Kontaktangaben können entfallen.',
                  ),
                ),
                field(context, name, 'Dein Name', 200, optional: exception),
                TextFormField(
                  controller: email,
                  maxLength: 255,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    errorStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    labelText: localText(context, 'Kontakt-E-Mail'),
                  ),
                  validator: (v) {
                    if (exception && (v ?? '').trim().isEmpty) return null;
                    return RegExp(r'^[^\s@]+@example\.invalid$')
                            .hasMatch((v ?? '').trim())
                        ? null
                        : localText(
                            context,
                            'Synthetische E-Mail mit @example.invalid erforderlich.',
                          );
                  },
                ),
                CheckboxListTile(
                  value: faith,
                  onChanged: busy
                      ? null
                      : (v) => setState(() => faith = v ?? false),
                  title: const LocalText(
                    'Ich melde nach bestem Wissen und halte meine Angaben für richtig und vollständig.',
                  ),
                ),
                const LocalText(
                  'Meldungen werden nur vom zuständigen Plattformteam bearbeitet. Kontaktangaben werden nicht automatisch an Veranstalter weitergegeben. Aufbewahrung und reale Zustellung müssen vor echtem Betrieb festgelegt werden.',
                ),
                FilledButton(
                  onPressed: busy || !faith ? null : submit,
                  child: const LocalText('Meldung einreichen'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

Widget field(
  BuildContext context,
  TextEditingController controller,
  String label,
  int max, {
  int lines = 1,
  bool optional = false,
}) => TextFormField(
  controller: controller,
  maxLength: max,
  maxLines: lines,
  decoration: InputDecoration(
    labelText: localText(context, label),
    errorStyle: TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    ),
  ),
  validator: (v) => !optional && (v ?? '').trim().isEmpty
      ? localText(context, 'Bitte ausfüllen.')
      : null,
);

class SellerManagementPage extends StatefulWidget {
  final TicketingApi api;
  final String profileId;
  const SellerManagementPage({
    super.key,
    required this.api,
    required this.profileId,
  });
  @override
  State<SellerManagementPage> createState() => _SellerManagementPageState();
}

class _SellerManagementPageState extends State<SellerManagementPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      address = TextEditingController(),
      contact = TextEditingController();
  int version = 0;
  String? status, notice;
  bool busy = true, canEdit = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final c in [name, address, contact]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> load() async {
    try {
      final r = await widget.api.ticketing(
        'profiles/${widget.profileId}/seller',
      );
      if (!mounted) return false;
      final s = r['seller'] as Map?;
      setState(() {
        name.text = s?['legal_name'] as String? ?? '';
        address.text = s?['address'] as String? ?? '';
        contact.text = s?['contact'] as String? ?? '';
        status = s?['seller_status'] as String?;
        version = s?['version'] as int? ?? 0;
        canEdit = r['can_edit'] == true;
      });
      return mounted;
    } catch (e) {
      if (mounted) {
        setState(() {
          canEdit = false;
          if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
            name.clear();
            address.clear();
            contact.clear();
            status = null;
          }
          notice = e is ApiFailure
              ? e.message
              : 'Verkäuferangaben konnten nicht geladen werden.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
    return false;
  }

  Future<void> save() async {
    if (busy || !canEdit || !form.currentState!.validate() || status == null) {
      return;
    }
    final session = TicketingSessionGuard(widget.api);
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      await widget.api.ticketing(
        'profiles/${widget.profileId}/seller',
        body: {
          'legal_name': name.text.trim(),
          'address': address.text.trim(),
          'contact': contact.text.trim(),
          'seller_status': status,
          'version': version,
        },
      );
      session.check();
      final refreshed = await load();
      session.check();
      if (mounted && refreshed) {
        setState(
          () => notice = localText(
            context,
            'Verkäuferangaben gespeichert. Veranstalterbestätigungen bitte erneut prüfen.',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
            canEdit = false;
            name.clear();
            address.clear();
            contact.clear();
            status = null;
          }
          notice = e is ApiFailure
              ? e.message
              : 'Die Änderung wurde nicht übernommen.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> refresh() async {
    if (busy) return;
    setState(() {
      busy = true;
      notice = null;
    });
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: accessAppBar(context, 'Verkäuferangaben'),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        width: AccessPageWidth.form,
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LocalText(
                'Diese Angaben sind für berechtigte Ticketkäufer vor dem Kauf sichtbar. Keine geschützte Veranstaltungsadresse eintragen. Im lokalen Test ausschließlich erfundene Angaben verwenden.',
              ),
              if (notice != null)
                Semantics(liveRegion: true, child: LocalText(notice!)),
              field(context, name, 'Vollständiger Verkäufername', 200),
              field(
                context,
                address,
                'Geschäfts- oder Kontaktanschrift',
                500,
                lines: 3,
              ),
              field(context, contact, 'Kontakt-E-Mail', 255),
              DropdownButtonFormField<String>(
                initialValue: status,
                isExpanded: true,
                decoration: InputDecoration(
                  errorStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  labelText: localText(context, 'Verkäuferstatus'),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'private',
                    child: LocalText(localText(context, 'Privatperson')),
                  ),
                  DropdownMenuItem(
                    value: 'business',
                    child: LocalText(localText(context, 'Unternehmer')),
                  ),
                ],
                onChanged: busy || !canEdit
                    ? null
                    : (v) => setState(() => status = v),
                validator: (v) =>
                    v == null ? localText(context, 'Bitte auswählen.') : null,
              ),
              const LocalText(
                'Der Verkäuferstatus richtet sich nach der tatsächlichen Tätigkeit. Die Auswahl ist keine rechtliche Einstufung durch die Plattform.',
              ),
              OutlinedButton(
                onPressed: busy ? null : refresh,
                child: const LocalText('Aktualisieren'),
              ),
              FilledButton(
                onPressed: busy || !canEdit ? null : save,
                child: const LocalText('Verkäuferangaben speichern'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class EventDeclarationPage extends StatefulWidget {
  final TicketingApi api;
  final String eventId;
  const EventDeclarationPage({
    super.key,
    required this.api,
    required this.eventId,
  });
  @override
  State<EventDeclarationPage> createState() => _EventDeclarationPageState();
}

class _EventDeclarationPageState extends State<EventDeclarationPage> {
  Map<String, dynamic>? data;
  bool confirmed = false, busy = true;
  String? notice;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<bool> load() async {
    try {
      final r = await widget.api.ticketing(
        'events/${widget.eventId}/declaration',
      );
      if (mounted) {
        setState(() {
          data = r;
          confirmed = false;
        });
      }
      return mounted;
    } catch (e) {
      if (mounted) {
        setState(() {
          data = null;
          confirmed = false;
          notice = e is ApiFailure
              ? e.message
              : 'Die Erklärung konnte nicht geladen werden.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
    return false;
  }

  Future<void> save(bool value) async {
    if (busy || data == null) return;
    final session = TicketingSessionGuard(widget.api);
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      await widget.api.ticketing(
        'events/${widget.eventId}/declaration',
        body: {
          'confirmed': value,
          'version': data?['declaration']?['version'] ?? 0,
          'event_version': data!['event_version'],
          'seller_version': data!['seller_version'],
          'terms_version': legalDeclarationVersion,
        },
      );
      session.check();
      final refreshed = await load();
      session.check();
      if (mounted && refreshed) {
        setState(
          () => notice = localText(
            context,
            value ? 'Bestätigung gespeichert.' : 'Veranstalterverantwortung nicht bestätigt. Verkauf bleibt geschlossen.',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
            data = null;
            confirmed = false;
          }
          notice = e is ApiFailure
              ? e.message
              : 'Die Änderung wurde nicht übernommen.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> refresh() async {
    if (busy) return;
    setState(() {
      busy = true;
      notice = null;
    });
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: accessAppBar(context, 'Veranstalterbestätigung'),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        width: AccessPageWidth.form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LocalText(legalAccessNotice),
            const LocalText(
              'Prüfe insbesondere die zulässige Nutzung des Veranstaltungsorts, erforderliche behördliche Erlaubnisse, Brandschutz, Kapazität, Jugendschutz und gegebenenfalls Musiklizenzen. Nicht jede Veranstaltung benötigt dieselben Erlaubnisse.',
            ),
            if (data != null) ...[
              if (data!['terms_version'] != legalDeclarationVersion)
                const LocalText(
                  'Der Erklärungstext wurde geändert. Bitte aktualisiere die Anwendung.',
                ),
              SellerInformation(
                seller: data!['seller'] == null
                    ? null
                    : Map<String, dynamic>.from(data!['seller'] as Map),
              ),
              LocalText(legalStateLabel(data!['legal_state'] as String?)),
              LocalText(
                data!['ready'] == true
                    ? 'Veranstalterverantwortung: bestätigt.'
                    : 'Veranstalterverantwortung: noch nicht aktuell bestätigt.',
              ),
              CheckboxListTile(
                value: confirmed,
                onChanged:
                    busy || data!['terms_version'] != legalDeclarationVersion
                    ? null
                    : (v) => setState(() => confirmed = v ?? false),
                title: const LocalText(legalDeclarationNotice),
              ),
              FilledButton(
                onPressed:
                    busy ||
                        !confirmed ||
                        data!['seller'] == null ||
                        data!['terms_version'] != legalDeclarationVersion
                    ? null
                    : () => save(true),
                child: const LocalText('Bestätigung speichern'),
              ),
              OutlinedButton(
                onPressed:
                    busy || data!['terms_version'] != legalDeclarationVersion
                    ? null
                    : () => save(false),
                child: const LocalText(
                  'Verantwortung nicht bestätigen · Verkauf geschlossen halten',
                ),
              ),
            ],
            if (data == null)
              OutlinedButton(
                onPressed: busy ? null : refresh,
                child: const LocalText('Aktualisieren'),
              ),
            if (notice != null)
              Semantics(liveRegion: true, child: LocalText(notice!)),
          ],
        ),
      ),
    ),
  );
}

class LegalReviewsPage extends StatefulWidget {
  final LegalApi api;
  final bool team;
  const LegalReviewsPage({super.key, required this.api, this.team = false});
  @override
  State<LegalReviewsPage> createState() => _LegalReviewsPageState();
}

class _LegalReviewsPageState extends State<LegalReviewsPage> {
  List<dynamic> items = [];
  bool busy = false;
  String? notice;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      final r = await widget.api.legal(widget.team ? 'reports' : 'mine');
      if (mounted) setState(() => items = r['items'] as List);
    } catch (e) {
      if (mounted) {
        setState(() {
          items = [];
          notice = e is ApiFailure
              ? e.message
              : 'Prüfungen konnten nicht geladen werden.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(Map<String, dynamic> item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LegalReviewDetailPage(
          api: widget.api,
          item: item,
          team: widget.team,
        ),
      ),
    );
    if (mounted) await load();
  }

  Future<void> mailbox() async {
    if (busy) return;
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      final r = await widget.api.legal('mailbox');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const LocalText('Lokales Testpostfach'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final n in r['items'] as List)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        '${n['recipient']} · ${n['kind']}\n${n['message']}',
                      ),
                    ),
                ],
              ),
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
    } catch (e) {
      if (mounted) {
        setState(
          () => notice = e is ApiFailure
              ? e.message
              : 'Postfach nicht verfügbar.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: accessAppBar(
      context,
      widget.team
          ? 'Veranstaltungsmeldungen prüfen'
          : 'Meine Veranstaltungsprüfungen',
    ),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LocalText(
              'Lokaler Test · keine rechtliche Freigabe und kein E-Mail-Versand',
            ),
            if (notice != null)
              Semantics(liveRegion: true, child: LocalText(notice!)),
            if (items.isEmpty && !busy)
              const LocalText('Keine Vorgänge vorhanden.'),
            for (final raw in items)
              ListTile(
                title: Text(
                  widget.team
                      ? '${raw['reference']}'
                      : localText(
                          context,
                          legalStateLabel(raw['action'] as String?),
                        ),
                ),
                subtitle: Text(
                  widget.team
                      ? localText(
                          context,
                          raw['status'] == 'open'
                              ? 'Meldung offen'
                              : 'Meldung entschieden',
                        )
                      : '${raw['reason']}',
                ),
                onTap: busy
                    ? null
                    : () => open(Map<String, dynamic>.from(raw as Map)),
              ),
            OutlinedButton(
              onPressed: busy ? null : load,
              child: const LocalText('Aktualisieren'),
            ),
            if (widget.team)
              OutlinedButton(
                onPressed: busy ? null : mailbox,
                child: const LocalText('Lokales Testpostfach'),
              ),
          ],
        ),
      ),
    ),
  );
}

class LegalReviewDetailPage extends StatefulWidget {
  final LegalApi api;
  final Map<String, dynamic> item;
  final bool team;
  const LegalReviewDetailPage({
    super.key,
    required this.api,
    required this.item,
    required this.team,
  });
  @override
  State<LegalReviewDetailPage> createState() => _LegalReviewDetailPageState();
}

class _LegalReviewDetailPageState extends State<LegalReviewDetailPage> {
  final form = GlobalKey<FormState>();
  final eventId = TextEditingController(),
      reason = TextEditingController(),
      statement = TextEditingController();
  Map<String, dynamic>? data;
  String action = 'sales_paused', basis = 'clarification';
  bool busy = true;
  String? notice;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    eventId.dispose();
    reason.dispose();
    statement.dispose();
    super.dispose();
  }

  Future<bool> load() async {
    try {
      final Map<String, dynamic> r;
      if (widget.team) {
        r = await widget.api.legal('reports/${widget.item['id']}');
      } else {
        final own = await widget.api.legal('mine');
        final matches = (own['items'] as List).where(
          (item) => item['id'] == widget.item['id'],
        );
        if (matches.isEmpty) {
          throw const ApiFailure(
            'Prüfungen konnten nicht geladen werden.',
            accessDenied: true,
          );
        }
        r = Map<String, dynamic>.from(matches.first as Map);
      }
      if (mounted) {
        setState(() {
          data = r;
          eventId.text = r['event_id'] as String? ?? '';
        });
      }
      return mounted;
    } catch (e) {
      if (mounted) {
        setState(() {
          data = null;
          eventId.clear();
          reason.clear();
          statement.clear();
          notice = e is ApiFailure
              ? e.message
              : 'Prüfungen konnten nicht geladen werden.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
    return false;
  }

  Future<void> run(Future<void> Function() work) async {
    if (busy || data == null) return;
    final session = TicketingSessionGuard(widget.api);
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      await work();
      session.check();
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
            data = null;
            eventId.clear();
            reason.clear();
            statement.clear();
          }
          notice = e is ApiFailure
              ? e.message
              : 'Der Vorgang wurde nicht übernommen.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> refresh() async {
    if (busy) return;
    setState(() {
      busy = true;
      notice = null;
    });
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: accessAppBar(context, 'Veranstaltungsprüfung'),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        width: AccessPageWidth.form,
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (notice != null)
                Semantics(liveRegion: true, child: LocalText(notice!)),
              if (data != null && widget.team) ...[
                Text(data!['reference'] as String),
                Text(data!['details'] as String),
                if (data!['event'] != null) ...[
                  Text(data!['event']['title'] as String),
                  LocalText(
                    legalStateLabel(data!['event']['legal_state'] as String?),
                  ),
                ],
                Text(
                  '${localText(context, 'Zuständigkeit')}: ${data!['assigned_to'] ?? localText(context, 'Noch nicht zugewiesen')}',
                ),
                for (final a in data!['actions'] as List)
                  Text(
                    '${localText(context, legalStateLabel(a['action'] as String?))} · ${localText(context, legalBasisLabel(a['basis'] as String?))}\n${a['reason']}\n${a['created_at']}',
                  ),
                for (final s in data!['statements'] as List)
                  Text(
                    '${localText(context, 'Stellungnahme')}: ${s['details']}',
                  ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          await widget.api.legal(
                            'reports/${widget.item['id']}/assign',
                            body: {'version': data!['version']},
                          );
                          if (await load() && mounted) {
                            setState(
                              () => notice = localText(
                                context,
                                'Vorgang gespeichert.',
                              ),
                            );
                          }
                        }),
                  child: const LocalText('Bearbeitung übernehmen'),
                ),
                field(
                  context,
                  eventId,
                  'Event-ID zur Prüfung',
                  36,
                  optional: action == 'no_action',
                ),
                DropdownButtonFormField<String>(
                  initialValue: action,
                  isExpanded: true,
                  itemHeight: 72,
                  decoration: InputDecoration(
                    errorStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    labelText: localText(context, 'Maßnahme'),
                  ),
                  items: [
                    for (final a in [
                      'sales_paused',
                      'blocked',
                      'active',
                      'no_action',
                    ])
                      DropdownMenuItem(
                        value: a,
                        child: Text(
                          localText(context, legalActionLabel(a)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (v) => setState(() {
                          action = v!;
                          basis = action == 'no_action'
                              ? 'unsubstantiated'
                              : action == 'sales_paused'
                              ? 'clarification'
                              : action == 'active'
                              ? 'resolved'
                              : 'prohibition';
                        }),
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey(action),
                  initialValue: basis,
                  isExpanded: true,
                  itemHeight: 72,
                  decoration: InputDecoration(
                    errorStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    labelText: localText(context, 'Grundlage'),
                  ),
                  items: [
                    for (final b
                        in action == 'no_action'
                            ? ['unsubstantiated']
                            : action == 'blocked'
                            ? ['prohibition', 'danger', 'cancellation']
                            : action == 'active'
                            ? ['resolved']
                            : ['clarification'])
                      DropdownMenuItem(
                        value: b,
                        child: Text(
                          localText(context, switch (b) {
                            'prohibition' => 'Bestätigtes Verbot',
                            'danger' => 'Konkrete Gefahr',
                            'cancellation' => 'Absage',
                            'resolved' => 'Klärung abgeschlossen',
                            'unsubstantiated' =>
                              'Keine ausreichende Grundlage für eine Maßnahme',
                            _ => 'Genehmigungslage klären',
                          }),
                        ),
                      ),
                  ],
                  onChanged: busy ? null : (v) => setState(() => basis = v!),
                ),
                field(
                  context,
                  reason,
                  'Begründung und Rechts- oder Regelgrundlage',
                  2000,
                  lines: 4,
                ),
                const LocalText(
                  'Eine Verkaufspause erhält bezahlte Tickets. Eine Sperre hält den Einlass an und erzeugt Erstattungsaufgaben. Erneutes Öffnen reaktiviert gestoppte Bestellungen nicht.',
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          if (!form.currentState!.validate()) return;
                          final existing = data!['event'] as Map?;
                          Map? eventState;
                          if (action != 'no_action') {
                            if (existing?['id'] == eventId.text.trim()) {
                              eventState = existing;
                            } else {
                              final loaded = await widget.api.legal(
                                'events/${eventId.text.trim()}',
                              );
                              if (mounted) {
                                setState(() {
                                  data = {...data!, 'event': loaded};
                                  notice = localText(
                                    context,
                                    'Prüfstand geladen. Bitte die Entscheidung bestätigen.',
                                  );
                                });
                              }
                              return;
                            }
                          }
                          await widget.api.legal(
                            'reports/${widget.item['id']}/decision',
                            body: {
                              'event_id': eventId.text.trim(),
                              'action': action,
                              'basis': basis,
                              'reason': reason.text.trim(),
                              'version': data!['version'],
                              'event_legal_version':
                                  eventState?['legal_version'] ?? 0,
                            },
                          );
                          if (await load() && mounted) {
                            setState(
                              () => notice = localText(
                                context,
                                'Vorgang gespeichert.',
                              ),
                            );
                          }
                        }),
                  child: const LocalText('Begründete Entscheidung speichern'),
                ),
              ] else if (data != null) ...[
                LocalText(legalStateLabel(data!['action'] as String?)),
                Text(data!['reason'] as String),
                field(
                  context,
                  statement,
                  'Stellungnahme oder Bitte um erneute Prüfung',
                  4000,
                  lines: 5,
                ),
                FilledButton(
                  onPressed: busy || data!['statement_submitted'] == true
                      ? null
                      : () => run(() async {
                          if (!form.currentState!.validate()) return;
                          await widget.api.legal(
                            'actions/${widget.item['id']}/statement',
                            body: {'details': statement.text.trim()},
                          );
                          if (mounted) {
                            setState(() {
                              statement.clear();
                              data = {...data!, 'statement_submitted': true};
                              notice = localText(
                                context,
                                'Vorgang gespeichert.',
                              );
                            });
                          }
                        }),
                  child: const LocalText('Erneute Prüfung anfordern'),
                ),
              ],
              OutlinedButton(
                onPressed: busy ? null : refresh,
                child: const LocalText('Aktualisieren'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

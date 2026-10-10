import 'product_scope.dart';

import 'package:flutter/material.dart';

import 'access_api.dart';
import 'access_flow_api.dart';
import 'app_language.dart';
import 'ticketing_api.dart';
import 'legal_pages.dart';
import 'legal_api.dart';
import 'ticketing_pages.dart';

class PrivateTicketCategories extends StatefulWidget {
  final TicketingApi api;
  final String eventId;
  final VoidCallback onChanged;
  const PrivateTicketCategories({
    super.key,
    required this.api,
    required this.eventId,
    required this.onChanged,
  });
  @override
  State<PrivateTicketCategories> createState() =>
      _PrivateTicketCategoriesState();
}

class _PrivateTicketCategoriesState extends State<PrivateTicketCategories> {
  List<dynamic> items = [];
  Map<String, dynamic>? seller, declaration;
  String? legalState;
  String? notice;
  bool busy = false, age = false;
  int generation = 0, loadSequence = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(PrivateTicketCategories old) {
    super.didUpdateWidget(old);
    if (old.api != widget.api || old.eventId != widget.eventId) {
      generation++;
      items = [];
      seller = null;
      declaration = null;
      legalState = null;
      notice = null;
      age = false;
      busy = false;
      load();
    }
  }

  @override
  void dispose() {
    generation++;
    super.dispose();
  }

  Future<void> load() async {
    final epoch = generation;
    final sequence = ++loadSequence;
    try {
      final r = await widget.api.ticketing('events/${widget.eventId}/types');
      if (mounted && epoch == generation && sequence == loadSequence) {
        setState(() {
          items = r['items'] as List;
          seller = r['seller'] == null
              ? null
              : Map<String, dynamic>.from(r['seller'] as Map);
          declaration = r['declaration'] == null
              ? null
              : Map<String, dynamic>.from(r['declaration'] as Map);
          legalState = r['legal_state'] as String?;
          notice = null;
        });
      }
    } catch (e) {
      if (mounted && epoch == generation && sequence == loadSequence) {
        setState(() {
          items = [];
          seller = null;
          declaration = null;
          age = false;
          legalState = null;
          notice = e is ApiFailure
              ? e.message
              : 'Ticketangebote konnten nicht neu geprüft werden.';
        });
      }
    }
  }

  Future<void> buy(Map<String, dynamic> item) async {
    if (busy) return;
    final epoch = generation;
    final session = TicketingSessionGuard(widget.api);
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      final r = await widget.api.ticketing(
        'types/${item['id']}/checkout',
        body: {'age_acknowledged': age},
      );
      session.check();
      if (!mounted || epoch != generation) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => TicketCheckoutPage(api: widget.api, initialOrder: r),
        ),
      );
      session.check();
      if (mounted && epoch == generation) {
        await load();
        session.check();
        if (mounted && epoch == generation) widget.onChanged();
      }
    } catch (e) {
      if (mounted &&
          epoch == generation &&
          e is ApiFailure &&
          (e.unauthenticated || e.accessDenied)) {
        setState(() {
          items = [];
          seller = null;
          declaration = null;
          age = false;
        });
      }
      if (mounted && epoch == generation) {
        setState(
          () => notice = e is ApiFailure
              ? e.message
              : 'Der Kauf konnte nicht freigegeben werden.',
        );
      }
    } finally {
      if (mounted && epoch == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (notice != null)
        Semantics(liveRegion: true, child: LocalText(notice!)),
      if (items.isNotEmpty) ...[
        const LocalText('Weitere Ticketangebote'),
        SellerInformation(seller: seller, declaration: declaration),
        const LocalText(legalAccessNotice),
        if (legalState != null) LocalText(legalStateLabel(legalState)),
        if (widget.api is LegalApi)
          ReportEventButton(
            api: widget.api as LegalApi,
            eventId: widget.eventId,
          ),
        CheckboxListTile(
          title: const LocalText(
            'Ich erfülle das für diese Veranstaltung angegebene Mindestalter.',
          ),
          value: age,
          onChanged: busy ? null : (v) => setState(() => age = v ?? false),
        ),
        for (final raw in items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LocalText(
                    '${raw['name']} · ${ticketMoney(raw['price_cents'])}',
                  ),
                  if (raw['purchase_rule'] == 'event_approval_required')
                    const LocalText(
                      'Vor dem Kauf ist eine persönliche Freigabe erforderlich.',
                    ),
                  const LocalText(
                    'Das Ticket gilt für dein Konto. Beim Einlass werden Eventzugang und Sperren erneut geprüft.',
                  ),
                  FilledButton(
                    onPressed: busy || !age || raw['can_buy'] != true
                        ? null
                        : () => buy(Map<String, dynamic>.from(raw)),
                    child: const LocalText('Dieses Ticket kaufen'),
                  ),
                ],
              ),
            ),
          ),
      ],
    ],
  );
}

class PrivateTicketManagementPage extends StatefulWidget {
  final TicketingApi api;
  final AccessFlowApi? access;
  final Map<String, dynamic> event;
  const PrivateTicketManagementPage({
    super.key,
    required this.api,
    required this.event,
    this.access,
  });
  @override
  State<PrivateTicketManagementPage> createState() =>
      _PrivateTicketManagementPageState();
}

class _PrivateTicketManagementPageState
    extends State<PrivateTicketManagementPage> {
  final name = TextEditingController(),
      price = TextEditingController(),
      quota = TextEditingController(),
      email = TextEditingController();
  String visibility = 'explicit_grant', rule = 'event_approval_required';
  String? notice;
  List<dynamic> items = [];
  bool busy = false, ready = false;
  int generation = 0;
  String get eventId => widget.event['id'] as String;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(PrivateTicketManagementPage old) {
    super.didUpdateWidget(old);
    if (old.api != widget.api || old.event['id'] != widget.event['id']) {
      generation++;
      items = [];
      notice = null;
      busy = false;
      ready = false;
      for (final c in [name, price, quota, email]) {
        c.clear();
      }
      load();
    }
  }

  @override
  void dispose() {
    generation++;
    for (final c in [name, price, quota, email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> load() async {
    final epoch = generation;
    try {
      final r = await widget.api.ticketing('events/$eventId/types/manage');
      if (mounted && epoch == generation) {
        setState(() {
          items = r['items'] as List;
          ready = true;
        });
        return true;
      }
    } catch (e) {
      if (mounted && epoch == generation) {
        setState(() {
          ready = false;
          items = [];
          if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
            for (final c in [name, price, quota, email]) {
              c.clear();
            }
          }
          notice = e is ApiFailure
              ? e.message
              : 'Ticketkategorien konnten nicht geladen werden.';
        });
      }
    }
    return false;
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy || !ready) return;
    final epoch = generation;
    final session = TicketingSessionGuard(widget.api);
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      await action();
      session.check();
      if (mounted && epoch == generation) {
        final refreshed = await load();
        session.check();
        if (!mounted || epoch != generation || !refreshed) return;
        setState(() => notice = 'Gespeichert.');
      }
    } catch (e) {
      if (mounted &&
          epoch == generation &&
          e is ApiFailure &&
          (e.unauthenticated || e.accessDenied)) {
        setState(() {
          ready = false;
          items = [];
          for (final c in [name, price, quota, email]) {
            c.clear();
          }
        });
      }
      if (mounted && epoch == generation) {
        setState(
          () => notice = e is ApiFailure
              ? e.message
              : 'Die Änderung wurde nicht übernommen.',
        );
      }
    } finally {
      if (mounted && epoch == generation) setState(() => busy = false);
    }
  }

  Future<void> create() async {
    final amount = price.text.trim().replaceAll(',', '.');
    final match = RegExp(r'^(\d{1,6})(?:\.(\d{1,2}))?$').firstMatch(amount);
    final count = int.tryParse(quota.text);
    if (match == null || count == null || count <= 0) {
      setState(() => notice = 'Bitte Preis und Kontingent gültig eingeben.');
      return;
    }
    final cents =
        int.parse(match[1]!) * 100 +
        int.parse((match[2] ?? '').padRight(2, '0'));
    await run(
      () => widget.api.ticketing(
        'events/$eventId/types',
        body: {
          'name': name.text.trim(),
          'price_cents': cents,
          'currency': 'EUR',
          'quota': count,
          'visibility_mode': visibility,
          'purchase_rule': rule,
          'communities': visibility == 'community_subset'
              ? [widget.event['community_id']]
              : [],
          'enabled': true,
          'version': 0,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: LocalText(
        ProductScope.extended ? 'Private Ticketangebote' : 'Einlassrollen',
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children:
          <Widget>[
                if (ready) LocalText(widget.event['title'] as String),
                const LocalText('Lokaler Test · kein echter Verkauf'),
                if (notice != null)
                  Semantics(liveRegion: true, child: LocalText(notice!)),
                if (ProductScope.extended) ...[
                  TextField(
                    controller: name,
                    decoration: InputDecoration(
                      labelText: localText(context, 'Ticketname'),
                    ),
                  ),
                  TextField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: localText(context, 'Preis (€)'),
                    ),
                  ),
                  TextField(
                    controller: quota,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: localText(context, 'Kategorienkontingent'),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: visibility,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: localText(context, 'Sichtbarkeit'),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'inherit_event',
                        child: LocalText('Alle mit Eventzugang'),
                      ),
                      DropdownMenuItem(
                        value: 'community_subset',
                        child: LocalText('Mitglieder der Eventcommunity'),
                      ),
                      DropdownMenuItem(
                        value: 'explicit_grant',
                        child: LocalText('Persönlich Freigeschaltete'),
                      ),
                    ],
                    onChanged: busy || !ready
                        ? null
                        : (v) => setState(() => visibility = v!),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: rule,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: localText(context, 'Kaufberechtigung'),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'event_approval_required',
                        child: LocalText('Teilnahmefreigabe erforderlich'),
                      ),
                      DropdownMenuItem(
                        value: 'visible_authenticated',
                        child: LocalText('Eventzugang und Konto genügen'),
                      ),
                    ],
                    onChanged: busy || !ready
                        ? null
                        : (v) => setState(() => rule = v!),
                  ),
                  const LocalText(
                    'Eine persönliche Kategorienfreigabe gibt keinen Eventzugang. Kategorienbedingungen gelten beim Kauf. Bei einem öffentlichen Event bleibt ein bezahlt erworbenes Ticket nach reinem Communityaustritt gültig. Event- und Veranstaltersperren greifen weiterhin.',
                  ),
                  FilledButton(
                    onPressed: busy || !ready ? null : create,
                    child: const LocalText('Kategorie anlegen'),
                  ),
                ],
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: localText(context, 'Bestätigte Konto-E-Mail'),
                  ),
                ),
                for (final raw in items)
                  ListTile(
                    title: LocalText(
                      '${raw['name']} · ${ticketMoney(raw['price_cents'])}',
                    ),
                    subtitle: LocalText(
                      raw['visibility_mode'] == 'explicit_grant'
                          ? 'Persönliche Freigabe'
                          : 'Zugang gemäß Kategorie',
                    ),
                    trailing: raw['visibility_mode'] == 'explicit_grant'
                        ? TextButton(
                            onPressed: busy || !ready
                                ? null
                                : () => run(
                                    () => widget.api.ticketing(
                                      'types/${raw['id']}/grant',
                                      body: {
                                        'email': email.text.trim(),
                                        'expires_at': DateTime.now()
                                            .toUtc()
                                            .add(const Duration(days: 1))
                                            .toIso8601String(),
                                        'revoked': false,
                                      },
                                    ),
                                  ),
                            child: const LocalText('24 h freigeben'),
                          )
                        : null,
                  ),
                if (widget.access != null)
                  OutlinedButton(
                    onPressed: busy || !ready
                        ? null
                        : () => run(
                            () => widget.access!.access(
                              'policy/events/$eventId/scanner',
                              body: {
                                'email': email.text.trim(),
                                'expires_at': DateTime.now()
                                    .toUtc()
                                    .add(const Duration(hours: 12))
                                    .toIso8601String(),
                              },
                            ),
                          ),
                    child: const LocalText('Einlassrolle für 12 h vergeben'),
                  ),
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

class OnlineCheckinPage extends StatefulWidget {
  final AccessFlowApi api;
  const OnlineCheckinPage({super.key, required this.api});
  @override
  State<OnlineCheckinPage> createState() => _OnlineCheckinPageState();
}

class _OnlineCheckinPageState extends State<OnlineCheckinPage> {
  final token = TextEditingController(), email = TextEditingController();
  List<dynamic> events = [];
  String? selected, notice;
  bool busy = false;
  int generation = 0;
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
    final epoch = generation;
    try {
      final r = await widget.api.access('policy/scanner-events');
      if (mounted && epoch == generation) {
        setState(() {
          events = r['items'] as List;
          if (!events.any((event) => event['id'] == selected)) selected = null;
        });
      }
    } catch (e) {
      if (mounted && epoch == generation) {
        setState(() {
          events = [];
          selected = null;
          token.clear();
          email.clear();
          notice = e is ApiFailure
              ? e.message
              : 'Keine Einlassrolle verfügbar.';
        });
      }
    } finally {
      if (mounted && epoch == generation) setState(() => busy = false);
    }
  }

  @override
  void didUpdateWidget(OnlineCheckinPage old) {
    super.didUpdateWidget(old);
    if (old.api != widget.api) {
      generation++;
      events = [];
      selected = null;
      notice = null;
      busy = false;
      token.clear();
      email.clear();
      load();
    }
  }

  @override
  void dispose() {
    generation++;
    token.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> scan() async {
    if (busy || selected == null) return;
    if (token.text.trim().isEmpty || email.text.trim().isEmpty) {
      setState(() => notice = 'Bitte Ticketcode und Konto-E-Mail eingeben.');
      return;
    }
    final epoch = generation;
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      await widget.api.access(
        'policy/events/$selected/checkin',
        body: {'token': token.text.trim(), 'holder_email': email.text.trim()},
      );
      if (mounted && epoch == generation) {
        setState(() {
          token.clear();
          email.clear();
          notice = 'Einlass bestätigt · synthetischer Test';
        });
      }
    } catch (e) {
      if (mounted &&
          epoch == generation &&
          e is ApiFailure &&
          (e.unauthenticated || e.accessDenied)) {
        setState(() {
          events = [];
          selected = null;
          token.clear();
          email.clear();
        });
      }
      if (mounted && epoch == generation) {
        setState(
          () => notice = e is ApiFailure ? e.message : 'Einlass nicht bestätigt. Bitte Verbindung und Berechtigung prüfen.',
        );
      }
    } finally {
      if (mounted && epoch == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const LocalText('Online-Einlass')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children:
          <Widget>[
                const LocalText(
                  'Lokaler Test. Nur online prüfen. Weitergegebene Screenshots ersetzen die Zuordnung zum Konto nicht.',
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey(events.map((event) => event['id']).join(',')),
                  initialValue: selected,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: localText(context, 'Veranstaltung'),
                  ),
                  items: [
                    for (final e in events)
                      DropdownMenuItem(
                        value: e['id'] as String,
                        child: LocalText(e['title'] as String),
                      ),
                  ],
                  onChanged: busy ? null : (v) => setState(() => selected = v),
                ),
                TextField(
                  controller: token,
                  decoration: InputDecoration(
                    labelText: localText(context, 'Ticketcode'),
                  ),
                ),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: localText(
                      context,
                      'Konto-E-Mail vor Ort abgleichen',
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: busy || selected == null ? null : scan,
                  child: const LocalText('Einlass online prüfen'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : load,
                  child: const LocalText('Aktualisieren'),
                ),
                if (notice != null)
                  Semantics(liveRegion: true, child: LocalText(notice!)),
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

import 'flyer_design.dart';
import 'product_scope.dart';
import 'private_ticket_pages.dart';
import 'access_flow_api.dart';

import 'package:flutter/material.dart';

import 'access_api.dart';
import 'app_language.dart';
import 'design_system.dart';
import 'ticketing_api.dart';
import 'legal_api.dart';
import 'legal_pages.dart';
import 'ticketing_checkout_bridge.dart';
import 'ticketing_checkout_window.dart'
    if (dart.library.js_interop) 'ticketing_checkout_window_web.dart';

String ticketMoney(dynamic cents) =>
    '${((cents as num? ?? 0) / 100).toStringAsFixed(2).replaceAll('.', ',')} €';
String ticketState(Map<String, dynamic> order) {
  if (order['blocked'] == true && order['state'] != 'refunded') {
    return 'Ticket gesperrt · Erstattung wird geprüft';
  }
  return switch (order['state']) {
    'creating' => 'Bestellung wird vorbereitet',
    'pending' => 'Für 15 Minuten reserviert · Zahlung offen',
    'paid' => 'Bezahlt · Teilnahme bestätigt',
    'expired' => 'Reservierung abgelaufen',
    'failed' => 'Zahlung fehlgeschlagen',
    'refunded' => 'Vollständig erstattet',
    _ => 'Status wird geprüft',
  };
}

class TicketPurchasePanel extends StatefulWidget {
  final TicketingApi api;
  final String eventId;
  final VoidCallback onChanged;
  const TicketPurchasePanel({
    super.key,
    required this.api,
    required this.eventId,
    required this.onChanged,
  });
  @override
  State<TicketPurchasePanel> createState() => _TicketPurchasePanelState();
}

class _TicketPurchasePanelState extends State<TicketPurchasePanel> {
  Map<String, dynamic>? offer, order;
  String? notice;
  bool busy = false, age = false;
  int generation = 0, loadSequence = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    generation++;
    super.dispose();
  }

  @override
  void didUpdateWidget(TicketPurchasePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId || oldWidget.api != widget.api) {
      generation++;
      offer = null;
      order = null;
      age = false;
      busy = false;
      notice = null;
      load();
    }
  }

  Future<void> load() async {
    final epoch = generation;
    final sequence = ++loadSequence;
    final session = TicketingSessionGuard(widget.api);
    try {
      final data = await widget.api.ticketing('events/${widget.eventId}/offer');
      session.check();
      final tickets = await widget.api.ticketing('mine');
      session.check();
      if (!mounted || epoch != generation || sequence != loadSequence) return;
      final matching = (tickets['items'] as List).where(
        (o) => o['event_id'] == widget.eventId,
      );
      setState(() {
        notice = null;
        offer = data;
        order = matching.isEmpty
            ? null
            : Map<String, dynamic>.from(matching.first as Map);
      });
    } catch (e) {
      if (mounted && epoch == generation && sequence == loadSequence) {
        offer = null;
        order = null;
        age = false;
        setState(
          () => notice = e is ApiFailure
              ? e.message
              : 'Tickets sind gerade nicht verfügbar.',
        );
      }
    }
  }

  Future<void> checkout() async {
    if (busy) return;
    final epoch = generation;
    final session = TicketingSessionGuard(widget.api);
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      final result = await widget.api.ticketing(
        'events/${widget.eventId}/checkout',
        body: {'age_acknowledged': age},
      );
      session.check();
      if (!mounted || epoch != generation) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              TicketCheckoutPage(api: widget.api, initialOrder: result),
        ),
      );
      session.check();
      if (!mounted || epoch != generation) return;
      await load();
      session.check();
      if (mounted && epoch == generation) widget.onChanged();
    } catch (e) {
      if (mounted &&
          epoch == generation &&
          e is ApiFailure &&
          (e.unauthenticated || e.accessDenied)) {
        setState(() {
          offer = null;
          order = null;
          age = false;
        });
      }
      if (mounted && epoch == generation) {
        setState(
          () => notice = e is ApiFailure
              ? e.message
              : 'Der Ticketkauf konnte nicht gestartet werden.',
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
      const SizedBox(height: AccessSpacing.s16),
      const LocalText(
        'Tickets',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      if (offer?['categories_supported'] == true)
        PrivateTicketCategories(
          api: widget.api,
          eventId: widget.eventId,
          onChanged: widget.onChanged,
        ),
      if (notice != null)
        Semantics(liveRegion: true, child: LocalText(notice!)),
      if (offer != null) ...[
        if (offer!['synthetic'] == true)
          const LocalText('Lokaler Test · kein echter Ticketverkauf'),
        LocalText('Verkäufer: ${offer!['seller']}'),
        SellerInformation(
          seller: offer!['seller_information'] == null
              ? null
              : Map<String, dynamic>.from(offer!['seller_information'] as Map),
          declaration: offer!['declaration'] == null
              ? null
              : Map<String, dynamic>.from(offer!['declaration'] as Map),
        ),
        const LocalText(legalAccessNotice),
        if (offer!['legal_state'] != null)
          LocalText(legalStateLabel(offer!['legal_state'] as String?)),
        if (widget.api is LegalApi)
          ReportEventButton(
            api: widget.api as LegalApi,
            eventId: widget.eventId,
          ),
        LocalText(
          '${offer!['item_name']} · ${ticketMoney(offer!['price_cents'])}',
        ),
        LocalText('${offer!['available']} Tickets verfügbar'),
        if (offer!['mode'] == 'approval')
          const LocalText(
            'Der Veranstalter muss den Kauf zuerst freigeben. Eine Freigabe reserviert keinen Platz.',
          ),
        if (order != null) ...[
          LocalText(ticketState(order!)),
          if (order!['refunded_cents'] != 0)
            LocalText('Erstattet: ${ticketMoney(order!['refunded_cents'])}'),
        ],
        if (offer!['minimum_age'] != null)
          CheckboxListTile(
            title: LocalText(
              'Ich erfülle das Mindestalter von ${offer!['minimum_age']} Jahren.',
            ),
            value: age,
            onChanged: busy ? null : (v) => setState(() => age = v ?? false),
          ),
        AccessAction(
          kind: AccessActionKind.primary,
          onPressed:
              busy ||
                  offer!['can_buy'] != true ||
                  (offer!['minimum_age'] != null && !age) ||
                  order?['state'] == 'paid'
              ? null
              : checkout,
          child: const LocalText('Eigenes Ticket kaufen'),
        ),
        if (order?['state'] == 'pending')
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => TicketCheckoutPage(
                          api: widget.api,
                          initialOrder: order!,
                        ),
                      ),
                    );
                    if (mounted) {
                      await load();
                      widget.onChanged();
                    }
                  },
            child: const LocalText('Reservierte Bestellung öffnen'),
          ),
      ],
      TextButton(
        onPressed: busy ? null : load,
        child: const LocalText('Ticketstatus aktualisieren'),
      ),
    ],
  );
}

class TicketCheckoutPage extends StatefulWidget {
  final TicketingApi api;
  final Map<String, dynamic> initialOrder;
  const TicketCheckoutPage({
    super.key,
    required this.api,
    required this.initialOrder,
  });
  @override
  State<TicketCheckoutPage> createState() => _TicketCheckoutPageState();
}

class _TicketCheckoutPageState extends State<TicketCheckoutPage> {
  late Map<String, dynamic> order;
  bool busy = false;
  String? notice;
  Uri? nativeCheckout;
  bool identityLost = false, admissionDenied = false;

  void failure(Object e) {
    nativeCheckout = null;
    if (e is ApiFailure && e.unauthenticated) {
      identityLost = true;
      order = {};
    } else if (e is ApiFailure && e.accessDenied) {
      admissionDenied = true;
    }
  }

  Future<void> prepareNative() async {
    if (busy || identityLost || admissionDenied) return;
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      final url = await prepareNativeTicketCheckout(widget.api, order);
      if (mounted) setState(() => nativeCheckout = url);
    } catch (e) {
      if (mounted) {
        setState(() {
          failure(e);
          notice = e is ApiFailure ? e.message : 'Der Checkout konnte nicht geöffnet werden. Bitte Kaufberechtigung und Zahlungsstatus prüfen.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    order = Map.from(widget.initialOrder);
  }

  Future<void> run(String? outcome) async {
    if (busy || identityLost) return;
    setState(() {
      busy = true;
      nativeCheckout = null;
      notice = null;
    });
    try {
      final result = await widget.api.ticketing(
        'orders/${order['id']}${outcome == null ? '' : '/simulate'}',
        body: outcome == null ? null : {'outcome': outcome},
      );
      if (mounted) setState(() => order = result);
    } catch (e) {
      if (mounted) {
        setState(() {
          failure(e);
          notice = e is ApiFailure
              ? e.message
              : 'Die Zahlung konnte nicht geprüft werden.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: accessAppBar(context, 'Ticketbestellung'),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        width: AccessPageWidth.form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AccessHeading(
              'Ticketbestellung',
              role: AccessHeadingRole.page,
              level: 1,
            ),
            const SizedBox(height: 24),
            if (!identityLost &&
                (order['event_title'] as String? ?? '').isNotEmpty) ...[
              Text(
                order['event_title'] as String,
                style: AccessTypography.cardTitle,
              ),
              const SizedBox(height: 24),
            ],
            if (order['synthetic'] == true)
              const LocalText(
                'Synthetische Zahlung · es wird kein Geld bewegt',
              ),
            const SizedBox(height: AccessSpacing.s16),
            if (!identityLost)
              SellerInformation(
                seller: order['seller_snapshot'] == null
                    ? null
                    : Map<String, dynamic>.from(
                        order['seller_snapshot'] as Map,
                      ),
                declaration: order['declaration_snapshot'] == null
                    ? null
                    : Map<String, dynamic>.from(
                        order['declaration_snapshot'] as Map,
                      ),
              ),
            if (!identityLost && widget.api is LegalApi)
              ReportEventButton(
                api: widget.api as LegalApi,
                eventId: order['event_id'] as String,
              ),
            if (!identityLost)
              LocalText('Ticketpreis: ${ticketMoney(order['total_cents'])}'),
            if (!identityLost)
              Semantics(liveRegion: true, child: LocalText(ticketState(order))),
            if (notice != null)
              Semantics(liveRegion: true, child: LocalText(notice!)),
            if (!identityLost &&
                !admissionDenied &&
                order['native_pretix'] == true &&
                ['pending', 'paid'].contains(order['state']) &&
                order['blocked'] != true)
              FilledButton(
                onPressed: busy
                    ? null
                    : nativeCheckout == null
                    ? prepareNative
                    : () => openNativeTicketCheckout(nativeCheckout!),
                child: LocalText(
                  order['state'] == 'paid'
                      ? (nativeCheckout == null
                            ? 'pretix-Ticket vorbereiten'
                            : 'pretix-Ticket öffnen')
                      : (nativeCheckout == null
                            ? 'pretix-Checkout vorbereiten'
                            : 'pretix-Checkout öffnen'),
                ),
              ),
            if (!identityLost &&
                !admissionDenied &&
                order['synthetic'] == true &&
                order['native_pretix'] != true &&
                order['state'] == 'pending' &&
                order['blocked'] != true) ...[
              const SizedBox(height: AccessSpacing.s24),
              FilledButton(
                onPressed: busy ? null : () => run('success'),
                child: const LocalText('Erfolgreiche Testzahlung'),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => run('failed'),
                child: const LocalText('Fehlgeschlagene Testzahlung'),
              ),
            ],
            TextButton(
              onPressed: busy || identityLost ? null : () => run(null),
              child: const LocalText('Zahlungsstatus prüfen'),
            ),
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const LocalText('Zurück zum Event'),
            ),
          ],
        ),
      ),
    ),
  );
}

class MyTicketsPage extends StatefulWidget {
  final TicketingApi api;
  final bool receiptsOnly;
  const MyTicketsPage({
    super.key,
    required this.api,
    this.receiptsOnly = false,
  });
  @override
  State<MyTicketsPage> createState() => _MyTicketsPageState();
}

class _MyTicketsPageState extends State<MyTicketsPage> {
  List<dynamic>? items;
  String? notice;
  bool busy = false, admissionDenied = false;
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
      final r = await widget.api.ticketing('mine');
      if (mounted) {
        setState(() {
          items = r['items'] as List;
          admissionDenied = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
            items = null;
          }
          notice = e is ApiFailure
              ? e.message
              : 'Tickets konnten nicht geladen werden.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> showTicket(Map<String, dynamic> o, {bool online = false}) async {
    if (busy) return;
    final session = TicketingSessionGuard(widget.api);
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      final r = await widget.api.ticketing('orders/${o['id']}/ticket');
      session.check();
      Map<String, dynamic>? checkin;
      if (widget.api is AccessFlowApi &&
          (online || r['ticket']['native_pretix'] != true)) {
        checkin = await (widget.api as AccessFlowApi).access(
          'policy/orders/${o['id']}/token',
          body: {},
        );
      }
      session.check();
      if (!mounted) return;
      if (r['ticket']['native_pretix'] == true && !online) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TicketCheckoutPage(api: widget.api, initialOrder: o),
          ),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const LocalText('Synthetisches Ticket'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocalText(r['ticket']['admission'] as String),
              SelectableText(
                checkin?['token'] as String? ?? r['ticket']['id'] as String,
              ),
              const LocalText(
                'Kontogebunden. Code vor Ort nur online prüfen. Screenshots können weitergegeben werden.',
              ),
              const LocalText('Testbeleg · kein gültiges Eintrittsticket'),
            ],
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
        setState(() {
          if (e is ApiFailure && e.unauthenticated) items = null;
          if (e is ApiFailure && e.accessDenied) admissionDenied = true;
          notice = e is ApiFailure
              ? e.message
              : 'Das Ticket ist nicht verfügbar.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: accessAppBar(context, 'Meine Tickets'),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AccessHeading(
              'Meine Tickets',
              role: AccessHeadingRole.page,
              level: 1,
            ),
            const SizedBox(height: 24),
            Text(
              localText(
                context,
                'Dein persönlicher Beleg für bestätigte Teilnahme.',
                'Your personal record of confirmed attendance.',
              ),
            ),
            const SizedBox(height: 32),
            if (notice != null)
              Semantics(liveRegion: true, child: LocalText(notice!)),
            if (items?.isEmpty == true)
              const LocalText('Du hast noch keine Ticketbestellung.'),
            for (final raw in items ?? [])
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: FlyerMark(
                  kind: FlyerMarkKind.frame,
                  child: AccessSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: AccessHeading(
                                raw['event_title'] as String? ??
                                    'Ticketbestellung',
                                role: AccessHeadingRole.card,
                                level: 2,
                              ),
                            ),
                            if (!widget.receiptsOnly &&
                                !admissionDenied &&
                                raw['state'] == 'paid' &&
                                raw['blocked'] != true)
                              IconButton(
                                tooltip: localText(
                                  context,
                                  'Ticket öffnen',
                                  'Open ticket',
                                ),
                                onPressed: busy
                                    ? null
                                    : () => showTicket(
                                        Map<String, dynamic>.from(raw),
                                      ),
                                icon: const AccessIcon(Icons.arrow_forward),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SellerInformation(
                          seller: raw['seller_snapshot'] == null
                              ? null
                              : Map<String, dynamic>.from(
                                  raw['seller_snapshot'] as Map,
                                ),
                          declaration: raw['declaration_snapshot'] == null
                              ? null
                              : Map<String, dynamic>.from(
                                  raw['declaration_snapshot'] as Map,
                                ),
                        ),
                        if (widget.api is LegalApi)
                          ReportEventButton(
                            api: widget.api as LegalApi,
                            eventId: raw['event_id'] as String,
                          ),
                        LocalText(ticketMoney(raw['total_cents'])),
                        LocalText(
                          ticketState(Map<String, dynamic>.from(raw as Map)),
                        ),
                        if (raw['refunded_cents'] != 0)
                          LocalText(
                            'Erstattet: ${ticketMoney(raw['refunded_cents'])}',
                          ),
                        if (!widget.receiptsOnly &&
                            !admissionDenied &&
                            raw['state'] == 'paid' &&
                            raw['blocked'] != true)
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => showTicket(
                                    Map<String, dynamic>.from(raw),
                                  ),
                            child: const LocalText('Ticket anzeigen'),
                          ),
                        if (!widget.receiptsOnly &&
                            !admissionDenied &&
                            raw['state'] == 'paid' &&
                            raw['blocked'] != true &&
                            raw['native_pretix'] == true &&
                            widget.api is AccessFlowApi)
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => showTicket(
                                    Map<String, dynamic>.from(raw),
                                    online: true,
                                  ),
                            child: const LocalText(
                              'Online-Einlasscode anzeigen',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            OutlinedButton(
              onPressed: busy ? null : load,
              child: const LocalText('Tickets neu laden'),
            ),
          ],
        ),
      ),
    ),
  );
}

class TicketingManagementPage extends StatefulWidget {
  final TicketingApi api;
  final String profileId;
  final List<Map<String, dynamic>> events;
  const TicketingManagementPage({
    super.key,
    required this.api,
    required this.profileId,
    required this.events,
  });
  @override
  State<TicketingManagementPage> createState() =>
      _TicketingManagementPageState();
}

class _TicketingManagementPageState extends State<TicketingManagementPage> {
  bool connected = false, busy = false;
  bool canManageConnection = false, ready = false;
  String? notice;
  List<dynamic> refunds = [];
  final configs = <String, Map<String, dynamic>>{};
  @override
  void initState() {
    super.initState();
    run(load);
  }

  Future<void> load() async {
    final session = TicketingSessionGuard(widget.api);
    final c = await widget.api.ticketing(
      'profiles/${widget.profileId}/connection',
    );
    session.check();
    final r = await widget.api.ticketing(
      'profiles/${widget.profileId}/refunds',
    );
    session.check();
    final next = <String, Map<String, dynamic>>{};
    for (final e in widget.events) {
      next[e['id'] as String] = await widget.api.ticketing(
        'events/${e['id']}/config',
      );
      session.check();
    }
    if (mounted) {
      setState(() {
        ready = true;
        connected = c['connected'] == true;
        canManageConnection = c['can_manage_connection'] != false;
        refunds = r['items'] as List;
        configs
          ..clear()
          ..addAll(next);
      });
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    final session = TicketingSessionGuard(widget.api);
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      await action();
      session.check();
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
            ready = false;
            connected = false;
            canManageConnection = false;
            refunds = [];
            configs.clear();
          }
          notice = e is ApiFailure
              ? e.message
              : 'Die Ticketverwaltung ist gerade nicht verfügbar.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> privateOffers(Map<String, dynamic> e) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PrivateTicketManagementPage(
          api: widget.api,
          event: e,
          access: widget.api is AccessFlowApi
              ? widget.api as AccessFlowApi
              : null,
        ),
      ),
    );
  }

  Future<void> edit(Map<String, dynamic> e) async {
    final current = configs[e['id']] ?? {'mode': 'none', 'version': 0};
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _TicketConfigDialog(config: current),
    );
    if (result == null || !mounted) return;
    await run(() async {
      await widget.api.ticketing('events/${e['id']}/config', body: result);
      await load();
    });
  }

  Future<void> refund(Map<String, dynamic> r) async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _RefundDialog(
        remaining: (r['total_cents'] as int) - (r['refunded_cents'] as int),
      ),
    );
    if (value == null || !mounted) return;
    await run(() async {
      await widget.api.ticketing(
        'refunds/${r['id']}/approve',
        body: {'amount_cents': value},
      );
      await load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: accessAppBar(context, 'Tickets verwalten'),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LocalText(
              'Lokaler synthetischer Betrieb · keine echte Stripe-Verbindung',
            ),
            LocalText(
              canManageConnection
                  ? 'Du bleibst Verkäufer deiner Tickets. Die Plattformprovision wird vom Erlös abgezogen.'
                  : 'Der Veranstalter bleibt Verkäufer der Tickets. Nur das verantwortliche Konto kann die Zahlungszuordnung ändern.',
            ),
            if (notice != null)
              Semantics(liveRegion: true, child: LocalText(notice!)),
            LocalText(
              connected
                  ? 'Testkonto verbunden'
                  : 'Testkonto noch nicht verbunden',
            ),
            OutlinedButton(
              onPressed: busy || !ready || !canManageConnection
                  ? null
                  : () => run(() async {
                      await widget.api.ticketing(
                        'profiles/${widget.profileId}/connection',
                        body: {'connected': !connected},
                      );
                      await load();
                    }),
              child: LocalText(
                connected
                    ? 'Testkonto trennen'
                    : 'Stripe-Testverbindung simulieren',
              ),
            ),
            OutlinedButton(
              onPressed: busy || !ready
                  ? null
                  : () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => SellerManagementPage(
                          api: widget.api,
                          profileId: widget.profileId,
                        ),
                      ),
                    ),
              child: const LocalText('Verkäuferangaben'),
            ),
            if (widget.api is LegalApi)
              OutlinedButton(
                onPressed: busy || !ready
                    ? null
                    : () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              LegalReviewsPage(api: widget.api as LegalApi),
                        ),
                      ),
                child: const LocalText('Meine Veranstaltungsprüfungen'),
              ),
            const SizedBox(height: AccessSpacing.s24),
            for (final e in ready ? widget.events : <Map<String, dynamic>>[])
              AccessSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LocalText(e['title'] as String),
                    TextButton(
                      onPressed: busy || !ready
                          ? null
                          : () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => EventDeclarationPage(
                                  api: widget.api,
                                  eventId: e['id'] as String,
                                ),
                              ),
                            ),
                      child: const LocalText('Veranstalterbestätigung'),
                    ),
                    LocalText(switch (configs[e['id']]?['mode']) {
                      'public' => 'Öffentlicher Ticketverkauf',
                      'approval' => 'Ticketkauf nach Freigabe',
                      _ => 'Ohne Ticketing',
                    }),
                    if (configs[e['id']]?['mode'] != 'none' &&
                        configs[e['id']] != null)
                      LocalText(
                        '${ticketMoney(configs[e['id']]?['price_cents'])} · ${configs[e['id']]?['quota']} Ticketplätze',
                      ),
                    TextButton(
                      onPressed: busy || !ready ? null : () => privateOffers(e),
                      child: const LocalText(
                        ProductScope.extended
                            ? 'Private Ticketangebote und Einlassrollen'
                            : 'Einlassrollen verwalten',
                      ),
                    ),
                    TextButton(
                      onPressed: busy || !ready ? null : () => edit(e),
                      child: const LocalText('Ticketverkauf einstellen'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AccessSpacing.s24),
            const LocalText(
              'Erstattungsaufgaben',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            if (refunds.isEmpty) const LocalText('Keine Erstattungsaufgaben.'),
            for (final raw in refunds)
              AccessSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LocalText('Bestellung ${raw['order_id']}'),
                    LocalText(
                      'Ticketpreis ${ticketMoney(raw['total_cents'])} · bereits erstattet ${ticketMoney(raw['refunded_cents'])}',
                    ),
                    LocalText(
                      'Provision ${ticketMoney(raw['fee_cents'])} · zurückgegeben ${ticketMoney(raw['fee_refunded_cents'])}',
                    ),
                    LocalText(
                      raw['state'] == 'done'
                          ? 'Erstattung abgeschlossen'
                          : 'Erstattung prüfen',
                    ),
                    if (raw['state'] == 'review')
                      FilledButton(
                        onPressed: busy || !ready
                            ? null
                            : () =>
                                  refund(Map<String, dynamic>.from(raw as Map)),
                        child: const LocalText(
                          'Erstattung prüfen und genehmigen',
                        ),
                      ),
                  ],
                ),
              ),
            OutlinedButton(
              onPressed: busy ? null : () => run(load),
              child: const LocalText('Ticketverwaltung neu laden'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RefundDialog extends StatefulWidget {
  final int remaining;
  const _RefundDialog({required this.remaining});
  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  late final TextEditingController amount;
  final form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    amount = TextEditingController(text: widget.remaining.toString());
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const LocalText('Erstattung genehmigen'),
    content: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LocalText(
            'Die Plattformprovision wird anteilig zurückgegeben.',
          ),
          TextFormField(
            controller: amount,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: localText(context, 'Erstattungsbetrag in Cent'),
            ),
            validator: (value) {
              final cents = int.tryParse(value ?? '');
              return cents == null || cents < 1 || cents > widget.remaining
                  ? localText(
                      context,
                      'Bitte 1 bis ${widget.remaining} Cent eingeben.',
                    )
                  : null;
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const LocalText('Abbrechen'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, int.parse(amount.text));
          }
        },
        child: const LocalText('Erstattung bestätigen'),
      ),
    ],
  );
}

class _TicketConfigDialog extends StatefulWidget {
  final Map<String, dynamic> config;
  const _TicketConfigDialog({required this.config});
  @override
  State<_TicketConfigDialog> createState() => _TicketConfigDialogState();
}

class _TicketConfigDialogState extends State<_TicketConfigDialog> {
  late String mode;
  late TextEditingController price, quota, name;
  final form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    mode = widget.config['mode'] as String;
    price = TextEditingController(
      text: widget.config['price_cents']?.toString() ?? '',
    );
    quota = TextEditingController(
      text: widget.config['quota']?.toString() ?? '',
    );
    name = TextEditingController(
      text: widget.config['item_name'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    price.dispose();
    quota.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const LocalText('Ticketverkauf einstellen'),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: mode,
              decoration: InputDecoration(
                labelText: localText(context, 'Ticketzugang'),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'none',
                  child: LocalText('Ohne Ticketing'),
                ),
                DropdownMenuItem(
                  value: 'public',
                  child: LocalText('Öffentlicher Verkauf'),
                ),
                DropdownMenuItem(
                  value: 'approval',
                  child: LocalText('Nach manueller Freigabe'),
                ),
              ],
              onChanged: (v) => setState(() => mode = v!),
            ),
            if (mode != 'none') ...[
              TextFormField(
                controller: name,
                decoration: InputDecoration(
                  labelText: localText(context, 'Ticketbezeichnung'),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? localText(context, 'Bitte benennen.')
                    : null,
              ),
              TextFormField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: localText(context, 'Ticketpreis in Cent'),
                ),
                validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0
                    ? localText(context, 'Positiven Centbetrag eingeben.')
                    : null,
              ),
              TextFormField(
                controller: quota,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: localText(context, 'Ticketkontingent'),
                ),
                validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0
                    ? localText(context, 'Positive Anzahl eingeben.')
                    : null,
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const LocalText('Abbrechen'),
      ),
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) return;
          Navigator.pop(context, {
            'mode': mode,
            'version': widget.config['version'],
            if (mode != 'none') ...{
              'item_name': name.text.trim(),
              'price_cents': int.parse(price.text),
              'quota': int.parse(quota.text),
            },
          });
        },
        child: const LocalText('Ticketkonfiguration speichern'),
      ),
    ],
  );
}

class TicketFeePage extends StatefulWidget {
  final TicketingApi api;
  const TicketFeePage({super.key, required this.api});
  @override
  State<TicketFeePage> createState() => _TicketFeePageState();
}

class _TicketFeePageState extends State<TicketFeePage> {
  final rate = TextEditingController();
  int version = 0;
  bool busy = false, ready = false;
  String? notice;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    rate.dispose();
    super.dispose();
  }

  Future<bool> load() async {
    try {
      final r = await widget.api.ticketing('fee');
      if (!mounted) return false;
      setState(() {
        ready = true;
        version = r['fee']?['version'] as int? ?? 0;
        rate.text = r['fee'] == null
            ? ''
            : ((r['fee']['basis_points'] as int) / 100).toStringAsFixed(2);
      });
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          ready = false;
          rate.clear();
          notice = e is ApiFailure ? e.message : 'Provision nicht verfügbar.';
        });
      }
    }
    return false;
  }

  Future<void> save() async {
    if (busy || !ready) return;
    final session = TicketingSessionGuard(widget.api);
    final input = rate.text.replaceAll(',', '.');
    if (!RegExp(r'^\d{1,2}(\.\d{1,2})?$').hasMatch(input)) {
      setState(
        () => notice = 'Prozentsatz zwischen 0 und 99,99 mit höchstens zwei Nachkommastellen eingeben.',
      );
      return;
    }
    final parts = input.split('.');
    final points =
        int.parse(parts.first) * 100 +
        int.parse(parts.length == 1 ? '0' : parts.last.padRight(2, '0'));
    setState(() => busy = true);
    try {
      await widget.api.ticketing(
        'fee',
        body: {'basis_points': points, 'version': version},
      );
      session.check();
      final refreshed = await load();
      session.check();
      if (mounted && refreshed) {
        setState(
          () => notice = 'Provision gespeichert. Bestehende Bestellungen behalten ihren Gebührenstand.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
            ready = false;
            rate.clear();
          }
          notice = e is ApiFailure
              ? e.message
              : 'Provision konnte nicht gespeichert werden.';
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
    try {
      await load();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: accessAppBar(context, 'Plattformprovision'),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        width: AccessPageWidth.form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LocalText(
              'Kein Standardsatz. Die Provision wird vom Veranstaltererlös abgezogen und bei Erstattungen anteilig zurückgegeben.',
            ),
            TextField(
              controller: rate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: localText(context, 'Plattformprovision in Prozent'),
              ),
            ),
            if (notice != null)
              Semantics(liveRegion: true, child: LocalText(notice!)),
            OutlinedButton(
              onPressed: busy ? null : refresh,
              child: const LocalText('Aktualisieren'),
            ),
            FilledButton(
              onPressed: busy || !ready ? null : save,
              child: const LocalText('Provision speichern'),
            ),
          ],
        ),
      ),
    ),
  );
}

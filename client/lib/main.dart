import 'package:flutter/material.dart';

import 'access_api.dart';
import 'public_discovery_button.dart';
import 'design_system.dart';
import 'event_page.dart';
import 'invitation_page.dart';
import 'contact_button.dart';
import 'account_recovery_page.dart';

void main() => runApp(
  CommunityAccessApp(
    api: HttpAccessApi(),
    initialInvitation: invitationToken(Uri.base.toString()),
    initialAccountLink: accountLink(Uri.base.toString()),
  ),
);

class CommunityAccessApp extends StatelessWidget {
  final AccessApi api;
  final String? initialInvitation;
  final AccountLinkData? initialAccountLink;
  const CommunityAccessApp({
    super.key,
    required this.api,
    this.initialInvitation,
    this.initialAccountLink,
  });
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Community Access · Gast',
    debugShowCheckedModeBanner: false,
    initialRoute: '/',
    theme: AccessDesign.theme(),
    home: GuestPage(
      api: api,
      initialInvitation: initialInvitation,
      initialAccountLink: initialAccountLink,
    ),
  );
}

class GuestPage extends StatefulWidget {
  final AccessApi api;
  final String? initialInvitation;
  final AccountLinkData? initialAccountLink;
  const GuestPage({
    super.key,
    required this.api,
    this.initialInvitation,
    this.initialAccountLink,
  });
  @override
  State<GuestPage> createState() => _GuestPageState();
}

class _GuestPageState extends State<GuestPage> {
  final _eventsKey = GlobalKey();
  final _communityKey = GlobalKey();
  final _search = TextEditingController();
  final _accountEmail = TextEditingController();
  bool _ownAccount = false;
  String _eventFilter = 'all';
  String _eventQuery = '';
  final _password = TextEditingController(text: 'NurDemo-2026!');
  String _email = 'guest.a@example.invalid';
  Map<String, dynamic>? _data;
  bool _authenticated = false;
  bool _busy = false;
  String? _error;
  String? _notice;
  final Map<int, bool> _age = {};
  final Map<int, String> _locations = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialAccountLink != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openRecovery(widget.initialAccountLink!);
      });
    }
    if (widget.initialInvitation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openInvitation(widget.initialInvitation);
      });
    }
  }

  Future<void> _openInvitation([String? token]) async {
    var signedIn = _authenticated;
    final authenticated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InvitationPage(
          api: widget.api,
          authenticated: _authenticated,
          initialInvitation: token,
          onAuthenticated: () => signedIn = true,
        ),
      ),
    );
    if (mounted && (authenticated == true || signedIn)) {
      setState(() => _authenticated = true);
      await _run(_refresh);
    }
  }

  Future<void> _openRecovery(AccountLinkData link) async {
    var resetCompleted = false;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => AccountRecoveryPage(
          api: widget.api,
          link: link,
          onPasswordReset: () => resetCompleted = true,
        ),
      ),
    );
    if (!mounted) return;
    if (result == 'reset' || resetCompleted) {
      setState(() {
        _authenticated = false;
        _data = null;
        _locations.clear();
        _age.clear();
        _password.clear();
        _ownAccount = true;
      });
    } else if (result == 'verify' && _authenticated) {
      await _run(_refresh);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Die Aktion konnte nicht abgeschlossen werden.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    // Never carry previously fetched locations into a refreshed authorization state.
    if (mounted) setState(_locations.clear);
    final result = await widget.api.snapshot();
    if (mounted) setState(() => _data = result);
  }

  Future<void> _login() => _run(() async {
    await widget.api.login(
      _ownAccount ? _accountEmail.text.trim() : _email,
      _password.text,
    );
    if (mounted) {
      setState(() {
        _authenticated = true;
        _password.clear();
      });
    }
    await _refresh();
  });

  Future<void> _logout() => _run(() async {
    try {
      await widget.api.logout();
    } finally {
      if (mounted) {
        setState(() {
          _authenticated = false;
          _data = null;
          _locations.clear();
          _age.clear();
          _search.clear();
          _eventQuery = '';
          _eventFilter = 'all';
          _password.clear();
          if (!_ownAccount) _password.text = 'NurDemo-2026!';
        });
      }
    }
  });

  Future<void> _withdrawApplication(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bewerbung zurückziehen?'),
        content: const Text(
          'Die Gastgeber können diese Bewerbung danach nicht mehr annehmen. Eine erneute Bewerbung ist gesperrt. Du kannst die Gastgeber weiterhin kontaktieren.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zurück'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rückzug bestätigen'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(() async {
        await widget.api.withdrawApplication(id);
        await _refresh();
        if (mounted) setState(() => _notice = 'Bewerbung zurückgezogen.');
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _accountEmail.dispose();
    _password.dispose();
    widget.api.close();
    super.dispose();
  }

  static String _status(String? status) => switch (status) {
    'pending' => 'Offen',
    'approved' => 'Aufgenommen',
    'rejected' => 'Abgelehnt',
    'withdrawn' => 'Zurückgezogen',
    'confirmed' => 'Event bestätigt',
    'cancelled' => 'Aufgehoben',
    _ => 'Noch nicht angefragt',
  };

  Widget _heading(String text, TextStyle style, {int level = 2}) => Semantics(
    container: true,
    headingLevel: level,
    child: Text(text, style: style),
  );

  Widget _panel(String number, String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: AccessReveal(
      child: AccessSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AccessDesign.neutral,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(number, style: _caption),
              ),
            ),
            const SizedBox(height: 18),
            _heading(
              title,
              const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w500,
                letterSpacing: -.8,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    ),
  );

  static const _caption = TextStyle(
    fontSize: 12,
    color: Color(0xFF55514F),
    height: 1.6,
  );
  static const _body = TextStyle(
    fontSize: 14,
    color: Color(0xFF55514F),
    height: 1.6,
  );

  Widget _statusLabel(
    String text, {
    bool positive = false,
    bool pending = false,
  }) => Semantics(
    liveRegion: true,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: pending
              ? const Color(0xFFFFF0DC)
              : positive
              ? const Color(0xFFE8EEE9)
              : const Color(0xFFEEEAE6),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: pending
                ? const Color(0xFF714516)
                : positive
                ? const Color(0xFF161616)
                : const Color(0xFF55514F),
          ),
        ),
      ),
    ),
  );

  Widget _entry(String title, Widget status) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        status,
      ],
    ),
  );

  Widget _feedback(String text, {bool error = false}) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFAEDE7) : const Color(0xFFE8EEE9),
        border: Border(
          left: BorderSide(
            width: 3,
            color: error ? const Color(0xFFA63028) : const Color(0xFF161616),
          ),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          height: 1.6,
          fontSize: 14,
          color: error ? const Color(0xFFA63028) : const Color(0xFF161616),
        ),
      ),
    ),
  );

  Widget _loginPanel() => _panel(
    'Demo',
    _ownAccount ? 'Mit deinem Testkonto anmelden' : 'Mit Demokonto anmelden',
    [
      Text(
        _ownAccount
            ? 'Melde dich mit deinem neu angelegten synthetischen Konto an.'
            : 'Wähle ein erfundenes Gastkonto.',
        style: _body,
      ),
      const SizedBox(height: 22),
      if (_ownAccount)
        TextField(
          controller: _accountEmail,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'E-Mail'),
        )
      else
        DropdownButtonFormField<String>(
          initialValue: _email,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Demokonto'),
          items: const [
            DropdownMenuItem(
              value: 'guest.a@example.invalid',
              child: Text('Gast A · Wolkenwinkel'),
            ),
            DropdownMenuItem(
              value: 'guest.b@example.invalid',
              child: Text('Gast B · Wolkenwinkel'),
            ),
            DropdownMenuItem(
              value: 'outsider@example.invalid',
              child: Text('Außenstehender Gast'),
            ),
          ],
          onChanged: _busy ? null : (value) => setState(() => _email = value!),
        ),
      const SizedBox(height: 22),
      TextField(
        controller: _password,
        obscureText: true,
        enabled: !_busy,
        decoration: InputDecoration(
          labelText: _ownAccount ? 'Passwort' : 'Demo-Passwort',
        ),
        autofillHints: const [AutofillHints.password],
        onSubmitted: (_) {
          if (!_busy) _login();
        },
      ),
      const SizedBox(height: 10),
      if (!_ownAccount)
        const Text('Nur für die lokale Demo: NurDemo-2026!', style: _caption),
      const SizedBox(height: 24),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          FilledButton(
            onPressed: _busy ? null : _login,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text('Anmelden')),
                SizedBox(width: 12),
                CircleAvatar(
                  radius: 13,
                  backgroundColor: Color(0xFF484951),
                  child: AccessIcon(
                    Icons.north_east,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => _openRecovery(const AccountLinkData('forgot')),
            child: const Text('Passwort vergessen?'),
          ),
        ],
      ),
      TextButton(
        onPressed: _busy
            ? null
            : () => setState(() {
                _ownAccount = !_ownAccount;
                _password.clear();
                if (!_ownAccount) _password.text = 'NurDemo-2026!';
              }),
        child: Text(
          _ownAccount ? 'Demokonto verwenden' : 'Eigenes Testkonto verwenden',
        ),
      ),
      OutlinedButton(
        onPressed: _busy ? null : () => _openInvitation(),
        child: const Text('Einladung öffnen'),
      ),
      const PublicDiscoveryButton(),
    ],
  );

  Widget _event(Map<String, dynamic> event) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AccessDesign.accentSoft,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EVENT',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _heading(
                  event['title'] as String,
                  TextStyle(
                    fontSize: constraints.maxWidth < 270
                        ? 20
                        : constraints.maxWidth < 360
                        ? 24
                        : 30,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                    letterSpacing: -.9,
                  ),
                  level: 3,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          icon: const AccessIcon(Icons.north_east, size: 18),
          label: const Text('Event ansehen'),
          onPressed: _busy
              ? null
              : () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EventPage(
                        api: widget.api,
                        eventId: event['id'] as int,
                      ),
                    ),
                  );
                  if (mounted) await _run(_refresh);
                },
        ),
        const SizedBox(height: 18),
        if (event['status'] == 'cancelled')
          const Text('Dieses Event ist abgesagt.', style: _body),
        Text(
          '${event['capacity']} ${event['capacity'] == 1 ? 'Platz' : 'Plätze'} · ab ${event['minimum_age']} Jahren',
          style: _body,
        ),
        const SizedBox(height: 14),
        _statusLabel(
          'Eventteilnahme: ${_status(event['request_status'] as String?)}',
          positive: event['request_status'] == 'confirmed',
          pending: event['request_status'] == 'pending',
        ),
        const SizedBox(height: 18),
        if (event['request_status'] == null &&
            event['status'] != 'cancelled') ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _age[event['id']] ?? false,
            onChanged: _busy
                ? null
                : (value) =>
                      setState(() => _age[event['id'] as int] = value ?? false),
            title: Text(
              'Ich bestätige, mindestens ${event['minimum_age']} Jahre alt zu sein.',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            subtitle: const Text(
              'Selbstauskunft, keine verifizierte Altersprüfung.',
              style: _caption,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _busy || !(_age[event['id']] ?? false)
                ? null
                : () => _run(() async {
                    await widget.api.requestEvent(event['id'] as int);
                    await _refresh();
                    if (mounted) {
                      setState(
                        () => _notice = 'Event angefragt. Die Gastgeber entscheiden separat.',
                      );
                    }
                  }),
            child: const Text('Eventteilnahme anfragen'),
          ),
        ],
        if (event['request_status'] == 'pending')
          const Text(
            'Deine Anfrage ist offen. Die genaue Location bleibt geschützt.',
            style: _body,
          ),
        if (event['request_status'] == 'confirmed' &&
            event['status'] != 'cancelled') ...[
          OutlinedButton.icon(
            icon: const AccessIcon(Icons.place_outlined, size: 18),
            label: const Text('Location abrufen'),
            onPressed: _busy
                ? null
                : () => _run(() async {
                    final id = event['id'] as int;
                    setState(() => _locations.remove(id));
                    final location = await widget.api.location(id);
                    if (mounted) setState(() => _locations[id] = location);
                  }),
          ),
          if (_locations[event['id']] != null) ...[
            const SizedBox(height: 14),
            Semantics(
              liveRegion: true,
              child: Text(_locations[event['id']]!, style: _body),
            ),
          ],
        ],
      ],
    ),
  );

  void _jumpTo(GlobalKey key) {
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        alignment: 0,
        curve: AccessDesign.curve,
      );
    }
  }

  Widget _masthead() {
    final navigation = Wrap(
      spacing: 8,
      children: [
        TextButton(
          onPressed: () => _jumpTo(_eventsKey),
          child: const Text('Events'),
        ),
        TextButton(
          onPressed: () => _jumpTo(_communityKey),
          child: const Text('Community'),
        ),
      ],
    );
    return AccessHeader(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 620 ||
              MediaQuery.textScalerOf(context).scale(14) > 18;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 112,
                    child: Semantics(
                      label: 'Community Access',
                      child: const ExcludeSemantics(
                        child: Row(
                          children: [
                            AccessIcon(Icons.radio_button_checked, size: 28),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'community\naccess',
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.1,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (_authenticated && !compact) navigation,
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _authenticated
                          ? TextButton(
                              onPressed: _busy ? null : _logout,
                              child: const Text('Abmelden'),
                            )
                          : const Text(
                              'Gastzugang',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              if (_authenticated && compact) navigation,
            ],
          );
        },
      ),
    );
  }

  Widget _intro({bool compact = false}) => AccessReveal(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AccessDesign.accentSoft,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Text('Gastzugang · Lokale Demo', style: _caption),
        ),
        const SizedBox(height: 24),
        _heading(
          _authenticated ? 'Events für dich.' : 'Teil einer Community werden.',
          TextStyle(
            fontSize: compact ? 38 : 64,
            height: 1.08,
            letterSpacing: compact ? -1.5 : -2.8,
            fontWeight: FontWeight.w500,
          ),
          level: 1,
        ),
        const SizedBox(height: 24),
        const Text(
          'Bewerbung → Aufnahme → Eventanfrage → separate Bestätigung',
          style: _body,
        ),
      ],
    ),
  );

  Widget _loginExperience() => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxWidth < 900 ||
          MediaQuery.textScalerOf(context).scale(14) > 18;
      final form = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_busy)
            const LinearProgressIndicator(
              semanticsLabel: 'Anfrage wird bearbeitet',
            ),
          if (_error != null) _feedback(_error!, error: true),
          if (_notice != null) _feedback(_notice!),
          _loginPanel(),
        ],
      );
      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_intro(compact: true), const SizedBox(height: 36), form],
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 80, top: 56),
                child: _intro(),
              ),
            ),
            SizedBox(width: 460, child: form),
          ],
        ),
      );
    },
  );

  bool _eventMatches(dynamic event) {
    final status = event['request_status'];
    final inFilter =
        _eventFilter == 'all' ||
        (_eventFilter == 'requested' &&
            (status == 'pending' || status == 'confirmed')) ||
        (_eventFilter == 'confirmed' && status == 'confirmed');
    return inFilter &&
        (event['title'] as String).toLowerCase().contains(
          _eventQuery.trim().toLowerCase(),
        );
  }

  Widget _eventNavigation() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        container: true,
        child: TextField(
          controller: _search,
          onChanged: (value) => setState(() => _eventQuery = value),
          decoration: InputDecoration(
            labelText: 'Event suchen',
            prefixIcon: const AccessIcon(Icons.search),
            suffixIcon: _eventQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Suche leeren',
                    onPressed: () {
                      _search.clear();
                      setState(() => _eventQuery = '');
                    },
                    icon: const AccessIcon(Icons.close),
                  ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final filter in const {
            'all': 'Alle Events',
            'requested': 'Angefragt',
            'confirmed': 'Bestätigt',
          }.entries)
            ChoiceChip(
              label: Text(filter.value),
              selected: _eventFilter == filter.key,
              onSelected: (_) => setState(() => _eventFilter = filter.key),
              selectedColor: AccessDesign.neutral,
              backgroundColor: Colors.white,
              labelStyle: const TextStyle(
                color: Color(0xFF161616),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              side: const BorderSide(color: Color(0xFF807A76)),
              shape: const StadiumBorder(),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Semantics(
        liveRegion: true,
        child: Text(
          '${(_data!['events'] as List).where(_eventMatches).length} ${(_data!['events'] as List).where(_eventMatches).length == 1 ? 'Event' : 'Events'} in dieser Auswahl',
          style: _caption,
        ),
      ),
      const SizedBox(height: 20),
    ],
  );

  Widget _accessPanels() {
    final panels = [
      _panel('01', 'Bewerbungen', [
        OutlinedButton(
          onPressed: _busy ? null : () => _openInvitation(),
          child: const Text('Einladung öffnen'),
        ),
        const SizedBox(height: 20),
        if ((_data!['applications'] as List).isEmpty)
          const Text('Keine Bewerbungen vorhanden.', style: _body),
        for (final app in _data!['applications'] as List)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _entry(
                app['community'] as String,
                _statusLabel(
                  'Bewerbung: ${_status(app['status'] as String)}',
                  positive: app['status'] == 'approved',
                  pending: app['status'] == 'pending',
                ),
              ),
              if (['rejected', 'withdrawn'].contains(app['status'])) ...[
                const Text(
                  'Eine erneute Bewerbung ist gesperrt.',
                  style: _body,
                ),
                const SizedBox(height: 12),
                ContactButton(contact: app['host_contact'] as String?),
                const SizedBox(height: 24),
              ],
              if (app['status'] == 'pending')
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _withdrawApplication(app['id'] as int),
                    child: const Text('Bewerbung zurückziehen'),
                  ),
                ),
            ],
          ),
        for (final block in (_data!['application_blocks'] as List? ?? []).where(
          (block) => !(_data!['applications'] as List).any(
            (app) => app['community_id'] == block['community_id'],
          ),
        )) ...[
          _entry(
            block['community'] as String,
            const Text('Erneute Bewerbung gesperrt', style: _body),
          ),
          ContactButton(contact: block['host_contact'] as String?),
          const SizedBox(height: 24),
        ],
        const Text(
          'Gastgeber entscheiden manuell. Die Aufnahme allein ist keine Eventzusage.',
          style: _body,
        ),
      ]),
      _panel('02', 'Mitgliedschaften', [
        if ((_data!['memberships'] as List).isEmpty)
          Text(
            (_data!['applications'] as List).any(
                  (app) => app['status'] == 'pending',
                )
                ? 'Noch keine Mitgliedschaft. Warte auf die Entscheidung der Gastgeber.'
                : 'Noch keine Mitgliedschaft.',
            style: _body,
          ),
        for (final member in _data!['memberships'] as List) ...[
          _entry(
            member['community'] as String,
            _statusLabel(
              member['active'] == true
                  ? 'Aktive Mitgliedschaft'
                  : 'Mitgliedschaft entzogen',
              positive: member['active'] == true,
            ),
          ),
          if (member['active'] != true) ...[
            ContactButton(contact: member['host_contact'] as String?),
            const SizedBox(height: 24),
          ],
        ],
      ]),
      _panel('03', 'Events', [
        _eventNavigation(),
        if ((_data!['events'] as List).isEmpty)
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AccessIcon(
                Icons.event_outlined,
                size: 20,
                color: Color(0xFF55514F),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Aktuell sind keine Events für dich zugänglich.',
                  style: _body,
                ),
              ),
            ],
          ),
        if ((_data!['events'] as List).isNotEmpty &&
            (_data!['events'] as List).where(_eventMatches).isEmpty)
          const Text('Keine Events für diese Auswahl.', style: _body),
        for (final event in (_data!['events'] as List).where(_eventMatches))
          _event(Map<String, dynamic>.from(event)),
      ]),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
        if (constraints.maxWidth >= 840 && !largeText) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: KeyedSubtree(key: _eventsKey, child: panels[2]),
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KeyedSubtree(key: _communityKey, child: panels[0]),
                    panels[1],
                  ],
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KeyedSubtree(key: _eventsKey, child: panels[2]),
            KeyedSubtree(key: _communityKey, child: panels[0]),
            panels[1],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          _masthead(),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: double.infinity),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 48),
                        if (!_authenticated) _loginExperience(),
                        if (_authenticated) ...[
                          LayoutBuilder(
                            builder: (context, constraints) => _intro(
                              compact:
                                  constraints.maxWidth < 760 ||
                                  MediaQuery.textScalerOf(context).scale(14) >
                                      18,
                            ),
                          ),
                          const SizedBox(height: 32),
                          if (_busy)
                            const LinearProgressIndicator(
                              semanticsLabel: 'Anfrage wird bearbeitet',
                            ),
                          if (_error != null) _feedback(_error!, error: true),
                          if (_notice != null) _feedback(_notice!),
                        ],
                        if (_authenticated) ...[
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 20,
                            runSpacing: 8,
                            children: [
                              Text(
                                _data?['user']?['name'] as String? ??
                                    'Angemeldet',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _busy ? null : () => _run(_refresh),
                                icon: const AccessIcon(Icons.refresh, size: 18),
                                label: const Text('Aktualisieren'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_data != null)
                            if (_data!['user']?['email_verified'] == true)
                              _accessPanels()
                            else
                              _panel('Konto', 'E-Mail bestätigen', [
                                VerificationNotice(
                                  api: widget.api,
                                  email: _data!['user']?['email'] as String?,
                                  onRefresh: () => _run(_refresh),
                                ),
                              ]),
                        ],
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFC7C0BB), height: 1),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Alle Konten, Kollektive und Orte sind erfunden. Änderungen werden im lokalen Prototyp gespeichert.',
                            style: _caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

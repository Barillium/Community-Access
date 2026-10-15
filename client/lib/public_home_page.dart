import 'flyer_design.dart';

import 'product_scope.dart';
import 'program_date_filter.dart';
import 'faq_content.dart';
import 'communities_page.dart';
import 'app_language.dart';
import 'access_brand.dart';
import 'access_account_menu.dart';
import 'account_registration_page.dart';
import 'better_auth_api.dart' show AccountApi;
import 'bookmark_views.dart';
import 'access_flow_api.dart';
import 'access_flow_page.dart';
import 'event_carousel.dart';
import 'guest_preferences.dart';

import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import 'design_system.dart';
import 'access_api.dart';
import 'directory_api.dart';
import 'directory_pages.dart';
import 'program_views.dart';
import 'site_information_page.dart';

enum _Section { events, communities, organizers, venues, faq }

/// Shared entry renders only the server-filtered public or personal catalog.
class PublicHomePage extends StatefulWidget {
  final WidgetBuilder accountBuilder;
  final DirectoryApi? directoryApi;
  final WidgetBuilder? profileAccountBuilder;
  final String? initialOrganizer;
  final Map<String, String>? initialResource;
  final String? initialProfileLink;
  final WidgetBuilder? initialAccountBuilder;
  const PublicHomePage({
    super.key,
    required this.accountBuilder,
    this.initialAccountBuilder,
    this.directoryApi,
    this.profileAccountBuilder,
    this.initialOrganizer,
    this.initialResource,
    this.initialProfileLink,
  });

  @override
  State<PublicHomePage> createState() => _PublicHomePageState();
}

class _PublicHomePageState extends State<PublicHomePage> {
  _Section _section = _Section.events;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  bool _showSearch = false;
  bool _menuOpen = false;
  ProgramDateFilter _dateFilter = ProgramDateFilter.all;
  final _searchKey = GlobalKey();
  final _searchFocus = FocusNode();
  Map<String, dynamic>? _program, _home;
  bool get _signedIn => _home?['signed_in'] == true;
  int _homeRequest = 0;
  String? _organizerCommunity;
  String? _eventFailure;
  bool _loadingEvents = false;
  int _eventRequest = 0;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadHome();
    if (widget.initialOrganizer != null && widget.directoryApi != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => OrganizerDetailPage(
                api: widget.directoryApi!,
                id: widget.initialOrganizer!,
                token: widget.initialProfileLink,
                openAccount: _openProfileAccount,
              ),
            ),
          );
        }
      });
    }
    final target = widget.initialResource;
    if (target != null &&
        widget.initialOrganizer == null &&
        widget.directoryApi != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => ProgramDetailPage(
                api: widget.directoryApi!,
                kind: target['kind'] == 'event' ? 'events' : 'series',
                id: target['id']!,
                openAccount: _openProfileAccount,
              ),
            ),
          );
        }
      });
    }
    final initial = widget.initialAccountBuilder;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openAccount(initial);
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openAccount([WidgetBuilder? builder]) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: builder ?? widget.accountBuilder));
    if (mounted) {
      await _loadHome();
      await _loadEvents();
    }
  }

  Future<void> _loadHome() async {
    final api = widget.directoryApi;
    if (api == null) return;
    final request = ++_homeRequest;
    try {
      final data = await api.directory('home');
      if (data['signed_in'] is! bool ||
          data['events'] is! List ||
          data['hero'] is! List) {
        throw const FormatException('Invalid home response');
      }
      if (mounted && request == _homeRequest) setState(() => _home = data);
    } catch (_) {
      if (mounted && request == _homeRequest) setState(() => _home = null);
    }
  }

  void _openEvent(String id) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ProgramDetailPage(
          api: widget.directoryApi!,
          kind: 'events',
          id: id,
          openAccount: _openProfileAccount,
        ),
      ),
    );
    if (mounted) await _loadHome();
  }

  Future<void> _openProfileAccount() =>
      _openAccount(widget.profileAccountBuilder);

  Future<void> _loadEvents({int page = 1}) async {
    final api = widget.directoryApi;
    if (api == null) return;
    final request = ++_eventRequest;
    setState(() {
      _program = null;
      _eventFailure = null;
      _loadingEvents = true;
    });
    try {
      final range = programDateRange(_dateFilter);
      final data = await api.directory(
        'events',
        query: {
          'q': _query,
          'page': '$page',
          'scope': 'upcoming',
          if (range != null) 'from': range.from.toUtc().toIso8601String(),
          if (range != null) 'before': range.before.toUtc().toIso8601String(),
        },
      );
      if (mounted && request == _eventRequest) setState(() => _program = data);
    } catch (error) {
      if (mounted && request == _eventRequest) {
        setState(
          () => _eventFailure = error is ApiFailure
              ? error.message
              : 'Die öffentlichen Events konnten nicht geladen werden.',
        );
      }
    } finally {
      if (mounted && request == _eventRequest) {
        setState(() => _loadingEvents = false);
      }
    }
  }

  void _submitSearch() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _query = _search.text.trim());
    _loadEvents();
  }

  void _openInformation(bool privacy) => Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => SiteInformationPage(privacy: privacy)),
  );

  void _select(_Section value, {String? community}) {
    setState(() {
      _section = value;
      if (value == _Section.organizers) _organizerCommunity = community;
    });
    if (_scroll.hasClients) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(0);
      } else {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: AccessDesign.curve,
        );
      }
    }
  }

  Widget _heading(
    String text, {
    int level = 2,
    AccessHeadingRole role = AccessHeadingRole.section,
  }) => AccessHeading(text, level: level, role: role);

  Widget _tag(String text) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AccessSpacing.s12,
      vertical: AccessSpacing.s8,
    ),
    decoration: BoxDecoration(
      color: AushangPalette.of(context).sunken,
      borderRadius: BorderRadius.zero,
    ),
    child: LocalText(
      text,
      style: const TextStyle(
        fontSize: AccessTypography.labelSize,
        letterSpacing: 1,
      ),
    ),
  );

  Widget _nav() => Semantics(
    container: true,
    explicitChildNodes: true,
    role: SemanticsRole.navigation,
    label: localText(context, 'Hauptnavigation'),
    child: _navItems(),
  );

  static const _desktopNavigation = {
    _Section.events: 'Programm',
    _Section.communities: 'Communities',
    _Section.venues: 'Orte',
    _Section.organizers: 'Veranstalter',
    _Section.faq: 'FAQ',
  };

  Widget _navItems() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final item in _desktopNavigation.entries.where(
        (item) => ProductScope.extended || item.key != _Section.venues,
      ))
        TextButton(
          onPressed: () => _select(item.key),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(48, 48),
          ),
          child: Semantics(
            selected: _section == item.key,
            child: FlyerMark(
              active: _section == item.key,
              child: LocalText(item.value),
            ),
          ),
        ),
    ],
  );

  Widget _header() => AccessHeader(
    child: LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 1050 || AccessLayout.largeText(context);
        final palette = AushangPalette.of(context);
        final menuWidth = (MediaQuery.sizeOf(context).width - 32).clamp(
          240.0,
          420.0,
        );
        final menu = PopupMenuButton<_Section>(
          tooltip: localText(context, 'Menü', 'Menu'),
          icon: AccessIcon(
            _menuOpen ? Icons.close : Icons.menu,
            color: FlyerStyle.marker,
          ),
          position: PopupMenuPosition.under,
          offset: const Offset(0, 10),
          elevation: 0,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: const RoundedRectangleBorder(),
          menuPadding: const EdgeInsets.symmetric(vertical: 12),
          constraints: BoxConstraints(minWidth: menuWidth, maxWidth: menuWidth),
          popUpAnimationStyle: AnimationStyle(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 160),
          ),
          onOpened: () => setState(() => _menuOpen = true),
          onCanceled: () => setState(() => _menuOpen = false),
          onSelected: (value) {
            setState(() => _menuOpen = false);
            _select(value);
          },
          itemBuilder: (_) => [
            for (final item in _desktopNavigation.entries.where(
              (item) => ProductScope.extended || item.key != _Section.venues,
            ))
              PopupMenuItem(
                value: item.key,
                height: 56,
                child: Semantics(
                  selected: _section == item.key,
                  child: FlyerMark(
                    active: _section == item.key,
                    child: LocalText(
                      item.value,
                      style: const TextStyle(
                        color: FlyerStyle.ink,
                        fontSize: AccessTypography.leadSize,
                      ),
                    ),
                  ),
                ),
              ),
            PopupMenuItem(
              height: 64,
              onTap: () => Future<void>.delayed(
                Duration.zero,
                () => _signedIn ? _openAccess() : _openAccount(),
              ),
              child: FlyerMark(
                kind: FlyerMarkKind.circle,
                child: LocalText(
                  'Mein Zugang',
                  style: const TextStyle(
                    color: FlyerStyle.ink,
                    fontSize: AccessTypography.leadSize,
                  ),
                ),
              ),
            ),
            if (ProductScope.extended)
              PopupMenuItem(
                height: 56,
                onTap: () =>
                    Future<void>.delayed(Duration.zero, _openBookmarks),
                child: const LocalText('Merkliste'),
              ),
            PopupMenuItem(
              height: 56,
              onTap: () =>
                  Future<void>.delayed(Duration.zero, _openMobileAccountMenu),
              child: const LocalText('Konto und Darstellung'),
            ),
          ],
        );
        return Row(
          children: [
            TextButton(
              onPressed: () => _select(_Section.events),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(104, 48),
              ),
              child: Semantics(
                label: localText(
                  context,
                  'Community Access · Hauptseite',
                  'Community Access · Home',
                ),
                excludeSemantics: true,
                child: Transform.translate(
                  offset: const Offset(-4, 0),
                  child: const AccessBrand(width: 108),
                ),
              ),
            ),
            const Spacer(),
            if (!compact) _nav(),
            if (!compact)
              IconButton(
                onPressed: _openSearch,
                tooltip: localText(context, 'Suche öffnen', 'Open search'),
                icon: const AccessIcon(Icons.search),
              ),
            const FlyerLanguageButton(),
            if (!compact)
              TextButton(
                onPressed: _openAccount,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(48, 48),
                ),
                child: FlyerMark(
                  kind: FlyerMarkKind.circle,
                  child: LocalText(
                    'Mein Zugang',
                    style: TextStyle(color: palette.ink),
                  ),
                ),
              )
            else
              menu,
          ],
        );
      },
    ),
  );

  Widget _intro(String title, String description, bool compact) =>
      AccessSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_section != _Section.events) ...[
              _tag(
                _signedIn
                    ? localText(context, 'DEINE AUSWAHL', 'YOUR SELECTION')
                    : 'OHNE ANMELDUNG ENTDECKEN',
              ),
              const SizedBox(height: AccessSpacing.s24),
            ],
            _heading(
              title,
              level:
                  _section == _Section.events &&
                      (_home?['hero'] as List? ?? []).isNotEmpty
                  ? 2
                  : 1,
              role:
                  _section == _Section.events &&
                      (_home?['hero'] as List? ?? []).isNotEmpty
                  ? AccessHeadingRole.section
                  : AccessHeadingRole.page,
            ),
            const SizedBox(height: AccessSpacing.s24),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AccessLayout.readingWidth,
              ),
              child: LocalText(
                description,
                style: const TextStyle(
                  fontSize: AccessTypography.bodySize,
                  height: AccessTypography.readingHeight,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _searchForm() {
    final field = AccessField(
      decoration: InputDecoration(
        labelText: localText(context, 'Event suchen'),
        hintText: localText(
          context,
          'Event, Veranstalter oder Ort',
          'Event, organizer or venue',
        ),
        helperText: localText(
          context,
          _signedIn
              ? 'Suche in kommenden Veranstaltungen, die für dich sichtbar sind.'
              : 'Suche in kommenden öffentlichen Veranstaltungen.',
          _signedIn
              ? 'Search upcoming events you can access.'
              : 'Search upcoming public events.',
        ),
        helperMaxLines: 20,
        counterText: '',
        prefixIcon: AccessIcon(Icons.search),
      ),
      builder: (decoration) => TextField(
        focusNode: _searchFocus,
        controller: _search,
        maxLength: 180,
        decoration: decoration,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _submitSearch(),
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      ),
    );
    final button = AccessAction(
      kind: AccessActionKind.neutral,
      onPressed: _submitSearch,
      child: const LocalText('Suchen'),
    );
    return Padding(
      key: _searchKey,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = !AccessLayout.columns(
            context,
            constraints.maxWidth,
            minWidth: AccessLayout.searchMinWidth,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    field,
                    const SizedBox(height: AccessSpacing.s20),
                    button,
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: field),
                    const SizedBox(width: AccessSpacing.s24),
                    button,
                  ],
                ),
              if (_query.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      _search.clear();
                      _submitSearch();
                    },
                    child: const LocalText('Suche zurücksetzen'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _empty(String title, String description) => AccessSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ExcludeSemantics(
          child: AccessIcon(
            Icons.radio_button_checked,
            size: AccessLayout.brandIllustrationSize,
            color: AccessDesign.focus,
          ),
        ),
        const SizedBox(height: AccessSpacing.s32),
        _heading(title),
        const SizedBox(height: AccessSpacing.s20),
        LocalText(
          description,
          style: const TextStyle(height: AccessTypography.readingHeight),
        ),
      ],
    ),
  );

  Widget _entryPanels(bool compact) {
    final palette = AushangPalette.of(context);
    Widget panel(
      String tag,
      String title,
      String copy,
      String label,
      VoidCallback action,
      AccessActionKind kind,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localText(context, tag).toUpperCase(),
          style: TextStyle(
            fontSize: AccessTypography.labelSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.04,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: 16),
        AccessHeading(title, role: AccessHeadingRole.card, level: 2),
        const SizedBox(height: 16),
        LocalText(copy, style: TextStyle(color: palette.muted, height: 1.55)),
        const SizedBox(height: 24),
        AccessAction(
          onPressed: action,
          kind: kind,
          suffix: const AccessIcon(Icons.arrow_forward),
          child: LocalText(label),
        ),
      ],
    );
    final guest = panel(
      'Für Gäste',
      ProductScope.extended
          ? 'Mit Konto sortieren wir das Programm nach deinem Geschmack.'
          : 'Mit Konto kannst du eine Aufnahme oder Eventteilnahme anfragen.',
      'Ein Konto schaltet nichts frei.',
      'Konto anlegen',
      _openRegistration,
      AccessActionKind.neutral,
    );
    final host = panel(
      'Für Veranstalter',
      'Du bestimmst, wer kommt und wann der Ort bekannt wird.',
      'Aufnahme und Eventteilnahme werden separat von Hand entschieden.',
      'Als Veranstalter starten',
      _openAccess,
      AccessActionKind.outline,
    );
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.ink)),
      ),
      padding: const EdgeInsets.only(top: 32),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                guest,
                const SizedBox(height: 48),
                Divider(color: palette.hair),
                const SizedBox(height: 32),
                host,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 48),
                    child: guest,
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: palette.hair)),
                    ),
                    padding: const EdgeInsets.only(left: 48),
                    child: host,
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _openRegistration() async {
    final api = widget.directoryApi;
    if (api is! AccountApi) {
      await _openAccount();
      return;
    }
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AccountRegistrationPage(api: api as AccountApi),
      ),
    );
    if (mounted && created != null) await _openAccount();
  }

  String _dateFilterLabel(ProgramDateFilter filter) => switch (filter) {
    ProgramDateFilter.all => localText(context, 'Alle Termine', 'All dates'),
    ProgramDateFilter.today => localText(context, 'Heute', 'Today'),
    ProgramDateFilter.tomorrow => localText(context, 'Morgen', 'Tomorrow'),
    ProgramDateFilter.thisWeek => localText(
      context,
      'Diese Woche',
      'This week',
    ),
  };

  Widget _dateFilters() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final choice in ProgramDateFilter.values)
        Semantics(
          selected: _dateFilter == choice,
          child: TextButton(
            onPressed: () {
              if (_dateFilter == choice) return;
              setState(() => _dateFilter = choice);
              _loadEvents();
            },
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              visualDensity: VisualDensity.standard,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              backgroundColor: _dateFilter == choice
                  ? FlyerStyle.orange
                  : AushangPalette.of(context).page,
              foregroundColor: _dateFilter == choice
                  ? FlyerStyle.ink
                  : AushangPalette.of(context).ink,
              shape: const RoundedRectangleBorder(),
              side: BorderSide(color: AushangPalette.of(context).ink),
            ),
            child: Text(
              _dateFilterLabel(choice),
              style: const TextStyle(fontSize: AccessTypography.captionSize),
            ),
          ),
        ),
    ],
  );

  void _openSearch() {
    setState(() {
      _section = _Section.events;
      _showSearch = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _searchKey.currentContext;
      if (target != null) Scrollable.ensureVisible(target, alignment: .1);
      _searchFocus.requestFocus();
    });
  }

  Widget _events(bool compact) {
    if ((_home?['hero'] as List? ?? []).isEmpty) return _legacyEvents(compact);
    final events = _home?['events'] as List? ?? [];
    final dates = events
        .map(
          (e) => DateTime.tryParse(e['starts_at'] as String? ?? '')?.toLocal(),
        )
        .whereType<DateTime>()
        .toList();
    const monthsDe = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];
    const monthsEn = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final sameMonth =
        dates.isNotEmpty &&
        dates.length == events.length &&
        dates.every(
          (d) => d.year == dates.first.year && d.month == dates.first.month,
        );
    final title = _dateFilter != ProgramDateFilter.all
        ? _dateFilterLabel(_dateFilter)
        : ProductScope.extended && _signedIn
        ? localText(context, 'Für dich', 'For you')
        : sameMonth
        ? localText(
            context,
            monthsDe[dates.first.month - 1],
            monthsEn[dates.first.month - 1],
          )
        : localText(context, 'Programm', 'Program');
    final heading = AccessHeading(
      title,
      role: AccessHeadingRole.section,
      level: 2,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: compact ? 64 : 48),
        if (compact) ...[
          Row(
            children: [
              Expanded(child: heading),
              IconButton(
                onPressed: _openSearch,
                tooltip: localText(context, 'Suche öffnen', 'Open search'),
                icon: const AccessIcon(Icons.search),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _dateFilters(),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: heading),
              _dateFilters(),
            ],
          ),
        if (_showSearch || _query.isNotEmpty) _searchForm(),
        const SizedBox(height: 24),
        _eventResults(),
        if (ProductScope.extended && _signedIn)
          TextButton(
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) =>
                      GuestPreferencesPage(api: widget.directoryApi!),
                ),
              );
              if (mounted) await _loadHome();
            },
            child: const LocalText('Meine Präferenzen'),
          ),
        SizedBox(height: compact ? 96 : 144),
        if (!_signedIn) _entryPanels(compact),
      ],
    );
  }

  Widget _legacyEvents(bool compact) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _intro(
        _signedIn
            ? localText(
                context,
                'Deine nächsten Veranstaltungen.',
                'Your next events.',
              )
            : 'Events & Communities.',
        ProductScope.extended && _signedIn
            ? localText(
                context,
                'Ausgewählt nach deinen Präferenzen, deiner Merkliste, gefolgten Communities und besuchten Veranstaltern.',
                'Selected using your preferences, saved events, followed communities and organizers you have visited.',
              )
            : 'Entdecke, was Gastgeber öffentlich teilen. Dein persönlicher Zugang beginnt mit einer Einladung.',
        compact,
      ),
      _searchForm(),
      _heading(
        ProductScope.extended && _signedIn
            ? localText(context, 'Für dich ausgewählt', 'Selected for you')
            : 'Öffentlich geteilt',
      ),
      const SizedBox(height: 24),
      _dateFilters(),
      const SizedBox(height: 24),
      _eventResults(),
      if (ProductScope.extended && _signedIn)
        TextButton(
          onPressed: () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => GuestPreferencesPage(api: widget.directoryApi!),
              ),
            );
            if (mounted) await _loadHome();
          },
          child: const LocalText('Meine Präferenzen'),
        ),
      const SizedBox(height: AccessSpacing.s64),
      if (!_signedIn) _entryPanels(compact),
    ],
  );

  Widget _eventResults() {
    if (_query.isEmpty &&
        _dateFilter == ProgramDateFilter.all &&
        _home != null) {
      final all = _home!['events'] as List? ?? [];
      final events = all;
      if (events.isNotEmpty) {
        return ProgramList(
          api: widget.directoryApi!,
          showHeading: false,
          calendarLayout: (_home?['hero'] as List? ?? []).isNotEmpty,
          openAccount: _openProfileAccount,
          program: {
            'events': events,
            'signed_in': _signedIn,
            'series': [],
            'page': 1,
            'has_more': false,
          },
          onRefresh: _loadHome,
        );
      }
      return _empty(
        localText(
          context,
          'Noch keine kommenden Veranstaltungen.',
          'No upcoming events yet.',
        ),
        localText(
          context,
          'Hier erscheinen die nächsten freigegebenen Veranstaltungen.',
          'Upcoming shared events will appear here.',
        ),
      );
    }

    if (_loadingEvents) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Öffentliche Events werden geladen',
        ),
      );
    }
    if (widget.directoryApi == null || _eventFailure != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _empty(
            'Öffentliche Events sind derzeit nicht verfügbar.',
            _eventFailure ??
                'In dieser Ansicht ist kein öffentlicher Katalog verfügbar.',
          ),
          if (widget.directoryApi != null)
            TextButton(
              onPressed: _loadEvents,
              child: const LocalText('Erneut versuchen'),
            ),
        ],
      );
    }
    if ((_program?['events'] as List? ?? []).isEmpty &&
        _dateFilter != ProgramDateFilter.all) {
      return _empty(
        localText(
          context,
          'Keine passenden Veranstaltungen in diesem Zeitraum.',
          'No matching events in this period.',
        ),
        localText(
          context,
          'Wähle einen anderen Zeitraum oder zeige alle Termine.',
          'Choose another period or show all dates.',
        ),
      );
    }
    if ((_program?['events'] as List? ?? []).isEmpty) {
      return _empty(
        _query.isEmpty
            ? 'Noch keine öffentlichen Events.'
            : (_signedIn
                  ? 'Keine passenden Veranstaltungen.'
                  : 'Keine passenden öffentlichen Events.'),
        _query.isEmpty
            ? 'Hier erscheinen Events, sobald Gastgeber sie öffentlich teilen.'
            : 'Versuche einen Eventtitel, Veranstalter, Ort oder ein Genre.',
      );
    }
    return ProgramList(
      api: widget.directoryApi!,
      showHeading: false,
      calendarLayout: (_home?['hero'] as List? ?? []).isNotEmpty,
      openAccount: _openProfileAccount,
      program: {..._program!, 'events': _program?['events'] as List? ?? []},
      onPage: (page) => _loadEvents(page: page),
      onRefresh: () => _loadEvents(page: _program?['page'] as int? ?? 1),
    );
  }

  Widget _faq() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const FaqContent(),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          onPressed: _openAccount,
          child: LocalText(
            _signedIn
                ? localText(context, 'Dein Konto')
                : localText(context, 'Anmelden'),
          ),
        ),
      ),
    ],
  );

  Future<void> _openBookmarks() async {
    if (!_signedIn || widget.directoryApi == null) {
      await _openProfileAccount();
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BookmarksPage(
          api: widget.directoryApi!,
          openAccount: _openProfileAccount,
        ),
      ),
    );
    if (mounted) await _loadHome();
  }

  Future<void> _openAccess() async {
    final api = widget.directoryApi;
    if (!_signedIn || api is! AccessApi || api is! AccessFlowApi) {
      await _openProfileAccount();
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AccessFlowPage(
          api: api as AccessApi,
          onReauthenticate: _openProfileAccount,
        ),
      ),
    );
    if (mounted) await _loadHome();
  }

  Widget _footer(bool compact) {
    Widget links(String title, List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localText(context, title),
          style: const TextStyle(
            fontSize: AccessTypography.labelSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
    final columns = [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AccessBrand(width: 160),
          const SizedBox(height: 24),
          const LocalText(
            'Community Access · Lokaler synthetischer Prototyp',
            style: TextStyle(fontSize: AccessTypography.labelSize, height: 1.5),
          ),
        ],
      ),
      links('ENTDECKEN', [
        if (ProductScope.extended)
          TextButton(
            onPressed: () => _select(_Section.venues),
            child: const LocalText('Veranstaltungsorte'),
          ),
        TextButton(
          onPressed: () => _select(_Section.organizers),
          child: const LocalText('Veranstalter'),
        ),
        TextButton(
          onPressed: () => _select(_Section.events),
          child: const LocalText('Programm'),
        ),
        TextButton(
          onPressed: () => _select(_Section.communities),
          child: const LocalText('Communityprofile'),
        ),
      ]),
      links('MITMACHEN', [
        TextButton(
          onPressed: _openAccess,
          child: const LocalText('Für Veranstalter'),
        ),
        TextButton(
          onPressed: () => _select(_Section.faq),
          child: const LocalText('FAQ'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const SiteContactPage()),
          ),
          child: const LocalText('Hilfe & Kontakt'),
        ),
      ]),
      links('RECHTLICHES', [
        TextButton(
          onPressed: () => _openInformation(false),
          child: const LocalText('Betreiber / Impressum'),
        ),
        TextButton(
          onPressed: () => _openInformation(true),
          child: const LocalText('Datenschutz'),
        ),
      ]),
    ];
    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.contentInfo,
      child: Padding(
        padding: const EdgeInsets.only(top: 96, bottom: 48),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AushangPalette.of(context).ink),
            ),
          ),
          padding: const EdgeInsets.only(top: 32),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final column in columns)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: column,
                      ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < columns.length; i++) ...[
                      if (i > 0) const SizedBox(width: 24),
                      Expanded(flex: i == 0 ? 2 : 1, child: columns[i]),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _openMobileAccountMenu() async {
    final openAccount = await showAccessAccountMenu(
      context,
      signedIn: _signedIn,
    );
    if (mounted && openAccount) await _openAccount();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              child: Column(
                children: [
                  Semantics(
                    container: true,
                    explicitChildNodes: true,
                    role: SemanticsRole.main,
                    child: Column(
                      children: [
                        if (_section == _Section.events &&
                            (_home?['hero'] as List? ?? []).isNotEmpty)
                          EventCarousel(
                            events: (_home!['hero'] as List)
                                .cast<Map<String, dynamic>>(),
                            onOpen: _openEvent,
                            onProgram: _openSearch,
                            onCommunities: () => _select(_Section.communities),
                            bookmarkBuilder: (event) => SizedBox(
                              width: 52,
                              child: BookmarkButton(
                                key: ValueKey('hero-bookmark:${event["id"]}'),
                                api: widget.directoryApi!,
                                kind: 'event',
                                id: event['id'] as String,
                                signedIn: _signedIn,
                                compact: true,
                                openAccount: _openProfileAccount,
                              ),
                            ),
                          ),
                        AccessPageFrame(
                          mainLandmark: false,
                          verticalPadding: false,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final compact =
                                  constraints.maxWidth <
                                      AccessLayout.twoColumnMinWidth ||
                                  AccessLayout.largeText(context);
                              return AccessReveal(
                                child: switch (_section) {
                                  _Section.events => _events(compact),
                                  _Section.communities => CommunitiesPage(
                                    api: widget.directoryApi,
                                    openAccount: _openProfileAccount,
                                    onFaq: () => _select(_Section.faq),
                                    onOrganizers: (id) => _select(
                                      _Section.organizers,
                                      community: id,
                                    ),
                                  ),
                                  _Section.organizers => DirectoryBrowser(
                                    key: ValueKey(
                                      'organizers:$_organizerCommunity',
                                    ),
                                    initialCommunity: _organizerCommunity,
                                    api: widget.directoryApi,
                                    venues: false,
                                    openAccount: _openProfileAccount,
                                  ),
                                  _Section.venues => DirectoryBrowser(
                                    key: const ValueKey('venues'),
                                    api: widget.directoryApi,
                                    venues: true,
                                    openAccount: _openProfileAccount,
                                  ),
                                  _Section.faq => _faq(),
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  AccessPageFrame(
                    mainLandmark: false,
                    verticalPadding: false,
                    child: LayoutBuilder(
                      builder: (context, constraints) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AccessSpacing.s64),
                          const Divider(),
                          _footer(
                            constraints.maxWidth <
                                    AccessLayout.twoColumnMinWidth ||
                                AccessLayout.largeText(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

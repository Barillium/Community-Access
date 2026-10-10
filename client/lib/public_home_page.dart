import 'product_scope.dart';
import 'app_language.dart';
import 'access_brand.dart';
import 'access_account_menu.dart';
import 'account_registration_page.dart';
import 'better_auth_api.dart' show AccountApi;
import 'appearance_scope.dart';
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

enum _Section { events, communities, organizers, venues, about }

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
  String _visibilityFilter = 'all';
  final _searchKey = GlobalKey();
  final _searchFocus = FocusNode();
  Map<String, dynamic>? _program, _home;
  bool get _signedIn => _home?['signed_in'] == true;
  int _homeRequest = 0;
  final Set<String> _following = {};
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
      final data = await api.directory(
        'events',
        query: {'q': _query, 'page': '$page', 'scope': 'upcoming'},
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

  void _select(_Section value) {
    setState(() {
      _section = value;
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

  static const _navigation = {
    _Section.events: 'Events',
    _Section.communities: 'Communities',
    _Section.organizers: 'Veranstalter',
    _Section.venues: 'Veranstaltungsorte',
    _Section.about: 'Über',
  };

  static const _desktopNavigation = {
    _Section.events: 'Programm',
    _Section.venues: 'Orte',
    _Section.organizers: 'Veranstalter',
    _Section.about: 'So funktioniert’s',
  };

  Widget _navItems() => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: AccessSpacing.s8,
    children: [
      for (final item in _desktopNavigation.entries.where(
        (item) => ProductScope.extended || item.key != _Section.venues,
      ))
        TextButton(
          onPressed: () => _select(item.key),
          style: TextButton.styleFrom(
            foregroundColor: _section == item.key
                ? AushangPalette.of(context).ink
                : AushangPalette.of(context).muted,
            backgroundColor: Colors.transparent,
            shape: const RoundedRectangleBorder(),
            side: BorderSide.none,
          ),
          child: Semantics(
            selected: _section == item.key,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (_section == item.key)
                  Positioned(
                    left: -4,
                    right: -4,
                    top: 14,
                    height: 9,
                    child: Transform.rotate(
                      angle: -.026,
                      child: ColoredBox(color: AccessDesign.accent),
                    ),
                  ),
                LocalText(
                  localText(context, item.value),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: _section == item.key
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _header() => AccessHeader(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final textStyle = Theme.of(context).textTheme.labelLarge!;
        double textWidth(String text, {TextStyle? style}) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style ?? textStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final width = painter.width;
          painter.dispose();
          return width;
        }

        final accountLabel = localText(
          context,
          _signedIn ? 'Dein Konto' : 'Anmelden',
        );
        final brandLabel = constraints.maxWidth >= 600;
        final brandWidth = brandLabel ? 148.0 : 104.0;
        final language = LanguageScope.of(context);
        final languageLabel = language?.value == true ? 'EN' : 'DE';
        final languageWidth = textWidth(languageLabel) + 72;
        final accountWidth = textWidth(accountLabel) + 56;
        final navWidth = _desktopNavigation.values.fold<double>(
          32,
          (sum, label) =>
              sum +
              textWidth(
                localText(context, label),
                style: textStyle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ) +
              32,
        );
        final compact =
            AccessLayout.largeText(context) ||
            constraints.maxWidth <
                brandWidth + navWidth + languageWidth + accountWidth + 80;
        final iconAccount =
            compact &&
            constraints.maxWidth <
                brandWidth + 48 + languageWidth + accountWidth + 12;
        final brand = TextButton(
          onPressed: () => _select(_Section.events),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: AccessSpacing.s4),
          ),
          child: Semantics(
            label: localText(
              context,
              'Community Access · Hauptseite',
              'Community Access · Home',
            ),
            excludeSemantics: true,
            child: AccessBrand(width: brandLabel ? 140 : 96),
          ),
        );
        final account = iconAccount
            ? IconButton(
                onPressed: _openAccount,
                tooltip: accountLabel,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AushangPalette.of(context).ink,
                  minimumSize: const Size(48, 48),
                ),
                icon: const AccessIcon(Icons.person_outline),
              )
            : AccessAction(
                onPressed: _openAccount,
                small: true,
                child: LocalText(accountLabel),
              );
        final switcher = PopupMenuButton<String>(
          tooltip: localText(context, 'Sprache wählen', 'Choose language'),
          enabled: language != null || AppearanceScope.of(context) != null,
          initialValue: languageLabel,
          onSelected: (value) {
            if (value == 'DE' || value == 'EN') language?.value = value == 'EN';
            if (value == 'light' || value == 'dark') {
              AppearanceScope.of(context)?.value = value == 'dark'
                  ? ThemeMode.dark
                  : ThemeMode.light;
            }
          },
          position: PopupMenuPosition.under,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'DE', child: Text('Deutsch')),
            PopupMenuItem(value: 'EN', child: Text('English')),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'light',
              child: LocalText('Helle Darstellung'),
            ),
            PopupMenuItem(
              value: 'dark',
              child: LocalText('Dunkle Darstellung'),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AccessSpacing.s8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AccessIcon(Icons.language, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    languageLabel,
                    style: textStyle.copyWith(
                      color: AushangPalette.of(context).ink,
                    ),
                  ),
                  const SizedBox(width: AccessSpacing.s4),
                  const AccessIcon(Icons.keyboard_arrow_down, size: 18),
                ],
              ),
            ),
          ),
        );
        final menu = PopupMenuButton<_Section>(
          tooltip: localText(context, 'Menü', 'Menu'),
          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
          position: PopupMenuPosition.under,
          initialValue: _section,
          onSelected: _select,
          icon: const AccessIcon(Icons.menu),
          constraints: const BoxConstraints(minWidth: 240, maxWidth: 280),
          itemBuilder: (_) => [
            for (final item in _navigation.entries.where(
              (item) => ProductScope.extended || item.key != _Section.venues,
            ))
              PopupMenuItem(
                value: item.key,
                child: Semantics(
                  selected: _section == item.key,
                  child: LocalText(item.value),
                ),
              ),
          ],
        );
        if (MediaQuery.sizeOf(context).width < 768) {
          return Row(
            children: [
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: brand),
              ),
              menu,
            ],
          );
        }
        return Row(
          spacing: compact ? AccessSpacing.s4 : AccessSpacing.s8,
          children: [
            if (compact)
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(fit: BoxFit.scaleDown, child: brand),
                ),
              )
            else
              brand,
            if (compact) menu else _nav(),
            if (!compact) const Spacer(),
            IconButton(
              onPressed: _openSearch,
              tooltip: localText(context, 'Suche öffnen', 'Open search'),
              icon: const AccessIcon(Icons.search),
            ),
            switcher,
            account,
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
              role: _section == _Section.events
                  ? AccessHeadingRole.section
                  : AccessHeadingRole.hero,
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

  Widget _accessSteps(bool compact) {
    final steps = [
      (
        '1',
        'Einladung erhalten',
        'Die Moderation teilt eine Einladung über einen bestehenden Kanal. Du beantwortest die Fragen der Community.',
      ),
      (
        '2',
        'Aufnahme abwarten',
        'Moderatoren entscheiden manuell über deine Mitgliedschaft.',
      ),
      (
        '3',
        'Eventteilnahme anfragen',
        'Erst eine separate Zusage bestätigt deinen Eventplatz.',
      ),
    ];
    Widget step((String, String, String) item) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.$1,
          style: const TextStyle(
            fontFamily: 'Archivo',
            fontVariations: [FontVariation('wdth', 68)],
            fontWeight: FontWeight.w800,
            fontSize: 52,
            height: 1,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                headingLevel: 3,
                child: LocalText(
                  item.$2,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              LocalText(
                item.$3,
                style: TextStyle(
                  color: AushangPalette.of(context).muted,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            headingLevel: 2,
            child: Text(
              localText(
                context,
                'So kommst du rein',
                'How to get access',
              ).toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.04,
                color: AushangPalette.of(context).muted,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AushangPalette.of(context).ink),
              ),
            ),
            child: compact
                ? Column(
                    children: [
                      for (final item in steps)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: step(item),
                        ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < steps.length; i++) ...[
                        if (i > 0) const SizedBox(width: 24),
                        Expanded(child: step(steps[i])),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

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
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.04,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          headingLevel: 2,
          child: LocalText(
            title,
            style: TextStyle(
              fontSize: compact ? 24 : 28,
              fontWeight: FontWeight.w600,
              height: 1.18,
              letterSpacing: -.56,
            ),
          ),
        ),
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
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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

  List _visibleProgramEvents(List events) => _visibilityFilter == 'all'
      ? events
      : events
            .where(
              (e) => _visibilityFilter == 'public'
                  ? eventAccessLabel(Map<String, dynamic>.from(e)) ==
                        'Öffentlich'
                  : e['access_mode'] == _visibilityFilter,
            )
            .toList();

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
    final title = ProductScope.extended && _signedIn
        ? localText(context, 'Für dich', 'For you')
        : sameMonth
        ? localText(
            context,
            monthsDe[dates.first.month - 1],
            monthsEn[dates.first.month - 1],
          )
        : localText(context, 'Programm', 'Program');
    Widget filters() => Wrap(
      spacing: 0,
      runSpacing: 8,
      children: [
        for (final choice in [
          ('all', 'Alle', 'All'),
          ('public', 'Öffentlich', 'Public'),
          if (ProductScope.extended)
            ('semi_public', 'Semi-öffentlich', 'Semi-public'),
        ])
          Semantics(
            selected: _visibilityFilter == choice.$1,
            child: TextButton(
              onPressed: () => setState(() => _visibilityFilter = choice.$1),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                backgroundColor: _visibilityFilter == choice.$1
                    ? AushangPalette.of(context).ink
                    : AushangPalette.of(context).page,
                foregroundColor: _visibilityFilter == choice.$1
                    ? AushangPalette.of(context).page
                    : AushangPalette.of(context).ink,
                shape: const RoundedRectangleBorder(),
                side: BorderSide(color: AushangPalette.of(context).ink),
              ),
              child: Text(
                localText(context, choice.$2, choice.$3),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
      ],
    );
    final heading = Semantics(
      headingLevel: 2,
      child: Text(
        title.toUpperCase(),
        semanticsLabel: title,
        style: TextStyle(
          fontSize: compact ? 44 : 72,
          fontWeight: FontWeight.w800,
          fontVariations: const [FontVariation('wdth', 68)],
          height: .9,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_signedIn) _accessSteps(compact),
        SizedBox(height: compact ? 96 : 144),
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
          filters(),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: heading),
              filters(),
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
      if (!_signedIn && (_home?['hero'] as List? ?? []).isNotEmpty)
        _accessSteps(compact),
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
    if (_query.isEmpty && _home != null) {
      final all = _home!['events'] as List? ?? [];
      final events = _visibleProgramEvents(all);
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
    if (_visibleProgramEvents(_program?['events'] as List? ?? []).isEmpty) {
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
      program: {
        ..._program!,
        'events': _visibleProgramEvents(_program?['events'] as List? ?? []),
      },
      onPage: (page) => _loadEvents(page: page),
      onRefresh: () => _loadEvents(page: _program?['page'] as int? ?? 1),
    );
  }

  Widget _communities(bool compact) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _intro(
        'Communities entdecken.',
        'Bestehende Veranstalter bleiben der Mittelpunkt. '
            'Die Gastgeber bestimmen, welche Informationen sie öffentlich teilen.',
        compact,
      ),
      if (_home != null) ...[
        for (final c in _home!['communities'] as List? ?? [])
          AccessSurface(
            child: ListTile(
              title: LocalText(c['name'] as String),
              trailing: !ProductScope.extended
                  ? null
                  : TextButton(
                      onPressed:
                          !ProductScope.extended || _following.contains(c['id'])
                          ? null
                          : () async {
                              if (!_signedIn) {
                                await _openProfileAccount();
                                return;
                              }
                              final id = c['id'] as String;
                              if (_following.contains(id)) return;
                              setState(() => _following.add(id));
                              try {
                                await widget.directoryApi!.directory(
                                  'follow',
                                  body: {
                                    'id': id,
                                    'following': c['following'] != true,
                                  },
                                );
                                if (mounted) await _loadHome();
                              } catch (e) {
                                // Recheck the authoritative status before another attempt:
                                // a lost response can follow a successful write.
                                if (mounted) await _loadHome();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: LocalText(
                                        e is ApiFailure ? e.message : 'Folgen konnte nicht gespeichert werden. Bitte prüfe den aktuellen Status.',
                                      ),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _following.remove(id));
                                }
                              }
                            },
                      child: LocalText(
                        c['following'] == true
                            ? localText(
                                context,
                                'Nicht mehr folgen',
                                'Unfollow',
                              )
                            : localText(context, 'Folgen', 'Follow'),
                      ),
                    ),
            ),
          ),
      ] else
        _empty(
          'Die Communityübersicht ist noch nicht angebunden.',
          'Ein persönlicher Kontakt und eine Einladung sind der Einstieg in eine Community.',
        ),
    ],
  );

  Widget _about(bool compact) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _intro(
        'Entdecken.\nKennenlernen.\nDabei sein.',
        'Community Access ergänzt bestehende Veranstalter um einen nachvollziehbaren Zugang. '
            'Bestehende Kommunikationskanäle bleiben bestehen.',
        compact,
      ),
      for (final step in const [
        (
          '01',
          'Einladung erhalten',
          'Die Moderation teilt eine Einladung über einen bestehenden Kanal.',
        ),
        (
          '02',
          'Persönlich bewerben',
          'Du beantwortest die Fragen der Community.',
        ),
        (
          '03',
          'Aufnahme abwarten',
          'Moderatoren entscheiden manuell über deine Mitgliedschaft.',
        ),
        (
          '04',
          'Eventteilnahme anfragen',
          'Erst eine separate Zusage bestätigt deinen Eventplatz.',
        ),
      ]) ...[
        AccessSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tag(step.$1),
              const SizedBox(height: AccessSpacing.s20),
              _heading(step.$2),
              const SizedBox(height: AccessSpacing.s16),
              LocalText(
                step.$3,
                style: const TextStyle(height: AccessTypography.readingHeight),
              ),
            ],
          ),
        ),
        const SizedBox(height: AccessSpacing.s20),
      ],
      const SizedBox(height: AccessSpacing.s12),
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
            fontSize: 13,
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
            style: TextStyle(fontSize: 13, height: 1.5),
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
          onPressed: () => _select(_Section.about),
          child: const LocalText('Über Community Access'),
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

  Widget _mobileNavigation() {
    Widget destination(
      String label,
      String english,
      IconData icon,
      VoidCallback action, {
      bool selected = false,
    }) => Expanded(
      child: TextButton(
        onPressed: action,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        ),
        child: Semantics(
          selected: selected,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AccessIcon(icon),
              const SizedBox(height: 4),
              Text(
                localText(context, label, english),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AushangPalette.of(context).ink)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            destination(
              'Programm',
              'Program',
              Icons.calendar_month,
              () => _select(_Section.events),
              selected: _section == _Section.events,
            ),
            if (ProductScope.extended)
              destination(
                'Merkliste',
                'Saved',
                Icons.bookmark_border,
                _openBookmarks,
              ),
            destination(
              'Mein Zugang',
              'My access',
              Icons.door_front_door_outlined,
              _openAccess,
            ),
            destination(
              'Konto',
              'Account',
              Icons.account_circle_outlined,
              _openMobileAccountMenu,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: MediaQuery.sizeOf(context).width < 768
        ? _mobileNavigation()
        : null,
    body: SafeArea(
      child: SingleChildScrollView(
        controller: _scroll,
        child: Column(
          children: [
            _header(),
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
                            _Section.communities => _communities(compact),
                            _Section.organizers => DirectoryBrowser(
                              key: const ValueKey('organizers'),
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
                            _Section.about => _about(compact),
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            AccessPageFrame(
              verticalPadding: false,
              child: LayoutBuilder(
                builder: (context, constraints) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AccessSpacing.s64),
                    const Divider(),
                    _footer(
                      constraints.maxWidth < AccessLayout.twoColumnMinWidth ||
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
  );
}

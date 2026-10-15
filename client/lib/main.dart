import 'package:flutter/foundation.dart'
    show LicenseRegistry, LicenseEntryWithLineBreaks;

import 'product_scope.dart';

import 'dart:async';

import 'mobile_links.dart';
import 'account_deletion_api.dart';
import 'account_deletion_page.dart';
import 'resource_return.dart';
import 'store_release.dart';

import 'resource_return_browser.dart'
    if (dart.library.js_interop) 'resource_return_browser_web.dart';
import 'private_access_management_page.dart';
import 'organizer_members_page.dart';
import 'private_ticket_pages.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_language.dart';
import 'access_brand.dart';
import 'flyer_design.dart';
import 'appearance_scope.dart';
import 'guest_preferences.dart';

import 'access_api.dart';
import 'access_flow_api.dart';
import 'access_flow_page.dart';
import 'account_complaints_page.dart';
import 'auth_mode.dart';
import 'public_discovery_button.dart';
import 'design_system.dart';
import 'event_page.dart';
import 'invitation_page.dart';
import 'contact_button.dart';
import 'account_recovery_page.dart';
import 'better_auth_api.dart';
import 'account_registration_page.dart';
import 'public_home_page.dart';
import 'directory_api.dart';
import 'ticketing_api.dart';
import 'legal_api.dart';
import 'legal_pages.dart';
import 'ticketing_pages.dart';
import 'organizer_management_page.dart';
import 'bookmark_views.dart';
import 'social_login_panel.dart';
import 'site_information_page.dart';
import 'social_browser.dart'
    if (dart.library.js_interop) 'social_browser_web.dart';

Future<void> main() async {
  // Expose controls to assistive technology from the first rendered frame.
  WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Archivo',
    ], await rootBundle.loadString('assets/fonts/Archivo-OFL.txt'));
  });
  if (!storeConfigurationValid || !ProductScope.valid) {
    runApp(const StoreUnavailablePage());
    return;
  }
  final launchUri = await initialMobileLink() ?? Uri.base;
  final initialAccountLink = accountLink(launchUri.toString());
  if (initialAccountLink?.token != null) clearAccountLinkFragment();
  runApp(
    CommunityAccessApp(
      api: BetterAuthAccessApi(),
      listenForMobileLinks: true,
      authOnly: true,
      showPublicHome: true,
      initialInvitation: invitationToken(launchUri.toString()),
      initialAccountLink: initialAccountLink,
      initialSocialResult: socialResult(launchUri),
      initialOrganizer: _profileParams(launchUri)['organizer'],
      initialResource: validatedResourceTarget(launchUri.fragment),
      initialProfileLink: _profileParams(launchUri)['profile_link'],
    ),
  );
}

Map<String, String> _profileParams([Uri? uri]) {
  try {
    final params = Uri.splitQueryString((uri ?? Uri.base).fragment);
    if (!RegExp(r'^[0-9a-f-]{36}$').hasMatch(params['organizer'] ?? '')) {
      return {};
    }
    return {
      'organizer': params['organizer']!,
      if (RegExp(r'^[0-9a-f]{64}$').hasMatch(params['profile_link'] ?? ''))
        'profile_link': params['profile_link']!,
    };
  } catch (_) {
    return {};
  }
}

class CommunityAccessApp extends StatefulWidget {
  final bool listenForMobileLinks;
  final Map<String, String>? initialResource;
  final String? initialSocialResult;
  final String? initialOrganizer;
  final String? initialProfileLink;
  final AccessApi api;
  final bool authOnly;
  final bool showPublicHome;
  final String? initialInvitation;
  final AccountLinkData? initialAccountLink;
  const CommunityAccessApp({
    super.key,
    required this.api,
    this.authOnly = false,
    this.showPublicHome = false,
    this.listenForMobileLinks = false,
    this.initialResource,
    this.initialOrganizer,
    this.initialProfileLink,
    this.initialInvitation,
    this.initialAccountLink,
    this.initialSocialResult,
  });
  @override
  State<CommunityAccessApp> createState() => _CommunityAccessAppState();
}

class _CommunityAccessAppState extends State<CommunityAccessApp> {
  final _navigator = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _mobileLinks;
  @override
  void initState() {
    super.initState();
    if (widget.listenForMobileLinks) {
      _mobileLinks = mobileLinkStream().listen(
        _openMobileLink,
        onError: (_) {},
      );
    }
  }

  void _openMobileLink(Uri uri) {
    if (!mounted || !trustedMobileLink(uri)) return;
    final link = accountLink(uri.toString());
    final invitation = invitationToken(uri.toString());
    final target = validatedResourceTarget(uri.fragment);
    final profile = _profileParams(uri);
    final navigator = _navigator.currentState;
    if (navigator == null) return;
    if (link != null || invitation != null) {
      navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => GuestPage(
            api: widget.api,
            closeApiOnDispose: false,
            authOnly: widget.authOnly,
            initialAccountLink: link,
            initialInvitation: invitation,
          ),
        ),
      );
    } else if (widget.api is DirectoryApi &&
        (target != null || profile.isNotEmpty)) {
      navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => PublicHomePage(
            directoryApi: widget.api as DirectoryApi,
            initialResource: target,
            initialOrganizer: profile['organizer'],
            initialProfileLink: profile['profile_link'],
            accountBuilder: (_) => GuestPage(
              api: widget.api,
              closeApiOnDispose: false,
              authOnly: widget.authOnly,
            ),
          ),
        ),
      );
    }
  }

  final _language = AppLanguage();
  final _appearance = ValueNotifier(ThemeMode.system);
  @override
  void dispose() {
    _mobileLinks?.cancel();
    widget.api.close();
    _language.dispose();
    _appearance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_appearance, _language]),
    builder: (context, _) => MaterialApp(
      locale: Locale(_language.value ? 'en' : 'de'),
      supportedLocales: const [Locale('de'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => ValueListenableBuilder<bool>(
        valueListenable: _language,
        builder: (context, english, _) => AppearanceScope(
          mode: _appearance,
          child: LanguageScope(
            language: _language,
            child: Semantics(
              localeForSubtree: Locale(english ? 'en' : 'de'),
              child: AccessForuiTheme(child: child!),
            ),
          ),
        ),
      ),
      title: 'Community Access',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      theme: AccessDesign.theme(),
      darkTheme: AccessDesign.theme(dark: true),
      themeMode: _appearance.value,
      home: widget.showPublicHome
          ? PublicHomePage(
              profileAccountBuilder: (_) => GuestPage(
                api: widget.api,
                initialInvitation: widget.initialInvitation,
                authOnly: widget.authOnly,
                returnToPrevious: true,
                returnAfterLogin: true,
                closeApiOnDispose: false,
              ),
              directoryApi: widget.api is DirectoryApi
                  ? widget.api as DirectoryApi
                  : null,
              initialOrganizer: widget.initialOrganizer,
              initialResource: widget.initialInvitation == null
                  ? widget.initialResource ?? resourceReturnTarget()
                  : null,
              initialProfileLink: widget.initialProfileLink,
              accountBuilder: (_) => GuestPage(
                api: widget.api,
                initialInvitation: widget.initialInvitation,
                authOnly: widget.authOnly,
                closeApiOnDispose: false,
              ),
              initialAccountBuilder:
                  widget.initialInvitation != null ||
                      widget.initialAccountLink != null ||
                      widget.initialSocialResult != null
                  ? (_) => GuestPage(
                      api: widget.api,
                      closeApiOnDispose: false,
                      authOnly: widget.authOnly,
                      initialInvitation: widget.initialInvitation,
                      initialAccountLink: widget.initialAccountLink,
                      initialSocialResult: widget.initialSocialResult,
                      returnAfterLogin:
                          widget.initialInvitation == null &&
                          (widget.initialOrganizer != null ||
                              resourceReturnTarget() != null),
                    )
                  : null,
            )
          : GuestPage(
              api: widget.api,
              closeApiOnDispose: false,
              authOnly: widget.authOnly,
              initialInvitation: widget.initialInvitation,
              initialAccountLink: widget.initialAccountLink,
              initialSocialResult: widget.initialSocialResult,
            ),
    ),
  );
}

class GuestPage extends StatefulWidget {
  final String? initialSocialResult;
  final bool returnToPrevious;
  final bool returnAfterLogin;
  final bool closeApiOnDispose;
  final AccessApi api;
  final bool authOnly;
  final String? initialInvitation;
  final AccountLinkData? initialAccountLink;
  const GuestPage({
    super.key,
    required this.api,
    this.authOnly = false,
    this.returnToPrevious = false,
    this.returnAfterLogin = false,
    this.closeApiOnDispose = true,
    this.initialInvitation,
    this.initialAccountLink,
    this.initialSocialResult,
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
  final _password = TextEditingController(
    text: privateMailMode ? '' : 'NurDemo-2026!',
  );
  String _email = privateMailMode ? '' : 'guest.a@example.invalid';
  Map<String, dynamic>? _data;
  bool _authenticated = false;
  bool _busy = false;
  String? _error;
  String? _notice;
  final Map<Object, bool> _age = {};
  final Map<Object, String> _locations = {};
  int _refreshSequence = 0;

  @override
  void initState() {
    super.initState();
    if (widget.api is BetterAuthAccessApi &&
        widget.initialAccountLink == null &&
        widget.initialSocialResult == null) {
      final knownSession = (widget.api as BetterAuthAccessApi).hasSession;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          () async {
            final attempt = _refreshSequence + 1;
            try {
              await _refresh();
              if (mounted && _data != null && attempt == _refreshSequence) {
                setState(() => _authenticated = true);
              }
            } on ApiFailure catch (error) {
              if ((!error.unauthenticated || knownSession) &&
                  mounted &&
                  attempt == _refreshSequence) {
                setState(() => _error = error.message);
              }
            }
          }();
        }
      });
    }
    if (widget.authOnly) {
      _ownAccount = true;
      _password.clear();
    }
    if (widget.initialAccountLink != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openRecovery(widget.initialAccountLink!);
      });
    }
    if (widget.initialInvitation != null && widget.api is! AccessFlowApi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openInvitation(widget.initialInvitation);
      });
    }
    if (widget.initialSocialResult != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        clearSocialResult();
        if (widget.initialSocialResult == 'success' &&
            widget.api is SocialAuthApi) {
          _run(() async {
            await (widget.api as SocialAuthApi).completeSocial();
            await _refresh();
            if (mounted) {
              setState(() {
                _authenticated = true;
                _password.clear();
              });
              _returnToResource();
            }
          });
        } else {
          setState(
            () => _error = 'Die Anbieteranmeldung wurde nicht abgeschlossen. Bestehende Konten bitte zuerst mit ihrer bisherigen Anmeldemethode anmelden und anschließend verbinden.',
          );
        }
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

  Future<void> _openRegistration() async {
    final api = widget.api;
    if (api is! AccountApi) return;
    final registered = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AccountRegistrationPage(api: api as AccountApi),
      ),
    );
    if (registered != null && mounted) {
      setState(() {
        _ownAccount = true;
        _authenticated = false;
        _data = null;
        _password.clear();
      });
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
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          if (error.unauthenticated || error.accessDenied) {
            _authenticated = false;
            _data = null;
            _locations.clear();
            _age.clear();
          }
        });
      }
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

  Future<void> _reauthenticateResource() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GuestPage(
          api: widget.api,
          authOnly: true,
          returnToPrevious: true,
          returnAfterLogin: true,
          closeApiOnDispose: false,
        ),
      ),
    );
  }

  Future<void> _openAccountRoute(Route<void> route) async {
    await Navigator.of(context).push<void>(route);
    if (mounted && _authenticated) await _run(_refresh);
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    // Never carry previously fetched locations into a refreshed authorization state.
    if (mounted) setState(_locations.clear);
    final sequence = ++_refreshSequence;
    final result = await widget.api.snapshot();
    if (!mounted || sequence != _refreshSequence) return;
    setState(() => _data = result);
  }

  Future<void> _login() => _run(() async {
    _refreshSequence++;
    if (_ownAccount) {
      final emailError = syntheticEmail(_accountEmail.text);
      if (emailError != null) throw ApiFailure(emailError);
      if (_password.text.isEmpty) {
        throw const ApiFailure('Trage dein Passwort ein.');
      }
    }
    await widget.api.login(
      _ownAccount ? _accountEmail.text.trim() : _email,
      _password.text,
    );
    TextInput.finishAutofillContext(shouldSave: true);
    if (mounted) {
      setState(() {
        _authenticated = true;
        _password.clear();
      });
    }
    await _refresh();
    _returnToResource();
  });

  void _returnToResource() {
    if (mounted &&
        widget.returnAfterLogin &&
        _data != null &&
        _data?['platform_blocked'] != true &&
        Navigator.of(context).canPop()) {
      Navigator.pop(context);
    }
  }

  Future<void> _logout() => _run(() async {
    _refreshSequence++;
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

  Future<void> _withdrawApplication(Object id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const LocalText('Bewerbung zurückziehen?'),
        content: const LocalText(
          'Die Gastgeber können diese Bewerbung danach nicht mehr annehmen. Mit einer gültigen Einladung kannst du dich erneut bewerben. Der Rückzug gibt keine Mitgliedschaft oder Eventzusage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const LocalText('Zurück'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const LocalText('Rückzug bestätigen'),
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
    if (widget.closeApiOnDispose) widget.api.close();
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
    child: LocalText(text, style: style),
  );

  Widget _panel(String number, String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: AccessSpacing.s24),
    child: AccessReveal(
      child: AccessSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AccessSpacing.s12,
                  vertical: AccessSpacing.s8,
                ),
                decoration: BoxDecoration(
                  color: AushangPalette.of(context).sunken,
                  borderRadius: BorderRadius.zero,
                ),
                child: LocalText(number, style: _caption),
              ),
            ),
            const SizedBox(height: AccessSpacing.s20),
            _heading(
              title,
              const TextStyle(
                fontSize: AccessTypography.sectionTitleSize,
                fontWeight: FontWeight.w500,
                letterSpacing: -.8,
                height: AccessTypography.titleHeight,
              ),
            ),
            const SizedBox(height: AccessSpacing.s24),
            ...children,
          ],
        ),
      ),
    ),
  );

  static const _caption = TextStyle(
    fontSize: AccessTypography.captionSize,
    height: AccessTypography.readingHeight,
  );
  static const _body = TextStyle(
    fontSize: AccessTypography.bodySize,
    height: AccessTypography.readingHeight,
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
        padding: const EdgeInsets.symmetric(
          horizontal: AccessSpacing.s12,
          vertical: AccessSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: pending || positive
              ? AushangPalette.of(context).decisionSurface
              : AushangPalette.of(context).sunken,
          borderRadius: BorderRadius.zero,
        ),
        child: LocalText(
          text,
          style: TextStyle(
            fontSize: AccessTypography.labelSize,
            height: AccessTypography.bodyHeight,
            color: positive
                ? AushangPalette.of(context).decision
                : AushangPalette.of(context).ink,
          ),
        ),
      ),
    ),
  );

  Widget _entry(String title, Widget status) => Padding(
    padding: const EdgeInsets.only(bottom: AccessSpacing.s20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LocalText(
          title,
          style: const TextStyle(
            fontSize: AccessTypography.bodySize,
            fontWeight: FontWeight.w600,
            height: AccessTypography.bodyHeight,
          ),
        ),
        const SizedBox(height: AccessSpacing.s12),
        status,
      ],
    ),
  );

  Widget _feedback(String text, {bool error = false}) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.only(bottom: AccessSpacing.s20),
      padding: const EdgeInsets.all(AccessSpacing.s16),
      decoration: BoxDecoration(
        color: error
            ? AushangPalette.of(context).decisionSurface
            : AushangPalette.of(context).sunken,
        border: Border(
          left: BorderSide(
            width: 3,
            color: error
                ? AushangPalette.of(context).decision
                : AushangPalette.of(context).ink,
          ),
        ),
      ),
      child: LocalText(
        text,
        style: TextStyle(
          height: AccessTypography.readingHeight,
          fontSize: AccessTypography.captionSize,
          color: error
              ? AushangPalette.of(context).decision
              : AushangPalette.of(context).ink,
        ),
      ),
    ),
  );

  Widget _loginPanel() => _panel(
    widget.authOnly ? 'Konto' : 'Demo',
    _ownAccount
        ? (privateMailMode
              ? 'Mit deinem Konto anmelden'
              : 'Mit deinem Testkonto anmelden')
        : 'Mit Demokonto anmelden',
    [
      LocalText(
        _ownAccount
            ? (privateMailMode
                  ? 'Melde dich mit deinem Konto an.'
                  : 'Melde dich mit deinem neu angelegten synthetischen Konto an.')
            : 'Wähle ein erfundenes Gastkonto.',
        style: _body,
      ),
      const SizedBox(height: AccessSpacing.s24),
      if (_ownAccount)
        AccessField(
          decoration: const InputDecoration(labelText: 'E-Mail'),
          builder: (decoration) => TextField(
            controller: _accountEmail,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            autocorrect: false,
            enableSuggestions: false,
            decoration: decoration,
          ),
        )
      else
        AccessField(
          decoration: const InputDecoration(labelText: 'Demokonto'),
          trailingWidth: AccessSpacing.s40,
          builder: (decoration) => DropdownButtonFormField<String>(
            initialValue: _email,
            isExpanded: true,
            itemHeight: null,
            decoration: decoration,
            items: const [
              DropdownMenuItem(
                value: 'guest.a@example.invalid',
                child: AccessOptionText('Gast A · Wolkenwinkel'),
              ),
              DropdownMenuItem(
                value: 'guest.b@example.invalid',
                child: AccessOptionText('Gast B · Wolkenwinkel'),
              ),
              DropdownMenuItem(
                value: 'outsider@example.invalid',
                child: AccessOptionText('Außenstehender Gast'),
              ),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _email = value!),
          ),
        ),
      const SizedBox(height: AccessSpacing.s24),
      AccessField(
        decoration: InputDecoration(
          labelText: _ownAccount ? 'Passwort' : 'Demo-Passwort',
        ),
        builder: (decoration) => TextField(
          controller: _password,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          enabled: !_busy,
          decoration: decoration,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) {
            if (!_busy) _login();
          },
        ),
      ),
      const SizedBox(height: AccessSpacing.s12),
      if (!_ownAccount)
        const LocalText(
          'Nur für die lokale Demo: NurDemo-2026!',
          style: _caption,
        ),
      const SizedBox(height: AccessSpacing.s24),
      AccessStack(
        gap: AccessSpacing.s12,
        children: [
          Wrap(
            spacing: AccessSpacing.s12,
            runSpacing: AccessSpacing.s8,
            children: [
              FilledButton(
                style: AccessDesign.primaryAction(context),
                onPressed: _busy ? null : _login,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: LocalText('Anmelden')),
                    SizedBox(width: AccessSpacing.s12),
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
                child: const LocalText('Passwort vergessen?'),
              ),
            ],
          ),
          if (!widget.authOnly)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _ownAccount = !_ownAccount;
                      _password.clear();
                      if (!_ownAccount) _password.text = 'NurDemo-2026!';
                    }),
              child: LocalText(
                _ownAccount
                    ? 'Demokonto verwenden'
                    : (privateMailMode
                          ? 'Eigenes Konto verwenden'
                          : 'Eigenes Testkonto verwenden'),
              ),
            ),
          if (widget.authOnly)
            OutlinedButton(
              onPressed: _busy ? null : _openRegistration,
              child: const LocalText(
                privateMailMode ? 'Konto anlegen' : 'Testkonto anlegen',
              ),
            ),
          if (!widget.authOnly)
            OutlinedButton(
              onPressed: _busy ? null : () => _openInvitation(),
              child: const LocalText('Einladung öffnen'),
            ),
          if (!widget.authOnly) const PublicDiscoveryButton(),
        ],
      ),
      if (widget.authOnly && widget.api is SocialAuthApi)
        SocialLoginPanel(api: widget.api as SocialAuthApi, disabled: _busy),
    ],
  );

  Widget _event(Map<String, dynamic> event) => Padding(
    padding: const EdgeInsets.only(bottom: AccessSpacing.s20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => Container(
            padding: const EdgeInsets.all(AccessSpacing.s20),
            decoration: BoxDecoration(
              color: AushangPalette.of(context).decisionSurface,
              borderRadius: BorderRadius.zero,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LocalText(
                  'EVENT',
                  style: TextStyle(
                    fontSize: AccessTypography.labelSize,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AccessSpacing.s16),
                AccessHeading(
                  event['title'] as String,
                  role: AccessHeadingRole.card,
                  level: 3,
                  weight: FontWeight.w700,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AccessSpacing.s20),
        OutlinedButton.icon(
          icon: const AccessIcon(
            Icons.north_east,
            size: AccessLayout.smallIconSize,
          ),
          label: const LocalText('Event ansehen'),
          onPressed: _busy
              ? null
              : () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EventPage(
                        api: widget.api,
                        eventId: event['id'] as Object,
                      ),
                    ),
                  );
                  if (mounted) await _run(_refresh);
                },
        ),
        const SizedBox(height: AccessSpacing.s20),
        if (event['status'] == 'cancelled')
          const LocalText('Dieses Event ist abgesagt.', style: _body),
        LocalText(
          '${event['capacity']} ${event['capacity'] == 1 ? 'Platz' : 'Plätze'} · ab ${event['minimum_age']} Jahren',
          style: _body,
        ),
        const SizedBox(height: AccessSpacing.s16),
        _statusLabel(
          'Eventteilnahme: ${_status(event['request_status'] as String?)}',
          positive: event['request_status'] == 'confirmed',
          pending: event['request_status'] == 'pending',
        ),
        const SizedBox(height: AccessSpacing.s20),
        if (event['request_status'] == null &&
            event['ticket_mode'] != 'public' &&
            event['status'] != 'cancelled') ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _age[event['id']] ?? false,
            onChanged: _busy
                ? null
                : (value) => setState(
                    () => _age[event['id'] as Object] = value ?? false,
                  ),
            title: LocalText(
              'Ich bestätige, mindestens ${event['minimum_age']} Jahre alt zu sein.',
              style: const TextStyle(
                fontSize: AccessTypography.captionSize,
                height: AccessTypography.bodyHeight,
              ),
            ),
            subtitle: const LocalText(
              'Selbstauskunft, keine verifizierte Altersprüfung.',
              style: _caption,
            ),
          ),
          const SizedBox(height: AccessSpacing.s16),
          FilledButton(
            onPressed: _busy || !(_age[event['id']] ?? false)
                ? null
                : () => _run(() async {
                    await widget.api.requestEvent(event['id'] as Object);
                    await _refresh();
                    if (mounted) {
                      setState(
                        () => _notice = 'Event angefragt. Die Gastgeber entscheiden separat.',
                      );
                    }
                  }),
            child: const LocalText('Eventteilnahme anfragen'),
          ),
        ],
        if (event['request_status'] == 'pending')
          const LocalText(
            'Deine Anfrage ist offen. Die genaue Location bleibt geschützt.',
            style: _body,
          ),
        if (event['request_status'] == 'confirmed' &&
            event['status'] != 'cancelled') ...[
          OutlinedButton.icon(
            icon: const AccessIcon(
              Icons.place_outlined,
              size: AccessLayout.smallIconSize,
            ),
            label: const LocalText('Location abrufen'),
            onPressed: _busy
                ? null
                : () => _run(() async {
                    final id = event['id'] as Object;
                    setState(() => _locations.remove(id));
                    final sequence = _refreshSequence;
                    final location = await widget.api.location(id);
                    if (mounted && sequence == _refreshSequence) {
                      setState(() => _locations[id] = location);
                    }
                  }),
          ),
          if (_locations[event['id']] != null) ...[
            const SizedBox(height: AccessSpacing.s16),
            Semantics(
              liveRegion: true,
              child: LocalText(_locations[event['id']]!, style: _body),
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
      spacing: AccessSpacing.s8,
      children: [
        TextButton(
          onPressed: () => _jumpTo(_eventsKey),
          child: const LocalText('Events'),
        ),
        TextButton(
          onPressed: () => _jumpTo(_communityKey),
          child: const LocalText('Community'),
        ),
      ],
    );
    return AccessHeader(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < AccessLayout.compactControlsWidth ||
              AccessLayout.largeText(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: AccessLayout.brandLockupWidth,
                    child: Semantics(
                      label: 'Community Access',
                      child: const ExcludeSemantics(
                        child: AccessBrand(
                          width: AccessLayout.brandLockupWidth,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AccessSpacing.s16),
                  const FlyerLanguageButton(),
                  if (_authenticated && !compact && !widget.authOnly)
                    navigation,
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _authenticated
                          ? TextButton(
                              onPressed: _busy ? null : _logout,
                              child: const LocalText('Abmelden'),
                            )
                          : const LocalText(
                              'Gastzugang',
                              style: TextStyle(
                                fontSize: AccessTypography.labelSize,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              if (_authenticated && compact && !widget.authOnly) navigation,
              if (Navigator.of(context).canPop())
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      if (widget.returnToPrevious) {
                        Navigator.of(context).pop();
                      } else {
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      }
                    },
                    child: LocalText(
                      widget.returnToPrevious ? 'Zurück' : 'Zur Hauptseite',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _intro({bool compact = false, double? referenceWidth}) => AccessReveal(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AccessSpacing.s12,
            vertical: AccessSpacing.s8,
          ),
          decoration: BoxDecoration(
            color: AushangPalette.of(context).decisionSurface,
            borderRadius: BorderRadius.zero,
          ),
          child: const LocalText('Gastzugang · Lokale Demo', style: _caption),
        ),
        const SizedBox(height: AccessSpacing.s24),
        AccessHeading(
          _authenticated
              ? (widget.authOnly ? 'Dein Konto.' : 'Events für dich.')
              : 'Teil einer Community werden.',
          role: AccessHeadingRole.page,
          referenceWidth: referenceWidth,
          level: 1,
        ),
        const SizedBox(height: AccessSpacing.s24),
        const LocalText(
          'Bewerbung – Aufnahme – Eventanfrage – separate Bestätigung',
          style: _body,
        ),
      ],
    ),
  );

  Widget _loginExperience() => AutofillGroup(
    child: LayoutBuilder(
      builder: (context, constraints) => AccessSection(
        child: AccessColumns(
          minWidth: AccessLayout.accountColumnsMinWidth,
          gap: AccessSpacing.s48,
          children: [
            _intro(referenceWidth: constraints.maxWidth),
            AccessContent(
              width: AccessPageWidth.form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_busy)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Anfrage wird bearbeitet',
                    ),
                  if (_error != null) _feedback(_error!, error: true),
                  if (_notice != null) _feedback(_notice!),
                  _loginPanel(),
                  const SiteInformationLinks(),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
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
        child: AccessField(
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
          builder: (decoration) => TextField(
            controller: _search,
            onChanged: (value) => setState(() => _eventQuery = value),
            decoration: decoration,
          ),
        ),
      ),
      const SizedBox(height: AccessSpacing.s12),
      Wrap(
        spacing: AccessSpacing.s8,
        runSpacing: AccessSpacing.s8,
        children: [
          for (final filter in const {
            'all': 'Alle Events',
            'requested': 'Angefragt',
            'confirmed': 'Bestätigt',
          }.entries)
            ChoiceChip(
              label: LocalText(filter.value),
              selected: _eventFilter == filter.key,
              onSelected: (_) => setState(() => _eventFilter = filter.key),
              selectedColor: AushangPalette.of(context).sunken,
              backgroundColor: AushangPalette.of(context).page,
              labelStyle: TextStyle(
                color: AushangPalette.of(context).ink,
                fontSize: AccessTypography.captionSize,
                fontWeight: FontWeight.w600,
              ),
              side: const BorderSide(color: Color(0xFF807A76)),
              shape: const RoundedRectangleBorder(),
            ),
        ],
      ),
      const SizedBox(height: AccessSpacing.s16),
      Semantics(
        liveRegion: true,
        child: LocalText(
          '${(_data!['events'] as List).where(_eventMatches).length} ${(_data!['events'] as List).where(_eventMatches).length == 1 ? 'Event' : 'Events'} in dieser Auswahl',
          style: _caption,
        ),
      ),
      const SizedBox(height: AccessSpacing.s20),
    ],
  );

  Widget _accessPanels() {
    if (widget.authOnly) {
      final user = _data!['user'] as Map<String, dynamic>;
      return AccessContent(
        width: AccessPageWidth.form,
        child: _panel(
          'Konto',
          privateMailMode ? 'Dein Konto' : 'Dein Testkonto',
          [
            LocalText(user['email'] as String, style: _body),
            const SizedBox(height: AccessSpacing.s20),
            if (user['email_verified'] != true)
              VerificationNotice(
                api: widget.api,
                email: user['email'] as String,
                onRefresh: () => _run(_refresh),
              )
            else
              const LocalText(
                'Deine E-Mail-Adresse ist bestätigt.',
                style: _body,
              ),
            const SizedBox(height: AccessSpacing.s24),
            if (widget.api is AccountDeletionApi)
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _openAccountRoute(
                        MaterialPageRoute(
                          builder: (_) => AccountDeletionPage(
                            api: widget.api as AccountDeletionApi,
                          ),
                        ),
                      ),
                child: Text(
                  localText(context, 'Konto löschen', 'Delete account'),
                ),
              ),
            if (_data!['platform_blocked'] == true)
              const LocalText(
                'Dein Konto ist für Plattformaktionen gesperrt. Eigene Bestellbelege und Beschwerden bleiben erreichbar.',
              ),
            if (widget.api is AccessFlowApi)
              OutlinedButton(
                onPressed: () => _openAccountRoute(
                  MaterialPageRoute(
                    builder: (_) =>
                        AccountComplaintsPage(api: widget.api as AccessFlowApi),
                  ),
                ),
                child: const LocalText('Meine Beschwerden'),
              ),
            if (_data!['platform_blocked'] != true &&
                widget.api is AccessFlowApi)
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => OrganizerMembersPage(
                              api: widget.api as AccessFlowApi,
                            ),
                          ),
                        );
                        if (mounted) await _run(_refresh);
                      },
                child: const LocalText('Auftritte und Einladungen'),
              ),
            if (_data!['product_available'] == true &&
                widget.api is AccessFlowApi)
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => AccessFlowPage(
                              api: widget.api,
                              onReauthenticate: () async {
                                await Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => GuestPage(
                                      api: widget.api,
                                      authOnly: true,
                                      returnToPrevious: true,
                                      returnAfterLogin: true,
                                      closeApiOnDispose: false,
                                    ),
                                  ),
                                );
                              },
                              initialInvitation: widget.initialInvitation,
                            ),
                          ),
                        );
                        if (mounted) await _run(_refresh);
                      },
                child: const LocalText('Zugang verwalten'),
              ),
            if (_data!['can_manage_access'] == true &&
                widget.api is AccessFlowApi)
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _openAccountRoute(
                        MaterialPageRoute(
                          builder: (_) => PrivateAccessManagementPage(
                            api: widget.api as AccessFlowApi,
                          ),
                        ),
                      ),
                child: const LocalText('Freigaben und Moderation'),
              ),
            if (_data!['ticketing_available'] == true &&
                widget.api is TicketingApi) ...[
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _openAccountRoute(
                        MaterialPageRoute(
                          builder: (_) => MyTicketsPage(
                            api: widget.api as TicketingApi,
                            receiptsOnly: _data!['platform_blocked'] == true,
                          ),
                        ),
                      ),
                child: const LocalText('Meine Tickets'),
              ),
              if (_data!['can_scan'] == true && widget.api is AccessFlowApi)
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _openAccountRoute(
                          MaterialPageRoute(
                            builder: (_) => OnlineCheckinPage(
                              api: widget.api as AccessFlowApi,
                            ),
                          ),
                        ),
                  child: const LocalText('Online-Einlass'),
                ),
              if (_data!['is_team'] == true)
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _openAccountRoute(
                          MaterialPageRoute(
                            builder: (_) =>
                                TicketFeePage(api: widget.api as TicketingApi),
                          ),
                        ),
                  child: const LocalText('Plattformprovision verwalten'),
                ),
            ],
            if (widget.api is LegalApi)
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _openAccountRoute(
                        MaterialPageRoute(
                          builder: (_) => LegalReviewsPage(
                            api: widget.api as LegalApi,
                            team: _data!['is_team'] == true,
                          ),
                        ),
                      ),
                child: LocalText(
                  _data!['is_team'] == true
                      ? 'Veranstaltungsmeldungen prüfen'
                      : 'Meine Veranstaltungsprüfungen',
                ),
              ),
            if (_data!['platform_blocked'] != true &&
                widget.api is SocialAuthApi)
              SocialLoginPanel(
                api: widget.api as SocialAuthApi,
                link: true,
                disabled: _busy,
              ),
            if (ProductScope.extended &&
                _data!['directory_available'] == true &&
                widget.api is DirectoryApi) ...[
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _openAccountRoute(
                        MaterialPageRoute(
                          builder: (_) => BookmarksPage(
                            api: widget.api as DirectoryApi,
                            openAccount: _reauthenticateResource,
                          ),
                        ),
                      ),
                child: const LocalText('Meine Merkliste'),
              ),
              const SizedBox(height: AccessSpacing.s16),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _openAccountRoute(
                        MaterialPageRoute(
                          builder: (_) => GuestPreferencesPage(
                            api: widget.api as DirectoryApi,
                          ),
                        ),
                      ),
                child: const LocalText('Meine Präferenzen'),
              ),
              const SizedBox(height: AccessSpacing.s24),
            ],
            if (_data!['is_host'] == true && widget.api is DirectoryApi) ...[
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _openAccountRoute(
                        MaterialPageRoute(
                          builder: (_) => OrganizerManagementPage(
                            api: widget.api as DirectoryApi,
                          ),
                        ),
                      ),
                child: const LocalText('Gastgeberverwaltung'),
              ),
              const SizedBox(height: AccessSpacing.s24),
            ],
            const LocalText(
              ProductScope.extended
                  ? 'Dein Konto begründet keine Mitgliedschaft oder Eventzusage. Profilzugriff wird separat vom Gastgeber freigegeben.'
                  : 'Dein Konto begründet keine Mitgliedschaft oder Eventzusage.',
              style: _body,
            ),
          ],
        ),
      );
    }
    final panels = [
      _panel('01', 'Bewerbungen', [
        OutlinedButton(
          onPressed: _busy ? null : () => _openInvitation(),
          child: const LocalText('Einladung öffnen'),
        ),
        const SizedBox(height: AccessSpacing.s20),
        if ((_data!['applications'] as List).isEmpty)
          const LocalText('Keine Bewerbungen vorhanden.', style: _body),
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
              if (app['status'] == 'withdrawn') ...[
                const LocalText(
                  'Du kannst dich erneut bewerben. Öffne dafür eine gültige Einladung dieser Community.',
                  style: _body,
                ),
                const SizedBox(height: AccessSpacing.s24),
              ],
              if (app['status'] == 'rejected') ...[
                const LocalText(
                  'Eine erneute Bewerbung ist gesperrt.',
                  style: _body,
                ),
                const SizedBox(height: AccessSpacing.s12),
                ContactButton(contact: app['host_contact'] as String?),
                const SizedBox(height: AccessSpacing.s24),
              ],
              if (app['status'] == 'pending')
                Padding(
                  padding: const EdgeInsets.only(bottom: AccessSpacing.s20),
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _withdrawApplication(app['id'] as Object),
                    child: const LocalText('Bewerbung zurückziehen'),
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
            LocalText(
              block['reason'] == 'withdrawn'
                  ? 'Freiwillig zurückgezogen – erneute Bewerbung möglich'
                  : 'Erneute Bewerbung gesperrt',
              style: _body,
            ),
          ),
          ContactButton(contact: block['host_contact'] as String?),
          const SizedBox(height: AccessSpacing.s24),
        ],
        const LocalText(
          'Moderatoren entscheiden manuell. Die Aufnahme allein ist keine Eventzusage.',
          style: _body,
        ),
      ]),
      _panel('02', 'Mitgliedschaften', [
        if ((_data!['memberships'] as List).isEmpty)
          LocalText(
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
            const SizedBox(height: AccessSpacing.s24),
          ],
        ],
      ]),
      _panel('03', 'Events', [
        _eventNavigation(),
        if ((_data!['events'] as List).isEmpty)
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AccessIcon(Icons.event_outlined, size: 20),
              SizedBox(width: AccessSpacing.s12),
              Expanded(
                child: LocalText(
                  'Aktuell sind keine Events für dich zugänglich.',
                  style: _body,
                ),
              ),
            ],
          ),
        if ((_data!['events'] as List).isNotEmpty &&
            (_data!['events'] as List).where(_eventMatches).isEmpty)
          const LocalText('Keine Events für diese Auswahl.', style: _body),
        for (final event in (_data!['events'] as List).where(_eventMatches))
          _event(Map<String, dynamic>.from(event)),
      ]),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (AccessLayout.columns(context, constraints.maxWidth)) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: KeyedSubtree(key: _eventsKey, child: panels[2]),
              ),
              const SizedBox(width: AccessSpacing.s32),
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
              child: AccessPageFrame(
                width: AccessPageWidth.content,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AccessSpacing.s48),
                    if (!_authenticated) _loginExperience(),
                    if (_authenticated) ...[
                      LayoutBuilder(
                        builder: (context, constraints) => _intro(
                          compact:
                              constraints.maxWidth <
                                  AccessLayout.mobileBreakpoint ||
                              AccessLayout.largeText(context),
                        ),
                      ),
                      const SizedBox(height: AccessSpacing.s32),
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
                        spacing: AccessSpacing.s20,
                        runSpacing: AccessSpacing.s8,
                        children: [
                          LocalText(
                            _data?['user']?['name'] as String? ?? 'Angemeldet',
                            style: const TextStyle(
                              fontSize: AccessTypography.captionSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _busy ? null : () => _run(_refresh),
                            icon: const AccessIcon(
                              Icons.refresh,
                              size: AccessLayout.smallIconSize,
                            ),
                            label: const LocalText('Aktualisieren'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AccessSpacing.s16),
                      if (_data != null)
                        if (widget.authOnly ||
                            _data!['user']?['email_verified'] == true)
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
                    const SizedBox(height: AccessSpacing.s16),
                    const Divider(color: Color(0xFFC7C0BB), height: 1),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: AccessSpacing.s24,
                      ),
                      child: LocalText(
                        'Alle Konten, Veranstalter und Orte sind erfunden. Änderungen werden im lokalen Prototyp gespeichert.',
                        style: _caption,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

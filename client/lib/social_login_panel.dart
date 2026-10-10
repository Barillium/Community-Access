import 'product_scope.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'design_system.dart';

import 'access_api.dart';
import 'app_language.dart';
import 'better_auth_api.dart';
import 'social_browser.dart'
    if (dart.library.js_interop) 'social_browser_web.dart';

String? socialResult(Uri uri) => uri.fragment == 'social=success'
    ? 'success'
    : uri.fragment == 'social=error'
    ? 'error'
    : null;

class SocialLoginPanel extends StatefulWidget {
  final SocialAuthApi api;
  final bool link;
  final bool disabled;
  final bool Function(Uri)? navigate;
  const SocialLoginPanel({
    super.key,
    required this.api,
    this.link = false,
    this.disabled = false,
    this.navigate,
  });

  @override
  State<SocialLoginPanel> createState() => _SocialLoginPanelState();
}

class _SocialLoginPanelState extends State<SocialLoginPanel> {
  List<String> _providers = [];
  bool _busy = false;
  String? _error;
  int _revision = 0;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    if (ProductScope.extended) _load();
  }

  @override
  void didUpdateWidget(SocialLoginPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api || oldWidget.link != widget.link) {
      _revision++;
      _providers = [];
      _busy = _loading = false;
      _error = null;
      if (ProductScope.extended) _load();
    }
  }

  @override
  void dispose() {
    _revision++;
    super.dispose();
  }

  Future<void> _load() async {
    // Web OAuth exchanges a browser cookie. Do not advertise it on native clients
    // until a separately verified PKCE/session handoff exists. Email login works.
    if (!kIsWeb && widget.api is BetterAuthAccessApi) return;
    if (_loading || _busy) return;
    final current = ++_revision;
    final api = widget.api;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final providers = await api.socialProviders();
      if (mounted && current == _revision) {
        setState(() => _providers = providers);
      }
    } catch (_) {
      if (mounted && current == _revision) {
        setState(
          () => _error = 'Weitere Anmeldemethoden konnten nicht geladen werden. Die Anmeldung mit E-Mail und Passwort bleibt verfügbar.',
        );
      }
    } finally {
      if (mounted && current == _revision) setState(() => _loading = false);
    }
  }

  Future<void> _start(String provider) async {
    if (_busy || _loading || widget.disabled) return;
    final current = _revision;
    final api = widget.api;
    final link = widget.link;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = await api.startSocial(provider, link: link);
      if (!mounted || current != _revision) return;
      if (!(widget.navigate ?? navigateToSocial)(url)) {
        throw const ApiFailure(
          'Diese Anmeldung ist derzeit im Browser verfügbar.',
        );
      }
    } catch (error) {
      if (mounted && current == _revision) {
        setState(
          () => _error = error is ApiFailure
              ? error.message
              : 'Die Anmeldung konnte nicht gestartet werden.',
        );
      }
    } finally {
      if (mounted && current == _revision) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ProductScope.extended) return const SizedBox.shrink();
    if (_providers.isEmpty && _error == null && !_loading) {
      return const SizedBox.shrink();
    }
    const names = {
      'google': 'Google',
      'apple': 'Apple',
      'facebook': 'Facebook',
    };
    return Padding(
      padding: const EdgeInsets.only(top: AccessSpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading) const LinearProgressIndicator(),
          LocalText(
            widget.link
                ? 'Anmeldemethode verbinden'
                : 'Oder mit einem anderen Konto anmelden',
          ),
          if (widget.link)
            const Padding(
              padding: EdgeInsets.only(top: AccessSpacing.s8),
              child: LocalText(
                'Bestätige zuerst deine E-Mail und melde dich unmittelbar vor dem Verbinden erneut an.',
              ),
            ),
          const SizedBox(height: AccessSpacing.s12),
          for (final id in _providers)
            Padding(
              padding: const EdgeInsets.only(bottom: AccessSpacing.s12),
              child: OutlinedButton(
                onPressed: _busy || _loading || widget.disabled
                    ? null
                    : () => _start(id),
                child: LocalText(
                  widget.link
                      ? '${names[id]} verbinden'
                      : 'Mit ${names[id]} anmelden',
                ),
              ),
            ),
          if (_error != null)
            Semantics(liveRegion: true, child: LocalText(_error!)),
          if (_error != null && _providers.isEmpty && !_loading)
            TextButton(
              onPressed: widget.disabled ? null : _load,
              child: const LocalText('Erneut versuchen'),
            ),
        ],
      ),
    );
  }
}

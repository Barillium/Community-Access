import 'product_scope.dart';
import 'app_language.dart';

import 'package:flutter/material.dart';

import 'design_system.dart';

import 'access_api.dart';
import 'directory_api.dart';
import 'directory_pages.dart';
import 'program_views.dart';

class BookmarkButton extends StatefulWidget {
  final DirectoryApi api;
  final String kind, id;
  final int? interestCount;
  final bool signedIn, compact;
  final Future<void> Function()? openAccount;
  const BookmarkButton({
    super.key,
    required this.api,
    required this.kind,
    required this.id,
    this.interestCount,
    this.signedIn = true,
    this.compact = false,
    this.openAccount,
  });
  @override
  State<BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<BookmarkButton> {
  bool _saved = false, _busy = true;
  String? _notice;
  int? _count;
  int _revision = 0;
  bool _needsLogin = false;
  bool _needsRefresh = false;
  @override
  void initState() {
    super.initState();
    _count = widget.interestCount;
    if (ProductScope.extended && widget.signedIn) {
      _load();
    } else {
      _busy = false;
    }
  }

  @override
  void didUpdateWidget(BookmarkButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interestCount != widget.interestCount) {
      _count = widget.interestCount;
    }
    if (oldWidget.signedIn != widget.signedIn ||
        oldWidget.api != widget.api ||
        oldWidget.kind != widget.kind ||
        oldWidget.id != widget.id) {
      _revision++;
      _needsLogin = false;
      _needsRefresh = false;
      _count = widget.interestCount;
      _saved = false;
      _notice = null;
      _busy = widget.signedIn;
      if (ProductScope.extended && widget.signedIn) _load();
    }
  }

  @override
  void dispose() {
    _revision++;
    super.dispose();
  }

  Future<void> _load() async {
    final revision = ++_revision;
    final kind = widget.kind, id = widget.id;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final data = await widget.api.directory('bookmarks');
      if (mounted && revision == _revision) {
        setState(() {
          _needsRefresh = false;
          _saved =
              (data[{
                            'profile': 'profiles',
                            'series': 'series',
                            'event': 'events',
                          }[kind]]
                          as List? ??
                      [])
                  .any((e) => e['id'] == id);
        });
      }
    } catch (e) {
      if (mounted && revision == _revision) {
        setState(() {
          _needsRefresh = true;
          _notice = e is ApiFailure
              ? e.message
              : 'Merkliste konnte nicht geladen werden.';
          if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
            _saved = false;
            _needsLogin = e.unauthenticated;
          }
        });
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _busy = false);
    }
  }

  Future<void> _toggle() async {
    if (_busy || !widget.signedIn || _needsLogin || _needsRefresh) return;
    final revision = ++_revision;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final result = await widget.api.directory(
        'bookmark',
        body: {'kind': widget.kind, 'id': widget.id, 'saved': !_saved},
      );
      if (mounted && revision == _revision) {
        setState(() {
          _saved = result['saved'] == true;
          _count = result['interest_count'] as int?;
        });
      }
    } catch (e) {
      if (mounted && revision == _revision) {
        setState(() {
          _needsRefresh = true;
          _notice = e is ApiFailure
              ? e.message
              : 'Merken konnte nicht gespeichert werden.';
          if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
            _saved = false;
            _needsLogin = e.unauthenticated;
          }
        });
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _busy = false);
    }
  }

  Widget _action(String label, VoidCallback? onPressed, IconData icon) =>
      AccessAction(
        onPressed: onPressed,
        iconOnly: widget.compact,
        tooltip: widget.compact ? label : null,
        prefix: widget.compact ? null : AccessIcon(icon),
        child: widget.compact
            ? Semantics(
                label: label,
                child: ExcludeSemantics(child: AccessIcon(icon)),
              )
            : LocalText(label),
      );

  @override
  Widget build(BuildContext context) => !ProductScope.extended
      ? const SizedBox.shrink()
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InterestCount(count: _count),
            if (_count != null) ...[
              const SizedBox(height: AccessSpacing.s8),
              const LocalText(
                'Merken zählt als öffentliches Interesse. Namen bleiben verborgen.',
              ),
              const SizedBox(height: AccessSpacing.s12),
            ],
            if (widget.signedIn && !_needsLogin && _needsRefresh)
              _action('Aktualisieren', _busy ? null : _load, Icons.refresh),
            if (widget.signedIn && !_needsLogin && !_needsRefresh)
              _action(
                _saved
                    ? 'Aus Merkliste entfernen'
                    : widget.kind == 'profile'
                    ? 'Veranstalter merken'
                    : widget.kind == 'series'
                    ? 'Reihe merken'
                    : 'Event merken',
                _busy ? null : _toggle,
                _saved ? Icons.bookmark : Icons.bookmark_border,
              ),
            if ((!widget.signedIn || _needsLogin) && widget.openAccount != null)
              _action(
                'Anmelden und merken',
                widget.openAccount,
                Icons.bookmark_border,
              ),
            if (_notice != null) LocalText(_notice!),
          ],
        );
}

class InterestCount extends StatelessWidget {
  final int? count;
  const InterestCount({super.key, this.count});
  @override
  Widget build(BuildContext context) => !ProductScope.extended || count == null
      ? const SizedBox.shrink()
      : Semantics(
          liveRegion: true,
          child: Text(
            localText(
              context,
              count == 1
                  ? '1 Person interessiert'
                  : '$count Personen interessiert',
              count == 1 ? '1 person interested' : '$count people interested',
            ),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        );
}

class BookmarksPage extends StatefulWidget {
  final DirectoryApi api;
  final Future<void> Function()? openAccount;
  const BookmarksPage({super.key, required this.api, this.openAccount});
  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  Map<String, dynamic>? _data;
  String? _notice;
  bool _busy = false;
  bool _needsLogin = false;
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _revision++;
    super.dispose();
  }

  Future<void> _openAccount() async {
    await widget.openAccount!();
    if (mounted) await _load();
  }

  Future<void> _load() async {
    final revision = ++_revision;
    setState(() {
      _busy = true;
      _data = null;
      _notice = null;
      _needsLogin = false;
    });
    try {
      final data = await widget.api.directory('bookmarks');
      if (mounted && revision == _revision) setState(() => _data = data);
    } catch (e) {
      if (mounted && revision == _revision) {
        setState(() {
          _notice = e is ApiFailure
              ? e.message
              : 'Merkliste konnte nicht geladen werden.';
          _needsLogin = e is ApiFailure && e.unauthenticated;
        });
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _busy = false);
    }
  }

  Future<void> _open(String kind, String id) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => kind == 'profile'
            ? OrganizerDetailPage(
                api: widget.api,
                id: id,
                openAccount: widget.openAccount == null ? null : _openAccount,
              )
            : ProgramDetailPage(
                api: widget.api,
                kind: kind == 'event' ? 'events' : 'series',
                id: id,
                openAccount: widget.openAccount == null ? null : _openAccount,
              ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _remove(String kind, String id) async {
    if (_busy) return;
    final revision = ++_revision;
    setState(() => _busy = true);
    try {
      await widget.api.directory(
        'bookmark',
        body: {'kind': kind, 'id': id, 'saved': false},
      );
      if (mounted && revision == _revision) await _load();
    } catch (e) {
      if (mounted && revision == _revision) {
        setState(() {
          _busy = false;
          if (e is ApiFailure && (e.unauthenticated || e.accessDenied)) {
            _data = null;
          }
          _needsLogin = e is ApiFailure && e.unauthenticated;
          _notice = e is ApiFailure ? e.message : 'Entfernen fehlgeschlagen.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: accessAppBar(context, 'Meine Merkliste'),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        title: 'Meine Merkliste',
        width: AccessPageWidth.content,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LocalText(
              'Merken bestätigt keine Mitgliedschaft oder Teilnahme. Deine Auswahl ist nur für dich sichtbar; bei öffentlichen Inhalten wird die Gesamtzahl als Interesse angezeigt. Namen bleiben verborgen.',
            ),
            const SizedBox(height: AccessSpacing.s24),
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_notice != null) directoryNotice(_notice!),
            if (_needsLogin && widget.openAccount != null)
              TextButton(
                onPressed: _busy ? null : _openAccount,
                child: const LocalText('Erneut anmelden'),
              ),
            if (_data != null) ...[
              if ((_data!['profiles'] as List? ?? []).isEmpty &&
                  (_data!['series'] as List? ?? []).isEmpty &&
                  (_data!['events'] as List? ?? []).isEmpty)
                const LocalText(
                  'Noch keine verfügbaren Einträge in deiner Merkliste.',
                ),
              for (final group in {
                'profiles': 'profile',
                'series': 'series',
                'events': 'event',
              }.entries)
                for (final entry in _data![group.key] as List? ?? [])
                  Padding(
                    padding: const EdgeInsets.only(bottom: AccessSpacing.s24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          entry['title'] as String,
                          style: const TextStyle(
                            fontSize: AccessTypography.cardTitleSize,
                          ),
                        ),
                        Wrap(
                          spacing: AccessSpacing.s12,
                          runSpacing: AccessSpacing.s8,
                          children: [
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _open(
                                      group.value,
                                      entry['id'] as String,
                                    ),
                              child: const LocalText('Ansehen'),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _remove(
                                      group.value,
                                      entry['id'] as String,
                                    ),
                              child: const LocalText('Entfernen'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
            ],
            OutlinedButton(
              onPressed: _busy ? null : _load,
              child: const LocalText('Aktualisieren'),
            ),
          ],
        ),
      ),
    ),
  );
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../haptics.dart';
import '../theme.dart';
import '../tokens.dart';
import 'basics.dart';
import 'marks.dart';

/// Ab 600 dp Breite (Tablet, Faltgerät, Querformat) bleibt der Inhalt eine Spalte
/// von höchstens 720 dp in der Mitte. Android 16 ignoriert dort die Hochformat-Sperre,
/// darum muss jede Seite in jeder Breite funktionieren.
class CaPageWidth extends StatelessWidget {
  const CaPageWidth({super.key, required this.child});
  static const double max = 720;
  final Widget child;

  @override
  // Material statt ColoredBox, damit Listenzeilen ihren gedrückten Zustand zeigen.
  Widget build(BuildContext context) => Material(
        color: CaColors.of(context).surfacePage,
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: max), child: child),
        ),
      );
}

/// iOS-Verhalten? Gilt auch für macOS. Richtet sich nach Theme.platform, damit
/// Vorschau und Tests jede Plattform zeigen können.
bool caIsCupertino(BuildContext context) {
  final p = Theme.of(context).platform;
  return p == TargetPlatform.iOS || p == TargetPlatform.macOS;
}

/// Seite mit großem Titel, der beim Scrollen in die Leiste wandert.
/// iOS: eingeklappt mittig, Aktualisieren durch Ziehen mit nativem Kreisel.
/// Android: eingeklappt links (Material „Large top app bar“), Aktualisieren mit Kreis.
/// Ohne [title] steht das Logo in einer festen Leiste (Startseite „Programm“).
class CaLargeTitlePage extends StatelessWidget {
  const CaLargeTitlePage({
    super.key,
    this.title,
    required this.slivers,
    this.actions = const [],
    this.header,
    this.onRefresh,
  });

  final String? title;
  final List<Widget> slivers;
  final List<Widget> actions;

  /// Bleibt unter dem Titel stehen, z. B. [CaSegments] oder [CaSearchField].
  final Widget? header;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final ios = caIsCupertino(context);
    final theme = Theme.of(context);
    final c = CaColors.of(context);
    Widget scroll = CustomScrollView(
      physics: ios
          ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
          : const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (title == null)
          SliverAppBar(
            pinned: true,
            title: const CaLogo(),
            centerTitle: false,
            actions: actions,
            shape: const Border(),
          )
        else
          // Großer Titel in Plakatschrift; eingeklappt die normale Leistenschrift.
          Theme(
            // appBarTheme.titleTextStyle würde sonst auch den großen Titel setzen.
            data: theme.copyWith(
                appBarTheme: AppBarTheme(
                  backgroundColor: theme.appBarTheme.backgroundColor,
                  foregroundColor: theme.appBarTheme.foregroundColor,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  systemOverlayStyle: theme.appBarTheme.systemOverlayStyle,
                ),
                textTheme: theme.textTheme.copyWith(
                    titleLarge: theme.appBarTheme.titleTextStyle,
                    headlineMedium:
                        CaType.section.copyWith(color: c.textPrimary))),
            child: SliverAppBar.large(
              title: Text(title!.toUpperCase()),
              centerTitle: ios,
              actions: actions,
              shape: const Border(),
            ),
          ),
        if (ios && onRefresh != null)
          CupertinoSliverRefreshControl(onRefresh: onRefresh),
        if (header != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: CaSpace.s2),
              child: header,
            ),
          ),
        ...slivers,
      ],
    );
    if (!ios && onRefresh != null) {
      scroll = RefreshIndicator(onRefresh: onRefresh!, child: scroll);
    }
    return CaPageWidth(child: scroll);
  }
}

/// Umschalter zwischen gleichrangigen Ansichten einer Seite, z. B. Events, Orte, Veranstalter.
/// iOS: Segmented Control. Android: Reiter über volle Breite, aktueller mit Klebestreifen.
class CaSegments<T extends Object> extends StatelessWidget {
  const CaSegments({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final Map<T, String> segments;
  final T value;
  final ValueChanged<T> onChanged;

  void _pick(T v) {
    if (v == value) return;
    CaHaptics.select();
    onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = CaColors.of(context);
    if (caIsCupertino(context)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: CaSpace.gutter),
        child: SizedBox(
          width: double.infinity,
          child: CupertinoSlidingSegmentedControl<T>(
            groupValue: value,
            thumbColor: c.surfacePage,
            backgroundColor: c.surfacePressed,
            onValueChanged: (v) => v == null ? null : _pick(v),
            children: {
              for (final e in segments.entries)
                // 48 hoch statt der iOS-üblichen 32: Tippflächen-Regel des Systems.
                e.key: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(e.value,
                      style: CaType.meta.copyWith(
                          color: c.textPrimary,
                          fontWeight: e.key == value
                              ? FontWeight.w600
                              : FontWeight.w500)),
                ),
            },
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.borderHair))),
      child: Row(children: [
        for (final e in segments.entries)
          Expanded(
            child: Semantics(
              selected: e.key == value,
              button: true,
              child: InkWell(
                onTap: () => _pick(e.key),
                child: SizedBox(
                  height: CaSpace.target,
                  child: Center(
                    child: CaTape(
                      key: ValueKey(e.key == value),
                      active: e.key == value,
                      child: Text(e.value,
                          style: CaType.meta.copyWith(
                              color: e.key == value
                                  ? c.textPrimary
                                  : c.textSecondary,
                              fontWeight: e.key == value
                                  ? FontWeight.w600
                                  : FontWeight.w500)),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Suchfeld. iOS: natives Suchfeld mit „Abbrechen“-Verhalten des Systems.
/// Android: Textfeld im Aushang-Stil mit Lupe.
class CaSearchField extends StatelessWidget {
  const CaSearchField({
    super.key,
    this.hint = 'Events, Orte, Veranstalter',
    this.onChanged,
    this.onSubmitted,
    this.controller,
  });

  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final c = CaColors.of(context);
    final field = caIsCupertino(context)
        ? CupertinoSearchTextField(
            controller: controller,
            placeholder: hint,
            style: CaType.body.copyWith(color: c.textPrimary),
            onChanged: onChanged,
            onSubmitted: onSubmitted,
          )
        : TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search),
              floatingLabelBehavior: FloatingLabelBehavior.never,
            ),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CaSpace.gutter),
      child: field,
    );
  }
}

class CaSettingsItem {
  const CaSettingsItem(this.label, {this.value, this.icon, this.onTap});
  final String label;

  /// Aktueller Wert rechts, z. B. „Deutsch“ oder „System“.
  final String? value;
  final IconData? icon;
  final VoidCallback? onTap;
}

/// Einstellungsliste im Konto. iOS: gruppierte Liste wie in den Einstellungen.
/// Android: Abschnittstitel mit Listeneinträgen.
class CaSettingsSection extends StatelessWidget {
  const CaSettingsSection({super.key, this.header, required this.items});
  final String? header;
  final List<CaSettingsItem> items;

  @override
  Widget build(BuildContext context) {
    final c = CaColors.of(context);
    if (caIsCupertino(context)) {
      return CupertinoListSection.insetGrouped(
        header: header == null
            ? null
            : Text(header!.toUpperCase(),
                style: CaType.fine.copyWith(color: c.textSecondary)),
        backgroundColor: Colors.transparent,
        decoration: BoxDecoration(
            color: c.surfaceSunken,
            borderRadius: const BorderRadius.all(Radius.circular(10))),
        separatorColor: c.borderHair,
        children: [
          for (final i in items)
            CupertinoListTile(
              title: Text(i.label,
                  style: CaType.body.copyWith(color: c.textPrimary)),
              leading: i.icon == null
                  ? null
                  : Icon(i.icon, size: 22, color: c.textPrimary),
              additionalInfo: i.value == null
                  ? null
                  : Text(i.value!,
                      style: CaType.body.copyWith(color: c.textSecondary)),
              trailing: i.onTap == null
                  ? null
                  : Icon(Icons.chevron_right, size: 24, color: c.textSecondary),
              onTap: i.onTap,
            ),
        ],
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (header != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(
              CaSpace.gutter, CaSpace.s5, CaSpace.gutter, CaSpace.s1),
          child: Text(header!,
              style: CaType.meta.copyWith(
                  color: c.textDecision, fontWeight: FontWeight.w600)),
        ),
      for (final i in items)
        ListTile(
          leading: i.icon == null ? null : Icon(i.icon, color: c.textPrimary),
          title: Text(i.label, style: CaType.body),
          subtitle: i.value == null
              ? null
              : Text(i.value!,
                  style: CaType.meta.copyWith(color: c.textSecondary)),
          onTap: i.onTap,
          minTileHeight: 56,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: CaSpace.gutter),
        ),
    ]);
  }
}

class CaAction {
  const CaAction(this.label, {required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// Weitere Aktionen zu einem Event (Teilen, In den Kalender, Melden).
/// iOS: Aktionsblatt von unten mit „Abbrechen“. Android: Blatt mit Liste.
Future<void> showCaActions(BuildContext context,
    {String? title, required List<CaAction> actions}) {
  final c = CaColors.of(context);
  if (caIsCupertino(context)) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: title == null
            ? null
            : Text(title, style: CaType.meta.copyWith(color: c.textSecondary)),
        actions: [
          for (final a in actions)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                a.onTap();
              },
              child: Text(a.label,
                  style: caFont(size: 20, height: 1.2)
                      .copyWith(color: c.textPrimary)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: Text('Abbrechen',
              style: caFont(size: 20, height: 1.2, weight: 600)
                  .copyWith(color: c.textPrimary)),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (context) => Column(mainAxisSize: MainAxisSize.min, children: [
      if (title != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(
              CaSpace.gutter, 0, CaSpace.gutter, CaSpace.s3),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title,
                  style: CaType.meta.copyWith(color: c.textSecondary))),
        ),
      for (final a in actions)
        ListTile(
          leading: Icon(a.icon, color: c.textPrimary),
          title: Text(a.label, style: CaType.body),
          minTileHeight: 56,
          onTap: () {
            Navigator.pop(context);
            a.onTap();
          },
        ),
      const SizedBox(height: CaSpace.s3),
    ]),
  );
}

/// Zum Entfernen nach links wischen, z. B. in der Merkliste. Auf beiden Plattformen
/// üblich; Android zeigt danach „Rückgängig“ (siehe [showCaToast]).
class CaSwipeToRemove extends StatelessWidget {
  const CaSwipeToRemove({
    super.key,
    required this.id,
    required this.onRemove,
    required this.child,
    this.label = 'Entfernen',
    this.icon = Icons.bookmark_remove_outlined,
  });

  final Object id;
  final VoidCallback onRemove;
  final Widget child;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = CaColors.of(context);
    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        CaHaptics.save();
        onRemove();
      },
      background: Container(
        color: c.surfaceInverse,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: CaSpace.s5),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: c.textInverse),
          const SizedBox(width: CaSpace.s2),
          Text(label,
              style: CaType.meta
                  .copyWith(color: c.textInverse, fontWeight: FontWeight.w600)),
        ]),
      ),
      child: child,
    );
  }
}

/// Feste Leiste unten für die Hauptaktion einer Detailseite, über dem Home-Balken.
class CaBottomAction extends StatelessWidget {
  const CaBottomAction({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = CaColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
          color: c.surfacePage,
          border: Border(top: BorderSide(color: c.borderHair))),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: CaSpace.s3),
        child: CaPageWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                CaSpace.gutter, CaSpace.s3, CaSpace.gutter, 0),
            child: child,
          ),
        ),
      ),
    );
  }
}

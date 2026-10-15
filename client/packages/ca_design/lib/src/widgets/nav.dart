import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../haptics.dart';
import '../theme.dart';
import '../tokens.dart';
import 'marks.dart';
import 'basics.dart';
import 'platform.dart';

class CaNavItem {
  const CaNavItem(this.label, this.icon, this.selectedIcon, {this.badge});
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Orange Zahl, nur bei einer neuen Entscheidung (an „Mein Zugang“).
  final int? badge;
}

/// Navigation unten: Programm, Merkliste, Mein Zugang, Konto. Kein Menü daneben.
/// Maße wie auf der Plattform üblich: iOS-Tab-Leiste 50 hoch mit 10er-Beschriftung,
/// Android-Navigationsleiste 80 hoch mit 12er-Beschriftung.
/// Aktuell: Klebestreifen unter dem Wort, Symbol in kräftiger Form.
class CaNavBar extends StatelessWidget {
  const CaNavBar(
      {super.key,
      required this.items,
      required this.currentIndex,
      required this.onSelect});
  final List<CaNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = CaColors.of(context);
    final ios = caIsCupertino(context);
    final width = math.min(MediaQuery.sizeOf(context).width, CaPageWidth.max);
    var height = ios ? 50.0 : 80.0;
    for (final item in items) {
      final painter = TextPainter(
        text: TextSpan(
            text: item.label,
            style: CaType.fine.copyWith(
                fontSize: ios ? 10 : 12, fontWeight: FontWeight.w600)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: math.max(1, width / items.length - 16));
      height =
          math.max(height, 24 + (ios ? 2 : CaSpace.s1) + painter.height + 8);
      painter.dispose();
    }
    return DecoratedBox(
      decoration: BoxDecoration(
          color: c.surfacePage,
          border: Border(top: BorderSide(color: c.borderRule))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: CaPageWidth(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                for (final (i, item) in items.indexed)
                  Expanded(
                    child: Semantics(
                      selected: i == currentIndex,
                      button: true,
                      label: item.badge == null
                          ? item.label
                          : '${item.label}, ${item.badge} neue Entscheidung',
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: () {
                          if (i == currentIndex) return;
                          CaHaptics.select();
                          onSelect(i);
                        },
                        child: _Item(
                            item: item,
                            current: i == currentIndex,
                            colors: c,
                            ios: ios),
                      ),
                    ),
                  ),
              ])),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(
      {required this.item,
      required this.current,
      required this.colors,
      required this.ios});
  final CaNavItem item;
  final bool current;
  final CaColors colors;
  final bool ios;

  @override
  Widget build(BuildContext context) {
    final ink = current ? colors.textPrimary : colors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Badge(
          isLabelVisible: item.badge != null,
          label: Text('${item.badge ?? ''}'),
          backgroundColor: colors.surfaceAccent,
          textColor: colors.textOnAccent,
          child: CaIcon(current ? item.selectedIcon : item.icon,
              size: 24, color: ink, plain: !current),
        ),
        SizedBox(height: ios ? 2 : CaSpace.s1),
        CaTape(
          key: ValueKey(current),
          active: current,
          child: Text(item.label,
              textAlign: TextAlign.center,
              style: CaType.fine.copyWith(
                  fontSize: ios ? 10 : 12,
                  color: ink,
                  fontWeight: current ? FontWeight.w600 : FontWeight.w500)),
        ),
      ]),
    );
  }
}

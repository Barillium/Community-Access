import 'package:flutter/services.dart';

/// Spürbare Rückmeldung, gleich auf iOS und Android. Sparsam: nie bei jedem Tippen.
abstract final class CaHaptics {
  /// Reiter wechseln, Filter wählen.
  static Future<void> select() => HapticFeedback.selectionClick();

  /// Ein Event merken oder nicht mehr merken.
  static Future<void> save() => HapticFeedback.lightImpact();

  /// Ein Mensch hat entschieden: Zusage kommt an oder Veranstalter entscheidet.
  static Future<void> decision() => HapticFeedback.mediumImpact();
}

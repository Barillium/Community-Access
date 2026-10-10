import 'package:flutter/material.dart';

/// Presentation preference stays in memory; it never changes account access.
class AppearanceScope extends InheritedNotifier<ValueNotifier<ThemeMode>> {
  const AppearanceScope({
    super.key,
    required ValueNotifier<ThemeMode> mode,
    required super.child,
  }) : super(notifier: mode);

  static ValueNotifier<ThemeMode>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>()?.notifier;
}

import 'package:flutter/material.dart';

import 'app_language.dart';
import 'appearance_scope.dart';
import 'design_system.dart';

/// Presentation settings never change the account session or catalog access.
Future<bool> showAccessAccountMenu(
  BuildContext context, {
  required bool signedIn,
}) async {
  final open = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(),
    barrierLabel: localText(
      context,
      'Konto-Menü schließen',
      'Close account menu',
    ),
    sheetAnimationStyle: AnimationStyle(
      duration:
          MediaQuery.disableAnimationsOf(context) ||
              FocusManager.instance.highlightMode ==
                  FocusHighlightMode.traditional
          ? Duration.zero
          : const Duration(milliseconds: 200),
      reverseDuration:
          MediaQuery.disableAnimationsOf(context) ||
              FocusManager.instance.highlightMode ==
                  FocusHighlightMode.traditional
          ? Duration.zero
          : const Duration(milliseconds: 120),
    ),
    builder: (_) => _AccountMenu(signedIn: signedIn),
  );
  return open == true;
}

class _AccountMenu extends StatelessWidget {
  final bool signedIn;
  const _AccountMenu({required this.signedIn});

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.of(context);
    final appearance = AppearanceScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget choice(String label, bool selected, VoidCallback? onPressed) =>
        Semantics(
          selected: selected,
          child: AccessAction(
            kind: selected
                ? AccessActionKind.neutral
                : AccessActionKind.outline,
            onPressed: onPressed,
            child: Text(label),
          ),
        );
    return ColoredBox(
      color: AushangPalette.of(context).page,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const AccessIcon(
                      Icons.account_circle_outlined,
                      size: 24,
                      active: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AccessHeading(
                        localText(context, 'Konto', 'Account'),
                        role: AccessHeadingRole.section,
                        level: 2,
                      ),
                    ),
                    IconButton(
                      tooltip: localText(
                        context,
                        'Konto-Menü schließen',
                        'Close account menu',
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      icon: const AccessIcon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                AccessAction(
                  kind: AccessActionKind.neutral,
                  fullWidth: true,
                  onPressed: () => Navigator.pop(context, true),
                  child: LocalText(signedIn ? 'Dein Konto' : 'Anmelden'),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const AccessIcon(Icons.language, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AccessHeading(
                        localText(context, 'Sprache', 'Language'),
                        role: AccessHeadingRole.card,
                        level: 3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    choice(
                      'Deutsch',
                      language?.value == false,
                      language == null ? null : () => language.value = false,
                    ),
                    choice(
                      'English',
                      language?.value == true,
                      language == null ? null : () => language.value = true,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    const AccessIcon(Icons.contrast, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AccessHeading(
                        localText(context, 'Darstellung', 'Appearance'),
                        role: AccessHeadingRole.card,
                        level: 3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    choice(
                      localText(context, 'Helle Darstellung'),
                      !dark,
                      appearance == null
                          ? null
                          : () => appearance.value = ThemeMode.light,
                    ),
                    choice(
                      localText(context, 'Dunkle Darstellung'),
                      dark,
                      appearance == null
                          ? null
                          : () => appearance.value = ThemeMode.dark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

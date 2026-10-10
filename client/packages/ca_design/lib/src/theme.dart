import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Archivo als variable Schrift: Breite (wdth) und Gewicht (wght) als Achsen.
/// Schmal 68 % für Namen, Daten und Überschriften, normal 100 % für Lesetext.
TextStyle caFont({
  required double size,
  double height = 1.45,
  int weight = 400,
  double width = 100,
  double letterSpacing = 0,
  List<FontFeature> features = const [],
}) {
  return TextStyle(
    fontFamily: 'Archivo',
    package: 'ca_design',
    fontSize: size,
    height: height,
    fontWeight: FontWeight.values[(weight ~/ 100).clamp(1, 9) - 1],
    fontVariations: [
      FontVariation('wght', weight.toDouble()),
      FontVariation('wdth', width)
    ],
    letterSpacing: letterSpacing,
    fontFeatures: features,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

const _tabular = [FontFeature.tabularFigures()];

/// Schriftstufen der App. Plakat, Anzeige, Abschnitt und Titel stehen in
/// Großbuchstaben: das macht der Text selbst (`.toUpperCase()`), nicht der Stil.
abstract final class CaType {
  static final poster =
      caFont(size: 84, height: .84, weight: 800, width: 68, letterSpacing: -.8);
  static final display = caFont(size: 56, height: .86, weight: 800, width: 68);
  static final section = caFont(size: 38, height: .92, weight: 800, width: 68);
  static final date =
      caFont(size: 38, height: 1, weight: 800, width: 68, features: _tabular);
  static final head =
      caFont(size: 24, height: 1.18, weight: 600, letterSpacing: -.48);
  static final title =
      caFont(size: 20, height: .98, weight: 800, width: 68, letterSpacing: .2);
  static final lead = caFont(size: 18, height: 1.45, letterSpacing: -.18);
  static final body = caFont(size: 16, height: 1.5);
  static final meta = caFont(size: 14, height: 1.45);
  static final fine = caFont(size: 13, height: 1.4);
  static final label =
      caFont(size: 13, height: 1.3, weight: 600, letterSpacing: .78);
  static final button = caFont(size: 16, height: 1.2, weight: 600);
}

/// Hell und dunkel. Dunkel folgt dem System, im Menü umschaltbar.
abstract final class CaTheme {
  static ThemeData light() => _build(Brightness.light, CaColors.light);
  static ThemeData dark() => _build(Brightness.dark, CaColors.dark);

  static ThemeData _build(Brightness b, CaColors c) {
    const square = RoundedRectangleBorder();
    final scheme = ColorScheme(
      brightness: b,
      primary: c.actionPrimary,
      onPrimary: c.actionOnPrimary,
      primaryContainer: c.surfaceDecision,
      onPrimaryContainer: c.textPrimary,
      secondary: c.actionNeutral,
      onSecondary: c.textInverse,
      tertiary: c.textDecision,
      onTertiary: c.textInverse,
      // Fehler stehen in Tinte mit Symbol und Text, nie in Rot.
      error: c.textPrimary,
      onError: c.textInverse,
      errorContainer: c.surfaceSunken,
      onErrorContainer: c.textPrimary,
      surface: c.surfacePage,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.surfacePage,
      surfaceContainerLow: c.surfaceSunken,
      surfaceContainer: c.surfaceSunken,
      surfaceContainerHigh: c.surfaceSunken,
      surfaceContainerHighest: c.surfacePressed,
      outline: c.borderControl,
      outlineVariant: c.borderHair,
      inverseSurface: c.surfaceInverse,
      onInverseSurface: c.textInverse,
      inversePrimary: c.actionPrimary,
      shadow: CaPrimitive.ink950,
      scrim: CaPrimitive.ink950,
      surfaceTint: Colors.transparent,
    );
    final text = TextTheme(
      displayLarge: CaType.poster,
      displayMedium: CaType.display,
      displaySmall: CaType.section,
      headlineLarge: CaType.date,
      headlineMedium: CaType.head,
      headlineSmall: CaType.title,
      titleLarge: CaType.title,
      titleMedium: caFont(size: 16, height: 1.3, weight: 600),
      titleSmall: caFont(size: 14, height: 1.3, weight: 600),
      bodyLarge: CaType.lead,
      bodyMedium: CaType.body,
      bodySmall: CaType.meta,
      labelLarge: CaType.button,
      labelMedium: caFont(size: 14, height: 1.3, weight: 500),
      labelSmall: CaType.fine,
    ).apply(bodyColor: c.textPrimary, displayColor: c.textPrimary);

    // Gedrückt: Fläche dunkler und 1 px tiefer (siehe CaButton). Keine Material-Welle.
    WidgetStateProperty<Color?> bg(
            Color normal, Color pressed, Color disabled) =>
        WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return disabled;
          if (s.contains(WidgetState.pressed)) return pressed;
          return normal;
        });
    final buttonBase = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
          Size(CaSpace.target, CaSize.buttonHeight)),
      padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: CaSpace.s5)),
      shape: const WidgetStatePropertyAll(square),
      textStyle: WidgetStatePropertyAll(CaType.button),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      animationDuration: CaDuration.quick,
      elevation: const WidgetStatePropertyAll(0),
    );
    final isDark = b == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      textTheme: text,
      fontFamily: 'packages/ca_design/Archivo',
      scaffoldBackgroundColor: c.surfacePage,
      canvasColor: c.surfacePage,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: c.surfaceHover,
      focusColor: c.surfacePressed,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.surfacePage,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: CaSize.headerHeightMobile,
        titleSpacing: CaSpace.gutter,
        titleTextStyle: caFont(size: 18, height: 1, weight: 800, width: 68)
            .copyWith(color: c.textPrimary),
        shape: Border(bottom: BorderSide(color: c.borderRule)),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: buttonBase.copyWith(
          backgroundColor:
              bg(c.actionPrimary, c.actionPrimaryPressed, c.actionDisabled),
          foregroundColor:
              bg(c.actionOnPrimary, c.actionOnPrimary, c.textDisabled),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: buttonBase.copyWith(
          backgroundColor:
              bg(c.actionNeutral, c.actionNeutralPressed, c.actionDisabled),
          foregroundColor: bg(c.textInverse, c.textInverse, c.textDisabled),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: buttonBase.copyWith(
          backgroundColor: bg(c.surfacePage, c.surfacePressed, c.surfacePage),
          foregroundColor: bg(c.textPrimary, c.textPrimary, c.textDisabled),
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(
                color: s.contains(WidgetState.disabled)
                    ? c.borderHair
                    : c.borderRule,
                width: CaSize.buttonOutline),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: buttonBase.copyWith(
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: CaSpace.s3)),
          foregroundColor: bg(c.textPrimary, c.textSecondary, c.textDisabled),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize:
              const WidgetStatePropertyAll(Size.square(CaSpace.target)),
          shape: const WidgetStatePropertyAll(square),
          iconSize: const WidgetStatePropertyAll(22),
          foregroundColor: bg(c.textPrimary, c.textPrimary, c.textDisabled),
          backgroundColor:
              bg(Colors.transparent, c.surfacePressed, Colors.transparent),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: CaSpace.s4, vertical: 15),
        labelStyle: CaType.meta.copyWith(color: c.textSecondary),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        helperStyle: CaType.fine.copyWith(color: c.textSecondary),
        errorStyle: CaType.fine
            .copyWith(color: c.textPrimary, fontWeight: FontWeight.w600),
        hintStyle: CaType.body.copyWith(color: c.textSecondary),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: c.borderControl)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: c.borderControl)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: c.borderRule, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: c.borderRule, width: 2)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: c.borderRule, width: 2)),
      ),
      dividerTheme:
          DividerThemeData(color: c.borderHair, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surfaceInverse,
        contentTextStyle: CaType.meta.copyWith(color: c.textInverse),
        actionTextColor: c.textInverse,
        shape: square,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(
            CaSpace.gutter, 0, CaSpace.gutter, CaSpace.s4),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfacePage,
        modalBackgroundColor: c.surfacePage,
        shape: Border(top: BorderSide(color: c.borderRule)),
        showDragHandle: true,
        dragHandleColor: c.borderControl,
        dragHandleSize: const Size(32, 4),
        elevation: 0,
        modalElevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfacePage,
        shape: Border.all(color: c.borderRule),
        elevation: 0,
        titleTextStyle: CaType.head.copyWith(color: c.textPrimary),
        contentTextStyle: CaType.body.copyWith(color: c.textPrimary),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: square,
        side: BorderSide(color: c.borderControl, width: CaLine.firm),
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? c.actionNeutral
                : Colors.transparent),
        checkColor: WidgetStatePropertyAll(c.textInverse),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? c.actionNeutral
                : c.surfacePressed),
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? c.textInverse : c.borderControl),
        trackOutlineColor: WidgetStatePropertyAll(c.borderControl),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
          color: c.textPrimary, linearTrackColor: c.surfacePressed),
      textSelectionTheme: TextSelectionThemeData(
          cursorColor: c.textPrimary,
          selectionColor: c.surfaceHighlight,
          selectionHandleColor: c.textPrimary),
      cupertinoOverrideTheme: CupertinoThemeData(
          primaryColor: c.textPrimary,
          scaffoldBackgroundColor: c.surfacePage,
          brightness: b),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        // iOS: native Schiebebewegung mit Wischen zurück vom Rand, auch bei reduzierter Bewegung.
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        // Android: vorausschauende Zurück-Geste; bei „Animationen entfernen“ nur Überblenden.
        TargetPlatform.android:
            _ReducedMotionFade(PredictiveBackPageTransitionsBuilder()),
      }),
    );
  }
}

class _ReducedMotionFade extends PageTransitionsBuilder {
  const _ReducedMotionFade(this.platform);
  final PageTransitionsBuilder platform;

  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    return platform.buildTransitions(
        route, context, animation, secondaryAnimation, child);
  }
}

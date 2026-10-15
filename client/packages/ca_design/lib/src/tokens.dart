// Erzeugt von tool/gen_tokens.py aus aushang3.tokens.json. Nicht von Hand ändern.
import 'package:flutter/material.dart';

/// Grundwerte. In Widgets nur über [CaColors] oder Theme verwenden.
abstract final class CaPrimitive {
  static const ink950 = Color(0xFF0D0E13);
  static const ink700 = Color(0xFF3A3C46);
  static const ink600 = Color(0xFF5E606B);
  static const ink500 = Color(0xFF6A6C77);
  static const ink400 = Color(0xFF8B8D98);
  static const ink200 = Color(0xFFE2E3E8);
  static const ink100 = Color(0xFFECEDF1);
  static const ink50 = Color(0xFFF4F4F6);
  static const ink300 = Color(0xFFC9CAD1);
  static const ink900 = Color(0xFF16171D);
  static const ink850 = Color(0xFF1A1B22);
  static const ink800 = Color(0xFF2A2B33);
  static const white = Color(0xFFFFFFFF);
  static const orange700 = Color(0xFFB83A0E);
  static const orange500 = Color(0xFFFF5A1F);
  static const orange600 = Color(0xFFF04A10);
  static const orange100 = Color(0xFFFFD9C9);
  static const orange50 = Color(0xFFFFF0E8);
  static const orange400 = Color(0xFFFF7A45);
  static const orange900 = Color(0xFF2A1810);
}

abstract final class CaSpace {
  static const double s1 = 4.0;
  static const double s2 = 8.0;
  static const double s3 = 12.0;
  static const double s4 = 16.0;
  static const double s5 = 24.0;
  static const double s6 = 32.0;
  static const double s7 = 48.0;
  static const double s8 = 64.0;
  static const double s9 = 96.0;
  static const double s10 = 144.0;
  static const double gutter = 16.0;
  static const double section = 96.0;
  static const double target = 48.0;
}

abstract final class CaLine {
  static const double hair = 1.0;
  static const double firm = 1.5;
  static const double mark = 3.0;
}

abstract final class CaDuration {
  static const quick = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 280);
  static const draw = Duration(milliseconds: 600);
  static const ambient = Duration(milliseconds: 2400);
}

abstract final class CaEase {
  static const standard = Cubic(.23, 1, .32, 1);
  static const spring = Cubic(.3, 1.25, .6, 1);
  static const inOut = Cubic(.77, 0, .175, 1);
}

abstract final class CaTilt {
  /// -3deg
  static const double stamp = -3.0 * 3.141592653589793 / 180;

  /// -1.5deg
  static const double flyer = -1.5 * 3.141592653589793 / 180;
}

abstract final class CaSize {
  static const double headerHeight = 72.0;
  static const double headerHeightMobile = 60.0;
  static const double buttonHeight = 52.0;
  static const double buttonHeightSm = 48.0;
  static const double buttonOutline = 1.5;
  static const double fieldHeight = 52.0;
  static const double accessMarkSize = 12.0;
  static const double accessMarkSizeLg = 16.0;
  static const double doorBox = 24.0;
  static const double embossWidth = 232.0;
  static const double embossHeight = 40.0;
  static const double rowDateColumn = 112.0;
  static const double rowImage = 176.0;
  static const double markerWidth = 3.0;
}

/// Bedeutungsfarben. Zugriff: `CaColors.of(context).textPrimary`.
class CaColors extends ThemeExtension<CaColors> {
  const CaColors(
      {required this.surfacePage,
      required this.surfaceSunken,
      required this.surfaceHover,
      required this.surfaceInverse,
      required this.surfaceDecision,
      required this.surfaceAccent,
      required this.surfacePressed,
      required this.surfaceHighlight,
      required this.textPrimary,
      required this.textSecondary,
      required this.textDisabled,
      required this.textInverse,
      required this.textDecision,
      required this.textOnAccent,
      required this.borderRule,
      required this.borderHair,
      required this.borderControl,
      required this.actionPrimary,
      required this.actionPrimaryPressed,
      required this.actionNeutral,
      required this.actionNeutralPressed,
      required this.actionDisabled,
      required this.actionOnPrimary,
      required this.markerStroke,
      required this.stampColor,
      required this.doorCurrent,
      required this.embossFill});
  final Color surfacePage;
  final Color surfaceSunken;
  final Color surfaceHover;
  final Color surfaceInverse;
  final Color surfaceDecision;
  final Color surfaceAccent;
  final Color surfacePressed;
  final Color surfaceHighlight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color textInverse;
  final Color textDecision;
  final Color textOnAccent;
  final Color borderRule;
  final Color borderHair;
  final Color borderControl;
  final Color actionPrimary;
  final Color actionPrimaryPressed;
  final Color actionNeutral;
  final Color actionNeutralPressed;
  final Color actionDisabled;
  final Color actionOnPrimary;
  final Color markerStroke;
  final Color stampColor;
  final Color doorCurrent;
  final Color embossFill;

  static const light = CaColors(
    surfacePage: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFF4F4F6),
    surfaceHover: Color(0xFFF4F4F6),
    surfaceInverse: Color(0xFF0D0E13),
    surfaceDecision: Color(0xFFFFF0E8),
    surfaceAccent: Color(0xFFFF5A1F),
    surfacePressed: Color(0xFFECEDF1),
    surfaceHighlight: Color(0xFFFFD9C9),
    textPrimary: Color(0xFF0D0E13),
    textSecondary: Color(0xFF5E606B),
    textDisabled: Color(0xFF6A6C77),
    textInverse: Color(0xFFFFFFFF),
    textDecision: Color(0xFFB83A0E),
    textOnAccent: Color(0xFF0D0E13),
    borderRule: Color(0xFF0D0E13),
    borderHair: Color(0xFFE2E3E8),
    borderControl: Color(0xFF8B8D98),
    actionPrimary: Color(0xFFFF5A1F),
    actionPrimaryPressed: Color(0xFFF04A10),
    actionNeutral: Color(0xFF0D0E13),
    actionNeutralPressed: Color(0xFF3A3C46),
    actionDisabled: Color(0xFFECEDF1),
    actionOnPrimary: Color(0xFF0D0E13),
    markerStroke: Color(0xFFFF5A1F),
    stampColor: Color(0xFFB83A0E),
    doorCurrent: Color(0xFFB83A0E),
    embossFill: Color(0xFFF4F4F6),
  );
  static const dark = CaColors(
    surfacePage: Color(0xFF0D0E13),
    surfaceSunken: Color(0xFF1A1B22),
    surfaceHover: Color(0xFF1A1B22),
    surfaceInverse: Color(0xFFF4F4F6),
    surfaceDecision: Color(0xFF2A1810),
    surfaceAccent: Color(0xFFFF5A1F),
    surfacePressed: Color(0xFF2A2B33),
    surfaceHighlight: Color(0xFF5A2A14),
    textPrimary: Color(0xFFF4F4F6),
    textSecondary: Color(0xFFA4A6B0),
    textDisabled: Color(0xFF6A6C77),
    textInverse: Color(0xFF0D0E13),
    textDecision: Color(0xFFFF7A45),
    textOnAccent: Color(0xFF0D0E13),
    borderRule: Color(0xFFF4F4F6),
    borderHair: Color(0xFF2A2B33),
    borderControl: Color(0xFF7C7E89),
    actionPrimary: Color(0xFFFF5A1F),
    actionPrimaryPressed: Color(0xFFF04A10),
    actionNeutral: Color(0xFFF4F4F6),
    actionNeutralPressed: Color(0xFFC9CAD1),
    actionDisabled: Color(0xFF1A1B22),
    actionOnPrimary: Color(0xFF0D0E13),
    markerStroke: Color(0xFFFF5A1F),
    stampColor: Color(0xFFFF7A45),
    doorCurrent: Color(0xFFFF7A45),
    embossFill: Color(0xFF1A1B22),
  );

  static CaColors of(BuildContext context) =>
      Theme.of(context).extension<CaColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  CaColors copyWith() => this;

  @override
  CaColors lerp(CaColors? other, double t) {
    if (other == null) return this;
    return CaColors(
        surfacePage: Color.lerp(surfacePage, other.surfacePage, t)!,
        surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
        surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
        surfaceInverse: Color.lerp(surfaceInverse, other.surfaceInverse, t)!,
        surfaceDecision: Color.lerp(surfaceDecision, other.surfaceDecision, t)!,
        surfaceAccent: Color.lerp(surfaceAccent, other.surfaceAccent, t)!,
        surfacePressed: Color.lerp(surfacePressed, other.surfacePressed, t)!,
        surfaceHighlight:
            Color.lerp(surfaceHighlight, other.surfaceHighlight, t)!,
        textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
        textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
        textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
        textInverse: Color.lerp(textInverse, other.textInverse, t)!,
        textDecision: Color.lerp(textDecision, other.textDecision, t)!,
        textOnAccent: Color.lerp(textOnAccent, other.textOnAccent, t)!,
        borderRule: Color.lerp(borderRule, other.borderRule, t)!,
        borderHair: Color.lerp(borderHair, other.borderHair, t)!,
        borderControl: Color.lerp(borderControl, other.borderControl, t)!,
        actionPrimary: Color.lerp(actionPrimary, other.actionPrimary, t)!,
        actionPrimaryPressed:
            Color.lerp(actionPrimaryPressed, other.actionPrimaryPressed, t)!,
        actionNeutral: Color.lerp(actionNeutral, other.actionNeutral, t)!,
        actionNeutralPressed:
            Color.lerp(actionNeutralPressed, other.actionNeutralPressed, t)!,
        actionDisabled: Color.lerp(actionDisabled, other.actionDisabled, t)!,
        actionOnPrimary: Color.lerp(actionOnPrimary, other.actionOnPrimary, t)!,
        markerStroke: Color.lerp(markerStroke, other.markerStroke, t)!,
        stampColor: Color.lerp(stampColor, other.stampColor, t)!,
        doorCurrent: Color.lerp(doorCurrent, other.doorCurrent, t)!,
        embossFill: Color.lerp(embossFill, other.embossFill, t)!);
  }
}

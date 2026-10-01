import 'dart:math' as math;

import 'package:flutter/material.dart';

abstract final class AccessDesign {
  static const ink = Color(0xFF151515);
  static const paper = Colors.white;
  static const muted = Color(0xFF666666);
  static const accentSoft = Color(0xFFFFE2E2);
  static const accent = Color(0xFFFF4848);
  static const neutral = Color(0xFFE6E6E6);
  static const focus = Color(0xFFC22626);
  static const curve = Cubic(.22, 1, .36, 1);

  static ThemeData theme() {
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFF797C81)),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Rubik',
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: focus,
        primary: ink,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: ink,
        onSurfaceVariant: muted,
        outline: const Color(0xFF797C81),
        error: const Color(0xFFA63028),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 76,
        titleTextStyle: TextStyle(
          fontFamily: 'Rubik',
          color: ink,
          fontSize: 17,
          fontWeight: FontWeight.w500,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: rounded,
        ).copyWith(side: _focusBorder(Colors.white)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              minimumSize: const Size(48, 52),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              shape: rounded,
            ).copyWith(
              side: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.focused)
                    ? const BorderSide(color: focus, width: 3)
                    : const BorderSide(color: Color(0xFF797C81)),
              ),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ).copyWith(side: _focusBorder(focus)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 20,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: focus, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        labelStyle: const TextStyle(fontFamily: 'Rubik', color: ink),
      ),
      dialogTheme: DialogThemeData(
        shape: rounded,
        backgroundColor: Colors.white,
      ),
    );
  }

  static WidgetStateProperty<BorderSide> _focusBorder(Color color) =>
      WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? BorderSide(color: color, width: 3)
            : BorderSide.none,
      );
}

/// Concentric surfaces share the same inset and radius throughout the app.
class AccessSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  const AccessSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: const Color(0xFFE6E6E6),
      borderRadius: BorderRadius.circular(32),
      border: Border.all(color: Colors.white),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0824252D),
          blurRadius: 40,
          offset: Offset(0, 16),
        ),
      ],
    ),
    child: Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: .65)),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    ),
  );
}

class AccessReveal extends StatelessWidget {
  final Widget child;
  const AccessReveal({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: AccessDesign.curve,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

class AccessHeader extends StatelessWidget {
  final Widget child;
  const AccessHeader({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: .15)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0924252D),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: IconTheme(
        data: const IconThemeData(color: Colors.white),
        child: Theme(
          data: Theme.of(context).copyWith(
            iconTheme: const IconThemeData(color: Colors.white),
            textButtonTheme: TextButtonThemeData(
              style:
                  TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ).copyWith(
                    side: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.focused)
                          ? const BorderSide(
                              color: AccessDesign.accentSoft,
                              width: 3,
                            )
                          : BorderSide.none,
                    ),
                  ),
            ),
            iconButtonTheme: IconButtonThemeData(
              style: IconButton.styleFrom(foregroundColor: Colors.white),
            ),
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class AccessTopBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final Widget leading;
  const AccessTopBar({super.key, required this.title, required this.leading});

  @override
  Size get preferredSize => const Size.fromHeight(88);

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: AccessHeader(
      child: Row(
        children: [
          leading,
          const SizedBox(width: 8),
          Expanded(
            child: DefaultTextStyle(
              style: const TextStyle(
                fontFamily: 'Rubik',
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
              child: title,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Existing icon identifiers keep control tests stable; glyphs use thin lines.
class AccessIcon extends Icon {
  const AccessIcon(
    super.icon, {
    super.key,
    super.size,
    super.color,
    super.semanticLabel,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    excludeSemantics: semanticLabel == null,
    child: SizedBox.square(
      dimension: size ?? IconTheme.of(context).size ?? 24,
      child: CustomPaint(
        painter: _AccessIconPainter(
          icon!,
          color ?? IconTheme.of(context).color ?? AccessDesign.ink,
        ),
      ),
    ),
  );
}

class _AccessIconPainter extends CustomPainter {
  final IconData icon;
  final Color color;
  _AccessIconPainter(this.icon, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    if (icon == Icons.radio_button_checked) {
      canvas.drawCircle(const Offset(9, 12), 7.5, pen);
      canvas.drawCircle(const Offset(15, 12), 7.5, pen);
    } else if (icon == Icons.search) {
      canvas.drawCircle(const Offset(10, 10), 6.5, pen);
      path.moveTo(15, 15);
      path.lineTo(21, 21);
    } else if (icon == Icons.north_east) {
      path.moveTo(5, 19);
      path.lineTo(19, 5);
      path.moveTo(6, 5);
      path.lineTo(19, 5);
      path.lineTo(19, 18);
    } else if (icon == Icons.arrow_back) {
      path.moveTo(20, 12);
      path.lineTo(4, 12);
      path.moveTo(10, 6);
      path.lineTo(4, 12);
      path.lineTo(10, 18);
    } else if (icon == Icons.close) {
      path.moveTo(6, 6);
      path.lineTo(18, 18);
      path.moveTo(18, 6);
      path.lineTo(6, 18);
    } else if (icon == Icons.refresh) {
      canvas.drawArc(
        const Rect.fromLTWH(4, 4, 16, 16),
        -.5,
        math.pi * 1.7,
        false,
        pen,
      );
      path.moveTo(20, 4);
      path.lineTo(20, 10);
      path.lineTo(14, 10);
    } else if (icon == Icons.place_outlined) {
      path.moveTo(12, 22);
      path.cubicTo(9, 18, 5, 14, 5, 9);
      path.cubicTo(5, 0, 19, 0, 19, 9);
      path.cubicTo(19, 14, 15, 18, 12, 22);
      canvas.drawCircle(const Offset(12, 9), 2.5, pen);
    } else if (icon == Icons.event_outlined) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(3, 5, 18, 16),
          const Radius.circular(3),
        ),
        pen,
      );
      path.moveTo(3, 10);
      path.lineTo(21, 10);
      path.moveTo(8, 3);
      path.lineTo(8, 7);
      path.moveTo(16, 3);
      path.lineTo(16, 7);
    }
    canvas.drawPath(path, pen);
  }

  @override
  bool shouldRepaint(_AccessIconPainter oldDelegate) =>
      oldDelegate.icon != icon || oldDelegate.color != color;
}

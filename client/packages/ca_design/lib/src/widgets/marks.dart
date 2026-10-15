import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';

/// Kreis von Hand um ein Datum oder eine Zahl. Zeichnet sich in 600 ms,
/// nach 500 ms; bei reduzierter Bewegung steht er sofort fertig da. Rein schmückend.
class DateCircle extends StatelessWidget {
  const DateCircle({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final color = CaColors.of(context).markerStroke;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 1100),
      curve: Curves.linear,
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: child),
      builder: (context, t, child) => CustomPaint(
        foregroundPainter: _HandCircle(
            color: color,
            drawn: reduced
                ? 1
                : CaEase.standard.transform(
                    ((t * 1100 - 500) / CaDuration.draw.inMilliseconds)
                        .clamp(0.0, 1.0)),
            opacity: 1),
        child: child,
      ),
    );
  }
}

class _HandCircle extends CustomPainter {
  _HandCircle(
      {required this.color, required this.drawn, required this.opacity});
  final Color color;
  final double drawn;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final path = Path();
    // Etwas mehr als eine Runde, Radius leicht unruhig wie von Hand.
    const steps = 72;
    for (var i = 0; i <= steps; i++) {
      final a = -2.6 + i / steps * math.pi * 2.12;
      final rx = size.width / 2 * (1.12 + .03 * math.sin(3 * a));
      final ry = size.height / 2 * (1.22 + .05 * math.cos(2 * a));
      final p = c + Offset(math.cos(a) * rx, math.sin(a) * ry);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * drawn), paint);
    }
  }

  @override
  bool shouldRepaint(_HandCircle old) =>
      old.drawn != drawn || old.opacity != opacity || old.color != color;
}

/// Klebestreifen unter der aktuellen Seite, dem aktiven Reiter oder Navigationspunkt.
/// Gerader oranger Streifen, leicht schief. Wischt in 280 ms von links herein,
/// bei reduzierter Bewegung blendet er ein.
class CaTape extends StatelessWidget {
  const CaTape({super.key, required this.child, this.active = true});
  final Widget child;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final strip = ColoredBox(color: CaColors.of(context).markerStroke);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -4,
          right: -4,
          bottom: -1,
          height: 6,
          child: Transform.rotate(
            angle: CaTilt.flyer,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: CaDuration.slow,
              curve: reduced ? Curves.linear : CaEase.standard,
              builder: (context, t, _) => reduced
                  ? Opacity(opacity: t, child: strip)
                  : ClipRect(clipper: _TapeClip(t), child: strip),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _TapeClip extends CustomClipper<Rect> {
  const _TapeClip(this.progress);
  final double progress;
  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * progress, size.height);
  @override
  bool shouldReclip(_TapeClip oldClipper) => oldClipper.progress != progress;
}

import 'package:flutter/material.dart';

import 'access_symbols.dart';

/// Authored marker paths shared with the approved Flyer preview.
class FlyerIconPainter extends CustomPainter {
  const FlyerIconPainter(this.symbol, this.color);
  final AccessSymbol symbol;
  final Color color;
  static bool supports(AccessSymbol s) => const {
    AccessSymbol.menu,
    AccessSymbol.arrowRight,
    AccessSymbol.arrowLeft,
    AccessSymbol.caretRight,
    AccessSymbol.check,
    AccessSymbol.close,
    AccessSymbol.clock,
    AccessSymbol.calendar,
    AccessSymbol.calendarFill,
    AccessSymbol.calendarAdd,
    AccessSymbol.users,
    AccessSymbol.mapPin,
    AccessSymbol.lock,
    AccessSymbol.mail,
  }.contains(s);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    if (symbol == AccessSymbol.arrowLeft) {
      canvas.translate(24, 0);
      canvas.scale(-1, 1);
    }
    final path = switch (symbol) {
      AccessSymbol.menu =>
        Path()
          ..moveTo(3, 8)
          ..cubicTo(9, 7, 15, 7, 21, 8)
          ..moveTo(3, 16)
          ..cubicTo(9, 15, 15, 15, 21, 16),
      AccessSymbol.arrowRight =>
        Path()
          ..moveTo(3, 14)
          ..cubicTo(8, 11, 14, 10, 20, 11)
          ..moveTo(14, 5)
          ..cubicTo(16, 7, 18, 9, 21, 11)
          ..cubicTo(18, 12, 16, 15, 14, 18),
      AccessSymbol.arrowLeft =>
        Path()
          ..moveTo(3, 14)
          ..cubicTo(8, 11, 14, 10, 20, 11)
          ..moveTo(14, 5)
          ..cubicTo(16, 7, 18, 9, 21, 11)
          ..cubicTo(18, 12, 16, 15, 14, 18),
      AccessSymbol.caretRight =>
        Path()
          ..moveTo(5, 13)
          ..cubicTo(9, 11, 13, 11, 19, 11)
          ..moveTo(14, 6)
          ..lineTo(20, 11)
          ..lineTo(14, 18),
      AccessSymbol.check =>
        Path()
          ..moveTo(4, 12)
          ..cubicTo(6, 13, 8, 16, 9, 18)
          ..cubicTo(12, 14, 15, 9, 20, 5),
      AccessSymbol.close =>
        Path()
          ..moveTo(5, 5)
          ..cubicTo(9, 8, 13, 14, 19, 19)
          ..moveTo(18, 5)
          ..cubicTo(13, 9, 9, 14, 5, 19),
      AccessSymbol.clock =>
        Path()
          ..moveTo(19, 5)
          ..cubicTo(14, 0, 5, 4, 4, 10)
          ..cubicTo(2, 16, 7, 21, 12, 21)
          ..cubicTo(19, 21, 23, 13, 20, 8)
          ..moveTo(12, 7)
          ..lineTo(11, 13)
          ..lineTo(16, 15),
      AccessSymbol.calendar =>
        Path()
          ..moveTo(5, 5)
          ..lineTo(19, 4)
          ..lineTo(20, 20)
          ..lineTo(4, 21)
          ..lineTo(5, 5)
          ..moveTo(8, 2)
          ..lineTo(9, 7)
          ..moveTo(16, 2)
          ..lineTo(15, 7)
          ..moveTo(5, 10)
          ..lineTo(19, 9)
          ..moveTo(8, 14)
          ..lineTo(10, 14)
          ..moveTo(14, 14)
          ..lineTo(16, 14),
      AccessSymbol.calendarFill =>
        Path()
          ..moveTo(5, 5)
          ..lineTo(19, 4)
          ..lineTo(20, 20)
          ..lineTo(4, 21)
          ..lineTo(5, 5)
          ..moveTo(8, 2)
          ..lineTo(9, 7)
          ..moveTo(16, 2)
          ..lineTo(15, 7)
          ..moveTo(5, 10)
          ..lineTo(19, 9)
          ..moveTo(8, 14)
          ..lineTo(10, 14)
          ..moveTo(14, 14)
          ..lineTo(16, 14),
      AccessSymbol.calendarAdd =>
        Path()
          ..moveTo(5, 5)
          ..lineTo(19, 4)
          ..lineTo(20, 20)
          ..lineTo(4, 21)
          ..lineTo(5, 5)
          ..moveTo(8, 2)
          ..lineTo(9, 7)
          ..moveTo(16, 2)
          ..lineTo(15, 7)
          ..moveTo(5, 10)
          ..lineTo(19, 9)
          ..moveTo(8, 14)
          ..lineTo(10, 14)
          ..moveTo(14, 14)
          ..lineTo(16, 14),
      AccessSymbol.users =>
        Path()
          ..moveTo(8, 3)
          ..cubicTo(3, 2, 3, 11, 8, 11)
          ..cubicTo(13, 11, 13, 3, 8, 3)
          ..moveTo(2, 21)
          ..cubicTo(1, 11, 15, 11, 15, 20)
          ..moveTo(17, 4)
          ..cubicTo(23, 4, 22, 12, 18, 12)
          ..moveTo(18, 15)
          ..cubicTo(21, 15, 23, 18, 22, 21),
      AccessSymbol.mapPin =>
        Path()
          ..moveTo(12, 22)
          ..cubicTo(8, 16, 2, 11, 5, 6)
          ..cubicTo(9, -1, 20, 3, 20, 9)
          ..cubicTo(20, 13, 15, 19, 12, 22)
          ..moveTo(13, 6)
          ..cubicTo(9, 5, 7, 12, 12, 12)
          ..cubicTo(16, 12, 17, 7, 13, 6),
      AccessSymbol.lock =>
        Path()
          ..moveTo(7, 11)
          ..cubicTo(6, 0, 17, 1, 17, 10)
          ..moveTo(4, 11)
          ..lineTo(20, 10)
          ..lineTo(21, 21)
          ..lineTo(4, 22)
          ..lineTo(4, 11)
          ..moveTo(12, 15)
          ..lineTo(12, 18),
      AccessSymbol.mail =>
        Path()
          ..moveTo(3, 6)
          ..lineTo(20, 5)
          ..lineTo(21, 20)
          ..lineTo(3, 21)
          ..lineTo(3, 6)
          ..moveTo(4, 7)
          ..lineTo(12, 14)
          ..lineTo(20, 6),
      _ => Path(),
    };
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(FlyerIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.symbol != symbol;
}

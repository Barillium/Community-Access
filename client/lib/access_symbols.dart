import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Scalable 24-unit drawings based on the supplied i-symbole.png reference.
/// Ink carries meaning; the optional second pen is decorative only.
enum AccessSymbol {
  arrowRight,
  arrowLeft,
  check,
  close,
  caretDown,
  caretRight,
  menu,
  search,
  bookmark,
  bookmarkFill,
  bookmarkRemove,
  calendar,
  calendarFill,
  calendarAdd,
  door,
  doorFill,
  user,
  userFill,
  users,
  lock,
  shieldCheck,
  clock,
  globe,
  mapPin,
  warning,
  help,
  wifiOff,
  refresh,
  trash,
  pause,
  play,
  contrast,
  share,
  shareAndroid,
  more,
  moreVertical,
  bell,
  mail,
  flag,
  document,
  filter,
  // Existing product actions, constructed on the same grid.
  external,
  image,
  key,
  eye,
  status,
}

AccessSymbol? accessSymbolFor(IconData? icon) => switch (icon) {
  Icons.arrow_forward => AccessSymbol.arrowRight,
  Icons.arrow_back => AccessSymbol.arrowLeft,
  Icons.check || Icons.check_outlined => AccessSymbol.check,
  Icons.close => AccessSymbol.close,
  Icons.keyboard_arrow_down || Icons.expand_more => AccessSymbol.caretDown,
  Icons.chevron_right || Icons.keyboard_arrow_right => AccessSymbol.caretRight,
  Icons.menu => AccessSymbol.menu,
  Icons.search => AccessSymbol.search,
  Icons.bookmark_border => AccessSymbol.bookmark,
  Icons.bookmark => AccessSymbol.bookmarkFill,
  Icons.bookmark_remove_outlined => AccessSymbol.bookmarkRemove,
  Icons.calendar_month ||
  Icons.event_outlined ||
  Icons.calendar_today_outlined => AccessSymbol.calendar,
  Icons.calendar_month_outlined => AccessSymbol.calendar,
  Icons.event_available => AccessSymbol.calendarFill,
  Icons.event_note || Icons.event_note_outlined => AccessSymbol.document,
  Icons.event => AccessSymbol.calendarFill,
  Icons.event_available_outlined => AccessSymbol.calendarAdd,
  Icons.door_front_door_outlined => AccessSymbol.door,
  Icons.door_front_door => AccessSymbol.doorFill,
  Icons.person_outline || Icons.account_circle_outlined => AccessSymbol.user,
  Icons.person || Icons.account_circle => AccessSymbol.userFill,
  Icons.groups_outlined || Icons.people_outline => AccessSymbol.users,
  Icons.lock_outline || Icons.lock => AccessSymbol.lock,
  Icons.verified_user_outlined => AccessSymbol.shieldCheck,
  Icons.schedule || Icons.access_time => AccessSymbol.clock,
  Icons.language => AccessSymbol.globe,
  Icons.place_outlined || Icons.location_on_outlined => AccessSymbol.mapPin,
  Icons.error_outline || Icons.warning_amber_outlined => AccessSymbol.warning,
  Icons.help_outline => AccessSymbol.help,
  Icons.wifi_off => AccessSymbol.wifiOff,
  Icons.refresh => AccessSymbol.refresh,
  Icons.delete_outline => AccessSymbol.trash,
  Icons.pause => AccessSymbol.pause,
  Icons.play_arrow => AccessSymbol.play,
  Icons.contrast => AccessSymbol.contrast,
  Icons.ios_share => AccessSymbol.share,
  Icons.share => AccessSymbol.shareAndroid,
  Icons.more_horiz => AccessSymbol.more,
  Icons.more_vert => AccessSymbol.moreVertical,
  Icons.notifications_none => AccessSymbol.bell,
  Icons.mail_outline => AccessSymbol.mail,
  Icons.flag_outlined => AccessSymbol.flag,
  Icons.description_outlined => AccessSymbol.document,
  Icons.tune => AccessSymbol.filter,
  Icons.north_east => AccessSymbol.external,
  Icons.add_photo_alternate_outlined => AccessSymbol.image,
  Icons.key_outlined => AccessSymbol.key,
  Icons.visibility_outlined => AccessSymbol.eye,
  Icons.radio_button_checked => AccessSymbol.status,
  _ => null,
};

class AccessSymbolPainter extends CustomPainter {
  const AccessSymbolPainter(
    this.symbol, {
    required this.ink,
    required this.accent,
    this.active = false,
  });
  final AccessSymbol symbol;
  final Color ink;
  final Color? accent;
  final bool active;

  void _line(Canvas c, Paint p, List<Offset> points, {bool close = false}) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    if (close) path.close();
    c.drawPath(path, p);
  }

  void _segment(Canvas c, Paint p, double x, double y, double x2, double y2) =>
      c.drawLine(Offset(x, y), Offset(x2, y2), p);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter;
    final solid = Paint()
      ..color = ink
      ..style = PaintingStyle.fill;
    final second = accent == null
        ? null
        : (Paint()
            ..color = accent!
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.butt);
    final tint = accent == null
        ? null
        : (Paint()
            ..color = accent!
            ..style = PaintingStyle.fill);
    final s = switch (symbol) {
      AccessSymbol.calendar when active => AccessSymbol.calendarFill,
      AccessSymbol.door when active => AccessSymbol.doorFill,
      AccessSymbol.user when active => AccessSymbol.userFill,
      _ => symbol,
    };
    switch (s) {
      case AccessSymbol.arrowRight:
        _segment(canvas, pen, 3, 12, 21, 12);
        _line(canvas, pen, const [
          Offset(15, 6),
          Offset(21, 12),
          Offset(15, 18),
        ]);
      case AccessSymbol.arrowLeft:
        _segment(canvas, pen, 21, 12, 3, 12);
        _line(canvas, pen, const [Offset(9, 6), Offset(3, 12), Offset(9, 18)]);
      case AccessSymbol.check:
        _line(canvas, pen, const [Offset(3, 12), Offset(9, 18), Offset(21, 5)]);
        if (active && second != null) _segment(canvas, second, 5, 22, 14, 21);
      case AccessSymbol.close:
        _segment(canvas, pen, 5, 5, 19, 19);
        _segment(canvas, pen, 19, 5, 5, 19);
      case AccessSymbol.caretDown:
        _line(canvas, pen, const [Offset(6, 9), Offset(12, 15), Offset(18, 9)]);
      case AccessSymbol.caretRight:
        _line(canvas, pen, const [Offset(9, 6), Offset(15, 12), Offset(9, 18)]);
      case AccessSymbol.menu:
        for (final y in [6.0, 12.0, 18.0]) {
          _segment(canvas, pen, 3, y, 21, y);
        }
      case AccessSymbol.search:
        canvas.drawCircle(const Offset(10, 10), 6, pen);
        _segment(canvas, pen, 14.5, 14.5, 21, 21);
      case AccessSymbol.bookmark:
      case AccessSymbol.bookmarkFill:
      case AccessSymbol.bookmarkRemove:
        final path = Path()
          ..moveTo(6, 3)
          ..lineTo(18, 3)
          ..lineTo(18, 21)
          ..lineTo(12, 16)
          ..lineTo(6, 21)
          ..close();
        canvas.drawPath(path, s == AccessSymbol.bookmarkFill ? solid : pen);
        if (s == AccessSymbol.bookmarkFill && second != null) {
          _line(canvas, second, const [
            Offset(8, 9),
            Offset(11, 12),
            Offset(16, 6),
          ]);
        } else if (s == AccessSymbol.bookmarkRemove) {
          _segment(canvas, pen, 9, 8, 15, 8);
        }
      case AccessSymbol.calendar:
      case AccessSymbol.calendarFill:
      case AccessSymbol.calendarAdd:
        canvas.drawRect(const Rect.fromLTWH(3, 5, 18, 16), pen);
        if (s == AccessSymbol.calendarFill) {
          canvas.drawRect(const Rect.fromLTWH(3, 5, 18, 5), solid);
        }
        _segment(canvas, pen, 3, 10, 21, 10);
        _segment(canvas, pen, 7, 2, 7, 7);
        _segment(canvas, pen, 17, 2, 17, 7);
        if (s == AccessSymbol.calendarAdd) {
          _segment(canvas, pen, 8, 15, 16, 15);
          _segment(canvas, pen, 12, 11, 12, 19);
        } else {
          canvas.drawRect(const Rect.fromLTWH(7, 13, 3, 3), solid);
          if (active && second != null) _segment(canvas, second, 7, 19, 16, 18);
        }
      case AccessSymbol.door:
      case AccessSymbol.doorFill:
        final frame = Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(const Rect.fromLTWH(5, 2, 14, 20))
          ..addRect(const Rect.fromLTWH(7, 4, 10, 16));
        canvas.drawPath(frame, solid);
        final leaf = Path()
          ..moveTo(6, 3)
          ..lineTo(13, 6)
          ..lineTo(13, 19)
          ..lineTo(6, 22)
          ..close();
        canvas.drawPath(leaf, s == AccessSymbol.doorFill ? solid : pen);
        if (active && tint != null) {
          _line(canvas, tint, const [
            Offset(14, 6),
            Offset(17, 4),
            Offset(17, 19),
            Offset(14, 20),
          ], close: true);
        }
        canvas.drawRect(const Rect.fromLTWH(10, 12, 3, 2), solid);
        _segment(canvas, pen, 2, 22, 22, 22);
      case AccessSymbol.user:
      case AccessSymbol.userFill:
        canvas.drawCircle(const Offset(12, 12), 9, pen);
        canvas.drawCircle(
          const Offset(12, 9),
          3,
          s == AccessSymbol.userFill ? solid : pen,
        );
        final shoulders = Path()
          ..moveTo(6, 19)
          ..lineTo(6, 17)
          ..quadraticBezierTo(6, 14, 12, 14)
          ..quadraticBezierTo(18, 14, 18, 17)
          ..lineTo(18, 19);
        canvas.drawPath(shoulders, s == AccessSymbol.userFill ? solid : pen);
        if (active && second != null) {
          canvas.drawArc(
            const Rect.fromLTWH(1, 1, 22, 22),
            -math.pi * .87,
            math.pi * .36,
            false,
            second,
          );
        }
      case AccessSymbol.users:
        canvas.drawCircle(const Offset(8, 7), 3, pen);
        canvas.drawCircle(const Offset(17, 7), 2.5, pen);
        canvas.drawPath(
          Path()
            ..moveTo(2, 20)
            ..lineTo(2, 17)
            ..quadraticBezierTo(2, 13, 8, 13)
            ..quadraticBezierTo(14, 13, 14, 17)
            ..lineTo(14, 20),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(16, 13)
            ..quadraticBezierTo(22, 13, 22, 17)
            ..lineTo(22, 20),
          pen,
        );
        if (active && second != null) _segment(canvas, second, 2, 22, 15, 21);
      case AccessSymbol.lock:
        canvas.drawRect(const Rect.fromLTWH(8, 3, 8, 7), pen);
        if (second != null) {
          canvas.save();
          canvas.clipRect(const Rect.fromLTWH(5, 11, 14, 10));
          for (double x = -12; x < 24; x += 4) {
            _segment(canvas, second, x, 22, x + 16, 10);
          }
          canvas.restore();
        }
        canvas.drawRect(const Rect.fromLTWH(4, 10, 16, 12), pen);
        canvas.drawRect(const Rect.fromLTWH(11, 15, 2, 2), solid);
      case AccessSymbol.shieldCheck:
        _line(canvas, pen, const [
          Offset(12, 2),
          Offset(21, 6),
          Offset(20, 14),
          Offset(12, 22),
          Offset(4, 14),
          Offset(3, 6),
        ], close: true);
        _line(canvas, pen, const [
          Offset(7, 11),
          Offset(11, 15),
          Offset(17, 8),
        ]);
        if (second != null) _segment(canvas, second, 19, 2, 21, 0);
      case AccessSymbol.clock:
        canvas.drawCircle(const Offset(12, 12), 9, pen);
        _line(canvas, pen, const [
          Offset(12, 5),
          Offset(12, 12),
          Offset(17, 15),
        ]);
        if (second != null) _segment(canvas, second, 12, 12, 8, 17);
      case AccessSymbol.globe:
        canvas.drawCircle(const Offset(12, 12), 9, pen);
        canvas.drawPath(
          Path()
            ..moveTo(12, 3)
            ..cubicTo(5, 5, 5, 19, 12, 21)
            ..cubicTo(19, 19, 19, 5, 12, 3),
          pen,
        );
        _segment(canvas, pen, 3, 12, 21, 12);
        if (second != null) _segment(canvas, second, 5, 21, 13, 22);
      case AccessSymbol.mapPin:
        canvas.drawPath(
          Path()
            ..moveTo(12, 22)
            ..lineTo(5, 12)
            ..cubicTo(-1, 0, 25, 0, 19, 12)
            ..close(),
          pen,
        );
        canvas.drawCircle(const Offset(12, 9), 2.5, pen);
        if (second != null) _segment(canvas, second, 9, 23, 15, 23);
      case AccessSymbol.warning:
        canvas.drawCircle(const Offset(12, 12), 9, pen);
        _segment(canvas, pen, 12, 6, 12, 13);
        canvas.drawRect(const Rect.fromLTWH(11, 16, 2, 2), solid);
        if (second != null) _segment(canvas, second, 3, 3, 1, 1);
      case AccessSymbol.help:
        canvas.drawCircle(const Offset(12, 12), 9, pen);
        canvas.drawPath(
          Path()
            ..moveTo(9, 8)
            ..quadraticBezierTo(9, 5, 12, 5)
            ..quadraticBezierTo(18, 5, 15, 9)
            ..lineTo(12, 12)
            ..lineTo(12, 14),
          pen,
        );
        canvas.drawRect(const Rect.fromLTWH(11, 17, 2, 2), solid);
        if (second != null) {
          _segment(canvas, second, 20, 4, 22, 2);
          _segment(canvas, second, 22, 7, 24, 6);
        }
      case AccessSymbol.wifiOff:
        canvas.drawPath(
          Path()
            ..moveTo(3, 7)
            ..quadraticBezierTo(12, 0, 21, 7),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(7, 11)
            ..quadraticBezierTo(12, 7, 17, 11),
          pen,
        );
        canvas.drawRect(const Rect.fromLTWH(11, 17, 2, 2), solid);
        _segment(canvas, pen, 2, 2, 22, 22);
      case AccessSymbol.refresh:
        canvas.drawArc(
          const Rect.fromLTWH(3, 3, 18, 18),
          .4,
          math.pi * 1.66,
          false,
          pen,
        );
        _line(canvas, pen, const [Offset(21, 2), Offset(21, 9), Offset(14, 9)]);
      case AccessSymbol.trash:
        _segment(canvas, pen, 3, 6, 21, 6);
        _line(canvas, pen, const [
          Offset(8, 6),
          Offset(8, 3),
          Offset(16, 3),
          Offset(16, 6),
        ]);
        _line(canvas, pen, const [
          Offset(5, 6),
          Offset(6, 21),
          Offset(18, 21),
          Offset(19, 6),
        ]);
        _segment(canvas, pen, 9, 10, 9, 17);
        _segment(canvas, pen, 15, 10, 15, 17);
      case AccessSymbol.pause:
        canvas.drawRect(const Rect.fromLTWH(6, 4, 4, 16), solid);
        canvas.drawRect(const Rect.fromLTWH(14, 4, 4, 16), solid);
      case AccessSymbol.play:
        _line(canvas, solid, const [
          Offset(6, 3),
          Offset(21, 12),
          Offset(6, 21),
        ], close: true);
      case AccessSymbol.contrast:
        canvas.drawCircle(const Offset(12, 12), 9, pen);
        canvas.save();
        canvas.clipPath(Path()..addOval(const Rect.fromLTWH(3, 3, 18, 18)));
        canvas.drawRect(const Rect.fromLTWH(12, 3, 9, 18), solid);
        canvas.restore();
        if (second != null) _segment(canvas, second, 2, 6, 5, 3);
      case AccessSymbol.share:
        _line(canvas, pen, const [
          Offset(7, 10),
          Offset(4, 10),
          Offset(4, 22),
          Offset(20, 22),
          Offset(20, 10),
          Offset(17, 10),
        ]);
        _segment(canvas, pen, 12, 15, 12, 2);
        _line(canvas, pen, const [Offset(7, 7), Offset(12, 2), Offset(17, 7)]);
      case AccessSymbol.shareAndroid:
        _segment(canvas, pen, 5, 12, 19, 4);
        _segment(canvas, pen, 5, 12, 19, 20);
        for (final o in const [Offset(4, 12), Offset(20, 4), Offset(20, 20)]) {
          canvas.drawCircle(o, 2.5, solid);
        }
      case AccessSymbol.more:
        for (final x in [4.0, 11.0, 18.0]) {
          canvas.drawRect(Rect.fromLTWH(x, 11, 2, 2), solid);
        }
      case AccessSymbol.moreVertical:
        for (final y in [4.0, 11.0, 18.0]) {
          canvas.drawRect(Rect.fromLTWH(11, y, 2, 2), solid);
        }
      case AccessSymbol.bell:
        canvas.drawPath(
          Path()
            ..moveTo(5, 17)
            ..lineTo(6, 8)
            ..quadraticBezierTo(6, 3, 12, 3)
            ..quadraticBezierTo(18, 3, 18, 8)
            ..lineTo(19, 17)
            ..close(),
          pen,
        );
        _segment(canvas, pen, 3, 19, 21, 19);
        canvas.drawRect(const Rect.fromLTWH(10, 21, 4, 2), solid);
        if (second != null) {
          _segment(canvas, second, 3, 6, 2, 3);
          _segment(canvas, second, 21, 6, 22, 3);
        }
      case AccessSymbol.mail:
        if (tint != null) {
          canvas.drawRect(const Rect.fromLTWH(4, 6, 16, 12), tint);
        }
        canvas.drawRect(const Rect.fromLTWH(3, 5, 18, 14), pen);
        _line(canvas, pen, const [Offset(3, 5), Offset(12, 12), Offset(21, 5)]);
      case AccessSymbol.flag:
        _segment(canvas, pen, 5, 2, 5, 22);
        final flag = Path()
          ..moveTo(5, 3)
          ..lineTo(20, 3)
          ..lineTo(17, 7)
          ..lineTo(20, 11)
          ..lineTo(5, 11)
          ..close();
        if (tint != null) canvas.drawPath(flag, tint);
        canvas.drawPath(flag, pen);
      case AccessSymbol.document:
        canvas.drawRect(const Rect.fromLTWH(5, 2, 14, 20), pen);
        for (final y in [7.0, 11.0, 15.0]) {
          _segment(canvas, pen, 8, y, 16, y);
        }
        if (second != null) _segment(canvas, second, 8, 19, 14, 18);
      case AccessSymbol.filter:
        for (final (y, x) in [(6.0, 7.0), (12.0, 16.0), (18.0, 10.0)]) {
          _segment(canvas, pen, 3, y, x - 2, y);
          _segment(canvas, pen, x + 2, y, 21, y);
          canvas.drawRect(Rect.fromLTWH(x - 2, y - 2, 4, 4), pen);
        }
      case AccessSymbol.external:
        _segment(canvas, pen, 4, 20, 20, 4);
        _line(canvas, pen, const [
          Offset(10, 4),
          Offset(20, 4),
          Offset(20, 14),
        ]);
      case AccessSymbol.image:
        canvas.drawRect(const Rect.fromLTWH(3, 3, 18, 18), pen);
        _line(canvas, pen, const [
          Offset(3, 17),
          Offset(9, 11),
          Offset(13, 15),
          Offset(17, 10),
          Offset(21, 14),
        ]);
        canvas.drawCircle(const Offset(16, 7), 1.5, solid);
      case AccessSymbol.key:
        canvas.drawCircle(const Offset(7, 7), 4, pen);
        _segment(canvas, pen, 10, 10, 21, 21);
        _segment(canvas, pen, 15, 15, 18, 12);
        _segment(canvas, pen, 18, 18, 21, 15);
      case AccessSymbol.eye:
        canvas.drawPath(
          Path()
            ..moveTo(2, 12)
            ..quadraticBezierTo(12, 0, 22, 12)
            ..quadraticBezierTo(12, 24, 2, 12),
          pen,
        );
        canvas.drawCircle(const Offset(12, 12), 3, pen);
      case AccessSymbol.status:
        canvas.drawCircle(const Offset(12, 12), 8, pen);
        canvas.drawRect(const Rect.fromLTWH(9, 9, 6, 6), solid);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(AccessSymbolPainter oldDelegate) =>
      oldDelegate.symbol != symbol ||
      oldDelegate.ink != ink ||
      oldDelegate.accent != accent ||
      oldDelegate.active != active;
}

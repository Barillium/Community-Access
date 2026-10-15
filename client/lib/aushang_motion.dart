import 'package:ca_design/ca_design.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Only the supplied mouse hover; focus, keyboard and touch never move media.
class AccessFlyerHover extends StatefulWidget {
  const AccessFlyerHover({super.key, required this.child});
  final Widget child;
  @override
  State<AccessFlyerHover> createState() => _AccessFlyerHoverState();
}

class _AccessFlyerHoverState extends State<AccessFlyerHover> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final moves = _hovered && !MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
      onEnter: (event) {
        if (event.kind == PointerDeviceKind.mouse) {
          setState(() => _hovered = true);
        }
      },
      onExit: (_) => setState(() => _hovered = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: moves ? 1 : 0),
        duration: CaDuration.base,
        curve: CaEase.standard,
        child: widget.child,
        builder: (context, t, child) => Transform.translate(
          offset: Offset(0, -4 * t),
          child: Transform.rotate(
            angle: CaTilt.flyer * t,
            child: Transform.scale(scale: 1 + .02 * t, child: child),
          ),
        ),
      ),
    );
  }
}

/// A poster is pasted from right to left; reduced motion only fades it in.
class AccessPaste extends StatelessWidget {
  const AccessPaste({super.key, required this.child, this.animate = true});
  final Widget child;
  final bool animate;
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: animate ? 0 : 1, end: 1),
      duration: animate ? CaDuration.slow : Duration.zero,
      curve: CaEase.standard,
      child: child,
      builder: (context, t, child) => reduced
          ? Opacity(opacity: t, child: child)
          : ClipRect(clipper: _PasteClip(t), child: child),
    );
  }
}

class _PasteClip extends CustomClipper<Rect> {
  const _PasteClip(this.progress);
  final double progress;
  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(size.width * (1 - progress), 0, size.width, size.height);
  @override
  bool shouldReclip(_PasteClip oldClipper) => oldClipper.progress != progress;
}

/// The complete Text still owns layout, scaling and semantics. The painter
/// reveals its shaped glyphs, so words wrap exactly as in the static title.
class AccessKineticTitle extends StatefulWidget {
  const AccessKineticTitle(
    this.text, {
    super.key,
    required this.style,
    this.animate = true,
  });
  final String text;
  final TextStyle style;
  final bool animate;
  @override
  State<AccessKineticTitle> createState() => _AccessKineticTitleState();
}

class _AccessKineticTitleState extends State<AccessKineticTitle>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this);
  bool? _reduced;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced == reduced) return;
    _reduced = reduced;
    _start();
  }

  void _start() {
    _controller.duration = _reduced!
        ? CaDuration.slow
        : Duration(
            milliseconds:
                200 +
                CaDuration.slow.inMilliseconds +
                45 * (widget.text.characters.length - 1).clamp(0, 200),
          );
    if (widget.animate) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(AccessKineticTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    return AnimatedBuilder(
      animation: _controller,
      child: Opacity(
        opacity: 0,
        alwaysIncludeSemantics: true,
        child: Text(widget.text, style: style),
      ),
      builder: (context, child) => CustomPaint(
        foregroundPainter: _KineticPainter(
          widget.text,
          style,
          MediaQuery.textScalerOf(context),
          Directionality.of(context),
          _controller.value,
          _controller.duration!.inMilliseconds,
          _reduced!,
        ),
        child: child,
      ),
    );
  }
}

class _KineticPainter extends CustomPainter {
  const _KineticPainter(
    this.text,
    this.style,
    this.scaler,
    this.direction,
    this.progress,
    this.total,
    this.reduced,
  );
  final String text;
  final TextStyle style;
  final TextScaler scaler;
  final TextDirection direction;
  final double progress;
  final int total;
  final bool reduced;
  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: scaler,
      textDirection: direction,
    )..layout(maxWidth: size.width);
    if (progress == 1) {
      painter.paint(canvas, Offset.zero);
      painter.dispose();
      return;
    }
    if (reduced) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: progress),
      );
      painter.paint(canvas, Offset.zero);
      canvas.restore();
      painter.dispose();
      return;
    }
    var offset = 0, index = 0;
    for (final letter in text.characters) {
      final t =
          ((progress * total - 200 - index * 45) /
                  CaDuration.slow.inMilliseconds)
              .clamp(0.0, 1.0);
      final eased = CaEase.standard.transform(t);
      final boxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: offset + letter.length),
      );
      final y = scaler.scale(style.fontSize ?? 16) * .42 * (1 - eased);
      for (final box in boxes) {
        canvas.save();
        canvas.clipRect(
          Rect.fromLTRB(box.left, box.top, box.right, box.bottom + y),
        );
        canvas.saveLayer(
          Offset.zero & size,
          Paint()..color = Colors.white.withValues(alpha: eased),
        );
        painter.paint(canvas, Offset(0, y));
        canvas.restore();
        canvas.restore();
      }
      offset += letter.length;
      index++;
    }
    painter.dispose();
  }

  @override
  bool shouldRepaint(_KineticPainter old) =>
      old.progress != progress ||
      old.text != text ||
      old.style != style ||
      old.scaler != scaler ||
      old.direction != direction ||
      old.reduced != reduced;
}

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_language.dart';
import 'access_typography.dart';

/// Approved Kulturplakat/Flyer identity. Illustrative media never supplies event data.
abstract final class FlyerStyle {
  static const paper = Color(0xfff8f6f0);
  static const ink = Color(0xff171713);
  static const orange = Color(0xffff5a1f);
  static const marker = Color(0xffe64a16);
  static const scene = 'assets/images/kulturraum.webp';
  static const textShadows = [
    Shadow(color: Color(0xee000000), blurRadius: 3),
    Shadow(color: Color(0xdd000000), blurRadius: 8),
    Shadow(color: Color(0xbb000000), blurRadius: 18),
  ];
}

enum FlyerMarkKind { underline, circle, frame }

/// Decoration is painted independently of the text, focus ring and hit target.
class FlyerMark extends StatelessWidget {
  const FlyerMark({
    super.key,
    required this.child,
    this.kind = FlyerMarkKind.underline,
    this.active = true,
  });
  final Widget child;
  final FlyerMarkKind kind;
  final bool active;
  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: active ? FlyerMarkPainter(kind) : null,
    child: Padding(
      padding: kind == FlyerMarkKind.circle
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : kind == FlyerMarkKind.frame
          ? const EdgeInsets.all(16)
          : const EdgeInsets.only(bottom: 7),
      child: child,
    ),
  );
}

class FlyerMarkPainter extends CustomPainter {
  const FlyerMarkPainter(this.kind);
  final FlyerMarkKind kind;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final pen = Paint()
      ..color = FlyerStyle.marker
      ..style = PaintingStyle.stroke
      ..strokeWidth = kind == FlyerMarkKind.underline ? 4.2 : 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width, h = size.height;
    final path = Path();
    switch (kind) {
      case FlyerMarkKind.underline:
        path.moveTo(2, h - 3);
        path.cubicTo(w * .24, h - 7, w * .62, h - 3, w - 2, h - 5);
      case FlyerMarkKind.circle:
        path.moveTo(w * .85, h * .16);
        path.cubicTo(w * .65, -1, w * .22, 0, w * .08, h * .28);
        path.cubicTo(-w * .12, h * .8, w * .36, h * 1.13, w * .72, h * .88);
        path.cubicTo(w * 1.15, h * .66, w * 1.03, h * .07, w * .7, h * .1);
      case FlyerMarkKind.frame:
        path.moveTo(3, 6);
        path.lineTo(w - 4, 2);
        path.lineTo(w - 1, h - 5);
        path.lineTo(2, h - 1);
        path.close();
    }
    canvas.drawPath(path, pen);
  }

  @override
  bool shouldRepaint(FlyerMarkPainter oldDelegate) => oldDelegate.kind != kind;
}

class FlyerTitle extends StatelessWidget {
  const FlyerTitle(
    this.text, {
    super.key,
    this.size,
    this.level = 1,
    this.italic = false,
    this.marked = true,
  });
  final String text;
  final double? size;
  final int? level;
  final bool italic, marked;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final resolvedSize = size ?? AccessTypography.page(c.maxWidth);
      final style = TextStyle(
        fontFamily: 'Archivo',
        fontVariations: const [FontVariation('wdth', 100)],
        fontSize: resolvedSize,
        fontWeight: FontWeight.w600,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        height: 1.06,
        letterSpacing: -.8,
      );
      return Semantics(
        container: level != null,
        headingLevel: level,
        child: FlyerMark(
          active: marked,
          child: Text(
            text,
            textWidthBasis: TextWidthBasis.longestLine,
            style: style,
          ),
        ),
      );
    },
  );
}

class FlyerLanguageButton extends StatelessWidget {
  const FlyerLanguageButton({super.key});
  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.of(context);
    if (language == null) return const SizedBox.shrink();
    final english = language.value;
    return PopupMenuButton<bool>(
      tooltip: localText(context, 'Sprache auswählen', 'Choose language'),
      initialValue: english,
      position: PopupMenuPosition.under,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: FlyerStyle.ink),
      ),
      constraints: const BoxConstraints(minWidth: 160),
      onSelected: (value) => language.value = value,
      itemBuilder: (_) => [
        for (final item in const {false: 'Deutsch', true: 'English'}.entries)
          PopupMenuItem<bool>(
            value: item.key,
            height: 48,
            child: Semantics(
              selected: english == item.key,
              child: Row(
                children: [
                  Icon(
                    Icons.check,
                    size: 18,
                    color: english == item.key
                        ? FlyerStyle.ink
                        : Colors.transparent,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    item.value,
                    style: const TextStyle(color: FlyerStyle.ink),
                  ),
                ],
              ),
            ),
          ),
      ],
      child: Semantics(
        label: english ? 'Language: English' : 'Sprache: Deutsch',
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  english ? 'EN' : 'DE',
                  style: const TextStyle(color: FlyerStyle.ink),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more, size: 16, color: FlyerStyle.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Responsive photographic stage: image first on phones; text-local shadows on desktop.
/// A supplied image has its own alt text. The fallback is explicitly illustrative.
class FlyerScene extends StatelessWidget {
  const FlyerScene({
    super.key,
    required this.child,
    this.information,
    this.topRight,
    this.image,
    this.showImage = true,
    this.minHeight = 550,
    this.padding = 32,
    this.mobileImageHeight = 220,
  });
  final Widget child;
  final Widget? information, image, topRight;
  final bool showImage;
  final double minHeight, padding, mobileImageHeight;
  Widget _picture(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      image ??
          Image.asset(
            FlyerStyle.scene,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            excludeFromSemantics: true,
          ),
      if (image == null)
        Positioned(
          right: 16,
          top: topRight == null ? 16 : 80,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: FlyerStyle.ink,
            child: Text(
              localText(
                context,
                'Synthetisches Kulturmotiv',
                'Synthetic cultural illustration',
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (!showImage) return child;
      final mobile =
          c.maxWidth < 900 || MediaQuery.textScalerOf(context).scale(16) > 20.8;
      final text = DefaultTextStyle.merge(
        style: const TextStyle(
          color: Colors.white,
          shadows: FlyerStyle.textShadows,
          height: 1.55,
        ),
        child: IconTheme(
          data: const IconThemeData(color: FlyerStyle.orange),
          child: child,
        ),
      );
      if (mobile) {
        return ColoredBox(
          color: FlyerStyle.ink,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: mobileImageHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _picture(context),
                    if (topRight != null)
                      Positioned(top: 16, right: padding, child: topRight!),
                  ],
                ),
              ),
              Padding(padding: EdgeInsets.all(padding), child: text),
              if (information != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
                  child: _information(false),
                ),
            ],
          ),
        );
      }
      return Stack(
        children: [
          Positioned.fill(child: _picture(context)),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 5,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: text,
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                  if (information != null)
                    SizedBox(width: 340, child: _information(true)),
                ],
              ),
            ),
          ),
          if (topRight != null)
            Positioned(top: 16, right: padding, child: topRight!),
        ],
      );
    },
  );
  Widget _information(bool desktop) => DefaultTextStyle.merge(
    style: const TextStyle(color: Colors.white, height: 1.5),
    child: IconTheme(
      data: const IconThemeData(color: FlyerStyle.orange),
      child: CustomPaint(
        painter: desktop ? const _FeatherPainter() : null,
        child: FlyerMark(kind: FlyerMarkKind.frame, child: information!),
      ),
    ),
  );
}

class _FeatherPainter extends CustomPainter {
  const _FeatherPainter();
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..color = const Color(0xf0171713)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 18),
    );
    c.drawRect(
      Rect.fromLTWH(8, 8, s.width - 16, s.height - 16),
      Paint()
        ..color = const Color(0xd9171713)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 7),
    );
  }

  @override
  bool shouldRepaint(covariant _FeatherPainter oldDelegate) => false;
}

class FlyerBanner extends StatelessWidget {
  const FlyerBanner({super.key, required this.title, this.description});
  final String title;
  final String? description;
  @override
  Widget build(BuildContext context) => FlyerScene(
    minHeight: 320,
    padding: 24,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FlyerTitle(
          localText(context, title),
          size: AccessTypography.page(MediaQuery.sizeOf(context).width),
        ),
        if (description != null) ...[
          const SizedBox(height: 20),
          Text(localText(context, description!), style: AccessTypography.lead),
        ],
      ],
    ),
  );
}

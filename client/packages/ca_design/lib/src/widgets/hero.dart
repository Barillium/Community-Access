import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import 'basics.dart';
import 'marks.dart';

/// Raster mit Titel, wenn ein Event kein Bild hat. Kein Ersatzfoto.
class CaNoImage extends StatelessWidget {
  const CaNoImage({super.key, this.title = ''});

  /// Leer lassen, wenn der Titel schon darüber steht (Plakat-Hero).
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = CaColors.of(context);
    return ExcludeSemantics(
      child: LayoutBuilder(builder: (context, box) {
        // Längstes Wort muss in eine Zeile passen (Flutter trennt nicht), 0,54 em je Zeichen.
        final longest = title
            .split(' ')
            .fold<int>(1, (m, w) => w.length > m ? w.length : m);
        final size = math
            .min(box.maxWidth / 6, box.maxWidth * .78 / (longest * .54))
            .clamp(10.0, 56.0);
        return CustomPaint(
          painter: _Grid(c.borderHair),
          child: ColoredBox(
            color: c.surfaceSunken.withValues(alpha: .6),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: EdgeInsets.all(size / 2),
                child: Text(title.toUpperCase(),
                    maxLines: 4,
                    overflow: TextOverflow.fade,
                    style:
                        caFont(size: size, height: .9, weight: 800, width: 68)
                            .copyWith(color: c.textPrimary)),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _Grid extends CustomPainter {
  _Grid(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (var x = 0.0; x < size.width; x += 16) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_Grid old) => old.color != color;
}

class PosterSlide {
  const PosterSlide(
      {required this.title, required this.date, this.image, this.imageNote});
  final String title;

  /// Kurz, z. B. „21.11.“. Bekommt den Kreis von Hand.
  final String date;
  final ImageProvider? image;

  /// Hinweis auf dem Bild, im Prototyp „Synthetisches Bild“.
  final String? imageNote;
}

/// Plakat-Hero: Bild randlos, Datum und Titel stehen auf dem Bild.
/// Infos und Knöpfe gehören unter das Plakat, nicht darauf.
class PosterHero extends StatelessWidget {
  const PosterHero({super.key, required this.slide, this.height = 440});
  final PosterSlide slide;
  final double height;

  @override
  Widget build(BuildContext context) {
    final hasImage = slide.image != null;
    // Auf dem Bild weiß, auf dem Raster Tinte.
    final white =
        hasImage ? CaPrimitive.white : CaColors.of(context).textPrimary;
    return SizedBox(
      height: height,
      child: Stack(fit: StackFit.expand, children: [
        if (hasImage)
          Image(
              image: slide.image!,
              fit: BoxFit.cover,
              excludeFromSemantics: true)
        else
          const CaNoImage(),
        if (hasImage)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                // Oben leicht abgedunkelt: Statusleiste, Zurück und Hinweis bleiben auf hellen Bildern lesbar.
                stops: [0, .25, .45, 1],
                colors: [
                  Color(0x730D0E13),
                  Color(0x000D0E13),
                  Color(0x000D0E13),
                  Color(0xDB0D0E13)
                ],
              ),
            ),
          ),
        if (slide.imageNote != null)
          Positioned(
            top: CaSpace.s4,
            left: CaSpace.gutter,
            child: Text(slide.imageNote!,
                style: CaType.meta.copyWith(color: white)),
          ),
        Positioned(
          left: CaSpace.gutter,
          right: CaSpace.gutter,
          bottom: CaSpace.s5,
          // Plakatschrift wächst mit der Systemschrift nur bis 130 %.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DateCircle(
                      child: Text(slide.date,
                          style: CaType.date.copyWith(color: white))),
                  const SizedBox(height: CaSpace.s3),
                  Semantics(
                    header: true,
                    label: '${slide.title}, ${slide.date}',
                    excludeSemantics: true,
                    child: LayoutBuilder(builder: (context, box) {
                      // ponytail: Schätzung statt Messen. Das längste Wort muss in eine Zeile passen,
                      // denn Flutter trennt nicht. 0,54 em je Zeichen bei Archivo schmal, Großbuchstaben.
                      final longest = slide.title
                          .split(' ')
                          .fold<int>(1, (m, w) => w.length > m ? w.length : m);
                      final scale = MediaQuery.textScalerOf(context).scale(1);
                      final size = (box.maxWidth / (longest * .54 * scale))
                          .clamp(32.0, 84.0);
                      return Text(slide.title.toUpperCase(),
                          maxLines: 3,
                          style: CaType.poster
                              .copyWith(color: white, fontSize: size));
                    }),
                  ),
                ]),
          ),
        ),
      ]),
    );
  }
}

/// Plakatreihe: wechselt alle 6 s oder per Wischen. Ein neues Plakat wird über
/// das alte geklebt (Wischen von rechts, 280 ms). Bei reduzierter Bewegung
/// wechselt sie nicht von selbst und blendet nur über.
class PosterCarousel extends StatefulWidget {
  const PosterCarousel(
      {super.key, required this.slides, this.height = 440, this.onIndex});
  final List<PosterSlide> slides;
  final double height;
  final ValueChanged<int>? onIndex;

  @override
  State<PosterCarousel> createState() => _PosterCarouselState();
}

class _PosterCarouselState extends State<PosterCarousel> {
  int _i = 0;
  bool _paused = false;
  Timer? _timer;

  void _go(int i) {
    setState(() => _i = i % widget.slides.length);
    widget.onIndex?.call(_i);
  }

  void _schedule() {
    _timer?.cancel();
    if (_paused ||
        MediaQuery.disableAnimationsOf(context) ||
        widget.slides.length < 2) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _go(_i + 1));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final n = widget.slides.length;
    return Semantics(
      label: 'Ausgewählte Veranstaltungen, ${_i + 1} von $n',
      child: Stack(children: [
        GestureDetector(
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v.abs() < 200) return;
            _go(v < 0 ? _i + 1 : _i - 1 + n);
            _schedule();
          },
          child: AnimatedSwitcher(
            duration: CaDuration.slow,
            switchInCurve: reduced ? Curves.linear : CaEase.standard,
            layoutBuilder: (current, previous) =>
                Stack(children: [...previous, if (current != null) current]),
            transitionBuilder: (child, a) => reduced
                ? FadeTransition(opacity: a, child: child)
                : AnimatedBuilder(
                    animation: a,
                    child: child,
                    builder: (context, child) =>
                        ClipRect(clipper: _FromRight(a.value), child: child),
                  ),
            child: PosterHero(
                key: ValueKey(_i),
                slide: widget.slides[_i],
                height: widget.height),
          ),
        ),
        if (n > 1 && !reduced)
          Positioned(
            top: CaSpace.s1,
            right: CaSpace.s1,
            child: IconButton(
              tooltip: _paused
                  ? 'Automatischen Wechsel starten'
                  : 'Automatischen Wechsel anhalten',
              color: widget.slides[_i].image != null
                  ? CaPrimitive.white
                  : CaColors.of(context).textPrimary,
              icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
              onPressed: () {
                setState(() => _paused = !_paused);
                _schedule();
              },
            ),
          ),
      ]),
    );
  }
}

class _FromRight extends CustomClipper<Rect> {
  _FromRight(this.t);
  final double t;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(size.width * (1 - t), 0, size.width, size.height);

  @override
  bool shouldReclip(_FromRight old) => old.t != t;
}

/// Kurzinfo unter dem Plakat: Veranstalter, Zugang, Schloss, Hauptknopf und Merken.
class PosterInfo extends StatelessWidget {
  const PosterInfo({
    super.key,
    required this.when,
    required this.host,
    required this.access,
    required this.action,
    this.lockText,
    this.save,
  });
  final String when;
  final String host;
  final CaAccess access;
  final String? lockText;
  final CaButton action;
  final CaSaveButton? save;

  @override
  Widget build(BuildContext context) {
    final c = CaColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          CaSpace.gutter, CaSpace.s5, CaSpace.gutter, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(when,
            style: CaType.meta
                .copyWith(fontWeight: FontWeight.w600, color: c.textPrimary)),
        const SizedBox(height: CaSpace.s2),
        Text(host, style: CaType.lead),
        const SizedBox(height: CaSpace.s3),
        Wrap(spacing: CaSpace.s4, runSpacing: CaSpace.s2, children: [
          AccessMark(access),
          if (lockText != null) LockLabel(lockText!),
        ]),
        const SizedBox(height: CaSpace.s5),
        Row(children: [
          Expanded(child: action),
          if (save != null) ...[const SizedBox(width: CaSpace.s2), save!],
        ]),
      ]),
    );
  }
}

import 'package:flutter/material.dart';

import '../haptics.dart';
import '../icons.dart';
import '../theme.dart';
import '../tokens.dart';

enum CaButtonKind {
  /// Orange: Hauptaktion. Höchstens eine je Bildschirm.
  primary,

  /// Tinte: zweite Aktion.
  neutral,

  /// Umriss: ruhige Aktion, auch Zurückziehen.
  outline,
}

/// Knopf mit Text links und Symbol rechts. Gedrückt: Fläche dunkler und 1 px tiefer.
class CaButton extends StatefulWidget {
  const CaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = CaButtonKind.primary,
    this.small = false,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final CaButtonKind kind;
  final bool small;
  final bool loading;
  final bool expand;

  @override
  State<CaButton> createState() => _CaButtonState();
}

class _CaButtonState extends State<CaButton> {
  final _states = WidgetStatesController();

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CaColors.of(context);
    final w = widget;
    final fg = switch (w.kind) {
      CaButtonKind.primary => c.actionOnPrimary,
      CaButtonKind.neutral => c.textInverse,
      CaButtonKind.outline => c.textPrimary,
    };
    final content = w.loading
        ? SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        : Row(
            mainAxisSize: w.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(w.label, overflow: TextOverflow.ellipsis)),
              if (w.icon != null) ...[
                SizedBox(width: w.small ? CaSpace.s4 : CaSpace.s6),
                Icon(w.icon, size: 20)
              ],
            ],
          );
    final style = w.small
        ? ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(
                Size(CaSpace.target, CaSize.buttonHeightSm)),
            padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: CaSpace.s4)),
            textStyle: WidgetStatePropertyAll(
                CaType.meta.copyWith(fontWeight: FontWeight.w600)),
          )
        : null;
    // Beim Laden bleibt der Knopf sichtbar aktiv, nimmt aber keinen zweiten Tipp an.
    final onPressed = w.loading ? () {} : w.onPressed;
    Widget button = switch (w.kind) {
      CaButtonKind.primary => FilledButton(
          onPressed: onPressed,
          style: style,
          statesController: _states,
          child: content),
      CaButtonKind.neutral => ElevatedButton(
          onPressed: onPressed,
          style: style,
          statesController: _states,
          child: content),
      CaButtonKind.outline => OutlinedButton(
          onPressed: onPressed,
          style: style,
          statesController: _states,
          child: content),
    };
    button = ValueListenableBuilder<Set<WidgetState>>(
      valueListenable: _states,
      child: button,
      builder: (context, s, child) => Transform.translate(
          offset: Offset(0, s.contains(WidgetState.pressed) ? 1 : 0),
          child: child),
    );
    if (w.expand) button = SizedBox(width: double.infinity, child: button);
    return Semantics(
        label: w.loading ? '${w.label}, lädt' : null, child: button);
  }
}

/// Symbol mit Veredelung: eine flache Fläche in Signalorange passgenau unter der Tinte,
/// sofern es eine gibt (`CaIcons.accentOf`). Werkzeuge, Hinweis und Hilfe bleiben einfarbig.
/// `plain: true` zeigt nur den Strich, z. B. für inaktive Navigation oder unter 16 px.
class CaIcon extends StatelessWidget {
  const CaIcon(this.icon,
      {super.key, this.size, this.color, this.plain = false});

  final IconData? icon;
  final double? size;
  final Color? color;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final i = icon;
    final accent = plain || i == null ? null : CaIcons.accentOf(i);
    final ink = Icon(icon, size: size, color: color);
    if (accent == null) return ink;
    return Stack(children: [
      Icon(accent, size: size, color: CaColors.of(context).surfaceAccent),
      ink,
    ]);
  }
}

/// Merken. Quadratisch, so hoch wie der Hauptknopf daneben.
class CaSaveButton extends StatelessWidget {
  const CaSaveButton({
    super.key,
    required this.saved,
    required this.onChanged,
    required this.eventTitle,
    this.icon = CaIcons.bookmark,
    this.savedIcon = CaIcons.bookmark,
    this.size = CaSize.buttonHeight,
  });

  final bool saved;
  final ValueChanged<bool> onChanged;
  final String eventTitle;
  final IconData icon;
  final IconData savedIcon;

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = CaColors.of(context);
    return IconButton(
      isSelected: saved,
      // Gemerkt zeigt nur die Tinte (dunkler Knopf); das orange Band bleibt in beiden Zuständen.
      icon: CaIcon(icon),
      selectedIcon: CaIcon(savedIcon),
      tooltip: saved ? '$eventTitle gemerkt' : '$eventTitle merken',
      onPressed: () {
        CaHaptics.save();
        onChanged(!saved);
      },
      style: IconButton.styleFrom(
        fixedSize: Size.square(size),
        shape: const RoundedRectangleBorder(),
        side: BorderSide(color: saved ? c.borderRule : c.borderControl),
        backgroundColor: saved ? c.surfaceInverse : c.surfacePage,
        foregroundColor: saved ? c.textInverse : c.textPrimary,
      ),
    );
  }
}

/// Wie man zu einem Event kommt. Private Events erscheinen nie auf öffentlichen Seiten.
enum CaAccess {
  public('Öffentlich'),
  semi('Semi-öffentlich'),
  private('Privat');

  const CaAccess(this.label);
  final String label;
}

/// Zugangszeichen: Kreis leer, halb, voll, immer mit Text daneben.
class AccessMark extends StatelessWidget {
  const AccessMark(this.access, {super.key, this.large = false, this.color});
  final CaAccess access;
  final bool large;

  /// Nur für Text auf Bildern (weiß). Sonst Tinte aus dem Theme.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? CaColors.of(context).textPrimary;
    final d = large ? CaSize.accessMarkSizeLg : CaSize.accessMarkSize;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
            child: CustomPaint(
                size: Size.square(d), painter: _AccessPainter(access, ink))),
        const SizedBox(width: 9),
        Text(access.label,
            style: (large ? CaType.body : CaType.meta)
                .copyWith(color: ink, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _AccessPainter extends CustomPainter {
  _AccessPainter(this.access, this.color);
  final CaAccess access;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    final fill = Paint()..color = color;
    switch (access) {
      case CaAccess.private:
        canvas.drawCircle(c, r, fill);
      case CaAccess.semi:
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(0, 0, size.width / 2, size.height));
        canvas.drawCircle(c, r, fill);
        canvas.restore();
      case CaAccess.public:
        break;
    }
    canvas.drawCircle(
      c,
      r - CaLine.firm / 2,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = CaLine.firm,
    );
  }

  @override
  bool shouldRepaint(_AccessPainter old) =>
      old.access != access || old.color != color;
}

/// Schloss mit kurzem Text, z. B. „Ort nach Zusage“.
class LockLabel extends StatelessWidget {
  const LockLabel(this.text, {super.key, this.icon = CaIcons.lock, this.color});
  final String text;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? CaColors.of(context).textSecondary;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      CaIcon(icon, size: 16, color: ink),
      const SizedBox(width: CaSpace.s2),
      Text(text, style: CaType.meta.copyWith(color: ink)),
    ]);
  }
}

/// Blindprägung: gesperrte Angabe als eingedrückte Fläche fester Breite.
/// Nimmt absichtlich keinen Inhalt an, damit keine Adresse durchscheinen kann,
/// auch nicht unscharf.
class EmbossedLock extends StatelessWidget {
  const EmbossedLock(
      {super.key,
      required this.label,
      this.fill = false,
      this.icon = CaIcons.lock});

  /// Was gesperrt ist, z. B. „Genauer Ort“. Nie der Inhalt selbst.
  final String label;
  final bool fill;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = CaColors.of(context);
    return Semantics(
      label: '$label, gesperrt',
      excludeSemantics: true,
      child: Container(
        width: fill ? double.infinity : CaSize.embossWidth,
        height: CaSize.embossHeight,
        padding: const EdgeInsets.symmetric(horizontal: CaSpace.s3),
        decoration: BoxDecoration(
          color: c.embossFill,
          // Eingedrückt: dunkle Kante oben, helle unten.
          border: Border(
            top: BorderSide(color: c.borderControl.withValues(alpha: .45)),
            bottom: BorderSide(color: c.surfacePage),
          ),
        ),
        child: Row(children: [
          CaIcon(icon, size: 16, color: c.textSecondary),
          const SizedBox(width: CaSpace.s2),
          Text(label,
              style: CaType.meta.copyWith(
                  color: c.textSecondary, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

/// Stempel für menschliche Entscheidungen: „Zugesagt“ schief in Orange, „Abgesagt“ ruhig.
class Stamp extends StatelessWidget {
  const Stamp(
      {super.key,
      required this.label,
      this.yes = true,
      this.icon,
      this.animate = false});
  final String label;
  final bool yes;
  final IconData? icon;

  /// Nur wenn die Entscheidung gerade eintrifft: kurz aufsetzen, 280 ms.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final c = CaColors.of(context);
    final ink = yes ? c.stampColor : c.textSecondary;
    final stamp = Transform.rotate(
      angle: yes ? CaTilt.stamp : 2 * 3.141592653589793 / 180,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(border: Border.all(color: ink, width: 2)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: CaSpace.s3),
          decoration: BoxDecoration(border: Border.all(color: ink)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              CaIcon(icon, size: 16, color: ink),
              const SizedBox(width: CaSpace.s2)
            ],
            Text(label.toUpperCase(),
                style: caFont(
                        size: 13,
                        height: 1,
                        weight: 800,
                        width: 68,
                        letterSpacing: .78)
                    .copyWith(color: ink)),
          ]),
        ),
      ),
    );
    if (!animate) return stamp;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: CaDuration.slow,
      curve: reduced ? Curves.linear : CaEase.spring,
      child: stamp,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        // Setzt von oben auf: startet bei 115 %, nie unter 90 %.
        child: reduced
            ? child
            : Transform.scale(scale: 1.15 - .15 * t, child: child),
      ),
    );
  }
}

enum DoorState {
  done('erledigt'),
  now('jetzt'),
  next('offen');

  const DoorState(this.spoken);
  final String spoken;
}

class DoorStep {
  const DoorStep(this.title, {this.detail, this.state = DoorState.next});
  final String title;
  final String? detail;
  final DoorState state;
}

/// Türliste „dein Stand“: wo ein Gast auf dem Weg hinein gerade steht.
class DoorList extends StatelessWidget {
  const DoorList(
      {super.key,
      required this.steps,
      this.doneIcon = CaIcons.check,
      this.nowIcon = CaIcons.clock});
  final List<DoorStep> steps;
  final IconData doneIcon;
  final IconData nowIcon;

  @override
  Widget build(BuildContext context) {
    final c = CaColors.of(context);
    return Column(children: [
      for (final (i, s) in steps.indexed)
        MergeSemantics(
          child: Semantics(
            value: s.state.spoken,
            child: Container(
              padding: EdgeInsets.only(
                  top: i == 0 ? 0 : CaSpace.s3, bottom: CaSpace.s3),
              decoration: BoxDecoration(
                  border: i == 0
                      ? null
                      : Border(top: BorderSide(color: c.borderHair))),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: CaSize.doorBox,
                  height: CaSize.doorBox,
                  decoration: BoxDecoration(
                    color: s.state == DoorState.done ? c.surfaceAccent : null,
                    border: Border.all(
                      color: switch (s.state) {
                        DoorState.done => c.surfaceAccent,
                        DoorState.now => c.doorCurrent,
                        DoorState.next => c.borderControl,
                      },
                      width: CaLine.firm,
                    ),
                  ),
                  child: switch (s.state) {
                    DoorState.done =>
                      Icon(doneIcon, size: 16, color: c.textOnAccent),
                    DoorState.now =>
                      Icon(nowIcon, size: 16, color: c.doorCurrent),
                    DoorState.next => null,
                  },
                ),
                const SizedBox(width: CaSpace.s4),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title,
                            style: CaType.body.copyWith(
                                fontWeight: FontWeight.w600, height: 1.3)),
                        if (s.detail != null)
                          Text(s.detail!,
                              style: CaType.fine.copyWith(
                                  color: s.state == DoorState.now
                                      ? c.textDecision
                                      : c.textSecondary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ])),
                      ]),
                ),
              ]),
            ),
          ),
        ),
    ]);
  }
}

/// Logo „Community Access“ mit „ACCESS“ auf dem orangen Streifen (Variante c4, gewählt
/// am 05.10.2026). Hell: Tinte, dunkel: „COMMUNITY“ hell. Als Bild in 1x, 2x, 3x.
class CaLogo extends StatelessWidget {
  const CaLogo({super.key, this.height = 32});
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      'assets/logo/${dark ? 'dunkel' : 'hell'}.png',
      package: 'ca_design',
      height: height,
      semanticLabel: 'Community Access',
      filterQuality: FilterQuality.medium,
    );
  }
}

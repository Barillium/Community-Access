import 'package:flutter/material.dart';

import '../icons.dart';
import '../theme.dart';
import '../tokens.dart';
import 'basics.dart';
import 'marks.dart';
import 'platform.dart';

/// Leer: ein Satz, ein Weg weiter.
class CaEmpty extends StatelessWidget {
  const CaEmpty(
      {super.key,
      required this.icon,
      required this.title,
      this.text,
      this.action});
  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = CaColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CaSpace.s7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DateCircle(child: Icon(icon, size: 28, color: c.textPrimary)),
        const SizedBox(height: CaSpace.s4),
        Text(title, style: CaType.head),
        if (text != null) ...[
          const SizedBox(height: CaSpace.s1),
          Text(text!, style: CaType.body.copyWith(color: c.textSecondary)),
        ],
        if (action != null) ...[const SizedBox(height: CaSpace.s4), action!],
      ]),
    );
  }
}

/// Platzhalter beim Laden: Form wie der Inhalt. Erscheint erst nach 300 ms und
/// atmet ruhig; bei reduzierter Bewegung steht er still.
class CaSkeleton extends StatefulWidget {
  const CaSkeleton({super.key, this.width, required this.height});
  final double? width;
  final double height;

  @override
  State<CaSkeleton> createState() => _CaSkeletonState();
}

class _CaSkeletonState extends State<CaSkeleton>
    with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _visible = true);
      if (!MediaQuery.disableAnimationsOf(context)) {
        _breath.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = SizedBox(
      width: widget.width,
      height: widget.height,
      child: ColoredBox(color: CaColors.of(context).surfacePressed),
    );
    if (!_visible) return SizedBox(width: widget.width, height: widget.height);
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: .55)
          .animate(CurvedAnimation(parent: _breath, curve: CaEase.inOut)),
      child: box,
    );
  }
}

enum CaNoteKind { info, decision, error }

/// Hinweis mit Kante links. Entscheidung: orange Kante. Fehler: Tinte mit Symbol, nie Rot.
class CaNote extends StatelessWidget {
  const CaNote(
      {super.key,
      required this.icon,
      required this.title,
      this.text,
      this.action,
      this.kind = CaNoteKind.info});
  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;
  final CaNoteKind kind;

  @override
  Widget build(BuildContext context) {
    final c = CaColors.of(context);
    final decision = kind == CaNoteKind.decision;
    return Semantics(
      liveRegion: kind == CaNoteKind.error,
      child: Container(
        padding: const EdgeInsets.all(CaSpace.s4),
        decoration: BoxDecoration(
          color: decision ? c.surfaceDecision : c.surfaceSunken,
          border: Border(
              left: BorderSide(
                  color: decision ? c.surfaceAccent : c.borderRule,
                  width: CaLine.mark)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CaIcon(icon,
              size: 22, color: decision ? c.textDecision : c.textPrimary),
          const SizedBox(width: CaSpace.s3),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: CaType.body
                      .copyWith(fontWeight: FontWeight.w600, height: 1.35)),
              if (text != null)
                Text(text!,
                    style: CaType.meta.copyWith(color: c.textSecondary)),
              if (action != null) ...[
                const SizedBox(height: CaSpace.s4),
                action!
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Offline-Zeile oben im Inhalt: sagt, welcher Stand zu sehen ist.
class CaOfflineBar extends StatelessWidget {
  const CaOfflineBar(
      {super.key, required this.text, this.icon = CaIcons.wifiOff});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = CaColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: c.surfaceInverse,
        padding: const EdgeInsets.symmetric(
            horizontal: CaSpace.gutter, vertical: CaSpace.s3),
        child: Row(children: [
          CaIcon(icon, size: 18, color: c.textInverse),
          const SizedBox(width: CaSpace.s3),
          Expanded(
              child: Text(text,
                  style: CaType.meta.copyWith(color: c.textInverse))),
        ]),
      ),
    );
  }
}

/// Kurze Rückmeldung unten mit „Rückgängig“, wie unter Android üblich.
/// iOS kennt keine solchen Hinweise: Dort reicht die Änderung am Knopf selbst
/// und ein spürbarer Impuls. Nur wichtige Nachrichten mit [alsoOnIOS] zeigen.
void showCaToast(BuildContext context, String message,
    {String? actionLabel, VoidCallback? onAction, bool alsoOnIOS = false}) {
  if (caIsCupertino(context) && !alsoOnIOS) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 4),
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ));
}

import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import 'basics.dart';
import 'hero.dart';

/// Eine Zeile im Programm, in „Für dich“ und in der Merkliste.
/// Gesperrte Orte zeigen nur das Schloss, nie eine Adresse.
class EventRow extends StatelessWidget {
  const EventRow({
    super.key,
    required this.title,
    required this.when,
    required this.access,
    this.image,
    this.place,
    this.placeLocked = false,
    this.reason,
    this.saved,
    this.onSaved,
    this.onTap,
  });

  final String title;

  /// Z. B. „Sa 14.11. · 19:00“.
  final String when;
  final CaAccess access;
  final ImageProvider? image;

  /// Nur öffentliche Orte. Bei [placeLocked] wird [place] ignoriert.
  final String? place;
  final bool placeLocked;

  /// Warum das Event in „Für dich“ steht, z. B. „Du folgst Morgenraum“.
  final String? reason;
  final bool? saved;
  final ValueChanged<bool>? onSaved;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = CaColors.of(context);
    return Container(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.borderHair))),
      padding: const EdgeInsets.symmetric(vertical: CaSpace.s4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox.square(
                dimension: 88,
                child: image != null
                    ? Image(
                        image: image!,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true)
                    : CaNoImage(title: title),
              ),
              const SizedBox(width: CaSpace.s4),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(when,
                          style: CaType.meta.copyWith(
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ])),
                      const SizedBox(height: CaSpace.s1),
                      Text(title.toUpperCase(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: CaType.title),
                      const SizedBox(height: CaSpace.s2),
                      Wrap(
                          spacing: CaSpace.s4,
                          runSpacing: CaSpace.s1,
                          children: [
                            AccessMark(access),
                            if (placeLocked)
                              const LockLabel('Ort nach Zusage')
                            else if (place != null)
                              Text(place!,
                                  style: CaType.meta
                                      .copyWith(color: c.textSecondary)),
                          ]),
                      if (reason != null) ...[
                        const SizedBox(height: CaSpace.s1),
                        Text(reason!,
                            style:
                                CaType.fine.copyWith(color: c.textSecondary)),
                      ],
                    ]),
              ),
            ]),
          ),
        ),
        if (saved != null && onSaved != null) ...[
          const SizedBox(width: CaSpace.s3),
          CaSaveButton(
              saved: saved!,
              onChanged: onSaved!,
              eventTitle: title,
              size: CaSpace.target),
        ],
      ]),
    );
  }
}

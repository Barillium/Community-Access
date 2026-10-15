import 'package:flutter/material.dart';

import 'design_system.dart';

const accessFeatureLabels = {
  'step_free': 'Stufenloser Zugang',
  'accessible_toilet': 'Barrierearmes WC',
  'seating': 'Sitzmöglichkeiten',
  'quiet_space': 'Rückzugsraum',
};
const accessNoteLabels = {
  'access_notes': 'Hinweise zur Zugänglichkeit',
  'awareness_notes': 'Awareness vor Ort',
  'awareness_contact': 'Freigegebener Awarenesskontakt',
};

class EventAccessDetails extends StatelessWidget {
  final Map<String, dynamic> details;
  const EventAccessDetails({super.key, required this.details});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: AccessSpacing.s24),
      const AccessHeading(
        'Zugänglichkeit und Awareness',
        role: AccessHeadingRole.section,
        level: 2,
      ),
      const SizedBox(height: AccessSpacing.s12),
      const Text(
        'Angaben des Veranstalters. Unbekannt bedeutet: keine Angabe.',
      ),
      for (final entry in accessFeatureLabels.entries)
        Padding(
          padding: const EdgeInsets.only(top: AccessSpacing.s12),
          child: Text(
            '${entry.value}: ${switch (details[entry.key]) {
              'yes' => 'Ja',
              'no' => 'Nein',
              _ => 'Unbekannt',
            }}',
          ),
        ),
      for (final entry in accessNoteLabels.entries)
        if ((details[entry.key] as String? ?? '').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AccessSpacing.s16),
            child: Text('${entry.value}\n${details[entry.key]}'),
          ),
    ],
  );
}

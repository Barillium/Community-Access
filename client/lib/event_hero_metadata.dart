import 'package:flutter/material.dart';

import 'app_language.dart';
import 'design_system.dart';

String eventHeroPrice(BuildContext context, Map<String, dynamic> event) {
  final cents = event['ticket_price_cents'];
  if (cents is int && cents >= 0 && event['ticket_mode'] != 'none') {
    final amount = (cents / 100).toStringAsFixed(2);
    return localText(context, '${amount.replaceAll('.', ',')} €', '€$amount');
  }
  // External catalogue prices preserve their published qualifiers and fees.
  if (event['external'] == true && event['event_content'] is Map) {
    final content = event['event_content'] as Map;
    final de = content['ticket_price_label_de'];
    final en = content['ticket_price_label_en'];
    if (de is String && de.trim().isNotEmpty) {
      return localText(
        context,
        de.trim(),
        en is String ? en.trim() : de.trim(),
      );
    }
  }
  return localText(context, 'Noch nicht angegeben', 'Not specified yet');
}

List<String> eventHeroCommunities(Map<String, dynamic> event) {
  final communities = event['communities'];
  if (communities is List) {
    final seen = <String>{};
    return [
      for (final community in communities)
        if (community is Map &&
            community['id'] is String &&
            (community['id'] as String).isNotEmpty &&
            community['name'] is String &&
            (community['name'] as String).trim().isNotEmpty &&
            seen.add(community['id'] as String))
          (community['name'] as String).trim(),
    ];
  }
  // Older registered-event responses contain one already masked community.
  // Editorial tags on external entries are not registered assignments.
  final legacy = event['community'];
  return event['external'] != true &&
          legacy is String &&
          legacy.trim().isNotEmpty
      ? [legacy.trim()]
      : [];
}

class EventHeroMetadata extends StatelessWidget {
  const EventHeroMetadata({super.key, required this.event});
  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final communities = eventHeroCommunities(event);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _fact(
          context,
          Icons.confirmation_number_outlined,
          localText(context, 'Ticketpreis', 'Ticket price'),
          eventHeroPrice(context, event),
        ),
        const SizedBox(height: 20),
        _fact(
          context,
          Icons.groups_outlined,
          localText(context, 'Communities', 'Communities'),
          communities.isEmpty
              ? localText(
                  context,
                  'Keine Community angegeben',
                  'No community specified',
                )
              : communities.join(' · '),
        ),
      ],
    );
  }

  Widget _fact(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          AccessIcon(icon, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: AccessTypography.labelSize),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(value),
    ],
  );
}

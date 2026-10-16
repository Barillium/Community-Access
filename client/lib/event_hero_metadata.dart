import 'package:flutter/material.dart';

import 'app_language.dart';
import 'design_system.dart';
import 'flyer_design.dart';

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

List<Map<String, String>> eventHeroAssignments(Map<String, dynamic> event) {
  final communities = event['communities'];
  final seen = <String>{};
  if (communities is! List) return [];
  return [
    for (final community in communities)
      if (community is Map &&
          community['id'] is String &&
          (community['id'] as String).isNotEmpty &&
          community['name'] is String &&
          (community['name'] as String).trim().isNotEmpty &&
          seen.add(community['id'] as String))
        {
          'id': community['id'] as String,
          'name': (community['name'] as String).trim(),
        },
  ];
}

List<String> eventHeroCommunities(Map<String, dynamic> event) {
  if (event['communities'] is List) {
    return eventHeroAssignments(event).map((c) => c['name']!).toList();
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
  const EventHeroMetadata({super.key, required this.event, this.onCommunity});
  final Map<String, dynamic> event;
  final ValueChanged<String>? onCommunity;

  @override
  Widget build(BuildContext context) {
    final communities = eventHeroCommunities(event);
    final assignments = eventHeroAssignments(event);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _fact(
          context,
          Icons.confirmation_number_outlined,
          localText(context, 'Ticketpreis', 'Ticket price'),
          Text(eventHeroPrice(context, event)),
        ),
        const SizedBox(height: 20),
        _fact(
          context,
          Icons.groups_outlined,
          localText(context, 'Communities', 'Communities'),
          assignments.isNotEmpty && onCommunity != null
              ? LayoutBuilder(
                  builder: (context, c) => Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (final item in assignments)
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: c.maxWidth),
                          child: FlyerMark(
                            child: TextButton(
                              key: ValueKey('community-link:${item['id']}'),
                              onPressed: () => onCommunity!(item['id']!),
                              style: TextButton.styleFrom(
                                foregroundColor: DefaultTextStyle.of(context)
                                    .style
                                    .color,
                                minimumSize: const Size(48, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                              child: Text(item['name']!),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : Text(
                  communities.isEmpty
                      ? localText(
                          context,
                          'Keine Community angegeben',
                          'No community specified',
                        )
                      : communities.join(' · '),
                ),
        ),
      ],
    );
  }

  Widget _fact(
    BuildContext context,
    IconData icon,
    String label,
    Widget value,
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
      value,
    ],
  );
}

/// Public visibility is read from the event payload, never from the current role.
bool isPublicEvent(Map<String, dynamic> event) {
  final mode = event['access_mode'];
  if (mode == 'public') return true;
  if (mode == null || mode == 'legacy') return event['is_public'] == true;
  return false;
}

/// Keep explicit ticket flows and unknown ticket configurations intact.
/// External catalogue entries have no Community Access participation workflow.
bool needsParticipationPanel(Map<String, dynamic> event) {
  if (!isPublicEvent(event)) return true;
  if (event['external'] == true) return false;
  return event['ticket_mode'] != 'none';
}

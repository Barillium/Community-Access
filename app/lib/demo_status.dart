/// Presentation fixtures only: not an authorization or transition model.
enum DemoStatus {
  applicationPending(
    'Bewerbung offen',
    'Die Gastgeber prüfen deine Bewerbung.',
  ),
  member(
    'Aufgenommen',
    'Du bist Mitglied. Eine Eventteilnahme ist noch nicht bestätigt.',
  ),
  eventRequested(
    'Event angefragt',
    'Die Veranstalter entscheiden über deine Eventanfrage.',
  ),
  eventConfirmed(
    'Event bestätigt',
    'Die Veranstalter haben deine Eventanfrage bestätigt.',
  );

  const DemoStatus(this.label, this.description);
  final String label;
  final String description;

  bool get hasEventConfirmation => this == eventConfirmed;
}

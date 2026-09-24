/// Vereinfachte Lernzustaende, kein vollstaendiges Produktmodell.
enum ApplicationStatus { pending, approved, rejected }

/// Prueft nur eine Lernregel; ersetzt keine serverseitige Autorisierung.
bool canTransition(ApplicationStatus from, ApplicationStatus to) {
  final isInitialDecision =
      from == ApplicationStatus.pending &&
      (to == ApplicationStatus.approved || to == ApplicationStatus.rejected);
  final isReopening =
      from == ApplicationStatus.approved && to == ApplicationStatus.pending;

  return isInitialDecision || isReopening;
}

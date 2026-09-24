/// Vereinfachte Lernzustaende, kein vollstaendiges Produktmodell.
enum ApplicationStatus { pending, approved, rejected }

/// Prueft nur eine Lernregel; ersetzt keine serverseitige Autorisierung.
bool canTransition(ApplicationStatus from, ApplicationStatus to) {
  return from == ApplicationStatus.pending &&
      (to == ApplicationStatus.approved || to == ApplicationStatus.rejected);
}

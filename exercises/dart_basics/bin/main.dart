import '../lib/application_status.dart';

void main() {
  final currentStatus = ApplicationStatus.pending;
  final requestedStatus = ApplicationStatus.approved;
  final allowed = canTransition(currentStatus, requestedStatus);

  print('Synthetische Lernuebung:');
  print('${currentStatus.name} -> ${requestedStatus.name}: $allowed');
}

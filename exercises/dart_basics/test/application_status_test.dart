import 'dart:io';

import '../lib/application_status.dart';

// Kleine ausfuehrbare Pruefung ohne zusaetzliches Testpaket.
// Keine assert-Anweisungen: Fehler muessen auch ohne --enable-asserts auffallen.
void main() {
  var failures = 0;
  var checks = 0;

  void check(ApplicationStatus from, ApplicationStatus to, bool expected) {
    checks++;
    final actual = canTransition(from, to);
    if (actual != expected) {
      failures++;
      stderr.writeln(
        'FEHLER: ${from.name} -> ${to.name}: '
        'erwartet $expected, erhalten $actual',
      );
    } else {
      print('OK: ${from.name} -> ${to.name}: $actual');
    }
  }

  check(ApplicationStatus.pending, ApplicationStatus.approved, true);
  check(ApplicationStatus.pending, ApplicationStatus.rejected, true);
  check(ApplicationStatus.pending, ApplicationStatus.pending, false);
  check(ApplicationStatus.approved, ApplicationStatus.pending, false);
  check(ApplicationStatus.rejected, ApplicationStatus.approved, false);
  check(ApplicationStatus.approved, ApplicationStatus.rejected, false);
  check(ApplicationStatus.approved, ApplicationStatus.approved, false);
  check(ApplicationStatus.rejected, ApplicationStatus.pending, false);
  check(ApplicationStatus.rejected, ApplicationStatus.rejected, false);

  print('$checks Pruefungen, $failures Fehler.');
  exitCode = failures == 0 ? 0 : 1;
}

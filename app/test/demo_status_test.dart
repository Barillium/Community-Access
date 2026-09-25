import 'package:flutter_test/flutter_test.dart';
import 'package:community_access/demo_status.dart';

void main() {
  test('Application, membership and request never imply confirmation', () {
    for (final status in [
      DemoStatus.applicationPending,
      DemoStatus.member,
      DemoStatus.eventRequested,
    ]) {
      expect(status.hasEventConfirmation, isFalse, reason: status.name);
    }
    expect(DemoStatus.eventConfirmed.hasEventConfirmation, isTrue);
  });
}

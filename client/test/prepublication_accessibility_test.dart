import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:community_access_client/main.dart';
import 'package:community_access_client/account_registration_page.dart';

import 'auth_account_widget_test.dart' show AuthAccountApi;

void main() {
  testWidgets('registration exposes a level-one heading', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(home: AccountRegistrationPage(api: AuthAccountApi())),
      );
      expect(
        tester
            .getSemantics(find.text('Testkonto anlegen.'))
            .getSemanticsData()
            .headingLevel,
        1,
      );
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('public landmarks preserve navigable heading semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        CommunityAccessApp(
          api: AuthAccountApi(),
          authOnly: true,
          showPublicHome: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.text('Events & Communities.'))
            .getSemanticsData()
            .headingLevel,
        1,
      );
      expect(
        tester
            .getSemantics(find.text('Öffentlich geteilt'))
            .getSemanticsData()
            .headingLevel,
        2,
      );
    } finally {
      semantics.dispose();
    }
  });
}

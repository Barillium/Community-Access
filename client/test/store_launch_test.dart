import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/account_deletion_api.dart';
import 'package:community_access_client/account_deletion_page.dart';
import 'package:community_access_client/event_flyer_picker_native.dart';
import 'package:community_access_client/mobile_platform.dart';
import 'package:community_access_client/mobile_links.dart';
import 'package:community_access_client/store_release.dart';

class DeletionFake implements AccountDeletionApi {
  int requests = 0;
  @override
  Future<Map<String, dynamic>> accountDeletionStatus() async => {
    'request': null,
  };
  @override
  Future<Map<String, dynamic>> requestAccountDeletion({
    String? password,
  }) async {
    requests++;
    return {
      'account_deleted': false,
      'request': {'id': 'synthetic-request', 'status': 'requested'},
    };
  }
}

void main() {
  test('store configuration blocks synthetic/local endpoints and missing age decisions', () {
    expect(
      storeConfigurationErrors(
        realAccounts: false,
        apiOrigin: 'http://127.0.0.1:8000',
        uiOrigin: 'http://127.0.0.1:8300',
        minimumAge: 0,
      ),
      hasLength(3),
    );
    expect(
      storeConfigurationErrors(
        realAccounts: true,
        apiOrigin: 'https://communityaccess.de',
        uiOrigin: 'https://communityaccess.de',
        minimumAge: 16,
      ),
      isEmpty,
    );
    for (final url in [
      'https://localhost',
      'https://127.0.0.1',
      'https://example.invalid',
      'https://user@communityaccess.de',
    ]) {
      expect(
        storeConfigurationErrors(
          realAccounts: true,
          apiOrigin: url,
          uiOrigin: url,
          minimumAge: 16,
        ),
        isNotEmpty,
      );
    }
  });
  test('external links reject executable schemes and embedded credentials', () {
    for (final url in [
      'javascript:alert(1)',
      'file:///private/file',
      'https://user:pass@example.invalid',
      'mailto:a@example.invalid?body=private',
      'https://example.invalid:8443',
    ]) {
      expect(allowedExternalUri(Uri.parse(url)), isFalse);
    }
    expect(allowedExternalUri(Uri.parse('https://communityaccess.de')), isTrue);
    expect(
      allowedExternalUri(Uri.parse('mailto:info@communityaccess.de')),
      isTrue,
    );
  });
  test(
    'app links accept only the configured root with no query or foreign origin',
    () {
      expect(
        trustedMobileLink(
          Uri.parse(
            'http://127.0.0.1:8300/#event=00000000-0000-4000-8000-000000000001',
          ),
        ),
        isTrue,
      );
      for (final url in [
        'https://evil.invalid/#reset=x',
        'http://127.0.0.1:8300/other#reset=x',
        'http://127.0.0.1:8300/?secret=x',
      ]) {
        expect(trustedMobileLink(Uri.parse(url)), isFalse);
      }
    },
  );
  testWidgets(
    'mobile flyer is re-encoded as bounded PNG; other input is refused',
    (tester) async {
      await tester.runAsync(() async {
        await expectLater(
          sanitizeMobileFlyer(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<ApiFailure>()),
        );
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(Colors.red, BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(32, 48);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final sanitized = await sanitizeMobileFlyer(
          bytes!.buffer.asUint8List(),
        );
        expect(sanitized, startsWith('data:image/png;base64,'));
        expect(
          base64Decode(sanitized.split(',').last).length,
          lessThanOrEqualTo(256 * 1024),
        );
        image.dispose();
        picture.dispose();
      });
    },
  );
  testWidgets(
    'deletion requires confirmation and reports a saved request without claiming erasure',
    (tester) async {
      final api = DeletionFake();
      await tester.pumpWidget(MaterialApp(home: AccountDeletionPage(api: api)));
      await tester.pumpAndSettle();
      expect(api.requests, 0);
      final checkbox = find.byType(CheckboxListTile);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pump();
      final submit = find.text('Löschanfrage senden');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(api.requests, 1);
      expect(
        find.text(
          'Deine Löschanfrage ist gespeichert. Dein Konto ist noch nicht gelöscht.',
        ),
        findsOneWidget,
      );
      expect(find.text('Löschanfrage senden'), findsNothing);
    },
  );
}

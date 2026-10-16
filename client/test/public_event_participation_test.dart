import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/event_participation.dart';
import 'package:community_access_client/flyer_design.dart';
import 'package:community_access_client/event_interest_panel.dart';
import 'package:community_access_client/program_views.dart';

import 'directory_widget_test.dart' show DirectoryFixture;
import 'event_editorial_test.dart' show demoFlyer;

class AttendanceFixture extends DirectoryFixture {
  AttendanceFixture(this.eventData);
  final Map<String, dynamic> eventData;
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    calls.add(path);
    if (body != null) bodies.add(body);
    if (path.endsWith('/access')) {
      return {
        'signed_in': false,
        'ticket_mode': eventData['ticket_mode'] ?? 'none',
        'form': [],
      };
    }
    return {
      'id': 'synthetic-event',
      'title': 'Demo öffentlicher Termin',
      'status': 'published',
      'organizer': 'Demo Veranstalter',
      'location': 'Demo Halle',
      'event_content': {'admission': 'Eintrittsbedingungen des Veranstalters.'},
      ...eventData,
    };
  }
}

void main() {
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets('event hero reaches header and both edges at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AccessDesign.theme(),
          home: ProgramDetailPage(
            api: AttendanceFixture({
              'access_mode': 'public',
              'ticket_mode': 'none',
              'event_content': {
                'flyer_data': demoFlyer,
                'flyer_aspect_ratio': 16 / 9,
                'admission': 'Eintrittsbedingungen des Veranstalters.',
              },
            }),
            kind: 'events',
            id: 'synthetic-event',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final hero = tester.getRect(find.byType(FlyerScene));
      final header = tester.getRect(find.byType(AccessHeader));
      expect(hero.left, 0);
      expect(hero.right, width);
      expect(hero.top, header.bottom);
      final details = tester.getRect(
        find.text('Eintrittsbedingungen des Veranstalters.'),
      );
      expect(details.left, greaterThan(0));
      expect(details.right, lessThan(width));
      expect(tester.takeException(), isNull);
    });
  }
  test('public detection does not infer admission from the role or contradictory flags', () {
    expect(
      isPublicEvent({'access_mode': 'private', 'is_public': true}),
      isFalse,
    );
    expect(
      isPublicEvent({'access_mode': 'semi_public', 'is_public': true}),
      isFalse,
    );
    expect(isPublicEvent({'access_mode': 'legacy', 'is_public': true}), isTrue);
    expect(isPublicEvent({}), isFalse);
    expect(needsParticipationPanel({'access_mode': 'public'}), isTrue);
    expect(
      needsParticipationPanel({
        'access_mode': 'public',
        'ticket_mode': 'approval',
      }),
      isTrue,
    );
    expect(
      needsParticipationPanel({
        'access_mode': 'public',
        'ticket_mode': 'public',
      }),
      isTrue,
    );
  });
  for (final sample in <(String, Map<String, dynamic>, bool)>[
    ('external public', {'access_mode': 'public', 'external': true}, false),
    (
      'public without platform ticket',
      {'access_mode': 'public', 'ticket_mode': 'none'},
      false,
    ),
    (
      'legacy public without platform ticket',
      {'access_mode': 'legacy', 'is_public': true, 'ticket_mode': 'none'},
      false,
    ),
    ('private', {'access_mode': 'private', 'ticket_mode': 'none'}, true),
    (
      'public ticket sale',
      {'access_mode': 'public', 'ticket_mode': 'public'},
      true,
    ),
    (
      'explicit ticket approval',
      {'access_mode': 'public', 'ticket_mode': 'approval'},
      true,
    ),
    ('unknown ticket configuration', {'access_mode': 'public'}, true),
  ]) {
    testWidgets(
      '${sample.$1}: admission presentation preserves the configured flow',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = AttendanceFixture(sample.$2);
        await tester.pumpWidget(
          MaterialApp(
            theme: AccessDesign.theme(),
            home: ProgramDetailPage(
              api: api,
              kind: 'events',
              id: 'synthetic-event',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(EventInterestPanel),
          sample.$3 ? findsOneWidget : findsNothing,
        );
        expect(
          api.calls.where((call) => call.endsWith('/access')),
          hasLength(sample.$3 ? 1 : 0),
        );
        expect(
          find.text('Eintrittsbedingungen des Veranstalters.'),
          findsOneWidget,
        );
        if (!sample.$3) {
          expect(find.text('Dein Stand'), findsNothing);
          expect(find.text('Erneut versuchen'), findsNothing);
          expect(find.text('Interesse bekunden'), findsNothing);
          expect(
            find.text(
              'Profilzugang und Eventfreigabe bestätigen keine Teilnahme.',
            ),
            findsNothing,
          );
        }
        expect(api.bodies, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

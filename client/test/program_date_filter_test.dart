import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/main.dart';
import 'package:community_access_client/program_views.dart';
import 'package:community_access_client/program_date_filter.dart';
import 'package:community_access_client/event_carousel.dart';

import 'discovery_widget_test.dart' show DiscoveryFixture;

class CalendarFilterFixture extends DiscoveryFixture {
  final calendarRequests = <Map<String, String>>[];
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final result = await super.directory(path, query: query, body: body);
    if (path != 'events') return result;
    calendarRequests.add({...?query});
    final from = DateTime.tryParse(query?['from'] ?? '');
    final before = DateTime.tryParse(query?['before'] ?? '');
    final q = query?['q'] ?? '';
    return {
      ...result,
      'events': events.where((event) {
        final start = DateTime.tryParse(event['starts_at'] as String? ?? '');
        return (from == null ||
                (start != null &&
                    !start.isBefore(from) &&
                    start.isBefore(before!))) &&
            (event['title'] as String).contains(q);
      }).toList(),
    };
  }
}

void main() {
  test('all dates has no restriction', () {
    expect(programDateRange(ProgramDateFilter.all), isNull);
  });
  test('today and tomorrow cross year end at local midnight', () {
    final now = DateTime(2026, 12, 31, 23, 59);
    final today = programDateRange(ProgramDateFilter.today, now: now)!;
    final tomorrow = programDateRange(ProgramDateFilter.tomorrow, now: now)!;
    expect(today.from, DateTime(2026, 12, 31));
    expect(today.before, DateTime(2027, 1, 1));
    expect(tomorrow.from, today.before);
    expect(tomorrow.before, DateTime(2027, 1, 2));
  });
  test('this week includes Monday and Sunday and excludes next Monday', () {
    for (var day = 19; day <= 25; day++) {
      final range = programDateRange(
        ProgramDateFilter.thisWeek,
        now: DateTime(2026, 10, day, 12),
      )!;
      expect(range.from, DateTime(2026, 10, 19));
      expect(range.before, DateTime(2026, 10, 26));
    }
    final next = programDateRange(
      ProgramDateFilter.thisWeek,
      now: DateTime(2026, 10, 26),
    )!;
    expect(next.from, DateTime(2026, 10, 26));
    expect(next.before, DateTime(2026, 11, 2));
  });
  test('calendar days cross leap day and clock changes at midnight', () {
    for (final day in [
      DateTime(2028, 2, 28),
      DateTime(2026, 3, 29),
      DateTime(2026, 10, 25),
    ]) {
      final range = programDateRange(ProgramDateFilter.tomorrow, now: day)!;
      expect(range.from, DateTime(day.year, day.month, day.day + 1));
      expect(range.before, DateTime(day.year, day.month, day.day + 2));
    }
  });
  for (final size in [
    const Size(320, 900),
    const Size(390, 844),
    const Size(1280, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('date selection and search at $size with $scale text', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final api = CalendarFilterFixture();
        final now = DateTime.now();
        api.events.first['starts_at'] = DateTime(
          now.year,
          now.month,
          now.day,
          18,
        ).toUtc().toIso8601String();
        api.events.last['starts_at'] = DateTime(
          now.year,
          now.month,
          now.day + 1,
          19,
        ).toUtc().toIso8601String();
        await tester.pumpWidget(
          CommunityAccessApp(api: api, authOnly: true, showPublicHome: true),
        );
        await tester.pumpAndSettle();
        Finder row(String title) => find.descendant(
          of: find.byType(ProgramList),
          matching: find.text(title),
        );
        Future<void> filter(String label) async {
          final button = find.widgetWithText(TextButton, label);
          await tester.ensureVisible(button);
          expect(tester.getRect(button).right, lessThanOrEqualTo(size.width));
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        await filter('Heute');
        expect(row('Demo Ambientabend'), findsOneWidget);
        expect(row('Demo Secret Night'), findsNothing);
        await filter('Morgen');
        expect(row('Demo Ambientabend'), findsNothing);
        expect(row('Demo Secret Night'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(EventCarousel),
            matching: find.text('Demo Ambientabend'),
          ),
          findsOneWidget,
        );
        final search = find.byTooltip('Suche öffnen').last;
        await tester.ensureVisible(search);
        await tester.tap(search);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Ambient');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(row('Demo Ambientabend'), findsNothing);
        expect(
          find.text('Keine passenden Veranstaltungen in diesem Zeitraum.'),
          findsOneWidget,
        );
        expect(api.calendarRequests.last['q'], 'Ambient');
        expect(api.calendarRequests.last['from'], isNotNull);
        await filter('Alle Termine');
        expect(row('Demo Ambientabend'), findsOneWidget);
        expect(api.calendarRequests.last.containsKey('from'), isFalse);
        await filter('Diese Woche');
        expect(row('Demo Ambientabend'), findsOneWidget);
        expect(row('Demo Secret Night'), findsNothing);
        expect(api.writes, isEmpty);
      });
    }
  }
}

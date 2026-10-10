import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/app_language.dart';
import 'package:community_access_client/event_datetime_field.dart';

Widget localizedField(AppLanguage language, TextEditingController controller) =>
    LanguageScope(
      language: language,
      child: ValueListenableBuilder<bool>(
        valueListenable: language,
        builder: (context, english, child) => MaterialApp(
          locale: Locale(english ? 'en' : 'de'),
          supportedLocales: const [Locale('de'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: EventDateTimeField(
                controller: controller,
                label: 'Beginn mit Zeitzone',
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  for (final english in [false, true]) {
    final languageCode = english ? 'en' : 'de';
    final label = english ? 'Start with timezone' : 'Beginn mit Zeitzone';
    final cancel = english ? 'Cancel' : 'Abbrechen';
    final apply = english ? 'Apply' : 'Übernehmen';

    testWidgets(
      '$languageCode date picker uses translated labels and native calendar',
      (tester) async {
        final language = AppLanguage()..value = english;
        final initial = DateTime(2026, 10, 9, 20).toUtc().toIso8601String();
        final controller = TextEditingController(text: initial);
        addTearDown(language.dispose);
        addTearDown(controller.dispose);
        await tester.pumpWidget(localizedField(language, controller));
        await tester.pumpAndSettle();
        expect(
          find.text('$label: ${english ? 'Date' : 'Datum'}'),
          findsOneWidget,
        );
        expect(
          find.text(english ? 'DD.MM.YYYY' : 'TT.MM.JJJJ'),
          findsOneWidget,
        );
        await tester.tap(
          find.byTooltip(
            '${english ? 'Choose date' : 'Datum auswählen'}: $label',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
        expect(
          find.text('$label: ${english ? 'Date' : 'Datum'}'),
          findsAtLeastNWidgets(1),
        );
        expect(
          find.text(english ? 'October 2026' : 'Oktober 2026'),
          findsOneWidget,
        );
        expect(
          find.byTooltip(english ? 'Next month' : 'Nächster Monat'),
          findsOneWidget,
        );
        expect(find.text(apply), findsOneWidget);
        await tester.tap(find.text(cancel));
        await tester.pumpAndSettle();
        expect(controller.text, initial);
        expect(find.byType(DatePickerDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$languageCode time picker validates translated input and applies selection',
      (tester) async {
        final language = AppLanguage()..value = english;
        final controller = TextEditingController(
          text: DateTime(2026, 10, 9, 20).toUtc().toIso8601String(),
        );
        addTearDown(language.dispose);
        addTearDown(controller.dispose);
        await tester.pumpWidget(localizedField(language, controller));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byTooltip(
            '${english ? 'Choose time' : 'Uhrzeit auswählen'}: $label',
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'time dialog opened');
        expect(find.byType(TimePickerDialog), findsOneWidget);
        expect(
          find.text(english ? 'Choose time' : 'Uhrzeit auswählen'),
          findsAtLeastNWidgets(1),
        );
        final inputMode = english
            ? 'Switch to text input mode'
            : 'Zum Texteingabemodus wechseln';
        expect(find.byTooltip(inputMode), findsOneWidget);
        await tester.tap(find.byTooltip(inputMode));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'switched to text input',
        );
        expect(find.text(english ? 'Hour' : 'Stunde'), findsOneWidget);
        expect(find.text('Minute'), findsOneWidget);
        final fields = find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.byType(TextFormField),
        );
        expect(fields, findsNWidgets(2));
        await tester.enterText(fields.first, '99');
        await tester.tap(find.text(english ? 'Apply' : 'OK'));
        await tester.pumpAndSettle();
        expect(
          find.text(english ? 'Invalid time.' : 'Zeit ungültig.'),
          findsAtLeastNWidgets(1),
        );
        expect(find.byType(TimePickerDialog), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'invalid time shown');
        await tester.enterText(fields.first, '21');
        await tester.enterText(fields.last, '45');
        await tester.tap(find.text(english ? 'Apply' : 'OK'));
        await tester.pumpAndSettle();
        expect(find.byType(TimePickerDialog), findsNothing);
        expect(
          DateTime.parse(controller.text),
          DateTime(2026, 10, 9, 21, 45).toUtc(),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

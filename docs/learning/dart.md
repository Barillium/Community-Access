# Dart lernen: Übung 1 – Bewerbungsstatus

## Ziel und Grenze

Diese erste Übung lebt unter `exercises/dart_basics/`, getrennt von der späteren App. Sie verwendet Dart 3.13.4 aus dem vorhandenen Flutter-SDK und keine zusätzlichen Pakete. `publish_to: none` verhindert eine versehentliche Paketveröffentlichung über Pub.

Die Regel ist bewusst vereinfacht: `pending` darf zu `approved` oder `rejected` wechseln. Als gemeinsam gewählte Erweiterung darf außerdem `approved → pending` zur erneuten Prüfung wechseln. Alle anderen Übergänge sind verboten. Das ist keine Backend-Autorisierung und noch kein vollständiges Produktmodell; insbesondere Rückzug, Community-Rechte und Eventbestätigung sind nicht implementiert.

## Erst vorhersagen, dann ausführen

1. Öffne [die Funktion](../../exercises/dart_basics/lib/application_status.dart) und [das Konsolenbeispiel](../../exercises/dart_basics/bin/main.dart).
2. Sage voraus: Welchen Wert liefert `pending → approved`? Welchen liefert `rejected → approved`?
3. Starte die Demo im Terminal:

```sh
cd "/Users/stanynyssen/Scene Access/exercises/dart_basics"
dart bin/main.dart
```

Erwartete Ausgabe: `pending -> approved: true` nach dem Hinweis auf die synthetische Lernübung. Der Aufruf führt nur lokalen Code aus; weder Anmeldung noch Netzwerk oder Datenbank sind beteiligt.

## Den kleinen Code verstehen

- **`enum`:** Eine feste Auswahl benannter Werte. `ApplicationStatus.pending` ist offen, `approved` angenommen und `rejected` abgelehnt. Beliebige Texte sind keine gültigen Funktionsargumente.
- **Funktion:** `canTransition(from, to)` beantwortet eine Frage für zwei Eingaben. Sie verändert keinen Status, speichert nichts und führt keine Aufnahme durch.
- **`bool`:** Das Ergebnis ist `true` (erlaubt) oder `false` (verboten).
- **`==`:** Vergleicht zwei Werte. `&&` bedeutet „und“, `||` bedeutet „oder“. Die Klammer fasst die beiden erlaubten Zielzustände zusammen.
- **`final`:** Eine Variable wird einmal belegt und danach nicht neu zugewiesen. Im Beispiel sind das der aktuelle und der gewünschte Status.
- **Reine Funktion:** Gleiche Eingaben liefern dasselbe Ergebnis, ohne Nebenwirkungen. Keine Uhr, Zufallswerte oder Datenbank beeinflussen diese Übung.

`null` bedeutet einen fehlenden oder unbekannten Wert, `""` einen vorhandenen leeren Text und `false` eine Nein-Aussage. Unsere Funktion nimmt zwei nicht-nullbare Enum-Werte entgegen: `null` und Texte werden bereits durch das Typsystem ausgeschlossen. Ein fachlich verbotener, aber korrekt typisierter Statuswechsel liefert dagegen `false`.

## Prüfungen selbst starten

Im selben Übungsordner:

```sh
dart format --output=none --set-exit-if-changed bin lib test
dart analyze
dart test/application_status_test.dart
```

Der erste Befehl prüft Formatierung ohne Quelldateien umzuschreiben, der zweite sucht statisch nach Problemen, der dritte führt unseren kleinen Prüfcode aus. Erwartet werden keine Formatänderungen, `No issues found!` und `9 Pruefungen, 0 Fehler.`

Die [Prüfdatei](../../exercises/dart_basics/test/application_status_test.dart) deckt alle neun Kombinationen der drei Statuswerte ab: drei erlaubte und sechs verbotene. Sie verwendet kein externes Testpaket. Deshalb ist der Aufruf ausdrücklich `dart test/application_status_test.dart`, nicht `dart test`. Fehler setzen den Prozess-Exitcode auf 1; sie bleiben auch bei abgeschalteten Dart-Assertions sichtbar. Die Zähler und die kleine Hilfsfunktion darin sind Prüfwerkzeug, nicht zusätzliche Produktlogik.

`dart pub get --offline` erzeugt bei Bedarf die lokale Paketkonfiguration ausschließlich aus lokal verfügbaren Informationen. Es gibt keine Paketabhängigkeiten. Die dabei erzeugte Lockdatei wird versioniert; `.dart_tool/` bleibt ignoriert. Analyse und Ausführung dürfen lokale Werkzeug-Caches schreiben, benötigen aber keine Administratorrechte.

## Technischer Prüfnachweis am 24.09.2026

- Offline-Paketauflösung erfolgreich; die Lockdatei enthält `packages: {}`.
- Formatierung: drei Dart-Dateien geprüft, keine Änderungen nötig.
- `dart analyze`: `No issues found!`.
- Prüfdatei: alle neun Statuskombinationen bestanden, Exitcode 0.
- Konsolenbeispiel: `pending -> approved: true` beobachtet.
- Keine Browser-, Backend-, Transaktions- oder Konkurrenztests ausgeführt: Diese reine Funktion greift auf keinen gemeinsamen Zustand zu und ersetzt solche späteren Tests nicht.

## Gemeinsam gewählte Regeländerung

Du hast `approved → pending` gewählt: Eine angenommene Bewerbung darf in dieser Lernübung erneut geöffnet werden. Codex hat die Codeänderung ausgeführt; eine selbstständig von dir geschriebene Änderung wird damit nicht als bestanden gewertet. Die Produktanforderungen bleiben unverändert.

Zuerst wurde nur die Testerwartung von `false` auf `true` geändert. Der beobachtete Fehler lautete `approved -> pending: erwartet true, erhalten false`; genau eine von neun Prüfungen schlug fehl (Exitcode 1). Das zeigt, dass der Test die neue Anforderung erkennt. Nach der Funktionsergänzung bestanden alle neun Prüfungen wieder (Exitcode 0); Formatprüfung und Analyse waren ebenfalls erfolgreich.

Die Funktion unterscheidet jetzt zwei benannte Bedingungen:

- `isInitialDecision`: Eine offene Bewerbung wird angenommen oder abgelehnt.
- `isReopening`: Eine angenommene Bewerbung wird erneut geöffnet.

`return isInitialDecision || isReopening;` liefert `true`, sobald eine dieser Bedingungen erfüllt ist. Die Funktion prüft weiterhin nur und verändert keine Bewerbung.

**Dein nächster eigener Versuch:** Erkläre, weshalb `approved → pending` jetzt erlaubt ist, `rejected → pending` aber weiterhin verboten bleibt. Ändere anschließend selbst im Konsolenbeispiel `currentStatus` auf `approved` und `requestedStatus` auf `pending` und starte `dart bin/main.dart`. Erwartet wird `true`. Dieser eigene Dateiversuch ist noch nicht nachgewiesen.

## Danach

Übung 2 zu Eventdaten, Klassen, Listen, Maps und Null-Sicherheit sowie Übung 3 zu `Future` und `async/await` sind nur geplant. Schritt 05 ist mit dieser ersten technischen Übung noch nicht vollständig abgeschlossen.

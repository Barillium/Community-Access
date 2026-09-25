# Eine Aufgabe vorbereiten

Die [JSON-Vorlage](single-task.example.json) ist ein Beispiel, **keine Freigabe**. Die Produktgrundlage bleibt die [Produktspezifikation](../product-spec.md). Der [Einzelaufgaben-Ablauf](../codex-workflow.md#manueller-einzelaufgaben-runner) erklärt die Aufrufe.

Vor der Freigabe gemeinsam festhalten:

- Ein konkretes Ergebnis und dessen Nutzen; keine Folgeaufgaben im Auftrag verstecken.
- Eindeutige neue `id`, erlaubte Dateien und ausdrücklich ausgeschlossene Änderungen.
- Menschlich festgelegtes Risiko. V1 nimmt nur `low` und ausschließlich synthetische Daten an; Authentifizierung, Rechte, Datenlöschung und Infrastruktur gehören nicht dazu.
- Prüffähige Abnahme und die Grenzen maschineller Prüfung. `contains` prüft nur einen exakten Textbaustein, weder fachliche Richtigkeit noch gute Sprache. Die beschriebene Satzanzahl und Verständlichkeit im Beispiel kontrolliert der Mensch im Diff.
- Geprüfter Basis-Commit und separat freigegebener Kontroll-Commit mit vollständigen SHA-Werten. Ein Commit allein ist keine Freigabe.
- Notwendige Tests, erwartete Ergebnisse und bereits bekannte Probleme. Fehlende Pflichtprüfungen bedeuten Blockade.

`scope` ist in V1 `docs` oder `dart-learning`. Erlaubt sind README und Markdown unter `docs/learning/`; für `dart-learning` zusätzlich vorhandene Dart-Dateien unter `exercises/dart_basics/lib/` und `bin/`. Neue Dateien sind nur unter `docs/learning/` vorgesehen. Höchstens fünf Dateien, keine Löschungen, Umbenennungen, Binärdateien oder Abhängigkeiten.

Tests, AGENTS, Produktvertrag, Architektur, Designregeln, Runner und diese Vorlage sind für den Coding-Agenten gesperrt. Deren Pflege bleibt eine eigene menschlich geprüfte Infrastrukturaufgabe. Erfordert eine Aufgabe neue Tests, ist die Testvorgabe zuerst separat zu prüfen und einzufrieren; der Runner darf die Lücke nicht durch unveränderte alte Tests als abgedeckt ausgeben.

Eine Änderung der Aufgabe, ihrer Risikoeinstufung, Abnahmekriterien oder Basis benötigt eine neue Prüfung und Freigabe. Freigaben sind einmalig, auch nach Abbruch verbraucht. Keine Freigabe-ID wiederverwenden.

# Bestandsaufnahme, Abnahme und Nachweise

Stand: 25.09.2026. Umfang dieser Ausbaustufe: genau eine manuell freigegebene synthetische Aufgabe. Keine dauerhafte Ausführung, automatische Übernahme oder Veröffentlichung.

## Tatsächliches Repository

Ausgangsstand war der saubere Branch `main`, Commit `68f3b149f565c48b2841455184019e30cca69b33`. Die Vorbereitung liegt auf `tooling/single-task-runner`. Vorhandene Änderungen mussten nicht umgeschrieben werden. Gelesene Anweisungsquellen: `~/.codex/AGENTS.md`, Root-`AGENTS.md` und die vom Nutzer bereitgestellten Projektregeln. Im Projekt wurde keine weitere AGENTS-Datei gefunden. Produkt-, Setup-, Git-, Codex- und Lern-Dokumentation wurden als Grundlage verwendet; keine privaten Notizen oder echten Anmeldedateien gelesen.

| Bereich | Einordnung | Nachweis / Grenze |
| --- | --- | --- |
| Produktumfang | Vorhanden als freigegebene Zielbeschreibung | [product-spec.md](product-spec.md); zwei Produktrollen, manuelle Entscheidungen, offene Fachfragen. Keine implementierte Produkteigenschaft. |
| Dart-Lernübung | Vorhanden und erneut funktionsfähig geprüft | Format, Analyse und neun Statusfälle bestanden. Keine Paketabhängigkeiten; `pubspec.lock` enthält keine Pakete. |
| Flutter-Werkzeuge | Vorhanden; frühere separate Demo geprüft | Flutter 3.47.5 / Dart 3.13.4, lokale Pfade in [setup.md](setup.md). Die externe Browser-Demo wurde in dieser Aufgabe nicht wiederholt. |
| Python / Git / macOS-Sandbox | Vorhanden und für lokale Prüfungen benutzt | Python 3.10.14, Apple Git, macOS ARM64. Keine Installation. |
| Codex-CLI | Vorhanden, Optionen geprüft | 0.155.0-alpha.9.2, `/Applications/ChatGPT.app/Contents/Resources/codex`; kein echter Modellaufruf für diesen Runner. |
| Runner und Kontrolltests | Neu implementiert, lokal geprüft | 25 Tests inklusive echter Sandbox-/Dart-Ausführung und CLI-Integration; Modellvorschläge in Tests deterministisch simuliert. |
| Entwicklungsanmeldung / Modellnetzwerk | Noch nicht eingerichtet beziehungsweise nicht geprüft | Keine normale Anmeldung kopiert oder gelesen. Blockiert ohne dedizierte Voraussetzung. Tarif und Modellwahl bleiben manuell. |
| Flutter-App in `app/` | Noch nicht vorhanden | Kein App-Build, Widget-, Integrations- oder Browserfunktionstest des Produkts. |
| Supabase / PostgreSQL | Noch nicht vorhanden | Keine Migrationen, SQL-/Transaktions-/Konkurrenztests oder lokale Backend-Umgebung. |
| Tatsächliche Produktrollen | Noch nicht vorhanden | Keine verifizierten Backend-Rechte oder Rollentests; keine erfundene Rechteentscheidung. |
| Remote / CI / Cloud / Veröffentlichung | Nicht eingerichtet in dieser Aufgabe | Kein Push, Deployment, Scheduler, Hintergrundjob oder automatischer Merge. |

## Reproduzierbare Aufrufe

Im Projektstamm, mit bewusst ausgewählten neuen Dateien im Index:

```sh
python3 -I scripts/check_project.py
python3 -I scripts/check_project.py --scope product
```

Der erste Befehl prüft die aktuellen versionierten Quellen in einer temporären Kopie: Markdown/relative Links, synthetische Sandboxgrenzen, Dart-Formatierung, Dart-Analyse, neun Statusfälle, anschließend die Runner-Tests und beide Git-Diff-Whitespace-Prüfungen. Er verändert keine Projektquellen, legt nur temporäre Testdaten an und installiert nichts. Er benötigt lokale Schreib-/Prozessrechte, keine Administratorrechte und kein Modellnetzwerk. Es handelt sich um eine Ausführung geprüften Infrastrukturcodes; nicht ungeprüfte fremde Tests außerhalb der Sandbox starten.

Erwartetes Ergebnis im vorhandenen Umfang: `PASS: current documentation, Dart exercise and runner only.` Übersprungene Runner-Tests oder ein leerer Testbestand führen zu einem Fehler. Der zweite Befehl muss derzeit mit `BLOCKED` und Exitcode 2 enden. Das ist ein bestandener Negativnachweis für die Sperre, **keine bestandene Produktabnahme**.

Gezielt nur Runner-Tests:

```sh
python3 -I -m unittest discover -s scripts/runner_tests -v
```

Dieser einzelne unittest-Aufruf kann außerhalb macOS Tests überspringen. Für die verbindliche Abnahme deshalb den übergeordneten `check_project.py` verwenden, der Überspringen nicht als Erfolg akzeptiert.

Die Runner-Gates verwenden das vorhandene Dart-SDK direkt und führen im exportierten `exercises/dart_basics/` aus:

```sh
dart format --output=none --set-exit-if-changed bin lib test
dart analyze
dart test/application_status_test.dart
```

Die letzte Zeile ist die vorhandene selbst geschriebene Prüfdatei, kein `package:test`-Aufruf. Eine neue Abhängigkeit wird nicht installiert. Alle drei Befehle laufen im Runner ohne Netzwerk und ohne Schreibrecht auf Quellcode oder eingefrorene Tests.

## Verbindliche Abnahme je Aufgabenart

| Aufgabenart | Pflichtprüfungen | Fehlende Voraussetzung |
| --- | --- | --- |
| Dokumentation / Dart-Lerncode, V1 | Unveränderte Baseline grün; Dateiliste und Testintegrität; Markdown/Links; eingefrorene Textkriterien; Dart-Format/Analyse/neun Fälle; vollständiger manueller Diff und fachliches Review | Blockieren; keine stillen Nebenreparaturen oder grünen Ersatzprüfungen. Neue Funktion außerhalb der Testabdeckung zuerst separat spezifizieren. |
| Spätere Flutter-App | Tatsächliche Format-/Analyse-/App-Tests, passende Widget-/Integrations- und Browserprüfungen sowie überprüfter Build | V1 blockiert diesen Scope. Keine Übertragung des Demo-Erfolgs auf das Produkt. |
| Späteres Backend / Rollen | Lokale reproduzierbare DB mit synthetischen Seeds, Migrationstests, direkte positive/negative Zugriffe als nicht angemeldetes Konto, eigener/fremder Gast, Gastgeber verschiedener Communities und entzogene Mitgliedschaft | V1 blockiert diesen Scope. Admin-/service_role-Erfolg ersetzt keinen Nutzerrollentest. |
| Spätere konsistente Abläufe | Wiederholung, atomarer Rollback bei Fehler, konkurrierende Aufnahme/Entzug und letzter Eventplatz, Löschfrist vor/nach Fälligkeit | Nicht vorhanden; [geplante Produktabnahme](product-spec.md#7-wie-wir-die-drei-wichtigsten-anforderungen-testen) bleibt verbindlicher Entwurf. |
| Steuerung / Testvorgaben / Rechte | Eigene menschlich geprüfte Änderung am Kontrollstand und erneute Schutztests | Für Coding-Aufgaben gesperrt; keine Selbsterteilung von Freigaben oder Abschwächung der Kriterien. |

## Beobachtete Nachweise und offene Grenze

Die Gesamtprüfung `python3 -I scripts/check_project.py` bestand am 25.09.2026: Dokumente/Links, Dart-Format/Analyse/neun Fälle und 25 Runner-Tests ohne übersprungene Tests. `--scope product` wurde ausgeführt und blockierte wie erwartet mit Exitcode 2. Darunter: unerlaubte Dateiziele, manipulierte Vorschlagsfelder, kontrollierter Steuerstand, doppelte Dateiziele, Symlinks, Traversal, veränderte Tests, bereinigte Umgebung, konkurrierender Start, Zeitlimit, fehlende Tests/Runtime, fehlgeschlagene Baseline, fehlende Entwicklungsanmeldung, einmaliger Freigabeverbrauch, Reparatur nach Fehler und Abbruch nach maximal drei Vorschlägen.

Die CLI-Demo wurde sowohl in der Testsuite als auch mit einer temporären Kopie der tatsächlich geprüften Projektdateien ausgeführt. Sie erzeugte eine Lerndatei nur im Kandidaten, einen Patch und einen expliziten `simulation_only`-Bericht. Das ursprüngliche Repository blieb dort sauber. Der Modellanbieter wurde nicht kontaktiert; dies ist kein Live-Codex-Nachweis. Die CLI-Tests erzeugen nur dafür synthetische lokale Commits, keine Freigabe für den echten Projektstand. Ein separat aufbewahrter Simulationsbericht mit SHA-256 des Runnercodes liegt lokal unter `.local/runner-verification/simulation-report.json`, der vorgeschlagene Diff unter `.local/runner-verification/simulation.patch`. Diese lokalen Nachweise sind absichtlich nicht versioniert.

Bei der Entwicklung schlug das erste macOS-Profil fehl. Die Ursache für den Startabbruch wurde auf fehlenden Lesezugriff auf das Wurzelverzeichnis selbst eingegrenzt. Das korrigierte Profil erlaubt diesen Verzeichniseintrag, nicht pauschal dessen Unterordner. Anschließend bestanden die tatsächlichen Schutztests und Dart-Prüfungen. Zwei frühere Python-Testprozesse (PIDs `38028`, `38445`) blieben trotz `SIGKILL` im Zustand `UEs` im Kernel. Sie sind kein gewollter Hintergrunddienst; ihr vollständiges Ende konnte nicht bestätigt werden. Vor echten Läufen muss der Nutzer diesen Zustand klären, gegebenenfalls durch einen kontrollierten macOS-Neustart. Ein gescheitertes Aufräumen darf nicht als abgeschlossen gelten.

Nicht ausgeführt: echter Codex-Modellaufruf mit eigener Entwicklungsanmeldung, dessen Netzwerk-/Auth-Profil, Flutter-Produktbuild, Produktbrowserprüfung, Datenbank-, Rollen-, Transaktions- und Konkurrenztests sowie andere Betriebssysteme. Gründe: separate Anmeldung/Netzfreigabe fehlen beziehungsweise Produktkomponenten existieren noch nicht. Native iOS-/Android-/Desktop-Plattformen bleiben ungeprüft. Keine vollständige Sicherheitszertifizierung oder Garantie gegen absichtlich bösartigen Code.

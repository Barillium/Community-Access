# Community Access

Eine kleine Zugangslösung für bestehende Kollektive in Aachen. Einladungen führen zu Bewerbungen und manueller Aufnahme; Eventteilnahme wird separat bestätigt. Bestehende Messenger bleiben bestehen.

## Stand und Einstieg

- [Produktspezifikation](docs/product-spec.md): Rollen, Abläufe, Schutzgrenzen und offene Entscheidungen.
- [Lokales Setup](docs/setup.md): getestete Flutter-Web-Umgebung auf macOS ARM64.
- [Git-Arbeitsablauf](docs/workflow.md): Änderungen prüfen, gezielt sichern und eine Rücknahme üben.
- [Projektanweisungen](AGENTS.md) und [Codex-Arbeitsablauf](docs/codex-workflow.md): kleine Aufgaben, Freigaben und geprüfte Schutzgrenzen.

Die erste [Dart-Lernübung](docs/learning/dart.md) übt erlaubte Bewerbungsstatuswechsel, getrennt von der späteren Anwendung.

Unter `app/` liegt eine minimale Flutter-Web-Demo mit vier synthetischen Statusanzeigen und fünf Tests. Sie speichert nichts und verbindet sich mit keinem Backend. Start und Prüfungen stehen im [Setup](docs/setup.md#projekt-app-starten-und-prüfen). Die separate frühere Werkzeugdemo bleibt unverändert.

Die ausgearbeitete [Flutter-Gastoberfläche](client/README.md) liegt seit dem 01.10.2026 separat unter `client/`. Das bisherige Laravel-Backend und seine zugehörige Struktur wurden aus dem aktiven Projekt entfernt. Die Umstellung auf Better Auth ist geplant, aber noch nicht implementiert; die Gastoberfläche besitzt derzeit kein lauffähiges Produkt-Backend.

## Projektstruktur

```text
Community Access/          Projektstamm
  README.md
  AGENTS.md
  .gitignore
  docs/                    Produkt, Setup und Arbeitsablauf
  scripts/                 manueller Einzelaufgaben-Runner und Prüfungen
  app/                     Flutter-Statusdemo mit eigenen Tests
  client/                  erhaltene Flutter-Gastoberfläche mit eigenen Tests
  supabase/                lokaler Auth-/API-Kern und Migration
```

`app/` und der lokale Supabase-Kern sind angelegt. Ein einziges Git-Repository im Projektstamm umfasst beide Bereiche. Kein verschachteltes Repository anlegen; die externe Setup-Demo wird nicht hierher kopiert.

Die getrennte lokale PostgreSQL-Testumgebung wird mit `python3 -I scripts/check_database.py` gestartet, geprüft und beendet. Sie verwendet nur synthetische Infrastruktur-Fixtures. Der zusätzliche lokale Supabase-Kern samt Auth-/API-Rollentests ist in [ADR 0002](docs/decisions/0002-local-supabase-core.md) beschrieben; das vollständige Produktmodell bleibt offen. Details stehen im [Setup](docs/setup.md#getrennte-lokale-postgresql-testdatenbank).

## Arbeitsregeln

Lokal zuerst: Flutter/Dart, PostgreSQL und Supabase. Nur synthetische Daten für Entwicklung, Tests und KI-Kontext. Keine echten Secrets, privaten Bewerbungen, Mitgliederlisten oder Einladungslinks im Repository. Community-Rollen sind communitybezogen; Mitgliedschaft ist keine bestätigte Eventteilnahme.

Keine Messenger-Synchronisierung, Zahlungen, KI-Kompatibilitätsbewertung, Trust Scores oder globalen Szeneprofile. Backend-Zugriff muss standardmäßig verweigert und explizit erlaubt werden. Privilegierte Schlüssel gehören niemals in den App-Build. Transaktionen und Konkurrenzfälle benötigen später eigene Tests.

Vor Änderungen Status und relevante Dokumente lesen, Plan und Prüfungen nennen und bestehende Arbeit erhalten. Installation, Netzwerkfreigaben, neue Dienste, Veröffentlichung, Server-/DNS-Eingriffe und destruktive Aktionen benötigen die entsprechende Nutzerfreigabe. Commits werden aus bewusst ausgewählten, geprüften Dateien erstellt.

## GitHub und lokale Entwicklung

Das öffentliche Repository [Barillium/Community-Access](https://github.com/Barillium/Community-Access) ist als `origin` verbunden. Es dient als Ziel für den ausdrücklich beauftragten Quellcode-Upload. Lokale Konfiguration, Datenbanken, Build-Ausgaben und das entfernte Laravel-Archiv unter `.local/` sind ausgeschlossen. Die Anwendung wird weiterhin lokal entwickelt; ein Quellcode-Upload ist kein Deployment und keine Produktabnahme. Git ersetzt keine gesonderte Sicherung lokaler Daten.

Open-Source-orientiert beschreibt die Ausrichtung. Eine Lizenz für den eigenen Projektcode wurde noch nicht gewählt; aus diesem README folgt keine Lizenzfreigabe. Die Lizenzen der installierten Werkzeuge stehen in der Setup-Dokumentation.

## Eine Aufgabe kontrolliert vorbereiten

Der [manuelle Einzelaufgaben-Runner](docs/codex-workflow.md#manueller-einzelaufgaben-runner) erzeugt isolierte Änderungsvorschläge mit Prüfbericht. Der Runner unterstützt Dokumentation, die Dart-Lernübung und eng begrenzte App-Oberflächenaufgaben gemäß [ADR 0003](docs/decisions/0003-runner-app-gates.md). Ein echter Dokumentationslauf und eine modellfreie App-Simulation sind nachgewiesen; der echte App-Modelllauf steht aus; keine automatischen Merges, Dauerläufe oder Deployments.

[Bestandsaufnahme und Abnahmekriterien](docs/verification.md), [Architekturentscheidung](docs/decisions/0001-single-task-runner.md), [Designregeln](docs/design-rules.md) und [Aufgabenvorlage](docs/tasks/README.md) beschreiben den Stand und die Grenzen. Die bestehenden Produktentscheidungen bleiben unverändert.

```sh
python3 -I scripts/check_project.py
```

Dieser Aufruf prüft den bestehenden lokalen Lernumfang und Runner. `--scope app` ergänzt die Flutter-Prüfungen; `--scope core` zusätzlich die bereits gestartete lokale Supabase-Testumgebung. Die vollständigen Produktabläufe fehlen weiterhin; deshalb blockiert `--scope product`.

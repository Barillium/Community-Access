# Bestandsaufnahme, Abnahme und Nachweise

Stand: 25.09.2026. Umfang dieser Ausbaustufe: genau eine manuell freigegebene synthetische Aufgabe. Keine dauerhafte Ausführung, automatische Übernahme oder Veröffentlichung.

## Aktueller Lesestand

Die folgenden Abschnitte dokumentieren die Entwicklung chronologisch. Ältere Aussagen wie „App nicht vorhanden“ sind historische Befunde; maßgeblich sind die Nachträge „Supabase Auth/API und Rollen“, „Runner-Erweiterung“ und der abschließende Kontrollreview. App und lokaler Backend-Kern existieren; vollständige Produktabläufe und ein echter App-Modelllauf stehen weiter aus.

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

## Nachtrag nach der separaten Anmeldung

Die früheren Prozesse wurden anschließend als beendet geprüft und die lokale Startsperre archiviert. Die Demo gegen den freigegebenen Commit `5c86c25` bestand ebenfalls; der lokale Bericht liegt unter `.local/task-runner/demo-2722c1d3/report.json`.

Der Nutzer meldete die separate Anmeldung als abgeschlossen. Ohne Lesen von Zugangsdaten wurde die reguläre `auth.json` im vorgesehenen Entwicklungsordner festgestellt. Zusätzlich vorhandene `log`-/`tmp`-Ordner blockierten die ursprüngliche Validierung. Die dafür vorbereitete Korrektur erlaubt diese regulären Ordner als vorhandene Einträge, ohne ihren Inhalt zu lesen oder dem Modellprozess freizugeben.

Die Gesamtprüfung nach der Korrektur bestand: 28 Runner-Tests ohne übersprungene Tests, neun Dart-Statusfälle, Dart-Formatierung und Analyse sowie Dokumentationsprüfungen. Drei zusätzliche Tests prüfen die Metadatenvalidierung, Ablehnung unbekannter Einträge/Symlinks und die tatsächliche OS-Lesesperre für synthetische Log-/Temp-Inhalte. Echte Zugangsdaten wurden in keinem Test verwendet. Ein echter Modellaufruf bleibt ungeprüft; vor seiner Ausführung benötigt der geänderte Kontrollstand einen eigenen Review und Freigabe.

## Erster echter Ausführungsversuch und vorbereitete Korrektur

Die Nutzeranweisung „Führe das aus“ wurde als einmaliger Auftrag für den vorhandenen synthetischen Lernhinweis erfasst. Basis und Kontrolle: `f226551bc6eacef181f50719ce30e117197f27d5`; Aufgabe `explain-event-confirmation`, Modellwahl `gpt-6-sol`, 600 Sekunden Budget, maximal zwei Reparaturrunden. Der Dry-Run war erfolgreich.

Der Lauf wurde tatsächlich gestartet, endete aber nach rund 0,91 Sekunden mit `blocked`. Dokumente/Links, Dart-Format, Analyse und alle neun Statusfälle der Ausgangsbasis bestanden. Die CLI brach mit `failed to initialize in-process app-server client: Operation not permitted` ab. Es entstand kein Änderungsvorschlag und kein Patch; eine erfolgreiche Modellverbindung wurde nicht nachgewiesen. Bericht: `.local/task-runner/run-explain-event-confirmation-33d647b6/report.json`. Die Aufgabenfreigabe ist verbraucht. Die Arbeitskopie wurde durch diesen Lauf nicht verändert.

Die anschließende Diagnose verwendete keine echten Zugangsdaten. Sie wies den Bedarf an einer beschreibbaren SQLite-Laufzeitablage und einem Dateilimit oberhalb 1 MB nach. Die vorbereitete Korrektur bestand `python3 -I scripts/check_project.py`: 31 Tests, neun Dart-Fälle, Format, Analyse und Dokumentationsprüfungen. Neue Tests prüfen den kontrollierten Auth-Verweis, den Schutz der ursprünglichen synthetischen Anmeldedatei bei schreibbarer Laufzeitablage und den echten Offline-Start der installierten CLI. Der Offline-Test erwartet die kontrollierte Zeitbegrenzung, nachdem die Initialisierung gelungen ist; er behauptet keine erfolgreiche Modellantwort. DNS-Auflösung von `chatgpt.com` bestand separat im vorgesehenen Netzwerkprofil ohne Anmeldung.

Noch ausstehend: Review/Freigabe des geänderten Kontrollstands und genau ein neuer authentifizierter Versuch mit einer neuen Freigabe-ID. App-, Datenbank- und Rollentests bleiben mangels Implementierung aus. Keine Veröffentlichung oder automatische Übernahme.

## Zweiter echter Versuch: CLI-Start erfolgreich, TLS blockiert

Nach ausdrücklicher Nutzerfreigabe wurde die Laufzeitkorrektur als `aff3b9ac066dd48ae41c540588fed4feaec05dc1` committet. Die unveränderte Dokumentationsaufgabe erhielt die neue ID `explain-event-confirmation-retry1`. Der Dry-Run und sämtliche Ausgangsprüfungen bestanden; Modellwahl blieb `gpt-6-sol`, Budget 600 Sekunden.

Die CLI startete nun, scheiterte aber wiederholt mit `invalid peer certificate: UnknownIssuer`. Der eindeutig identifizierte eigene Codex-Prozess wurde gezielt mit SIGTERM beendet. Der Runner räumte auf und meldete nach 63,19 Sekunden `blocked` mit Exit -15. Keine Modellantwort, keine abgeschlossene Vorschlagsrunde und kein Patch. Bericht: `.local/task-runner/run-explain-event-confirmation-retry1-418f0005/report.json`. Auch diese Freigabe ist verbraucht.

Ein separater, auf 15 Sekunden begrenzter Test ohne Anmeldung verwendete ausschließlich das öffentliche vorhandene System-CA-Bündel. Danach trat HTTP `401 Unauthorized` statt `UnknownIssuer` auf. Der Test wurde durch sein Zeitlimit beendet; dies ist ein TLS-Verbindungsnachweis, kein erfolgreicher Aufgabenlauf und keine Modellantwort.

Die daraus vorbereitete Korrektur bestand die Gesamtprüfung: 33 Runner-Tests ohne übersprungene Tests, neun Dart-Statusfälle, Formatierung, Analyse und Dokumentationsprüfungen. Zwei zusätzliche Tests prüfen die feste CA-Vorgabe statt geerbter Umgebungswerte und den blockierten Start bei fehlendem Bündel. Der vollständige Diff wurde geprüft. Die technische TLS-Prüfung bleibt aktiv. Review und Freigabe des neuen Kontrollstands sowie ein weiterer einzelner angemeldeter Versuch stehen noch aus; Produkt-App, Datenbank und Rollen bleiben ungeprüft und nicht implementiert.

## Minimale Flutter-App (separater manueller Schritt)

`app/` enthält nun eine synthetische Flutter-Web-Statusdemo. Der frühere Tabellenstand „App nicht vorhanden“ ist damit überholt; Backend und Berechtigungsmodell fehlen weiterhin. Es gibt keine Aufnahme- oder Eventmutationen, sondern ausdrücklich gekennzeichnete Beispielzustände. Daher keine Transaktions- oder Konkurrenztests für diese reine Anzeige.

Ausgeführt: Offline-Auflösung der SDK-Pakete; Dart-Formatierung; Flutter-Analyse ohne Befund; fünf Tests (ein Logiktest, vier Widget-Tests); Web-Release-Build; sichtbare Startansicht und Wechsel zur Veranstalterbestätigung im lokalen Codex-Browser. Abgedeckt sind getrennte Eventzusage, Startzustand, alle vier Demozustände einschließlich Rückwechsel, schmale Ansicht mit großer Schrift sowie Auswahl per Tastatur. Ein fehlgeschlagener erster Paketaufruf im Projektstamm wurde im richtigen App-Verzeichnis erfolgreich wiederholt.

Nicht ausgeführt: automatisierte Browserintegration, Backend-/Rollen-/Transaktionsprüfungen und native Plattformen. Die bestehende V1-Projektprüfung wird nicht als App-Prüfung verwendet: Sie exportiert nur bekannte Quelldateitypen und unterstützt unter anderem `app/web/index.html` noch nicht. Runner/Controller blieben unverändert; vor Aufnahme der App in dessen freigegebenen Kontrollstand ist ein eigener Ausbau samt Review nötig. `--scope product` bleibt gesperrt. Die neue App wurde unabhängig mit den im Setup dokumentierten Aufrufen geprüft. Keine automatische Übernahme in einen freigegebenen Runner-Stand und kein Commit in diesem Schritt.

## Getrennte lokale Datenbank-Testumgebung

Das manuelle Skript `scripts/check_database.py` wurde mit dem vorhandenen PostgreSQL 17.10 ausgeführt. Ein frischer Cluster unter `.local/database-tests/` bestand Isolation (eigener Datenpfad, kein TCP, privater Socket), synthetische SQL-Fixtures mit Rollback und Unique-Constraint sowie zwei konkurrierende Updates über unabhängige Verbindungen. Anschließend wurde der eigene Server bestätigt beendet. Der Bericht liegt im jeweiligen lokalen Laufverzeichnis als `report.json`.

Das ist ausschließlich ein Infrastrukturtest. Die Fixture-Tabelle ist ausdrücklich kein Produktdatenmodell; der synthetische Administrator ersetzt keine Nutzerrollentests. Supabase, Produktmigrationen, Eventkapazität, Löschfristen und Rollenprüfungen bleiben offen. Die App-Arbeit aus dem vorherigen Schritt blieb uncommittet erhalten. Der V1-Runner wurde nicht erweitert und die vollständige Produktprüfung bleibt blockiert. Ausführungsdetails und Grenzen stehen im Setup.

## Supabase Auth/API und Rollen: lokaler Kern

CLI 2.117.0 und separate Colima-Test-VM eingerichtet. Finale Netzprüfung: Host und Container nur 127.0.0.1:55431/55432. Die vorausgegangene unerwartete Wildcard-Bindung wurde durch Stoppen und ein Loopback-Netz korrigiert; sie ist im [ADR 0002](decisions/0002-local-supabase-core.md) dokumentiert.

47 Auth-/API-Prüfungen bestanden, einschließlich fünf echten synthetischen Kontoanmeldungen, fremder Community, eigener/fremder Bewerbung, Selbstaufnahmeverbot, verbotener direkter Schreibzugriffe, erzwungenem Transaktionsrollback, konkurrierender Aufnahme und letztem Eventplatz sowie Zugriffsentzug mit bestehendem JWT. Bericht: `.local/supabase-tests/c0e5c691128c4131ac5e67aadba70127.json`. `supabase db lint --local --schema public,access_private --fail-on warning` meldete keine Befunde.

Noch offen: Einladungen, Kollektivaufnahme, Bewerbungsantworten/-rückzug, Löschfristen, vollständiger Entzugsablauf, Eventverwaltung und Flutter-Backend-Verbindung. Das Produktdatenmodell ist nur als Kern implementiert; keine vollständige Produktabnahme. Der V1-Runner und seine Produkt-Sperre bleiben unverändert. App-Tests wurden für diesen reinen Backend-Schritt nicht erneut ausgeführt; App-Dateien blieben unverändert.

## Runner-Erweiterung: geprüfter App-Scope und manuelle Kernprüfung

Auf `codex/runner-app-gates` implementiert, noch uncommittet und nicht als neuer Kontrollstand freigegeben. Grenzen und technische Ausnahmen stehen in [ADR 0003](decisions/0003-runner-app-gates.md).

Der gemeinsame Aufruf `check_project.py --scope core` bestand mit expliziter Einbeziehung der neuen Dateien: Dokumentation, neun geschützte Dart-Lernfälle, Offline-Auflösung der Flutter-Abhängigkeiten, App-Formatierung/Analyse, fünf App-Tests, Web-Build, 47 echte lokale Auth-/API-Prüfungen, SQL-Analyse ohne Befund und 37 Runner-Tests ohne übersprungene Tests. Backend-Bericht: `.local/supabase-tests/c6babc3547e14f558eec609a2d0c97ad.json`.

Ein vollständiger `app-ui`-Aufgabenlauf mit vorgegebenem Kommentarvorschlag bestand Ausgangs- und Kandidatenprüfungen und erzeugte einen Patch. Bericht: `.local/task-runner/app-proof-38d32392/report.json`, ausdrücklich `simulation_only`, `codex_executed: false`. Kein tatsächlicher App-Modellaufruf, keine Übernahme des Beispielpatches. Der reale frühere Dokumentationslauf ersetzt diesen ausstehenden App-Modellnachweis nicht.

Negativnachweise: `--scope product` blockierte mit Exitcode 2. Der Backend-Prüfer blockierte bei gestoppter VM ebenfalls mit Exitcode 2. Fehlende/übersprungene/fehlgeschlagene App-Tests werden in neuen Kontrolltests abgewiesen. Supabase und Test-VM wurden nach der Prüfung beendet. Keine Veröffentlichung oder automatische Freigabe.

Bei der Isolation wurden zuvor blockierte SDK-Cache-Schreibversuche, Compiler-Dateilimit, notwendige SDK-Hilfsprogramme sowie das Beenden eigener Flutter-Kindprozesse untersucht. Das schließlich geprüfte Profil lässt Quellcode/Tests/SDK schreibgeschützt und erlaubt nur begrenzte Build-Ausgaben, macOS-Systemdienstsuche, Kindprozesssignale und Loopback-Netzwerk. Keine Garantie gegen absichtlich bösartigen Code; keine Portisolierung gegenüber anderen lokalen Diensten. Historische fehlgeschlagene Diagnoseläufe gelten nicht als bestanden.

## Kontrollreview und Freigabe auf Nutzerauftrag

Der Nutzer hat ausdrücklich beauftragt: „Änderungen und den neuen Kontrollstand prüfen und freigeben“. Geprüft wurde der gesamte bisher uncommittete App-/Backend-/Runner-Stand auf `codex/runner-app-gates`, einschließlich neuer Dateien, erlaubter Dateiziele, eingefrorener Tests, Schutz der Steuerung, begrenzter Wiederholungen und dokumentierter Isolationsgrenzen. Keine neuen Produktrechte oder Testkriterien festgelegt. Überholte Statusangaben in README und Workflow wurden berichtigt; ältere Prüfabschnitte sind ausdrücklich als Historie eingeordnet.

Erneut ausgeführt und bestanden: `check_project.py --scope app` mit den 17 explizit einbezogenen neuen Dateien, Dokument-/Linkprüfungen, neun Dart-Lernfälle, App-Formatierung/Analyse, fünf App-Tests, Web-Build und 37 Runner-Tests ohne übersprungene Tests. `check_database.py` bestand mit frischem Cluster, Rollback/Unique-Constraint und zwei konkurrierenden Updates; Serverende bestätigt. Bericht: `.local/database-tests/run-vx4vns34/report.json`. Die vollständige Produktprüfung blockierte weiterhin wie vorgesehen.

Nicht erneut ausgeführt: Supabase Auth/API und SQL-Analyse, weil deren unveränderte lokale Umgebung gestoppt bleibt. Der vorhandene Bericht `.local/supabase-tests/c6babc3547e14f558eec609a2d0c97ad.json` wurde gezielt geprüft: 47 bestandene Aussagen. Dies ist ein früherer Nachweis, keine erneute Backend-Abnahme. Der frühere echte Dokumentationslauf (`run-explain-event-confirmation-retry2-aff86e86`) und die App-Simulation (`app-proof-38d32392`) wurden anhand ihrer Berichte bestätigt. Kein neuer Modellaufruf, Browserintegrationstest oder nativer Plattformtest.

Die Nutzerfreigabe gilt für den nach dieser Prüfung lokal gesicherten Kontrollcommit; seine vollständige SHA wird im Abschlussbericht genannt. Keine konkrete Aufgabenfreigabe erzeugt und `approve` nicht ausgeführt. Der nächste App-Auftrag benötigt weiterhin eine eigene menschliche Aufgabenfreigabe. Bestehende Grenzen bleiben: Loopback-Zugriff anderer lokaler Dienste möglich, keine vollständige Isolation gegen absichtlich bösartigen Code, keine Gesamt-Diskquote, kein Backend-Coding-Scope und keine vollständige Produktabnahme. Kein Merge, Push oder Deployment.

# Codex als Entwicklungspartner

Historischer Ausgangsstand: 24.09.2026. Dieser Ablauf betrifft das lokale Community-Access-Repository. Codex ist bereits in Benutzung; in Schritt 04 wird keine zusätzliche Codex-Installation oder Kontoeinrichtung vorgenommen.

## Ein kleiner Arbeitszyklus

1. **Verstehen:** Projektstamm, Git-Status, geltende Anweisungen und passende Dokumentation lesen. Keine privaten Daten als Beispiele verwenden.
2. **Planen:** Ein konkretes Ergebnis, die betroffenen Dateien und die passenden Prüfungen nennen. Unbekannte Begriffe kurz erklären.
3. **Freigabe zuordnen:** Ein ausdrücklicher Arbeitsauftrag erlaubt die darin enthaltenen gewöhnlichen lokalen Änderungen. Zusätzliche riskante Aktionen benötigen die Freigabe gemäß [AGENTS.md](../AGENTS.md). Bereits erteilte Freigaben nicht unnötig erneut abfragen; technische Freigabedialoge können trotzdem erforderlich sein.
4. **Ändern:** Auf einem Aufgabenbranch klein und nachvollziehbar arbeiten. Bestehende Änderungen erhalten. Keine Erweiterung um Backend, neue Dienste oder Veröffentlichung ohne Auftrag.
5. **Prüfen:** Nur tatsächlich beobachtete Ergebnisse als bestanden melden. Fehlgeschlagene und nicht ausgeführte Tests sowie deren Gründe nennen.
6. **Sichern und erklären:** Diff prüfen, konkrete Dateien auswählen, im autorisierten Umfang lokal committen und den Nutzen sowie offene Grenzen zusammenfassen.

Beispiel für eine harmlose Folgeaufgabe: „Ergänze im README einen Link zur bestehenden Setup-Anleitung. Nenne zuerst Plan und betroffene Dateien, ändere nur diesen Link und prüfe danach Ziel und Diff.“

## Anweisungen und technische Rechte auseinanderhalten

`AGENTS.md` beschreibt, wie Codex arbeiten soll. Dateisystem- und Netzwerkberechtigungen begrenzen dagegen, welche Aktionen ein Werkzeug tatsächlich ausführen kann. Ein Leseverbot in Markdown oder ein Eintrag in `.gitignore` macht eine Datei technisch nicht unlesbar. Auch eine lokale Programmausführung beweist keine ausschließlich lokale Modellverarbeitung.

Die offiziellen Hinweise unterscheiden globale Anweisungen und projektbezogene Dateien. Ein `AGENTS.override.md` kann am selben Ort Vorrang vor `AGENTS.md` haben. Bei einer neuen Sitzung die berücksichtigten Quellen zusammenfassen lassen; aus der bloßen Existenz einer Datei folgt noch kein Nachweis, dass eine bestimmte Sitzung sie automatisch geladen hat. [Offizielle Anweisungsdokumentation](https://learn.chatgpt.com/docs/agent-configuration/agents-md)

Technische Profile können Schreib- und Lesezugriffe sowie Netzwerkzugriff begrenzen. Die Namen und Einzelheiten können sich ändern; keine alten Konfigurationsbeispiele ungeprüft übernehmen. In diesem Schritt wird keine globale Konfiguration verändert. [Offizielle Berechtigungsdokumentation](https://learn.chatgpt.com/docs/permissions)

## Historischer Befund vom 24.09.2026

| Bereich | Beobachtung und Grenze |
| --- | --- |
| Arbeitsverzeichnis | Git-Projektstamm `Scene Access`; zu Beginn sauberer Branch `main`. |
| Globale Anweisungen | `~/.codex/AGENTS.md` ausdrücklich gelesen. Sie erlaubt Cloud-Projekte im jeweiligen Nutzerauftrag; diese Aufgabe autorisiert keine Veröffentlichung. |
| Projektanweisungen | Vorher keine `AGENTS.md` oder `AGENTS.override.md` im Projekt gefunden. Die neue Root-Datei wird in dieser Sitzung ausdrücklich gelesen und angewendet. |
| Nutzeranweisungen | Die im Gespräch vorgegebenen Community-Access-Regeln gelten weiter und wurden in der Projektdatei festgehalten. |
| Dateirechte | Die Sitzung meldet ein eingeschränktes, standardmäßig lesendes Dateisystemprofil. Lesen des README gelang; eine Schreiböffnung ohne Eskalation wurde verweigert. Beim Test wurden keine Bytes geschrieben. |
| Zusätzliche Freigaben | Repository-Schreibzugriffe erfolgen über die vorhandenen Freigabemechanismen. Es gibt bereits genehmigte Befehlsregeln aus früheren Schritten; daher nicht behaupten, jeder Schreibversuch müsse einen neuen Dialog auslösen. |
| Lesegrenze | Der Test belegt keine auf dieses Repository beschränkte Leseberechtigung. Zum Beispiel waren die globale Anweisungsdatei und Skill-Dateien außerhalb des Repositorys lesbar. |
| Netzwerk | Laut Sitzung eingeschränkt; offizielle Dokumentation konnte über das Web-Werkzeug abgerufen werden. Keine allgemeine Netzwerksperre oder identische Rechte aller Werkzeuge nachgewiesen. |
| Dateninventar | Bekannte Projektdateien sind Dokumentation und Git-Regeln; zusätzlich besteht die selbst angelegte, ignorierte synthetische Git-Testkonfiguration. Keine produktiven Zugänge oder echten Bewerbungen wurden für dieses Projekt angelegt. Keine umfassende Inhaltsprüfung ignorierter Dateien, des Rechners oder verbundener Dienste durchgeführt. |
| Modell, Konto, Kosten | Die laufende Sitzung ist nutzbar. Tarif, Abrechnung und aktuelle Kontingente wurden nicht geprüft oder verändert; es wurde kein zusätzlicher Modelldienst eingerichtet. |

Kein Vollzugriff wurde aktiviert. Die Regeln sind für die weitere Arbeit geeignet, aber keine Garantie gegen Datenabfluss. Echte Secrets und Bewerbungen müssen weiterhin aus dem KI-Arbeitsbereich fernbleiben; eine strengere technische Lesebegrenzung wäre eine separate, ausdrücklich freizugebende Konfigurationsaufgabe.

## Dokumentationsaufgabe als Übung

Die beauftragte Aufgabe für Schritt 04 ist selbst der harmlose Arbeitszyklus: Projektregeln ablegen, diese Erläuterung schreiben und beide Dateien im README verlinken. Der Nutzerauftrag „Weiter“ setzt den zuvor angekündigten Schritt 04 fort. Die konkrete Dateiliste und Prüfungen wurden vor der Änderung genannt; für das Schreiben greift zusätzlich die technische Freigabe.

Abnahmekriterien: genau `AGENTS.md`, `docs/codex-workflow.md` und `README.md` ändern; bestehende Produkt-, Setup- und Git-Dokumentation erhalten; relative Links und Markdown-Struktur prüfen; tatsächliche Rechte nicht mit Verhaltensregeln verwechseln; den vollständigen Diff prüfen und gezielt lokal committen.

Eine neue, unabhängige Codex-Sitzung zur automatischen Anweisungserkennung wurde nicht gestartet. Für eine spätere Kontrolle im Projektstamm fragen: „Welche Anweisungsquellen gelten hier, welche Dateien darfst du technisch lesen oder schreiben, und was wurde davon tatsächlich geprüft?“ Erst die Antwort dieser Sitzung ist ein weiterer Nachweis.

Flutter-Formatierung, Analyse und Anwendungstests werden für diese reine Dokumentationsaufgabe nicht wiederholt. Die vorhandene Demo-Abnahme steht in [setup.md](setup.md); App- und Backend-Berechtigungstests folgen erst nach ihrer Implementierung. Das Berechtigungsmodell `docs/access-model.md` ist noch nicht vorhanden und wird nicht als bestehende Quelle verlinkt.

## Manueller Einzelaufgaben-Runner

Ergänzung vom 25.09.2026. Der Runner bereitet überprüfbare Änderungen an Dokumentation und Dart-Lerncode vor. Er ist noch keine Automatisierung einer Flutter-/Supabase-App. [Architektur und Grenzen](decisions/0001-single-task-runner.md), [Prüfungen und Bestandsaufnahme](verification.md), [Aufgabenvorlage](tasks/README.md) und [Designregeln](design-rules.md) ergänzen die vorhandene Produktgrundlage.

### Vor dem ersten echten Lauf

1. Änderungen an Runner, Tests und Steuerdokumenten gemeinsam prüfen und bewusst lokal committen. Den vollständigen 40-stelligen Kontroll-Commit ausdrücklich freigeben. Eine automatisch angelegte Freigabe ist kein Ersatz für diese Entscheidung. Der Runner muss bytegenau zu diesem Commit passen.
2. `python3 -I scripts/check_project.py` ausführen. Python `-I` ignoriert benutzerspezifische Python-Pfade. Der Aufruf prüft die aktuellen versionierten Dateien, echte Dart-Prüfungen und Runner-Tests; er installiert nichts. Neue Dateien vorher mit expliziten Pfaden auswählen. Erfolgreich ist ausschließlich der bestehende Lernprojektumfang.
3. Vor einem Modellaufruf Netzwerkzugriff, konkretes Modell und vorhandenen Tarif beziehungsweise mögliche Kosten freigeben. Keine Zugänge oder Rechte für Produktion oder Veröffentlichung verwenden. Ein separates, nur für Entwicklung bestimmtes Codex-Anmeldeverzeichnis manuell einrichten; normale Anmeldung nicht kopieren. Die CLI unterstützt `CODEX_HOME="<absoluter Entwicklungsordner>" /Applications/ChatGPT.app/Contents/Resources/codex login --device-auth`. Dieser Befehl meldet aktiv an und benötigt Netzwerk; er wurde hier nicht ausgeführt. Das Verzeichnis darf für V1 nur die reguläre Datei `auth.json` enthalten. Falls die CLI weitere Pflichtdateien benötigt, stoppt V1; nicht durch umfassendere Dateirechte umgehen.
4. Offene Prozessaufräum-Probleme aus der Bestandsaufnahme zuerst klären. Eine vorhandene lokale `cleanup-required`-Sperre nicht ungesehen entfernen. Erst nach bestätigtem Prozessende, gegebenenfalls nach einem vom Nutzer vorgenommenen Neustart, kontrolliert aufheben und Prüfungen wiederholen.

Alle folgenden Aufrufe erfolgen im Git-Projektstamm ohne Administratorrechte. Schreibende Aufrufe benötigen lokale Schreibfreigabe; `run` zusätzlich die separat genehmigte Modellverbindung. Es werden keine Dienste dauerhaft gestartet.

### Aufgabe ansehen und freigeben

Die Platzhalter vor Ausführung durch bewusst geprüfte Werte ersetzen. `task_base` ist der saubere aktuelle Projektstand; `task_control` ist der menschlich geprüfte Steuerstand. Beide sind vollständige Commit-IDs und dürfen nicht blind aus wechselnden Branchnamen abgeleitet werden.

```sh
task_base="VOLLSTAENDIGE_GEPRUEFTE_BASIS_SHA"
task_control="VOLLSTAENDIGE_FREIGEGEBENE_KONTROLL_SHA"
python3 -I scripts/task_runner.py dry-run docs/tasks/single-task.example.json --base "$task_base" --control "$task_control"
```

`dry-run` liest Aufgabe und lokale Commits. Er zeigt Dateiliste, Risiko, Abnahme, Prüfungen und `task_sha256`, schreibt keine Freigabe und ruft kein Modell auf. Er ist kein Testnachweis. Keine ignorierten Konfigurationen werden exportiert. V1 lehnt unprüfbare Dateitypen, Symlinks, übergroße Quellen und unbekannte Aufgabenscopes ab.

Nach inhaltlicher menschlicher Prüfung des Plans und des angezeigten Aufgabenhashes:

```sh
python3 -I scripts/task_runner.py approve docs/tasks/single-task.example.json --base "$task_base" --control "$task_control" --confirm-task-sha256 "GEPRUEFTER_AUFGABENHASH"
```

Nur der Mensch startet diese Freigabe. Erwartet wird `Approval saved locally: explain-event-confirmation`. Das Programm speichert die gesamte Aufgabe mit Hash und Commit-Bindung unter `.local/task-runner/`. Eine geänderte Aufgabe oder erneute Ausführung braucht eine neue ID und neue Prüfung. Die Vorlage selbst ist keine Freigabe. Uncommittete Änderungen blockieren den Start.

### Genau einen Lauf starten

```sh
python3 -I scripts/task_runner.py run explain-event-confirmation --codex-home "/ABSOLUTER/ENTWICKLUNGSORDNER" --model "FREIGEGEBENES_MODELL" --timeout 600
```

Das Zeitbudget beträgt hier 600 Sekunden, maximal erlaubt sind 1800. Es gilt gemeinsam für Modellaufruf und Prüfungen, nicht neu pro Reparatur. Der Runner startet einen isolierten Export, prüft den unveränderten Ausgangsstand, fordert einen Dateivorschlag an, prüft ihn und erlaubt höchstens zwei Korrekturrunden. Die Freigabe wird vor dem ersten Versuch verbraucht; ein Abbruch erzeugt keine automatische Wiederholung.

Erwartete Ausgabe: JSON mit `status` und Pfad zu `report.json`. `ready_for_review` bedeutet nur: die implementierten Pflichtprüfungen bestanden. `failed` bedeutet ausgeschöpfte Reparaturen, `blocked` eine fehlende Voraussetzung oder Schutzverletzung. Rückgabecode 0 gilt nur für ein prüfbares Ergebnis; Fehler und Blockaden liefern ungleich 0. Bericht, `changes.patch` und `candidate/` bleiben lokal zur Prüfung erhalten. Bei früher Blockade kann der Patch fehlen.

Die Codex-CLI läuft nicht interaktiv, mit `-a never`, ignorierter Benutzerkonfiguration und Regeln, ohne vererbte Shell-/Cloud-Umgebung und mit deaktivierten Shell-, App-, Plugin- und weiteren Werkzeugfunktionen. Ein zusätzliches OS-Profil ist die eigentliche Grenze. Im Gegensatz zum vorhandenen interaktiven Tutorial darf dieser Coding-Agent weder Freigaben erzeugen noch seine Prüfvorgaben ändern. Die Optionen wurden an der vorhandenen CLI geprüft; der echte Anmelde- und Modellpfad bleibt ungeprüft. Siehe auch die [offizielle Dokumentation zu Agent-Freigaben](https://learn.chatgpt.com/docs/agent-approvals-security).

### Modellfreie Demonstration

```sh
python3 -I scripts/task_runner.py demo --base "$task_base" --control "$task_control"
```

Die Demo verwendet einen fest eingebauten synthetischen Dateivorschlag und echte lokale Prüfungen. Sie benötigt weder Modellnetzwerk noch Anmeldung, schreibt keine produktive Aufgabenfreigabe und kennzeichnet ihren Bericht mit `simulation_only` und `codex_executed: false`. Ein erfolgreiches Ergebnis belegt den Ablauf ab dem Vorschlag, keinen erfolgreichen Modellaufruf. Die automatisierten CLI-Tests führen diesen Weg in einem temporären synthetischen Git-Repository aus.

### Ergebnis übernehmen

Zuerst Bericht, vollständigen Patch und Kandidatendateien lesen. Fachliche Richtigkeit, Sprache, Scope und fehlende Prüfungen kontrollieren. Ein Patch ist keine automatische Freigabe. Die bewusste Übernahme auf einen eigenen Branch und ein gezielt ausgewählter Commit bleiben manuelle Schritte nach dem [Git-Workflow](workflow.md). Der Runner führt weder `git apply`, Merge, Push noch Deployment aus.

### Anweisung oder technische Grenze?

| Regel | Umsetzung und Nachweisgrenze |
| --- | --- |
| Nur freigegebene Aufgabe | Mensch prüft Inhalt und Risiko; Hash bindet gespeicherte Aufgabe. OS-Profil hält Freigabedateien vom Kind fern. Keine Signatur oder Benutzeridentitätsprüfung. |
| Schutz von Tests und Steuerung | Nur erlaubte Dateivorschläge werden übernommen; Kinder erhalten keine Schreibrechte am Kandidaten oder Kontrollverzeichnis. Kontrollcode wird mit gewähltem Commit verglichen. |
| Höchstens ein Lauf / zwei Reparaturen | Dateilock je Repository und feste Schleifengrenze im übergeordneten Runner. Andere Repository-Kopien und Prozesse des Kontoinhabers sind nicht global gesperrt. |
| Laufzeit / Aufräumen | Gemeinsame Deadline, Beendigung der Prozessgruppe, begrenztes Warten; bei unbestätigtem Ende Sperrdatei. Kein harter Kernel- oder VM-Watchdog. |
| Keine Produktionszugänge | Bereinigte Umgebung, keine geerbten Anmeldedateien und eingeschränkte Datei-Leserechte. Entwicklungsanmeldung und rein synthetischer Quelleninhalt bleiben menschlich zu kontrollieren. |
| Keine Veröffentlichung | Kein solcher Schritt im Runner; Tests ohne Netz, Modellprozess ohne Deployment-Werkzeuge. Modellnetzwerk ist nicht domainbeschränkt. |
| Produktqualität und Datenschutz | Produktvertrag, Designregeln und menschliches Review sind Anweisungen. Die vollständige App-/Backend-Durchsetzung ist noch nicht implementiert. |

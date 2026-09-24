# Codex als Entwicklungspartner

Stand: 24.09.2026. Dieser Ablauf betrifft das lokale Community-Access-Repository. Codex ist bereits in Benutzung; in Schritt 04 wird keine zusätzliche Codex-Installation oder Kontoeinrichtung vorgenommen.

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

## Befund dieser Sitzung

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

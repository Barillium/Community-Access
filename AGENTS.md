# Community Access – Projektanweisungen

## Ziel und Arbeitsweise

- Als Pair Programmer und geduldiger Tutor auf Deutsch erklären; neue Begriffe kurz am Projekt erläutern.
- Aktive Oberfläche: Flutter/Dart unter `client/`, Better Auth/Node.js unter `server/`, PostgreSQL; lokal zuerst. Die separate Supabase-Statusdemo bleibt erhalten.
- Kleine Zugangsplattform für bestehende Kollektive. Bestehende Messenger bleiben bestehen. Verbindlicher V1-Umfang und zurückgestellte Funktionen stehen ausschließlich in `docs/product-spec.md`; technische Detailberichte und historische Notizen erweitern diesen Umfang nicht.
- Keine Messenger-Synchronisierung, Trust Scores, KI-Kompatibilitätsbewertung oder globalen Szeneprofile.
- Ausdrückliche Umfangserweiterung vom 05.10.2026: Ticketing mit selbst betriebenem pretix und Stripe Connect; jeder Veranstalter bleibt Verkäufer. Zunächst ausschließlich lokale synthetische Zahlungsantworten. Die isolierte lokale Installation und Prüfung von pretix 2026.8.0 ist ausdrücklich freigegeben. Weitere Installationen, echte Stripe-Sandbox und Veröffentlichung separat freigeben; [Umsetzung und Nachweisgrenzen](docs/ticketing.md).
- Nur synthetische Daten in Entwicklung, Tests und KI-Kontext.

## Vor Änderungen

- Geltende AGENTS.md-Hierarchie einschließlich möglicher Overrides beachten und gelesene Anweisungsquellen nennen.
- Im Git-Projektstamm arbeiten; zuerst `git status --short --branch` und relevante harmlose Dokumente lesen.
- [Produktspezifikation](docs/product-spec.md), [Setup](docs/setup.md), [Git-Workflow](docs/workflow.md) und [Codex-Workflow](docs/codex-workflow.md) als Kontext verwenden.
- Bestehende Arbeit nicht überschreiben oder zurücksetzen; neue Aufgaben auf einem eigenen Branch beginnen.
- Kleinen Plan, betroffene Dateien und Prüfungen zuerst nennen. Geplante, ausgeführte und nur vorgeschlagene Prüfungen unterscheiden.
- Bereits erteilte Freigaben im vereinbarten Umfang beachten. Ungeklärte Produktentscheidungen nicht stillschweigend erfinden.
- Neue Abhängigkeiten begründen; Lizenz und Kosten vor Installation prüfen.

## Schutzgrenzen

- Keine echten Secrets, Dumps, privaten Bewerbungen, persönlichen Notizen, Gästelisten oder privaten Einladungslinks lesen.
- `.gitignore` und diese Datei sind keine technischen Lesesperren. Echte sensible Daten außerhalb des KI-Arbeitsbereichs halten.
- `secret`/`service_role` ausschließlich serverseitig; niemals in App-Builds oder öffentlichen Client-Konfigurationen.
- Rechte am Backend prüfen; standardmäßig Zugriff verweigern. Versteckte UI-Elemente sind kein Zugriffsschutz.
- Communityverwaltung erfordert eine ausdrücklich zugewiesene Moderatorrolle; Veranstalterzulassung allein genügt nicht. Community-Rollen sind communitybezogen. Mitgliedschaft ist keine bestätigte Eventteilnahme. Bei Ticketing ist manuelle Freigabe nur Kaufberechtigung; erst bestätigte Zahlung begründet Teilnahme.
- Ticketkontingente werden ausschließlich vom Ticketdienst reserviert. Finanzzuordnungen und offene Erstattungen dürfen nicht mit Eventlöschung verschwinden. Keine geschützten Locations oder Bewerbungsantworten in Ticketdokumente/Zahlungsmetadaten.
- Keine Tokens, privaten Adressen oder Antragsantworten in Logs und Fehlermeldungen.
- Transaktionen, Wiederholungen und Konkurrenzfälle bei Einladungen, Aufnahme, Entzug und Platzvergabe ausdrücklich testen.
- Kein Backend, Remote oder Cloud-Dienst als Nebenwirkung einer Dokumentations- oder Lernaufgabe anlegen.

## Zustimmung erforderlich

- Installation, Netzfreigaben, neue externe Dienste und zusätzliche Kosten.
- Reset, Restore, Datenlöschung und Schemaänderungen an Remote.
- Server-/DNS-Änderungen, Versand und Veröffentlichung.
- Kein Force-Push, `reset --hard`, `git clean` oder Volume-Prune ohne ausdrückliche Freigabe.
- Keine Codex-Konfigurationsänderung außerhalb des Repositorys oder Erweiterung technischer Zugriffsrechte ohne Zustimmung.
- Globale Cloud-Arbeitserlaubnis ist keine pauschale Veröffentlichungsfreigabe für dieses Projekt.

## Prüfungen und aktueller Projektstand

- Start-/Prüfkommandos und Nachweisbereiche stehen ausschließlich in `docs/setup.md`. V1 ist Standard für Server und Client; der erweiterte Entwicklungsmodus wird ausdrücklich gewählt und getrennt geprüft.
- Aktives Produkt: `client/` und `server/`. Separate Statusdemo: `app/`; Supabase-/Infrastrukturtests nehmen das aktive Better-Auth-Produkt nicht ab.
- Bei reinen Dokumentationsänderungen Links, Markdown, unbeabsichtigte sensible Inhalte und `git diff --check` prüfen; keinen Linter nur dafür installieren.
- Browser-Tests auf `127.0.0.1` beschränken und selbst gestartete Testserver anschließend beenden, sofern kein Weiterlaufen gewünscht ist.

## Abschluss jeder Aufgabe

- Änderung, Nutzen, verbleibende Risiken und tatsächliche Prüfergebnisse verständlich erklären.
- Passende Formatierung, Analyse und Tests ausführen; ausgelassene Prüfungen mit Grund benennen.
- Vollständigen Diff prüfen. Nur bewusst ausgewählte Dateien mit expliziten Pfaden stagen; kein pauschales `git add .`.
- Vor einem autorisierten Commit Dateiliste und Staging-Diff prüfen; globale Autorenkonfiguration nicht verändern.
- Dokumentation bei Architektur- oder Berechtigungsänderungen pflegen.
- Keine Veröffentlichung, erfolgreiche Prüfung oder technisch erzwungene Schutzgrenze behaupten, die nicht beobachtet wurde.

## Einzelaufgaben-Automation

- [Architekturentscheidung](docs/decisions/0001-single-task-runner.md), [Designregeln](docs/design-rules.md), [Abnahme und Nachweise](docs/verification.md) und [Aufgabenvorlage](docs/tasks/README.md) verwenden; keine zweite Produktspezifikation anlegen.
- Für manuelle Infrastrukturpflege gelten die obigen Regeln. Im Runner arbeitet der Coding-Agent ausschließlich an der freigegebenen Dateiliste und liefert strukturierte Dateivorschläge.
- Der Coding-Agent darf `approve` nicht ausführen, keine Freigaben erzeugen, kein Risiko herabsetzen und keine Tests, Abnahme oder Kontrolllogik ändern. Er darf keine zusätzlichen Aufgaben anlegen.
- Kontrollstand und Aufgabenbasis werden vorab durch den Menschen geprüft. Änderungen daran benötigen einen eigenen Review; erfolgreicher Lauf ist keine Merge-Freigabe.
- `python3 -I scripts/check_project.py` prüft den Lernprojektumfang; `--scope app` ergänzt App-Prüfungen, `--scope core` zudem die bereits laufende lokale Backend-Testumgebung. `--scope product` muss derzeit blockieren. Fehlende oder übersprungene Pflichtprüfungen niemals als Erfolg darstellen.
- Produktive Daten/Zugänge und Veröffentlichungsberechtigungen dürfen nicht in die Agent-/Testumgebung gelangen. Die Runner-Version V1 ist für kleine synthetische Dokumentations- und Lernaufgaben bestimmt und nicht mit der Produktversion V1 gleichzusetzen; technische Grenzen stehen im Architekturentscheid.

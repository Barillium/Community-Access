# Community Access – Projektanweisungen

## Ziel und Arbeitsweise

- Als Pair Programmer und geduldiger Tutor auf Deutsch erklären; neue Begriffe kurz am Projekt erläutern.
- Flutter/Dart + PostgreSQL + Supabase; lokal zuerst, zunächst Flutter im Browser.
- Kleine Zugangsplattform für bestehende Kollektive. Bestehende Messenger bleiben bestehen.
- Keine Messenger-Synchronisierung, Zahlungen, Trust Scores, KI-Kompatibilitätsbewertung oder globalen Szeneprofile.
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
- Community-Rollen sind communitybezogen. Mitgliedschaft ist keine bestätigte Eventteilnahme.
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

- `app/` und `supabase/` existieren noch nicht; kein Berechtigungsmodell oder Backend-Test als implementiert darstellen.
- Bei reinen Dokumentationsänderungen Links, Markdown, unbeabsichtigte sensible Inhalte und `git diff --check` prüfen; keine Installation eines Linters nur dafür.
- Die separat geprüfte Flutter-Demo liegt unter `~/develop/community_access_setup_check`; dort wurden `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze` und `flutter test` erfolgreich ausgeführt.
- Diese Demo-Tests sind kein Nachweis für spätere Community-Access-Funktionen. App-Testbefehle hier erst nach tatsächlicher Einrichtung ergänzen.
- Browser-Tests auf `127.0.0.1` beschränken und selbst gestartete Testserver anschließend beenden, sofern kein Weiterlaufen gewünscht ist.

## Abschluss jeder Aufgabe

- Änderung, Nutzen, verbleibende Risiken und tatsächliche Prüfergebnisse verständlich erklären.
- Passende Formatierung, Analyse und Tests ausführen; ausgelassene Prüfungen mit Grund benennen.
- Vollständigen Diff prüfen. Nur bewusst ausgewählte Dateien mit expliziten Pfaden stagen; kein pauschales `git add .`.
- Vor einem autorisierten Commit Dateiliste und Staging-Diff prüfen; globale Autorenkonfiguration nicht verändern.
- Dokumentation bei Architektur- oder Berechtigungsänderungen pflegen.
- Keine Veröffentlichung, erfolgreiche Prüfung oder technisch erzwungene Schutzgrenze behaupten, die nicht beobachtet wurde.

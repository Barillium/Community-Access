# Lokale Prüfung der Store-Vorbereitung · 09.10.2026

Branch `codex/store-launch-preparation-20261009`. Bestehende Änderungen wurden erhalten; kein Commit, Upload, Entwicklerkonto, DNS-/Cloudwechsel oder echter Versand. Gelesene Arbeitsanweisungen: globale Codex-AGENTS.md, Repository-AGENTS.md und vom Nutzer mitgeteilte Projektanweisungen; Flutter-Skill `ecc:dart-flutter-patterns`. Keine Unteragenten eingesetzt.

## Tatsächlich ausgeführt

| Prüfung | Ergebnis | Nachweisgrenze |
| --- | --- | --- |
| Flutter-Formatierung der betroffenen Dart-Dateien | 20 Dateien, keine Änderung nötig | Kein natives Kompilieren |
| Flutter-Analyse | Ohne Befund | Keine vollständige Sicherheitsprüfung |
| Vollständige Flutter-Tests | 292 bestanden | Widgets/Logik lokal |
| Neue Store-Tests separat | 5 bestanden | Konfiguration, Linkfilter, Bildneukodierung, Löschanfrage |
| Node: Store/HTTP/Public-Gateway | 8 bestanden | Ausgewählte Regressionen |
| Isolierte PostgreSQL-Löschanfragen | 4 bestanden | Eigenes Konto, Reauthentifizierung, fremde Rechte, Parallelität; keine Löschung |
| Bestehende Auth-Prüfung | 12 bestanden | Synthetische Konten |
| Bestehende private Mailprüfung | 2 bestanden | Synthetische Transportantworten, kein Zustellnachweis |
| Bestehender privater Zugang | 26 bestanden | Lokale HTTP/PostgreSQL-Abläufe |
| Bestehendes Ticketing | 14 bestanden | Synthetische Zahlungen |
| Web-Release-Kandidat | Erfolgreich gebaut | Kein iOS-/Android-Artefakt |
| Browserprüfung | 5 Prüfgruppen bestanden | Chromium mit lokalen synthetischen API-Antworten |
| iOS-Plists / Android-XML | Erfolgreich gelesen | Syntax, keine SDK-Prüfung |
| Diff-Leerzeichenprüfung | Bestanden | Einschließlich bestehenden Arbeitsstands |

Browsergrößen: 390×844, 768×1024 und 1440×1000. Startseite, leere Konto-E-Mail und unbestätigtes Altersfeld ab 16 überprüft; Hilfe und Löschseite auf Handygröße geprüft. Keine Seitenfehler oder externen Requests; eigener Server danach beendet. Vorschauen für Registrierung, Tabletstart und App-Icon zusätzlich visuell angesehen. Keine nativen Store-Screenshots.

Build: `.local/store-launch/candidates/20261009T153905401511Z/web`. Browserbilder und maschinenlesbarer Bericht: `.local/store-launch/browser/`. Lokale Testprotokolle: `/private/tmp/community-access-store-*.log`. Diese Nachweise enthalten ausschließlich synthetische Prüfabläufe und ersetzen keine Geräte-, Anbieter- oder Rechtsabnahme.

## Blockiert oder nicht ausgeführt

Die Startprüfung meldet 3 bestandene statische Voraussetzungen und 14 offene Voraussetzungen: fehlendes vollständiges Xcode und Android-SDK sowie 12 fachliche/betriebliche Nachweise aus `release-plan.json`. Rückgabecode 2 ist erwartet. Native Buildversuche stoppten an der fehlenden Werkzeugkette; keine SDKs installiert und keine Lizenzen angenommen. Geräte, VoiceOver/TalkBack, echte Anbieterzahlungen/Erstattungen, mobile Browsersitzungsübergabe, Löschbearbeitung, Supportzustellung und Produktionswiederherstellung nicht geprüft.

Der produktive Produkt-/Ticketbetrieb ist noch nicht implementiert. Die vorhandenen Anbieter akzeptieren ausdrücklich nur synthetische Zahlungen. Vorbereitung und bestandene lokale Tests sind keine Startfreigabe. [Offene Arbeit und Betriebsübergabe](operations.md), [Altersvoraussetzungen](age-review.md).

## Reproduzieren

Die Befehle für App-/Backendprüfungen stehen in [README.md](README.md). Die Browserprüfung benötigt das bereits vorhandene Playwright; sie installiert nichts:

```sh
CA_PLAYWRIGHT_MODULE=/pfad/zum/vorhandenen/playwright node scripts/check_store_candidate_browser.mjs .local/store-launch/candidates/20261009T153905401511Z/web
```

Das Skript leitet ausschließlich die API-Aufrufe im Prüfbrowser auf den eigenen Loopbackserver um. Die gebauten Kandidatendateien bleiben unverändert. Ohne diese synthetische Umleitung ist der gewählte Produktionsserver noch nicht verfügbar.

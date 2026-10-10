# Lokales Setup

Stand: 10.10.2026. Aktive App: Flutter unter `client/`, Better Auth/Node.js unter `server/`, PostgreSQL und synthetisches Ticketing. Ausschließlich lokale synthetische Daten. Diese Anleitung installiert nichts und veröffentlicht nichts.

## Voraussetzungen

Vorhanden sein müssen Node.js, PostgreSQL 17 unter dem im Startskript angegebenen Homebrew-Pfad, Flutter/Dart sowie die bereits eingerichteten Node-/Flutter-Abhängigkeiten. Fehlt etwas, nicht ungefragt installieren. Eine neue Installation benötigt Lizenz-/Kostenprüfung und Freigabe. Die installierte native pretix-Version ist optional für die separate native Regression; sie wird durch die folgenden Befehle nicht installiert.

Alle Befehle beginnen im tatsächlichen Git-Projektstamm. Auf diesem Rechner liegt er auf der SSD; ein alter Dokumente-Pfad kann eine symbolische Verknüpfung sein. Keine globale Codex-Konfiguration ändern, um diese Verknüpfung zu umgehen.

## Flutter mit Better Auth starten

Für eine vollständige V1-Demo in Terminal 1:

```sh
CA_PRODUCT_EDITION=v1 python3 -I scripts/local_auth.py --ticketing-demo
```

Dieser ausdrücklich gewählte Demostart erzeugt eine frische synthetische Datenbank, beschränkt HTTP auf `127.0.0.1:8000`, startet den synthetischen Ticketdienst auf `127.0.0.1:8400` und verwendet private Unix-Sockets für PostgreSQL. Er überschreibt keine persistente Demo. Alle Zahlungen sind simuliert.

In Terminal 2:

```sh
cd client
flutter run --no-pub -d chrome --web-hostname=127.0.0.1 --web-port=8300
```

V1 ist der Standardbuild. Synthetische Demokonten: `guest.a@example.invalid`, `host.a@example.invalid`, `team@example.invalid`; ausschließliches Fixture-Passwort `Synthetic-2026!`. Das lokale Testpostfach liegt unter `http://127.0.0.1:8000/testing/mailbox`; kein externer Versand. Diese Fixturewerte sind keine produktiven Zugangsdaten.

Flutter mit `q`, den zugehörigen Demostart mit Strg+C beenden. Der Startwrapper beendet seine eigenen Datenbank-/Ticketprozesse; erhaltene synthetische Diagnosedaten nicht ungeprüft löschen. Bereits laufende fremde Prozesse nicht beenden.

Ein Authstart mit `python3 -I scripts/local_auth.py --persistent` erhält synthetische Konten/Sitzungen über Neustarts, besitzt aber nicht automatisch den vollständigen Ticket-Demoumfang. `--fresh` startet eine neue Auth-Testumgebung. Keiner dieser Modi ist Produktivbetrieb.

## Synthetischer Zugangsablauf – 05.10.2026

```sh
python3 -I scripts/local_auth.py --access-demo
```

Frische synthetische Konten für Veranstalteraufnahme, Moderatorzuweisung, persönliche Einladungen, Mitgliedschaft und Eventzusage. Veranstalteraufnahme allein vergibt keine Communitymoderation. Flutterstart wie oben. Diese Überschrift bleibt für bestehende Dokumentationsverweise erhalten.

## Lokale Ticketing-Demo 05.10.2026

`--ticketing-demo` oben ist der V1-Einstieg mit Standardticket. `--native-ticketing-demo` verwendet die bereits installierte isolierte pretix-Version mit zusätzlichem Plugin. Kein echter Stripezugriff, kein Download. Native Kategorien gehören zum erweiterten Entwicklungsmodus.

## V1 und erweiterten Modus getrennt prüfen

```sh
python3 -I scripts/local_auth.py --test-v1
node --test server/product_scope.test.mjs
cd client
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub test/v1_scope_test.dart
```

Bestehende Flutterregressionen, weiterhin aus `client/`:

```sh
flutter test --no-pub --dart-define=CA_PRODUCT_EDITION=extended --exclude-tags=v1
```

Bestehende Integrationssuiten, wieder aus dem Projektstamm:

```sh
python3 -I scripts/local_auth.py --test
python3 -I scripts/local_auth.py --test-access
python3 -I scripts/local_auth.py --test-directory
python3 -I scripts/local_auth.py --test-ticketing
python3 -I scripts/local_auth.py --test-private-access
python3 -I scripts/local_auth.py --test-native-ticketing
```

Diese bestehenden Testmodi wählen standardmäßig `extended`, um den erhaltenen Ausbau weiterhin zu prüfen. `--test-v1` erzwingt V1. Jede Integrationssuite verwendet eine eigene synthetische Umgebung und beendet ihre Dienste. Backendläufe mit festen Datenbank-/Dienstports nacheinander ausführen.

Zur bewussten lokalen Nutzung des erweiterten Modus müssen beide Seiten übereinstimmen: Serverstart mit `CA_PRODUCT_EDITION=extended`, Flutter mit `--dart-define=CA_PRODUCT_EDITION=extended`. Ein Requestparameter aktiviert ihn nicht. Für einen separaten V1-Webbuild ohne Installation:

```sh
cd client
flutter build web --release --no-pub --no-web-resources-cdn --pwa-strategy=none --output=/private/tmp/community-access-v1-web
```

Browserprüfungen nur auf `127.0.0.1`; eigene Testserver anschließend beenden. Ein Build ist kein Nachweis für reale Geräte oder Livebetrieb.

## Projekt-App starten und prüfen

Die separate Statusdemo liegt unter `app/`. Ihre Formatierung, Analyse und Tests werden dort ausgeführt; sie prüfen weder Better Auth noch Ticketing. Historische Werkzeugeinrichtung und Runner-Abnahmen bleiben in der [Prüfhistorie](verification.md) dokumentiert.

## Getrennte lokale PostgreSQL-Testdatenbank

`python3 -I scripts/check_database.py` prüft synthetische Infrastruktur. Die separate Supabase-Demo folgt [ADR 0002](decisions/0002-local-supabase-core.md). Der ältere Runner und seine Scopes stehen in [Codex-Workflow](codex-workflow.md); `--scope product` bleibt dort ausdrücklich blockiert.

## Grenzen vor echtem Start

Betreiber-/Verkäuferdaten, gewählte Provision, Vertrags-/Datenschutz-/Aufbewahrungsentscheidungen, echte Anbieter-Testzahlungen und Zustellung, Hosting, Backup-/Wiederherstellungsnachweise und Geräteabnahme bleiben gesondert erforderlich. Store-Kandidaten und native Projekte sind Vorbereitung, keine Einreichung oder Freigabe. `private-mail` ist ein gesonderter Kontobetrieb und kein Produkt-/Ticketbackend. Private Konfigurationen oder Secrets nicht für diese Anleitung lesen.

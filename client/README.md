# Community Access · aktive Flutter-App

Stand: 10.10.2026. Die aktive Oberfläche verwendet Better Auth/Node.js und PostgreSQL unter `../server/`. `../app/` ist eine separate Statusdemo. Maßgeblich sind [Produktspezifikation](../docs/product-spec.md) und [Setup](../docs/setup.md).

## V1 als Standard

Öffentliche/private Einzelveranstaltungen, E-Mail-Konto mit Wiederherstellung, persönliche Communityaufnahme, Eventanfrage/Zusage, geschützte Location, Standardtickets, Belege, Erstattung und Einlass sind angebunden. Veranstalterverwaltung, Communitymoderation, Plattformteam und Scanner bleiben getrennte Berechtigungen.

`ProductScope` wählt beim Build standardmäßig V1. Zurückgestellte Funktionen fehlen in der Oberfläche; der Backendprozess begrenzt dieselben Wege. Der erweiterte Entwicklungsmodus wird ausschließlich bewusst mit `--dart-define=CA_PRODUCT_EDITION=extended` gebaut und benötigt den entsprechend gestarteten Server.

## Start und Prüfung

Backendstart, Voraussetzungen, Fixturekonten und vollständige Prüfkommandos stehen ausschließlich in der [Setup-Anleitung](../docs/setup.md#flutter-mit-better-auth-starten). Aus diesem Ordner:

```sh
flutter run --no-pub -d chrome --web-hostname=127.0.0.1 --web-port=8300
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub test/v1_scope_test.dart
flutter test --no-pub --dart-define=CA_PRODUCT_EDITION=extended --exclude-tags=v1
```

Keine automatische Paketinstallation. V1-Tests und bestehende Ausbau-Regressionssuite werden getrennt ausgeführt. Eigene Browser-Testserver anschließend beenden.

## Konto, Datenschutz und Darstellung

Die Anmeldung wird serverseitig geprüft und im selben Browser über HttpOnly-Cookie wieder aufgenommen. Das signierte Clienttoken bleibt flüchtig; keine Speicherung in Browserstorage. Veraltete Antworten nach Kontowechsel werden verworfen. DE/EN-Bedientexte und responsive Darstellung bleiben erhalten; Veranstalterinhalte werden nicht automatisch übersetzt.

Informations-, Support- und Kontolöschungsseiten bleiben erreichbar. Die Löschfunktion erzeugt eine geschützte Anfrage und behauptet keine bereits erfolgte Löschung. Betreiber-/Rechtstexte bleiben unvollständige Entwürfe. Änderungen an den Informationstexten sind mit den statischen HTML-Seiten abzugleichen.

## Native Vorbereitung

`ios/` und `android/` bleiben erhalten. Storebuilds, Altersvoraussetzungen, mobiler Checkout-Handoff, echte Geräte/Assistenztechnik und Veröffentlichung sind gesondert abzunehmen. Der lokale Webbuild und synthetische Zahlungen sind kein nativer Startnachweis.

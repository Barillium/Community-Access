# Lokaler Betrieb und Wiederanlauf

V1 startet nach [Setup](../setup.md). Die folgenden Kategorienabläufe und die dafür gedachte Browserprüfung benötigen ausdrücklich den erweiterten Modus auf Server und Client. Standardticketing, Abgleich, Belege, Erstattungen und Einlass bleiben in V1 aktiv. Maßgeblicher Umfang: [Produktspezifikation](../product-spec.md).

## Grenzen

Keine echten Zahlungen, neue Anbieter, Downloads, Remote-Migration oder Veröffentlichung. Kategorien laufen im vorhandenen synthetischen Vertragsdienst oder im ausdrücklich freigegebenen lokalen pretix 2026.8.0. Native Artikel tragen ein Kategorienkontingent und zusätzlich das gemeinsame Eventkontingent. Der vorhandene Einzelartikel-, PDF-, Gebühren- und Erstattungsablauf bleibt erhalten.

## Reproduzierbare Prüfungen

Im Projektstamm:

```sh
python3 -I scripts/local_auth.py --test-private-access
python3 -I scripts/local_auth.py --test-ticketing
python3 -I scripts/local_auth.py --test-access
python3 -I scripts/local_auth.py --test-directory
python3 -I scripts/local_auth.py --test-native-ticketing
```

Jeder Lauf besitzt eine neue synthetische PostgreSQL-Umgebung. Backend als auth_app, Ticketdienst als pretix_app, Bootstrap als separater Eigentümerprozess. Netzwerkdienste nur Loopback, Datenbanken nur private Unix-Sockets. Die Testumgebung stoppt ihre Dienste im finally-Pfad und erhält den synthetischen Zustand zur Diagnose. Kein Reset persistenter Demodaten.

## Abgleich und Sperrfolgen

Bestehender Abgleich bleibt Quelle für Zahlungsstatus; Browserrückleitung bestätigt keine Zahlung. Direkt vor Codeausgabe und Einlassprüfung wird der Zahlungsstand erneut abgeglichen. Ist der Ticketdienst nicht erreichbar, gibt es keine positive Einlassbestätigung. Bei Wiederanlauf werden offene Reservierungen und Erstattungsaufträge erneut gelesen. Anbieterreferenzen und Refund-ID bleiben stabil. Bei Zahlungsbestätigung prüft die App aktuellen privaten Zugang unter demselben Zugangs-Schreiblock wie Sperrvorgänge. Sperre zuerst → keine aktive Ausstellung; Zahlung zuerst → anschließende Sperre setzt admission_hold und erzeugt Erstattungsprüfung. Zahlungs-, Erstattungs- und Einlassstatus bleiben getrennt. Keine automatische Wiederbelebung stornierter oder erstatteter Tickets.

Katalogfehler: provider_ready=false hält Verkauf geschlossen. Dieselbe Kategorienversion kann wiederholt zum Ticketdienst übertragen werden. Gesamtkapazität wird im Ticketdienst unter dessen Transaktionslock geprüft, nicht im Client.

## Aufbewahrung und Rücknahme

Für neue Datenklassen nur Vorschau, keine Ausführung. Kategorien, Sperren und Einlassreferenzen verhindern versehentliches kaskadierendes Entfernen. Alte Eventbereinigung muss diese Referenzen erhalten und geschützte Inhalte getrennt behandeln. Backups/WAL, Browserreste und externe Anbieter sind keine nachgewiesen gelöschten Daten.

Bei Pilot-Rücknahme neue Käufe deaktivieren; laufende Zahlungen weiter abgleichen und Finanznachweise behalten. Neue additive Migration nicht destruktiv zurückrollen. Vor echtem Verkauf fehlen die in [decisions.md](decisions.md) genannten Entscheidungen und produktiven Nachweise.

## Pilotschalter

Im ausschließlich synthetischen Backend sind drei Umgebungsoptionen vorhanden. `false` deaktiviert den betreffenden neuen Ablauf:

| Option | Wirkung bei `false` |
| --- | --- |
| CA_PRIVATE_COMMUNITIES_ENABLED | Neue Einladungen, Aufnahmeanträge und Event-/Communityfreigaben pausieren |
| CA_PRIVATE_TICKETS_ENABLED | Neue Kategorien, Grants und Kategorienkäufe pausieren; Käuferkatalog liefert keine Kategorien |
| CA_TICKET_SALES_ENABLED | Alle neuen Reservierungen pausieren; Kaufbuttons werden deaktiviert |

Im lokalen Testmodus sind die Optionen standardmäßig aktiv. `CA_TICKETING_SYNTHETIC=true` ist weiterhin explizit nötig; echte/private Mail- und Produktionsmodi lehnen synthetisches Ticketing ab. Ein Schalter startet keinen produktiven Dienst. Schalterwechsel erfolgt durch Neustart mit derselben bestehenden synthetischen Datenbank, niemals durch Austausch des Bestands. Bestellnachweise, Zahlungsabgleich, offene Erstattungen und Moderationsmaßnahmen bleiben verfügbar. Ein bereits bezahltes oder reserviertes Ticket wird nicht allein durch Abschalten neuen Verkaufs rückgängig gemacht.

## Rollen und Regeln

Die Tabellen `ca_host` und `ca_profile_community` sind keine Communityadministration. Neue Moderatorzuweisung: Plattformteam → policy/staff; danach Communityaufnahme, Regelversion, Veröffentlichungsrecht und Communityfreigabe durch die gültig zugewiesene Moderation. Entzug eines Veranstalterrechts entfernt keine unabhängig zugewiesene Moderationsrolle. Abgelaufene Moderator- und Scannerrollen werden bei jedem Abruf erneut geprüft.

Neue Eventveröffentlichungen benötigen die Communityfreigabe. Eigenständige Event-Sichtgrants erzeugen keine Profilfreigabe und keine Mitgliedschaft. Ein Kategoriengrant erweitert nie Eventzugang. Temporäre Einschränkungen und dauerhaft unabhängig bestätigte Ausschlüsse können über den Moderationsbereich aufgehoben werden; bezahlte gesperrte Tickets werden dadurch nicht automatisch wieder aktiviert.

`server/retention_config.mjs` enthält die getrennten Datenklassen mit `retention_days=null` und deaktivierter Ausführung. Der Vorschauendpunkt ist teambegrenzt und liefert ausschließlich aggregierte Mengen. Der Nutzer hat eine Ausführung bis zur beschlossenen Richtlinie ausgeschlossen. Bestehende Aufbewahrungslogik aus früheren Aufträgen wurde nicht zu einer neuen Frist umgedeutet.

## Browserprüfung

Nach lokalem Flutterbuild `--ticketing-demo` starten und `scripts/check_private_access_browser.mjs` ausführen. CA_PLAYWRIGHT_MODULE muss auf ein bereits vorhandenes Modul verweisen; das Skript installiert nichts. Es prüft ausschließlich Loopback, synthetische Konten und Testzahlungen, beendet seinen Browser und Webserver im finally-Pfad. Den separat gestarteten Demolauf anschließend beenden. Tokens bleiben im Speicher; Screenshot der manuellen Einlassseite maskiert Eingaben. Ergebnisse liegen in evidence/browser.

## Gemeinsame Auftrittsverwaltung

Das verantwortliche Konto öffnet in der Gastgeberverwaltung beim ausgewählten Auftritt „Gemeinsam verwalten“ und lädt ein bereits bestätigtes Konto per E-Mail-Zuordnung ein. Es wird keine E-Mail versandt. Das Empfängerkonto öffnet „Auftritte und Einladungen“ und nimmt die Einladung ausdrücklich an. Anschließend führt „Auftritt verwalten“ in die Verwaltung des zugeordneten Auftritts. Neue eigene Auftritte benötigen weiterhin eine separate Veranstalterzulassung.

Einladungen laufen nach sieben Tagen ab. Annahme, erneute Einladung und Entzug benötigen die angezeigte aktuelle Version; nach einer konkurrierenden Änderung zunächst aktualisieren. Nur das verantwortliche Konto kann Verwalter einladen oder entziehen und die Zahlungszuordnung ändern. Delegierte Verwalter können Angebote, Anfragen, Freigaben und Erstattungen bearbeiten, aber keine Communityrollen vergeben. Der Entzug wirkt bei jeder folgenden Backendaktion; bereits geöffnetes Formularspeichern wird abgewiesen. Offene von einem entzogenen Verwalter ausgestellte Profilaufnahme-Links werden nicht mehr eingelöst; unabhängig bereits erteilte Gastrechte bleiben getrennt.

Migration 0007 ergänzt Mitgliedschaften, Migration 0008 ergänzt den Aussteller offener Profilaufnahme-Links. Alte Links erhalten beim Upgrade das verantwortliche Konto als Aussteller. Keine Änderung bereits angewendeter Migrationen und kein destruktiver Rückbau. Die Ergänzung ist ausschließlich lokal mit synthetischen Daten geprüft; [Prüfbericht](collaboration.md) und Nachweise liegen separat unter evidence/collaboration.

# Gemeinsame Veranstalterverwaltung · 08.10.2026

Die Nutzerergänzung „Wenn mehrere Nutzer zum Veranstalter gehört, sollte diese den Auftritt zusammen verwalten können“ ist im lokalen synthetischen System umgesetzt. Ein Veranstalterauftritt kann mehrere angenommene Verwalter besitzen. Communitymoderation bleibt eine gesondert zugewiesene Rolle.

## Verhalten und Grenzen

Das verantwortliche Konto lädt bestätigte Konten unter „Gemeinsam verwalten“ ein. Die Einladung ist sieben Tage gültig. Das Empfängerkonto muss sie unter „Auftritte und Einladungen“ ausdrücklich annehmen, bevor es Verwaltungsrechte erhält. Es wird keine externe Nachricht verschickt. Jeder Verwalterzugriff prüft die aktive Annahme für genau den Auftritt und die fortgeltende Veranstalterzulassung des verantwortlichen Kontos. Weitere Auftritte desselben Eigentümers sind dadurch nicht freigegeben.

Angenommene Verwalter bearbeiten Profil, Events, Reihen, Veranstalter-/Eventformulare, Anfragen, Gastfreigaben, Ticketangebote und Erstattungen. Sie können Eventeinschränkungen und zeitlich begrenzte Einlassrollen verwalten. Profilweite Einschränkungen bleiben beim verantwortlichen Konto. Eigene neue Auftritte benötigen weiterhin die separate Veranstalterzulassung. Communityzuordnungen richten sich nach den Rechten des verantwortlichen Kontos des bearbeiteten Auftritts; fremde eigene Veranstalterrechte des Verwalters erweitern sie nicht.

Nur das verantwortliche Konto verwaltet Verwaltereinladungen und ihren Entzug sowie Änderungen der Zahlungszuordnung. `ca_organizer.owner_id`, Verkäuferkonto und Finanzzuordnungen bleiben erhalten. Es gibt keinen neuen Eigentümerwechsel oder Eigentümerentzug. Verwaltungsmitgliedschaften können das verantwortliche Konto nicht entfernen.

Ein Entzug beendet nachfolgende Verwaltungsaktionen auch in einem zuvor geöffneten Formular. Noch nicht eingelöste Profilaufnahme-Links prüfen das aktuelle Recht ihres Ausstellers. Unabhängig erteilte Gastfreigaben und bereits aktive Gastmitgliedschaften haben ihren eigenen Lebenszyklus. Annahme, erneute Einladung und Entzug verwenden Versionen; konkurrierende veraltete Schreibaktionen werden abgewiesen. Alle Änderungen teilen den bestehenden Zugangs-Schreiblock mit Event- und Zahlungsaktionen.

## Betroffene Dateien

- `server/organizer_access.mjs`, `organizer_members.mjs`: auftrittsbezogene Verwaltungsprüfung, Einladung, Annahme, Entzug und Audit.
- `server/migrations/0007-organizer-members.sql`, `0008-organizer-link-issuers.sql`, `access_migrations.mjs`: additive Mitgliedschaften und Linkaussteller; alte Migrationen unverändert.
- `server/directory.mjs`, `catalog.mjs`, `discovery.mjs`, `event_policy.mjs`, `private_access.mjs`, `ticketing.mjs`: gemeinsame Verwaltung bei weiterhin kanonischer Veranstalter-/Verkäuferzuordnung.
- `client/lib/organizer_members_page.dart`, `organizer_management_page.dart`, `main.dart`, `ticketing_pages.dart`, `app_language.dart`, `better_auth_api.dart`: Einladungs- und Verwaltungsoberfläche, verantwortliches Konto und deutsche/englische Meldungen.
- `server/private_access.test.mjs`, `access.test.mjs`, `client/test/organizer_members_test.dart`, `scripts/check_private_access_browser.mjs`: Berechtigungs-, Konkurrenz-, Upgrade-, Oberflächen- und Browsernachweise.

Vorbestehende Änderungen sind erhalten. Keine neuen Pakete, Installation, Veröffentlichung, Remote-Migration, echte Zahlung, Staging oder Commit.

## Tatsächlich ausgeführte Prüfungen

| Prüfung | Ergebnis | Nachweis |
| --- | --- | --- |
| Private Rechte einschließlich gemeinsamer Verwaltung | 20 bestanden, 0 fehlgeschlagen | [private.log](evidence/collaboration/private.log) |
| Aufnahme und Migrationen | 14 bestanden, 0 fehlgeschlagen | [access.log](evidence/collaboration/access.log) |
| Verzeichnis, Events, Projektionen und Suche | 57 bestanden, 0 fehlgeschlagen | [directory.log](evidence/collaboration/directory.log) |
| Ticketing und Erstattungen | 14 bestanden, 0 fehlgeschlagen | [ticketing.log](evidence/collaboration/ticketing.log) |
| Native pretix 2026.8.0 | 7 Tests und 7 zusätzliche Modell-/PDF-Prüfpunkte bestanden | [native.log](evidence/collaboration/native.log) |
| Flutter | 223 Tests bestanden | [flutter.log](evidence/collaboration/flutter.log) |
| Formatierung und Analyse | 99 Dateien ohne Formatabweichung, keine Analysebefunde | [format.log](evidence/collaboration/format.log), [analyze.log](evidence/collaboration/analyze.log) |
| Webbuild | Erfolgreich | [build.log](evidence/collaboration/build.log) |
| Chromium 151, ausschließlich Loopback | 10 Prüfpunkte, 0 Seitenfehler | [Browserergebnis](evidence/collaboration/browser/browser-result.json), [320px-Ansicht](evidence/collaboration/browser/shared-organizer-mobile.png) |

Die 112 Backendtests enthalten die übergeordneten vom Node-Runner gezählten Tests. Native Modell-/PDF-Prüfpunkte und Browserprüfpunkte werden separat gezählt. Neue Berechtigungstests prüfen insbesondere Annahme durch genau den Empfänger, konkurrierende Annahme und Entzug, Ablauf, Versionskonflikte, gemeinsame Profiländerung, unveränderten Eigentümer, getrennte Communityrechte, fremde Auftritte, Events, Kategorien, Reihen, Formulare, Freigaben, Erstattungen und geschlossenes Management nach Entzug. Der Upgrade-Test prüft auch die Ausstellerzuordnung alter Profilaufnahme-Links und wiederholte Anwendung.

Der Browserablauf prüft Einladung, Annahme, gemeinsame Profiländerung und Entzug eines Verwalters. Ein bereits offenes Formular kann nach Entzug nicht mehr speichern. Die neue Seite wurde bei 320 Pixel Breite visuell ohne Überlappung geprüft. Die sieben bisherigen privaten Ticket-/Einlass-/Moderationsprüfpunkte bleiben enthalten. Browserdatum: 08.10.2026, 21:32 UTC. Die gestarteten Browser-, Demo- und Datenbankdienste wurden beendet.

Eine zuvor veränderte Fehlerantwort an unberechtigte Konten wurde nach Regressionstest wieder auf das bestehende Verhalten begrenzt. Der Migrationstest wurde um die beiden erwarteten additiven Migrationen ergänzt. Fehlgeschlagene Zwischenstände zählen nicht als bestandene Prüfungen. Im Webbuild bleibt der bestehende Hinweis zur CupertinoIcons-Schriftfamilie; kein Paket wurde dafür installiert.

Dies ist ein lokaler synthetischer Funktionsnachweis. Echte Stripe-Zahlungen, produktiver Betrieb sowie Safari und reale Mobilgeräte wurden nicht geprüft. Die vereinbarte Aufbewahrungsvorschau bleibt ohne neue Löschfristen oder Ausführung. Weitere Grenzen des privaten Ausbaus stehen im [ursprünglichen Prüfbericht](report.md).

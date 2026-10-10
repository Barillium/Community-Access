# Prüfbericht · privater Ausbau · 08.10.2026

Dieser Bericht dokumentiert den ersten Abschlussstand. Die anschließend ausdrücklich gewünschte gemeinsame Auftrittsverwaltung ist im [Ergänzungsbericht](collaboration.md) mit aktuellen Nachweisen beschrieben: 112 Backendtests, 223 Fluttertests und 10 Browserprüfpunkte bestanden. Die unten stehenden Zahlen bleiben als Nachweis des vorherigen Standes erhalten.

Der freigegebene lokale Erstumfang ist auf `codex/private-access-roadmap-20261008` umgesetzt. Communities werden von ausdrücklich zugewiesenen Moderatoren verwaltet; Veranstalter bleiben für eigene Auftritte, Events und Verkäufe verantwortlich. Private Kategorien, unabhängige Zugangswege, Moderationsfälle mit Einspruch, Zahlungssperren und kontogebundener Online-Einlass sind integriert. Neue Aufbewahrungsausführung bleibt nach Nutzerentscheidung deaktiviert.

Die bestehende Better-Auth/Node/PostgreSQL-Architektur und die separate Supabase-Demo bleiben erhalten. Der Fahrplan schlägt Zieltabellen vor; Abweichungen und offene Organisationsentscheidungen sind in [decisions.md](decisions.md) begründet. Vorbestehende Änderungen wurden erhalten. Keine neue Installation, Remote-Migration, echte Zahlung, Veröffentlichung, Staging oder Commit.

## Tatsächlich ausgeführte Prüfungen

| Prüfung | Ergebnis | Nachweis |
| --- | --- | --- |
| Neue Berechtigungs-, Kategorie-, Moderations- und Konkurrenztests | 18 bestanden, 0 fehlgeschlagen | [private.log](evidence/private.log) |
| Bestehender Aufnahmeablauf | 14 bestanden, 0 fehlgeschlagen | [access.log](evidence/access.log) |
| Verzeichnis, Projektionen, Such-/Zähler-/Pagingrechte | 57 bestanden, 0 fehlgeschlagen | [directory.log](evidence/directory.log) |
| Ticketing, Abgleich und wiederholbare Erstattungen | 14 bestanden, 0 fehlgeschlagen | [ticketing.log](evidence/ticketing.log) |
| Native pretix-Modelle einschließlich Kategorien und gemeinsamer Kapazität | 7 bestanden, 0 fehlgeschlagen | [native.log](evidence/native.log) |
| Zusätzliche native Modell-/PDF-Prüfung | 7 Prüfpunkte bestanden | native_verification in native.log |
| Flutter-Tests für die aktive Oberfläche | 220 bestanden | [flutter.log](evidence/flutter.log) |
| Dart-Formatierung | 97 Dateien, keine Formatabweichung | [format.log](evidence/format.log) |
| Flutter-Analyse | Keine Befunde | [analyze.log](evidence/analyze.log) |
| Flutter-Webbuild | Erfolgreich | [build.log](evidence/build.log) |
| Browser, Chromium, ausschließlich 127.0.0.1 | 7 Prüfpunkte, keine pageErrors | [Browserergebnis](evidence/browser/browser-result.json) |
| SQL-Upgrade | Synthetischer Altbestand 0001/0002 → 0003–0006 und erneute Anwendung erfolgreich | private.log |
| SQL-Zugriffsplan als begrenzte Backendrolle | Eine berechtigte Kategorie; 0,788 ms Planung, 0,172 ms Ausführung im kleinen Fixture | private.log; kein Last-/Produktionsnachweis |

Die 110 Backendtests enthalten die vom Node-Runner gezählten übergeordneten Tests. Die sieben zusätzlichen nativen Prüfpunkte und die sieben Browserprüfpunkte werden separat gezählt. Vorläufig fehlgeschlagene Browserselektoren und ein während des getrennten Arbeitsimages unterbrochener Lauf wurden korrigiert beziehungsweise wiederholt; sie zählen nicht als erfolgreiche Läufe. Im Webbuild bleibt ein bestehender Hinweis zur nicht eingebundenen CupertinoIcons-Schriftfamilie. Es wurde dafür kein Paket installiert.

## Abnahmeszenarien aus dem Fahrplan

| Szenario | Beobachteter Umfang |
| --- | --- |
| A01–A05 | Anonym/Follower/Communitymitglied/persönlicher Eventgrant/Kategoriengrant: Event-, Profil- und Kategoriegrenzen; bekannte IDs bleiben geschützt |
| A06–A07 | Sichtbare Kategorie ohne Teilnahmefreigabe nicht kaufbar; freigegebener Gast kauft; ein aktives Ticket je Konto/Event über mehrere Kategorien |
| A08 | Sperre eines Communitywegs erhält bestätigten zweiten Communityweg oder gültigen Eventgrant |
| A09–A11 | Event-/Auftrittsmaßnahmen, fremde Zuständigkeit, vertraulicher Fall, kein Selbstreview, unabhängige dauerhafte Communitymaßnahme und Einspruch |
| A12–A13 | Konkurrenz um letzten Platz und verschiedene Kategorien unter gemeinsamer Kapazität; sowohl Vertragsdienst als auch native pretix-Quotas |
| A14 | Wiederholter Ablauf und verspätete Zahlung; keine neue Teilnahme nach Ablauf; native 15-Minuten-Reservierung gibt Bestand frei |
| A15–A16 | Clientpreise/Mengen/Währung abgelehnt; Anbieterantwort erneut auf EUR, Bestellung, Kategorie, Betrag, Verkäufer und Konto geprüft; doppelte Benachrichtigung und Rückzahlung wiederholbar |
| A17 | Sperre gleichzeitig mit Zahlung: kein unzulässig aktiver Einlass; admission_hold und Finanznachweis bleiben erhalten |
| A18–A19 | Bereits bezahltes Ticket bleibt bei reinem Verkaufsende gültig; gleichzeitige Entwertung genau einmal; fremde/abgelaufene Scannerrolle abgelehnt |
| A20 | HTTP-IDs, Rechteentzug, begrenzte SQL-Browserrolle, verspätete Flutter-Antworten und Kontositzung geprüft. Keine separate Storage- oder Realtime-Schnittstelle vorhanden; dafür kein Nachweis behauptet |
| A21–A22 | Käufer behält minimalen Beleg nach Sperre; vorübergehender Erstattungsfehler bleibt wiederholbar ohne weitere Erstattung |
| A23 | Frühere Event-/Antragsbereinigung und unabhängige Mitgliedschaft/Sperre in Regressiontests. Neue Datenklassen ausschließlich aggregierte Vorschau ohne Mutation, ausdrücklich keine neue Löschabnahme |
| A24 | Direkte SQL SELECT/INSERT/UPDATE/DELETE einer unberechtigten Browserrolle verweigert; Backend ohne DDL und ohne Selbstzuweisung von Teamrechten |
| A25 | Öffentliches Event mit privater Kategorie: allgemein sichtbares Event, Kategorie nur Berechtigten; bezahltes Ticket nach reinem Wegfall der Kaufmitgliedschaft weiter gültig |

Manipulierte Zahlungsbenachrichtigungen sind im lokalen Vertrag untrusted Hinweise, die den authentifizierten Anbieterabruf auslösen. Echte Stripe-Signaturen und Stripe-Sandbox wurden nicht eingeführt oder geprüft.

## Oberfläche und Bilder

Der Browser erstellt Kategorie und persönlichen Grant in Flutter, weist eine Scannerrolle zu, verweigert einem anderen Konto die Kategorie, kauft mit einem freigegebenen Konto und bestätigt die simulierte Zahlung. Der Zahlungsstatus wird direkt vor Tokenausgabe und Einlass mit dem Ticketdienst abgeglichen; ein bereits erstattetes Ticket wird auch bei zuvor bezahltem lokalen Stand abgewiesen. Die Onlineprüfung bestätigt einmal, verweigert den zweiten Versuch und zeigt bei Verbindungsunterbrechung keinen Erfolg. Verwaltung und Einlass wurden bei 320 Pixeln visuell kontrolliert; Formularabstände wurden anhand der Bilder korrigiert.

- [Private Kategorien, schmale Ansicht](evidence/browser/category-management-mobile.png)
- [Simulierte Zahlung](evidence/browser/category-payment.png)
- [Online-Einlass, Eingaben maskiert](evidence/browser/online-checkin-mobile.png)
- [Moderation, schmale Ansicht](evidence/browser/moderation-mobile.png)

Deutsche und englische Oberfläche verwenden übersetzte Aktions- und Feldbeschriftungen. Die bestehenden Aufnahmetexte nennen die Moderation. Veranstaltertexte und vertrauliche Falltexte werden nicht automatisch übersetzt. Native Tickets behalten den vorhandenen pretix-Dokumentpfad und erhalten im Konto zusätzlich den Plattformcode für manuelle Onlineprüfung; dafür besteht ein eigener Widgettest. Neue Kameraerkennung, Safari-/Mobilgerätprüfung und umfassende Barrierefreiheitsabnahme sind nicht nachgewiesen.

## Betroffene Dateien

- Backendregeln und Integration: server/access_policy.mjs, event_policy.mjs, access.mjs, catalog.mjs, discovery.mjs, directory.mjs, http.mjs, auth.mjs, access_migrations.mjs.
- Neue Fachbereiche: server/private_access.mjs, private_ticketing.mjs, retention_config.mjs sowie Migrationen 0003-private-access.sql bis 0006-publisher-permissions.sql.
- Zahlungs-/Inventarpfade: server/ticketing.mjs, pretix_client.mjs, synthetic_pretix.mjs, synthetic_pretix.sql.
- Native Erweiterung: pretix-plugin/community_access_pretix/service.py, models.py, local_urls.py, local_middleware.py und migrations/0003_service_type.py; Vendorcode unverändert.
- Oberfläche: client/lib/private_ticket_pages.dart, private_access_management_page.dart, ticketing_pages.dart, access_flow_page.dart, main.dart, better_auth_api.dart, app_language.dart, public_home_page.dart.
- Prüfungen und Fixtures: server/private_access.test.mjs, native_ticketing.test.mjs, access.test.mjs, directory.test.mjs, directory_fixtures.mjs, client/test/private_ticket_pages_test.dart, scripts/local_auth.py und check_private_access_browser.mjs. Bestehende Rechteassertionen wurden erhalten; Fixtures weisen die zusätzliche Moderatorrolle ausdrücklich zu.
- Dokumentation: docs/product-spec.md, access-flow.md, ticketing.md und docs/implementation/.

## Offene Entscheidungen und Einführung

Gemeinsame Verwaltung war beim ersten Abschluss noch offen. Der Nutzer hat sie anschließend ausdrücklich gewählt; sie ist mit angenommenen auftrittsbezogenen Verwaltern umgesetzt und [separat geprüft](collaboration.md). Der eindeutige Verantwortliche und die Trennung von Communitymoderation bleiben bestehen.

Vor echtem Verkauf fehlen Verkäuferangaben, Zahlungsempfänger, freigegebene Provision und Erstattungsverantwortung, beschlossene Aufbewahrungsfristen, echte Stripe-Sandbox und Betriebsabnahme. Die drei [Pilotschalter und Wiederanlaufregeln](operations.md) wurden lokal geprüft. Der übergreifende Einzelaufgaben-Runner, `app/` und die Supabase-Statusdemo wurden nicht verändert oder als vollständiges Produkt abgenommen. Der `product`-Scope bleibt gemäß Projektanweisung blockiert.

Die während dieser Aufgabe gestarteten Demo-, Browser- und Datenbankdienste wurden nach dem abschließenden Browserlauf beendet. Dokumentationslinks, JavaScript-Syntax und `git diff --check` wurden ohne Befund geprüft.

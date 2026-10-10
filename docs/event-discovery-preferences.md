# Evententdeckung und Gastpräferenzen · 04.10.2026

> Einordnung für V1 · 10.10.2026: Dieser datierte Detailbericht beschreibt den damaligen Implementierungsstand einschließlich des erhaltenen erweiterten Modus. Maßgebliche Produktregeln und Umfang stehen ausschließlich in der [Produktspezifikation](product-spec.md); aktuelle Start- und Prüfbefehle im [Setup](setup.md). Historische Statusangaben und Prüfergebnisse sind keine heutige Funktions- oder Betriebsfreigabe.

Die Anforderungen stehen in der [Produktspezifikation](product-spec.md#verbindliche-erweiterung-vom-04102026). Dieser Text beschreibt den lokalen technischen Umfang; keine zweite Produktspezifikation und keine Veröffentlichungsfreigabe.

## Daten und Rechte

`server/discovery.sql` ergänzt ausschließlich die in `createAuth` überprüfte lokale synthetische Datenbank. Der private Mailmodus erhält weiterhin keinen Produktkatalog. Keine neue Abhängigkeit, kein externer Dienst und keine Remote-Migration.

`ca_guest_preferences` speichert vier begrenzte, freiwillige Listen pro Konto. `ca_community_follow` enthält die selbst gewählten öffentlichen Communities. `ca_organizer_visit` hat ausschließlich `user_id` und `profile_id`: kein Eventschlüssel, keine Besuchszeit, kein Zähler. `ca_event_interest` und Eventmerklisten/-freigaben haben kaskadierende Event-Fremdschlüssel. `ca_profile_request` trägt die unabhängige Profilfreigabe ohne Eventbezug.

Persönliche Startseitenergebnisse übernehmen die Sichtbarkeitsregeln der normalen Eventabrufe. Seit dem 05.10.2026 verwendet die Startseitensuche denselben berechtigten Bestand über `scope=upcoming`. Die öffentliche Archivabfrage und das öffentliche Hero verwenden keine persönlichen Freigaben. Empfehlungen addieren Merkliste (8), Community-Folgen (4), besuchten Veranstalter (3) und Präferenztreffer (2); anschließend entscheiden ausschließlich der freigegebene Beginn und die Event-ID. Das sind transparente lokale Regeln, keine Aussage über einen Gast oder dessen Eignung. Die Oberfläche zeigt die verwendeten Gründe. [Gemeinsame Regeln und aktuelle Prüfergebnisse](unified-event-policy.md).

Semi-öffentliche Details verwenden dieselben Zeit-/Ortsbedingungen in Detailabruf, persönlichen Ergebnissen und der Gastgebervorschau. Unfreigegebene Orts-/Zeitfelder, Flyer und frei formulierte Zugänglichkeits-/Awarenesshinweise werden nicht an unberechtigte Leser ausgegeben. Öffentliche Beschreibung und Line-up sind bewusst öffentlich; eine Prüfung beliebiger Texte auf versteckte Orts-/Zeithinweise wird nicht behauptet. Private Profilnamen werden im öffentlichen Werbeeintrag verborgen.

Formulare gehören zum Veranstalterprofil; Fremdzuweisungen sind gesperrt. Titel, Felder und Versionen werden gespeichert. Änderungen erfordern die erwartete Version. Gleichzeitige Gästeanfragen und Gastgeberentscheidungen werden in Transaktionen mit Datensatzsperren behandelt. Ein begrenzter serverseitiger Fragenkatalog blockiert unbekannte Fragen und Strukturfehler. Er ersetzt keine juristische Einzelfallprüfung. Leitlinien: [DSGVO Artikel 5, 9 und 10](https://eur-lex.europa.eu/legal-content/DE/ALL/?uri=celex%3A32016R0679).

## Löschung und Grenzen

Die Frist beträgt exakt 168 Stunden ab dem vom Veranstalter eingetragenen tatsächlichen Ende, unabhängig von Sommer-/Winterzeit. Neue veröffentlichte und abgesagte Einträge ohne Endzeit werden abgewiesen. Vorhandene Altbestände mit fehlendem Ende werden nicht mit einem erfundenen Datum versehen; der Gastgeber muss sie ergänzen. Die API filtert abgelaufene Einträge, der lokale Server löscht bei Start, Anfragen und minütlich. Zwei gleichzeitige Bereinigungen werden mit einer transaktionalen Sperre serialisiert. Im Betrieb kann die physische Löschung zwischen zwei Minutenläufen liegen; während einer Abschaltung erfolgt sie erst beim Neustart. Bereinigungsfehler bei einem API-Aufruf führen zur Fehlerantwort.

Die aktive Eventzeile wird gelöscht. Dadurch verschwinden JSON-Inhalte/Flyer, Eventanfragen samt Antworten, Eventzugänge und Eventmerklisten. Übrig bleiben auf Nutzerwunsch die reine Veranstalter-Besuchszuordnung sowie der unabhängige Profilzugang. Kontolöschung kaskadiert sämtliche eigenen Präferenz-/Zugangszeilen. Backups, WAL, bereits übermittelte Details, Empfängerkopien und Browser-/Betriebssystemreste sind hier nicht als gelöscht abgenommen. Diese Grenze ist angesichts des ausdrücklich genannten Schutzmotivs relevant.

## Prüfung

Abschließend am lokalen Checkout tatsächlich ausgeführt, ausschließlich mit synthetischen Daten:

| Prüfung | Ergebnis |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test` im Client | Bestanden, keine Formatänderungen erforderlich. |
| `flutter analyze --no-pub` | Bestanden, keine Befunde. |
| `flutter test --no-pub --reporter expanded` | 161 Tests bestanden. Neue Widgetprüfungen betreffen Carouselwechsel, Sprache, 320-/768-/1440-Pixel-Breiten mit doppelter Schrift, personalisierte Rückkehr, blockierte Formularfragen und Registrierung einschließlich Wiederholung nach einem Präferenzspeicherfehler. |
| `flutter build web --no-pub --no-web-resources-cdn --pwa-strategy=none --output=/private/tmp/community-access-discovery-web` | Bestanden. Bestehende Cupertino-Fontwarnung und Abkündigung des PWA-Parameters bleiben. Kein separater Wasm- oder nativer Build. |
| `python3 -I scripts/local_auth.py --test-directory` | 39 Tests bestanden, keine übersprungen. Echte lokale PostgreSQL und signierte Better-Auth-Sitzungen. `server/discovery.test.mjs` prüft zusätzlich Pflichtangaben, Formularrechte/-versionen, parallele Anfragen/Entscheidungen, getrennte Zeit-/Ortsfreigabe, Profilentzug, Empfehlungen, Kontolöschung, Veranstalter-Besuchszuordnung und kaskadierende Eventlöschung einschließlich konkurrierender Bereinigung. |
| `python3 -I scripts/local_auth.py --test` | Zehn Auth-Tests bestanden, keine übersprungen. |
| `node --test server/http.test.mjs server/event_content.test.mjs` | Vier Tests bestanden, keine übersprungen. |
| Aufgabenbezogener Quellvergleich, lokale Dokumentationslinks und `git diff --check` | Bestanden. |

Im finalen Webbuild auf `127.0.0.1:8300` tatsächlich angesehen: synchroner Wechsel von Hero und Detailbereich, sichtbare beide Pfeile, DE/EN für Navigation und Startseite, gestapeltes Carousel bei 320 Pixeln, Anmeldung mit einem vorhandenen synthetischen Gast, erstmalige freiwillige Präferenzabfrage, Speicherung und Rückkehr zu Empfehlungen mit dem Grund „Passt zu deinen Präferenzen“. Keine Warnungen oder Fehler im abgefragten Browserkonsolenprotokoll. Temporäre Browsergröße zurückgenommen; selbst gestartete Testserver nach Abschluss beendet. Nachweise: [öffentliche Startseite](screenshots/discovery-home-20261004.jpg), [mobile Startseite](screenshots/discovery-home-mobile-20261004.jpg), [persönliche Startseite](screenshots/discovery-personal-home-20261004.jpg).

Der Sprachwechsel übersetzt die betroffenen Bedienoberflächen. Redaktionelle Veranstalter-/Eventtexte bleiben in ihrer eingegebenen Sprache; vollständige Übersetzung sämtlicher älterer Rechts- und Fehlertexte ist nicht abgenommen. Browserprüfung für die geschützten Gastgeberentscheidungen und realen Freigabezeitpunkte wurde nicht zusätzlich durchgeführt; deren Nachweis stammt aus den oben genannten API-/Datenbanktests. Keine vollständige Barrierefreiheits- oder Produktabnahme.

Die vorhandene, bereits geänderte Arbeitskopie wurde erhalten. Änderungen liegen auf `codex/event-discovery-preferences`; keine Installation, Remote-Migration, Veröffentlichung, Staging oder Commit.

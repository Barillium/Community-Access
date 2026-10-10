# Gemeinsame Eventberechtigungen und Ausgabe · 05.10.2026

> Einordnung für V1 · 10.10.2026: Dieser datierte Detailbericht beschreibt den damaligen Implementierungsstand einschließlich des erhaltenen erweiterten Modus. Maßgebliche Produktregeln und Umfang stehen ausschließlich in der [Produktspezifikation](product-spec.md); aktuelle Start- und Prüfbefehle im [Setup](setup.md). Historische Statusangaben und Prüfergebnisse sind keine heutige Funktions- oder Betriebsfreigabe.

Dieser Text beschreibt die Umsetzung der bestehenden Produktspezifikation und ergänzt [ADR 0006](decisions/0006-scoped-program-visibility.md). Er ersetzt keine Produktspezifikation. Umfang: lokaler synthetischer Flutter-/Better-Auth-/PostgreSQL-Prototyp.

## Gemeinsame Regeln

`server/event_policy.mjs` enthält die Eventberechtigungen, Feldmaskierung, öffentliche Interessenzählung und die Normalisierung des Veröffentlichungsmodus. Das Modul hängt weder vom Katalog noch von der Verzeichnisverwaltung ab. Detailabruf, Gastgebervorschau, Programm, Startseite, Eventsuche und Eventmerkliste verwenden dieselben SQL-Regeln. `discovery_policy.mjs` stellt nur noch kompatible Exporte bereit.

| Regel | Wirkung |
| --- | --- |
| Event sichtbar | Veröffentlicht oder abgesagt, innerhalb der Speicherfrist und öffentlich oder persönlich berechtigt; persönliche Zugänge brauchen aktuelle Gastgeberzuständigkeit und dürfen nicht entzogen sein. Entwürfe bleiben ausgeblendet. |
| Profil sichtbar | Öffentlicher Profilname oder unabhängig erlaubter Profilzugang. Ein semi-öffentliches Event kann ohne Freigabe des privaten Profils sichtbar und merkbar sein. |
| Mitgliedschaft | Aktive Mitgliedschaft kann ein entsprechend markiertes Event sichtbar machen, ohne das private Veranstalterprofil zu öffnen oder Teilnahme zu bestätigen. |
| Semi-öffentliche Zeit und Ort | Für Gäste erst nach bestätigter Teilnahme und jeweiligem Freigabezeitpunkt. Profil-, Reihen- und Eventfreigaben reichen hierfür nicht. Verantwortliche Profilinhaber sehen ihre eigenen Angaben. |
| Genaue Adresse | Eigener geschützter Adressabruf; bestätigt berechtigte Teilnahme, gegebenenfalls aktive Mitgliedschaft und Ortsfreigabe. Keine genaue Adresse in Katalog, Suche, Startseite, Merkliste oder Vorschau. |
| Interesse | `interest_count` zählt eindeutige Merker bestätigter Konten nur für aktuell öffentliche Events. Privat zugängliche Events erhalten keinen öffentlichen Zähler. Merken erzeugt keine Teilnahme oder zusätzliche Rechte. |
| Veröffentlichungsmodus | Der endgültige Modus wird vor der Berechtigungsprüfung bestimmt und ebenso gespeichert. `public` braucht ein öffentliches Veranstalterprofil, auch bei widersprüchlichem `is_public: false` oder beim Bearbeiten ohne erneute Modusangabe. Die ausdrücklich erlaubte semi-öffentliche Werbung bleibt möglich. |

`eventColumns()` erzeugt die gemeinsame Ausgabe. Listen dürfen umfangreiche Inhalte auslassen; die Freigabe der enthaltenen Felder bleibt identisch. Endzeit folgt der Zeitfreigabe, Ortsname der Ortsfreigabe. Semi-öffentliche Flyer sowie freie Awareness-/Zugänglichkeitshinweise bleiben entsprechend der bestehenden Regeln verborgen. Unsichtbare Vorschauen enthalten keine Eventdaten. Suchbegriffe werden ausschließlich mit bereits maskierten Feldern verglichen, einschließlich sichtbarer Veranstalter, Orte, Beschreibungen und Genres.

Die Sicherheitskorrektur vom 05.10.2026 erweitert die Policy um `requestWindow`, `withdrawalWindow` und `visitWindow`. Bei verborgenen Zeiten bleibt `before_start` leer; Anfrage und Rückzug folgen einer unabhängig veröffentlichten `request_deadline_at`. Ein Rückzug braucht eine eigene laufende Anfrage und aktuell sichtbares Event, andernfalls lautet die Antwort einheitlich `404 NOT_FOUND`. Besuchsbestätigung braucht bestätigte Teilnahme sowie freigegebene, vergangene Endzeit. Anfragesperren und Empfehlungsmerkmale verwenden damit ebenfalls die Ausgaberechte. Einzelheiten und aktuelle Nachweise: [Sicherheitskorrekturen](security-event-policy-fixes.md).

Die Vorschau simuliert ausdrücklich ausgewählte Rechte: anonym, Profil, Reihe, Event, aktive Mitgliedschaft oder bestätigte Teilnahme. Tatsächliche Rechte des betrachtenden Gastgebers werden nicht in die simulierte Gastansicht übernommen. Sie erzeugt keine Freigaben und berichtet lediglich, ob eine gespeicherte genaue Adresse mit den simulierten Rechten derzeit abrufbar wäre.

## Startseite und Suche

`catalog.discover()` liefert für Startseite und Suche denselben persönlichen Bestand, dieselben maskierten Felder und dieselbe Rangfolge. Die Gewichte bleiben Merkliste 8, Community-Folgen 4, Veranstalterbesuch 3, Präferenztreffer 2. Danach entscheiden ausschließlich freigegebener Beginn und Event-ID. Verborgene Zeitangaben beeinflussen weder Sortierung noch den Ausschluss aus diesem Bestand.

Profilmerker und Veranstalterbesuche zählen nur bei aktuell sichtbarem Profil; Reihenmerker nur bei aktuell sichtbarem Profil und sichtbarer Reihe. Community-Folgen zählt nur bei öffentlicher Community. Das direkte Merken eines zugänglichen Events bleibt unabhängig möglich. Gespeicherte Marker für entzogene Zuordnungen verraten dadurch weder über Gründe noch über Sortierung den Zusammenhang.

- `GET /api/directory/events?scope=upcoming&q=…&page=…`: kommende veröffentlichte Events, für den aktuellen Leser berechtigt. Ohne Anmeldung nur öffentliche Ergebnisse. 20 Ergebnisse je Seite, Seitenaufteilung nach Rechteprüfung, Suche und Rangfolge.
- `GET /api/directory/events?q=…&page=…` beziehungsweise `scope=public`: bestehende öffentliche Archivabfrage, weiterhin auch abgesagte und vergangene Events innerhalb der Speicherfrist. Persönliche Freigaben erweitern diese Abfrage nicht.
- `GET /api/directory/home`: verwendet `discover()` für den persönlichen Bestand. Das Hero verwendet ausdrücklich den anonymen öffentlichen Bestand.

Bei nicht freigegebenem Beginn lässt sich die Eigenschaft „kommend“ nicht ohne Rückschluss auf die verborgene Zeit feststellen. Solche sichtbaren Einträge bleiben bis zur bestehenden Speicherfrist in der Entdeckung und werden nach Event-ID eingeordnet. Ein nach bestätigter Teilnahme freigegebener vergangener Beginn kann das Event dagegen aus dem kommenden Bestand entfernen. Detail und Merkliste haben absichtlich keine Beschränkung auf kommende Termine.

## Nachweise und Grenzen

Die Regressionstests in `server/event_policy.test.mjs` laufen innerhalb der bestehenden Katalogsuite mit echter lokaler PostgreSQL, HTTP-Aufrufen und signierten synthetischen Sitzungen. Sie vergleichen Ausgaben mehrerer Endpunkte, prüfen versteckte Suchfelder und Sortierung, getrennte Teilnahme-/Adressrechte, Entzug, Mitgliedschaft sowie widersprüchliche Veröffentlichungsangaben. Der bereits vorhandene synthetische Community-/Teilnahmeablauf bleibt erhalten.

Tatsächlich ausgeführte lokale Prüfungen am 05.10.2026:

| Prüfung | Ergebnis |
| --- | --- |
| `python3 -I scripts/local_auth.py --test-directory` | 49 bestanden, keine fehlgeschlagen oder übersprungen. |
| `python3 -I scripts/local_auth.py --test-access` | 13 bestanden, keine fehlgeschlagen oder übersprungen. |
| Clientformatierung und `flutter analyze --no-pub` | Bestanden, keine Analysebefunde. |
| `flutter test --no-pub --reporter expanded` | 166 bestanden. |
| Regulärer `flutter build web --no-pub --no-web-resources-cdn --pwa-strategy=none` | Bestanden; Ausgabe unter `/private/tmp/community-access-unified-policy-web`. Bestehende Cupertino-Fontwarnung und Abkündigung des PWA-Parameters bleiben. |
| Quellvergleich gegen den Aufgabenbeginn, Dokumentationslinks und `git diff --check` | Bestanden. |

Zusätzlich wurde die echte Flutter-Startseitenoberfläche mit isolierten synthetischen Anzeigedaten in einem eigenen Webbuild auf `127.0.0.1:8361` angesehen. Die Suche nach „Demo Kulturhalle“ zeigt das passende Event und dessen öffentlichen Interessenzähler; der andere Eintrag mit geschütztem Ort verschwindet aus dem Suchergebnis. Die abgefragte Browserkonsole enthielt keine Warnungen oder Fehler. [Browsernachweis](screenshots/unified-event-policy-20261005.png). Das ist eine Darstellungsprüfung mit Anzeigefixture, kein durchgängiger Browsernachweis gegen das Backend. Dessen Nachweis stammt aus den Datenbank-/HTTP-Tests. Temporärer Tab und eigener statischer Testserver wurden beendet; der bestehende Backendprozess wurde nicht verändert.

Die Regeln schützen strukturierte Felder. Eine automatische Prüfung redaktioneller Freitexte auf versehentlich erwähnte Adressen wird nicht behauptet. Der lokale Ranglistenabruf lädt weiterhin den berechtigten Bestand vor der Seitenaufteilung; eine Abnahme für große Datenmengen ist nicht erfolgt. Bereits angezeigte Angaben können nicht aus Empfängerkopien entfernt werden. Kein Produktionsnachweis, keine Remote-Migration und keine Veröffentlichung.

Die vorhandene geänderte Arbeitskopie wurde bewahrt. Eigene Änderungen liegen auf `codex/unified-event-policy`; kein Staging, Commit oder Push.

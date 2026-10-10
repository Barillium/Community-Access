# ADR 0006: Sichtbarkeit je Profil, Reihe und Event

> Teilweise ersetzt durch [ADR 0007](0007-v1-scope.md). Die folgenden Abschnitte dokumentieren den damaligen Ausbau, nicht den heutigen Umfang. Aktueller Konto-/Sitzungs- und Rechtevertrag: [Produktspezifikation](../product-spec.md); Start und Prüfung: [Setup](../setup.md). Historische Backend-fehlt-, Cookie- und erweiterte Profil-/Reihenaussagen gelten nicht als aktuelle V1-Regeln.

Datum: 02.10.2026. Status: Nutzerentscheidungen bestätigt; lokale synthetische Umsetzung. Keine Freigabe für reale Gästekreise, privaten Mailbetrieb oder Veröffentlichung.

## Entscheidung

Ein öffentliches Veranstalterprofil kann öffentliches Programm und Programm für getrennt freigegebene Gästekreise enthalten. Die öffentliche Oberfläche erwähnt persönliche Profile und ausgeblendete Veranstaltungen nicht. Die Kenntnis einer ID oder URL verleiht keinen Zugriff. Eine gültige Anmeldung gehört zu jeder persönlichen Freigabe.

Der Nutzer hat bestätigt:

- Eine Reihenfreigabe umfasst alle veröffentlichten und zukünftigen Events derselben Reihe.
- Gästekreise für Profil, Veranstaltungsreihe und einzelne Veranstaltung werden getrennt festgelegt.

| Berechtigung | Sichtbarkeit |
| --- | --- |
| Ohne persönliche Freigabe | Frei sichtbare Profile sowie ausdrücklich öffentliche Reihen und Events öffentlicher Profile in öffentlichen Communities. |
| Profilfreigabe | Das betreffende private Profil; keine automatische Freigabe geschützter Reihen oder Events. |
| Reihenfreigabe | Die betreffende Reihe und ihre veröffentlichten sowie abgesagten Events, einschließlich später angelegter Termine. Entwürfe bleiben ausgeschlossen. |
| Eventfreigabe | Nur die betreffende Veranstaltung; keine geschützten Reihennamen, Reihen-IDs oder anderen Termine. |
| Entzug | Neue Abrufe über diese Freigabe werden gesperrt. Andere ausdrücklich erteilte Einzelfreigaben gelten weiterhin. |

Bei privaten Profilen muss zusätzlich das Profil selbst freigegeben sein. Zuständige Gastgeber können ihr eigenes Programm verwalten. Sichtbarkeit bestätigt weder Mitgliedschaft noch Teilnahme und gibt keine nicht ausdrücklich angezeigten Ortsinformationen frei.

## Lokales Modell und Zugriff

`ca_series` gehört zu einem Veranstalterprofil und einer verantwortlichen Community. `ca_event` wird bei bewusstem Anlegen oder Bearbeiten diesem Profil und optional einer Reihe zugeordnet. Die Zuordnung zu einer Reihe erfordert dasselbe Profil und dieselbe verantwortliche Community. Eine Reihe mit bestehenden Events kann nicht in eine andere Community verschoben werden. Änderungen und Freigaben erfordern aktuelle Gastgeberrechte, den zugehörigen Profilinhaber und Versionsprüfungen.

`ca_series_grant` und `ca_event_grant` halten je Konto und Ziel eine eindeutige, versionierte Freigabe. Der Gastgeber wählt ein bestehendes Konto mit bestätigter E-Mail. Ein Konto erhält durch seine Registrierung keine Gastgeberrolle. Es gibt keine automatische Übernahme aus Profilanträgen, Mitgliedschaften, Kontakten oder externen Messengern. Entzug und erneute Freigabe werden in Transaktionen bearbeitet; konkurrierende Änderungen derselben Version können sich nicht unbemerkt überschreiben.

`server/catalog.mjs` prüft die Rechte vor Auswahl und Seitenaufteilung. Die Flutter-Ansicht erhält nur sichtbare Inhalte. Auf einem öffentlichen Profil entstehen für ausgeblendete Reihen und Events weder Platzhalter noch Treffer, Summen oder zusätzliche Navigationspunkte. Ein Event in einer geschützten Reihe wird durch seine eigene öffentliche Markierung nicht öffentlich. Eine ausdrücklich erteilte Einzelfreigabe kann ausschließlich dieses Event öffnen.

Das öffentliche Ortsverzeichnis nutzt denselben Filter für öffentliche Eventsichtbarkeit. Geschützte Events erzeugen auch für angemeldete Gäste keine öffentlichen Orte, Eventzahlen oder Suchtreffer. Beginn und Ortsangabe haben zusätzliche Anzeigefelder; ein sichtbares Event macht nicht automatisch seine unveröffentlichten Felder sichtbar. Verborgene Beginne beeinflussen die sichtbare Sortierung nicht.

## API und Client

- `GET /api/directory/organizers/:id/program?page=…`: sichtbares Programm, 20 Reihen und 20 Events je Seite; `has_more` entsteht nur aus sichtbaren Datensätzen.
- `GET /api/directory/series/:id?page=…`: sichtbare Reihe mit jeweils 20 erlaubten Events.
- `GET /api/directory/events/:id`: sichtbare Einzelveranstaltung.
- `POST /api/directory/manage/series`: Reihe anlegen oder versioniert ändern.
- `POST /api/directory/manage/grant`: verifizierten Gast für Reihe oder Event freigeben.
- `POST /api/directory/manage/revoke`: betreffende Freigabe versioniert entziehen.

Profilzugang bleibt über die bereits implementierten Anträge, Formulare und persönlichen Links möglich. Ohne Anmeldung antwortet der private Zugangsendpunkt seit dieser Änderung ebenso wie ein unbekanntes Profil mit 404. Öffentliche Zugangsendpunkte geben anonym keine Formulare oder persönlichen Zugangsoptionen aus. Das Veranstalterverzeichnis ergänzt `signed_in`, um den geteilten Zugangseinstieg erst nach Anmeldung anzubieten. Backend und Flutter müssen zusammen aktualisiert werden; ein alter Client kann den anonymen privaten Formulareinstieg nicht mehr verwenden.

## Migration und Grenzen

Die Erweiterung in `server/directory.sql` ist additiv und ausschließlich für den geprüften lokalen synthetischen Datenbestand. Vorhandene Events behalten ihre öffentlichen Markierungen, jedoch keine automatisch erfundene Profilzuordnung, Reihenzuordnung oder persönliche Freigabe. Korrektur auf Nutzerauftrag vom 02.10.2026: Bereits ausdrücklich öffentliche Altbestands-Events ohne Profil- und Reihenzuordnung bleiben im öffentlichen Ortsverzeichnis sichtbar, solange ihre Community öffentlich ist, ein aktueller Gastgeber zuständig ist und der Ort ausdrücklich angezeigt wird. Dies erzeugt weder Profilzuordnung noch persönliche Freigabe. Zugeordnete Events benötigen weiterhin ein öffentliches Profil und gegebenenfalls eine öffentliche Reihe. Erneute Schemaausführung darf bestehende Freigaben nicht verändern.

Im privaten Mailmodus wird das gesamte Verzeichnismodul weiterhin nicht geladen. Keine Remote-Migration, Installation, Veröffentlichung, E-Mail-Zustellung oder neue externe Abhängigkeit. Der Nutzerauftrag betrifft die manuelle Umsetzung und erweitert keinen Runner-Kontrollstand.

Die erste Verwaltung arbeitet mit einzelnen bestätigten Gastkonten. Gruppenimport, Messenger-Synchronisierung, Teilnahmezusagen, geschützte genaue Locations, Speicherfristen, unabhängiges Sicherheitsaudit und Produktionsbetrieb sind nicht Bestandteil dieser Umsetzung. Früher berechtigt angezeigte Inhalte können nicht rückwirkend aus dem Wissen oder Screenshots eines Gastes entfernt werden.

Tatsächliche lokale Prüfergebnisse und Browsernachweise stehen unter [Veranstalter und Veranstaltungsorte in Flutter](../organizers-venues-flutter.md).

## Ergänzung: mehrere Veranstalterprofile und öffentliche Inhalte

Nutzerentscheidung vom 02.10.2026: Ein Gastgeberkonto kann mehrere Veranstalterprofile anlegen. Die lokale Schemaänderung hebt ausschließlich die bisherige Eindeutigkeit des Profilinhabers auf. Profil-IDs, bestehende Zuordnungen, Anträge, Links und Freigaben bleiben erhalten. Die Verwaltung wählt das Profil ausdrücklich; Änderungen an einem fremden Profil werden serverseitig verweigert. Frühere Einzelprofilaufrufe bleiben für Konten mit genau einem Profil möglich; neue Schreibaufrufe ohne eindeutige Auswahl werden bei mehreren Profilen abgewiesen.

Öffentliche Events und Reihen benötigen ein öffentliches Profil. Dies wird beim Schreiben und bei jedem öffentlichen Lesen geprüft, einschließlich Ortsverzeichnis und Reihenaufrufen. Die Privatstellung eines Profils verhindert deshalb auch neue anonyme Abrufe seiner vorher öffentlichen Inhalte. Sie verändert keine persönlichen Freigaben und erzeugt keine automatische Teilnahmezusage.

Die Gastgebervorschau verwendet dieselbe Sichtbarkeitspolitik mit ausdrücklich hypothetischen Profil-/Reihen-/Eventfreigaben. Nur der aktuell verantwortliche Profilinhaber darf sie abrufen; der Aufruf erstellt keine Freigaben oder Sitzungen. Verborgene Orts- und Beginnfelder bleiben auch in der Vorschau verborgen. Die Ansicht einer bestätigten Teilnahme kennzeichnet den noch fehlenden Teilnahme-/Adressanschluss.

`ca_bookmark` speichert kontobezogene Profile oder Reihen; eindeutige Teilindizes verhindern doppelte Einträge bei wiederholten oder gleichzeitigen Aufrufen. Die Leseliste filtert vor Ausgabe nach aktuellen Berechtigungen. Die Merkliste enthält keine kopierten Profil-/Reihentitel und kann Zugang weder erhalten noch verleihen.

`ca_event.access_details` speichert validierte Ausstattungsangaben mit unbekannten Ausgangswerten und optionale ausdrücklich freigegebene Hinweise. Fremde Felder werden verworfen, indem der Schreibaufruf abgewiesen wird. Die Ausgabe erfolgt erst nach erfolgreicher Eventberechtigungsprüfung. Es entsteht kein Speicher oder Endpunkt für geschützte genaue Adressen.

API-Ergänzungen: `GET /api/directory/manage?profile_id=…`, `POST /api/directory/manage/profile` mit `id` beziehungsweise ausdrücklich `create=true`, `POST /api/directory/manage/preview`, `GET /api/directory/bookmarks` und `POST /api/directory/bookmark`. Event-/Reihenanlage und persönliche Linkerstellung tragen das ausgewählte `profile_id`. Details und Prüfungen stehen in [Veranstalterfunktionen](../organizer-features.md).

## Ergänzung: redaktionelle Eventinhalte

Auf Nutzerauftrag vom 02.10.2026 ergänzt `ca_event.event_content` die Beschreibung, das geordnete Line-up, Genres, Einlass, Mindestalter, Veranstaltungsortname, Endzeit sowie einen begrenzten lokalen JPEG-Flyer und Alternativtext. Die feste Feldliste wird serverseitig validiert; Eigentümer-, Community- und Versionsprüfungen bleiben bestehen. Omitierte Inhalte alter Clients werden erhalten. Endzeit benötigt einen früheren Beginn.

Sichtbare Einzelveranstaltung und Gastgebervorschau verwenden dieselbe SQL-Feldmaskierung: Ortsname folgt `location_public`, Endzeit folgt `starts_public`. Die übrigen Eventinhalte sind nur innerhalb eines berechtigt sichtbaren Events verfügbar. Die Bildauswahl im Browser dekodiert und kodiert lokale Rasterbilder neu. Das Backend begrenzt JPEG-Größe und Abmessungen und verwirft EXIF-/Kommentarsegmente, ersetzt jedoch keinen vollständigen serverseitigen Bildprozessor. Ausschließlich der Event-Schreibendpunkt hat ein erhöhtes JSON-Limit von 400000 Bytes. Keine externe Medienintegration oder Remote-Migration. [Umfang, Mediengrenzen und Nachweise](../event-editorial-pages.md).


## Ergänzung: öffentliche Interessen und Event-Merkliste

Nutzerentscheidung vom 02.10.2026: Die Merkliste dient bei öffentlichen Veranstalterprofilen, Reihen und einzelnen Events als Interessenzähler. `ca_bookmark.event_id` ergänzt die bisherigen Referenzen; genau ein Ziel je Eintrag sowie eindeutige Ziel-/Kontoindizes erhalten die Idempotenz. Bestehende Merker bleiben bei Schemawiederholung erhalten. Zielindizes unterstützen Zählabfragen. Das Backend berechnet `interest_count` aus den Einträgen aktuell bestätigter Konten, statt einen getrennten Zähler zu pflegen.

Die Anzeige einer Anzahl erfordert aktuelle öffentliche Sichtbarkeit. Persönlich zugängliche geschützte Inhalte erhalten keine öffentliche Aggregation. Namen und Kontolisten bleiben privat. Eventmerker verwenden dieselben Zugangsprüfungen wie Eventdetails und verschwinden nach Entzug aus der eigenen sichtbaren Merkliste. Merken erteilt keine zusätzlichen Rechte und keine Teilnahmezusage. [Umfang und Nachweise](../public-interest-counts.md).

## Ergänzung: gemeinsame Eventregeln vom 05.10.2026

Detail, Vorschau, Programm, Suche, Startseite und Eventmerkliste verwenden `server/event_policy.mjs` für Berechtigungen und Feldmaskierung. Die persönliche Suche der Startseite nutzt ausdrücklich `scope=upcoming`; die öffentliche Archivabfrage übernimmt weiterhin keine persönlichen Freigaben. Verborgene Beginne beeinflussen weder Rangfolge noch die Auswahl des kommenden Bestands. Öffentlich beworbene semi-öffentliche Events können ohne Freigabe ihres privaten Profils angesehen und gemerkt werden. Aktive Communitymitgliedschaft kann ein entsprechend markiertes Event öffnen, ohne Teilnahme oder Profilzugang zu erzeugen.

Der zwischenzeitlich ergänzte synthetische Teilnahme- und Adressablauf verwendet die gemeinsamen Zeit-/Adressregeln. Die früheren Umfangsgrenzen dieses ADR beschreiben den damaligen Stand; die genaue Adresse bleibt ein separater, geschützter Abruf. Der endgültige Veröffentlichungsmodus wird vor der Profilprüfung normalisiert. [Aktuelle Regeln, Endpunkte, Nachweise und Grenzen](../unified-event-policy.md).

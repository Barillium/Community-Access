# Veranstaltungsseiten und Gastgebereditor

Stand: 02.10.2026. Lokale Umsetzung des Nutzerauftrags mit synthetischen Daten, ohne Veröffentlichung.

## Darstellung und Bedienung

Die [vom Nutzer genannte Resident-Advisor-Seite](https://de.ra.co/events/2391353) dient als Referenz für die Informationshierarchie: große Eventüberschrift, kompakte Angaben zu Datum, Veranstaltungsort und Veranstalter, Line-up, Genres, Beschreibung, Einlass und ein groß dargestellter Flyer. Die bestehende Flutter-Gestaltung bleibt erhalten; fremde Bilder, Markenzeichen und Texte werden nicht übernommen.

Gastgeber bearbeiten diese optionalen Inhalte im vorhandenen Eventeditor unter **Inhalte der Eventseite**. Acts werden zeilenweise in gewünschter Reihenfolge eingegeben; bis zu acht Genres sind möglich. Beschreibung, Einlasshinweise, Mindestalter, Ortsname und Endzeit ergänzen die bisherigen Angaben. **Seite vorab ansehen** zeigt einen noch nicht gespeicherten Entwurf. Die echte Detailseite und **Wer sieht was?** verwenden denselben Darstellungsbaustein. Auf breiten Bildschirmen stehen Text und Flyer nebeneinander; auf schmalen Bildschirmen oder bei großer Schrift untereinander. Der vollständige Flyer lässt sich öffnen und vergrößern. Fehlende optionale Angaben erzeugen keine erfundenen Inhalte.

Der Webeditor nimmt lokale JPG-/PNG-Dateien bis 10 MiB entgegen. Der Browser dekodiert sie, begrenzt die längste Seite auf 1600 Pixel und kodiert sie ohne ursprüngliche Metadaten als JPEG neu. Das gespeicherte Bild darf höchstens 256 KiB groß sein; ein Alternativtext ist erforderlich. Auswahl, Ersetzen, Entfernen und Abbruch sind möglich. Es gibt keine externen Bildabrufe oder neue Speicheranbieter. Die Beispielbilder unter `demo-assets/` sind eigens erzeugte synthetische Testmedien.

## Rechte und Speicherung

`ca_event.event_content` ist ein zusätzliches JSONB-Feld mit einer festen erlaubten Feldliste, Längen- und Datentypgrenzen. Alte Clients, die es nicht mitsenden, erhalten vorhandene Inhalte. Der Endzeitpunkt muss hinter einem vorhandenen Beginn liegen. Ortsname und Ortsangabe teilen dieselbe Freigabe; Endzeit und Beginn teilen dieselbe Freigabe. Das Backend entfernt diese Felder vor der Ausgabe, wenn ihre Anzeige nicht erlaubt ist. Beschreibung, Line-up, Genres, Einlass und Flyer sind nur innerhalb eines sichtbaren Events abrufbar. Diese Angaben sind ausdrücklich für diesen Gästekreis bestimmt; geschützte genaue Adressen gehören nicht in Freitexte oder Flyer.

Ein unsichtbares Event liefert auch in der Gastgebervorschau keine Inhalte. Die vorhandenen Eigentümer-, Community-, Profil-, Reihen- und Versionsprüfungen gelten weiter. Profilzugang und Eventfreigabe bleiben von Teilnahme und Adressfreigabe getrennt. Öffentliche Events benötigen weiterhin ein öffentliches Veranstalterprofil.

Der Server erlaubt ausschließlich begrenzte JPEG-Daten, prüft Base64, Dateigrenzen, JPEG-Rahmen und Abmessungen und lehnt EXIF-/Kommentarsegmente ab. Das ist keine vollständige serverseitige Bilddekodierung. Für einen Produktionsbetrieb bleiben ein eigenständiger Medienpfad mit vollständiger Verarbeitung, Speicherplanung und Freigabe erforderlich. Im lokalen Teilumfang liegt der Flyer begrenzt direkt am Event. Nur der Event-Schreibendpunkt erhält ein JSON-Limit von 400000 Bytes; die übrigen JSON-Endpunkte behalten 16384 Bytes.

## Quellen und Zusammenarbeit

Gelesen wurden die Nutzerregeln, Projekt-`AGENTS.md`, Produktspezifikation, Setup, Git-/Codex-Workflow, Designregeln und ADR 0006. Der Skill `design-taste-frontend` wurde auf die Eventdarstellung angewendet. Es wurden keine Abhängigkeiten installiert und keine Runner-Kontrollen verändert.

Der vorgefundene Quellstand wurde unter `/private/tmp/community-access-editorial-before/` gesichert und zunächst der Branch `codex/event-editorial-pages` angelegt. Parallel beauftragte Arbeiten an Anbieteranmeldung und Veröffentlichungsprüfung wechseln denselben Checkout und ändern gemeinsame Dateien. Diese Änderungen bleiben erhalten; ein Branchwechsel isoliert uncommittete Dateien nicht. Es wurde nichts gestagt, committet oder veröffentlicht.

Betroffene Quellen: `server/event_content.mjs`, `directory.sql`, `directory.mjs`, `catalog.mjs`, das begrenzte Event-Request-Limit in `http.mjs` und entsprechende Tests; in `client/` der neue Eventdarstellungsbaustein, Inhaltseditor, lokale Bildauswahl, Event-/Profilnavigation und Sichtbarkeitsvorschau sowie Widgettests. Produktspezifikation und ADR 0006 dokumentieren die Ergänzung. Tatsächliche Prüfungen stehen in [Abnahme und Nachweise](verification.md).

## Verbleibender Umfang

Ticketverkauf, Zahlungen, externe Medienprofile und automatischer Versand sind nicht Bestandteil dieser Umsetzung. Die später ausdrücklich beauftragten [öffentlichen Interessenzähler](public-interest-counts.md) verwenden die Merkliste. Teilnahmezusagen und geschützte genaue Adressen bleiben im lokalen Better-Auth-Teilumfang noch nicht angebunden. Die neue Eventdarstellung ist kein Nachweis einer vollständigen Produktabnahme.


## Ergänzung vom 04.10.2026: Eventalter und Jugendschutz

Das bestehende Feld **Mindestalter (optional)** bleibt vom Veranstalter je Event wählbar. Ein kurzer Hinweis direkt am Feld erklärt, dass gesetzliche Jugendschutzvorgaben und behördliche Auflagen auch bei fehlender Altersangabe gelten. Aufklappbare Details behandeln Veranstaltungen in Deutschland, darunter Begleitung und Zeitgrenzen bei öffentlichen Tanzveranstaltungen sowie den Minderjährigenausschluss in Nachtbars/Nachtclubs. Der amtliche Gesetzestext ist auf bewusste Auswahl erreichbar; der vorhandene Einlasstext nimmt eventbezogene Bedingungen auf.

Die Oberfläche führt keine automatische rechtliche Freigabe, Identitätsprüfung oder allgemeine 18-Jahre-Grenze ein. Konto-Zugang Minderjähriger bleibt gesondert zu entscheiden. [Entscheidung, Quellen und aktueller Prüfstand](pilot-preparation.md#eventalter). Keine Änderung an API, Datenbankschema oder Runner.

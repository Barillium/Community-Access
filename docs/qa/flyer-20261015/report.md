# Community Access · Flyer in Flutter · 15.10.2026

Der abgestimmte Kulturplakat/Flyer-Stil ist in der aktiven Flutter-App unter `/Volumes/CommunityAccessNative/Projects/Community Access/client` umgesetzt. Die freigegebene Referenz ist `Designvorschlaege-2026-10-15/Kulturplakat-Elemente/`, einschließlich der späteren Anmerkungen zum weißen Header, zu Markierungen und Bildübergängen. Die separaten HTML-Entwürfe bleiben als Referenz erhalten.

## Umsetzung

- Gemeinsame warme Papier-/Tinte-Palette und vorhandene Archivo-Schriften in normaler Breite; keine neue Schrift oder Abhängigkeit.
- Weißer Header auch bei dunkler Seitenansicht. Regulär 67 logische Pixel hoch; Bedienelemente mindestens 48 Pixel, Vergrößerung darf die Höhe erweitern. Logo optisch am Seitenrand ausgerichtet.
- Ein einzelner orangefarbener Strich am aktiven Navigationswort, orange umkreistes „Mein Zugang“, schwarze Schrift, direkter EN-/DE-Wechsel. Mobiles Menü mit zwei gezeichneten Strichen, ohne graue Trenner und schwarze Textunterstreichungen.
- Volle Inhaltsbreite auf Desktop, mit fließendem Seitenrand. Lesetext und bestehende Formulargruppen behalten ihre eigenen Begrenzungen.
- Cinematische Startseite mit ausdrücklich gekennzeichnetem synthetischem Kulturmotiv. Textschatten folgen den Schriftzügen; die rechte Eventinformation erhält nur auf Desktop einen weich auslaufenden schwarzen Hintergrund. Markierungen bleiben eine separate scharfe Zeichenebene.
- Manuelle Eventauswahl, automatische Wechsel standardmäßig ausgeschaltet. Reduzierte Bewegung, Tastaturfokus und inaktive Routen unterbrechen automatische Wechsel.
- Chronologische Programmzeilen mit normal geschriebenen Titeln und gezeichneten Pfeilen. Kein sichtbarer Zeitraum-Legendentext. V1 reserviert keinen Platz für die zurückgestellte Merkliste.
- Fotoüberschriften für öffentliche Verzeichnisse/Profile; Verwaltung bleibt ein ruhiger Arbeitsbereich. Eventdetails verwenden ausschließlich tatsächlich gelieferte Eventmedien. Ein Event ohne Bild erhält keine erfundene Bilddatei. Keine Vergrößerungsaktion am Hero.
- Formulare, Konto, Zugang, Veranstalterverwaltung und Tickets übernehmen die gemeinsamen Grundlagen. Eigene Tickets erhalten einen orangefarbenen Rahmen und einen zum Veranstaltungstitel ausgerichteten Pfeil. Bestellung und Ticketliste haben markierte Überschriften.
- Bedeutungen und API-Bedingungen von Mitgliedschaft, Eventfreigabe, Kaufrecht und bezahlter Teilnahme bleiben getrennt. Private Orte, Identitätswechsel, Sperrungen, Erstattung und Belege verwenden die vorhandenen Regeln.

## Prüfungen

| Prüfung | Ergebnis |
| --- | --- |
| `flutter analyze --no-pub` | PASS, keine Hinweise |
| V1-Umfang und neue Flyer-Regressionsprüfungen | 15 Tests PASS |
| Gesamte Clientregression, `extended`, ohne V1-Tags | 336 Tests PASS |
| Gezielte Ticket-/Zugangsregression nach der Kartenanpassung | 37 Tests PASS; zusätzlich durch den vollständigen abschließenden Lauf abgedeckt |
| V1-Boardexport aus echten Flutter-Widgets | 26 Renderprüfungen PASS, 13 Ansichten bei 1440 und 390 Pixeln |
| Lokaler Release-Webbuild ohne externe Webressourcen-CDN | PASS |
| Eigener Quelldiff / Formatierung | geprüft, keine Leerraumfehler |

Die neuen Flyerprüfungen decken 320, 390, 768 und 1440 Pixel bei einfacher und doppelter Schriftgröße ab; außerdem Sprachwechsel mit erhaltener Eventauswahl, ausgeschalteten Autoplay-Start, Menü/Escape, 48-Pixel-Ziele, weißen Header im dunklen Theme und fehlende Eventmedien/geschützte Orte. Die erhaltenen Funktionssuiten prüfen unter anderem Fehlerrückmeldungen, Formularerhalt, Widerruf und Identitätswechsel, Ticketstatus, Erstattung, Einlass und die getrennten Rechte.

Der lokale Browserlauf verwendet eine frisch erzeugte synthetische V1-Datenbank auf `127.0.0.1`. Desktop- und Mobilstartseite, mobiles Menü, englische Navigation und Escape mit Fokusrückgabe wurden direkt in der gebauten Flutter-App geprüft. Screenshots liegen im SSD-Nachweisordner. Der Impeccable-Quellencheck meldet keine mechanischen Befunde; er ersetzt keine Flutter- oder visuelle Prüfung.

Alle 26 PNG-Boards wurden visuell gesichtet. Die Galerie zeigt **13 ausgewählte Flutter-Seiten-/Komponentenansichten**, keine Behauptung einer erneuten 81-Seiten-/Zustandsabnahme. Lange Seiten sind Ausschnitte bei 1500 Pixeln Desktop- und 2200 Pixeln Mobilhöhe. Weitere Inhalte bleiben in der echten App scrollbar. Die Boardfixtures sind ausschließlich synthetisch und ändern keine Datenquellen der App. Manche Komponenten sind zur Betrachtung isoliert mit einem gemeinsamen Seitenrahmen zusammengestellt; die Boards behaupten keine exakte Abbildung jeder vollständigen Navigationsroute.

## Ablage und Weiterarbeit

Alle nachfolgend genannten Dateien liegen im [SSD-Nachweisordner](</Volumes/CommunityAccessNative/Projects/Webdesign Praktiken/Community-Access/Flutter-Flyer-2026-10-15/index.html>).

- `index.html`: Desktop-/Mobilvergleich und Gesamtübersicht.
- `boards/`: 26 PNG-Dateien.
- `logs/`: Analyse, Test- und Buildnachweise.
- `baseline/`, `baseline.patch`, `baseline-sha256.json`: vorhandener Ausgangsstand vor den Änderungen.
- `implementation.patch`, `implementation-files.json`: separater Design-Diff zum gesicherten, bereits veränderten Ausgangsstand. Das Bildasset ist zusätzlich im Client vorhanden.
- `preservation.json`: beobachteter Git-Zustand und parallel entstandene Unterschiede.

Für diesen Auftrag wurde zunächst `codex/flyer-design-20261015` angelegt. Während der Arbeit haben parallele Läufe den aktiven Branch im gemeinsamen Verzeichnis mehrfach gewechselt. Diese Umsetzung setzt keinen Branch zurück, stellt keine fremden Dateien wieder her und staged/committed keine vorhandenen Änderungen. Der aktuelle gemeinsame Arbeitsstand enthält die Gestaltung; der separate Patch dokumentiert ihren Anteil. Die Anwendung des Patches auf andere Stände muss vorher auf passende Ausgangsdateien geprüft werden.

## Grenzen

Lokale Flutter-/Web- und synthetische Funktionsnachweise. Keine Abnahme auf realen iOS-/Android-Geräten, keine vollständige Screenreader-/Kontrastprüfung jedes Bildpixels, keine pixelgenaue Abnahme sämtlicher Rollen/Zustände und keine neue Backend-/Zahlungsanbieter-/Produktionsabnahme. Keine Veröffentlichung, keine echten Zahlungen, keine produktiven Daten und keine neue Paketinstallation. Die separate historische Beispiel-App unter `client/packages/ca_design/example` wurde nicht neu gestaltet oder mit neuen Goldens überschrieben.

Die für diese Prüfung gestarteten App-/Demo-Dienste wurden anschließend sicher beendet. Die statische Vergleichsgalerie bleibt im bereits vorhandenen lokalen Entwurfsserver geöffnet. Zum interaktiven Weiterarbeiten die aktive App gemäß `docs/setup.md` erneut starten.

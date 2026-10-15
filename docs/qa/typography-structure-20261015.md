# Audit: Typografie und Seitenstruktur – 15.10.2026

## Ergebnis und Umfang

Der Auftrag umfasst Prüfung **und Korrektur** der bestehenden Flyer-Oberfläche.
Die visuelle Identität und Produktfunktionen bleiben erhalten. Arbeitsbasis ist
Commit `9da68b5` auf `codex/flyer-development-20261015`; die getrennte Arbeitskopie
bewahrt die parallele Arbeit im ursprünglichen Community-Access-Checkout.

Der Quellcode von 88 bestehenden `client/lib`-Dateien wurde inventarisiert.
Die Ausgangslage enthielt 50 numerische `fontSize`-Angaben mit elf unterschiedlichen
Werten; nicht jede Zahl war ein Fehler (z. B. Datumsziffern und Bildannotation).
Entscheidend sind gleiche Rollen und nachvollziehbare Unterschiede. Ein zusätzlicher
Typografiebaustein ersetzt die verstreuten Festlegungen für gemeinsame Textrollen.

## Befunde und umgesetzte Maßnahmen

| Priorität | Vorher | Durchgesetzte Korrektur |
|---|---|---|
| P1 | Mehrere Formulare, Kontakt-/Informations- und Verwaltungsansichten besaßen nur einen kleinen Toolbar-Titel. | Fehlende sichtbare H1-Titel ergänzt; gemeinsamer Rahmen besitzt ein optionales Titel-Feld. 16 repräsentative Ansichten prüfen genau eine H1. |
| P2 | Event-Abschnittstitel mit 14 px waren kleiner als 16-px-Fließtext; Beschreibungen mit 28 px dominierten sie. | Abschnitte 28–32 px, Einleitung 20 px; eigener Statusbereich als zugehörige Überschrift. |
| P2 | FAQ: Titel 80 px/800, Gruppen 14 px, Fragen 18 px; andere Seiten verwendeten andere Titelrampen. | Gemeinsame H1-/H2-Rollen, Fragen 20 px, Antworten 16 px. Gruppen sind sichtbar übergeordnet. |
| P2 | Communities, Veranstalter- und Veranstaltungslisten verwendeten verschiedene frei definierte Titelgrößen; einige Titel hatten keine Überschriftensemantik. | Gemeinsame Abschnitts-/Eintragstitel und ausdrücklich passende H2-/H3-Ebenen. |
| P2 | `FlyerTitle` verkleinerte lange Titel anhand der Textbreite bis auf 28 px. | Definierte responsive Rolle, natürlicher Zeilenumbruch, erhaltene Nutzerskalierung; lange englische Titel werden getestet. |
| P2 | Event-Lesetexte konnten die gesamte Desktopfläche einnehmen. | 680-px-Lesebereich für Beschreibung, Line-up und Erläuterungen; Bilder/Listen bleiben breit. |
| P2 | Hauptinhalte waren nur auf der öffentlichen Startansicht als solche markiert. | Gemeinsamer Seitenrahmen markiert Hauptinhalt; vorhandene öffentliche Main-/Footerregionen werden ausdrücklich ausgenommen. |
| P2 | Einzelne H3-Untergruppen wurden wie große Abschnitte dargestellt. | Untergruppen nutzen die Eintragstitel-Rolle unter ihren H2-Gruppen. |

## Regeln und dauerhafte Durchsetzung

Die maßgeblichen Werte stehen in `client/lib/access_typography.dart`, die Verwendung
und strukturellen Regeln in `docs/design-rules.md`. Keine zusätzlichen Schriftdateien,
Pakete oder externen Schriftanfragen. Semantische Ebene und visuelle Rolle sind
getrennt; ein direkter Eintrag unter H1 kann H2 sein, ohne wie ein Hauptabschnitt
gestaltet zu werden.

`client/test/typography_structure_test.dart` sichert:

- streng absteigende Schriftrollen bei 320, 390, 768 und 1440 px;
- 16 Ansichten mit genau einem Hauptinhaltsbereich, genau einer H1 und ohne übersprungene Überschriftenebene,
  jeweils 390/1440 px und normaler/doppelter Schrift (64 Kombinationen);
- lange englische Titel bei 320/768 px und doppelter Schrift ohne Verkleinerung;
- benannte Schriftrollen statt numerischer `fontSize`-Angaben in sechs zentralen
  öffentlichen Inhaltskomponenten.

Getestete Ansichten: Startseite, FAQ, Communities, Veranstalterverzeichnis,
Veranstalterprofil, Event, Kontakt, Datenschutz, Betreiberinformationen, Anmeldung,
Registrierung, Wiederherstellung, Zugang, Veranstalterverwaltung, eigene Tickets
und Checkout. 17 Desktop-/Mobilboardpaare umfassen zusätzlich die isolierte
Programmkomponente. Ein Board ist teils eine Komponentenansicht mit synthetischem
Rahmen und ersetzt keinen vollständigen Navigationsweg.

## Prüfung und Nachweisgrenzen

Analyse ohne Befund. 406 erweiterte UI-Tests sowie 83 V1-/Hierarchieprüfungen
bestanden; 34 aktuelle Boards gerendert. Die Übersicht aller Boardpaare und volle
FAQ-/Eventansichten wurden visuell kontrolliert. Bestehende Prüfungen wurden für
neue Seitentitel und die bereits beauftragte Carousel-Position korrigiert, mit
präzisen Überschriftenselektoren und Scrollen zum Kontaktbutton.

Der Impeccable-Detektor meldet keine Befunde. Seine Unterstützung für Flutter/Dart
ist begrenzt; dieses Ergebnis wird nicht als Typografie- oder Barrierefreiheitsnachweis
verwendet. Die belastbaren Nachweise sind Quellprüfung, Flutter-Layout/Semantiktests,
Boards und die separate Live-Browserprüfung.

SSD-Nachweise: `Webdesign Praktiken/Community-Access/Typografie-Struktur-Audit-2026-10-15/`.
Die dortigen Logs und `live-check.json` dokumentieren den endgültigen Build/Commit.

Dieser Audit prüft Typografie, Inhaltsgliederung und responsive Struktur. Kein
Backend-, Sicherheits-, Performance- oder rechtlicher Vollaudit; keine pauschale
WCAG-Zertifizierung und keine physische Geräte-/Screenreaderabnahme. Development
bleibt eine Frontend-Vorschau ohne verbundene Konto-/Datenbank-/Zahlungsfunktionen.

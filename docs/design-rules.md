# Regeln für die spätere Oberfläche

Stand: 25.09.2026. Diese Regeln konkretisieren die Verständlichkeit der [Produktspezifikation](product-spec.md); eine synthetische Statusoberfläche ist implementiert; eine verbindliche visuelle Identität ist noch nicht festgelegt.

- Deutsch, kurze Beschriftungen und klare nächste Schritte. Fachbegriffe beim ersten Auftreten erklären.
- Einladung, Bewerbung, Mitgliedschaft, Eventanfrage und Eventbestätigung getrennt benennen. Ein genehmigter Bewerbungsstatus darf keine zugesagte Eventteilnahme suggerieren.
- Manuelle Entscheidungen als solche kennzeichnen. Keine KI-Bewertung, Vertrauensskala oder communityübergreifenden Profile.
- Community und zuständigen Kontext sichtbar machen; Sichtbarkeit ist kein Backend-Zugriffsschutz.
- Ladezustand, leerer Zustand, Fehler und Erfolg benötigen verständliche Rückmeldungen. Fehlertexte enthalten keine Tokens, privaten Adressen oder Bewerbungsantworten.
- Bedienbarkeit mit Tastatur, eindeutige Feldbeschriftungen und verständliche Fokuszustände als spätere Abnahme vorsehen. Status nicht allein durch Farbe vermitteln.
- Nur synthetische Beispiele. Formularpflichtfelder, Aufbewahrung weiterer Daten, konkrete Gestaltung, Farben, Schrift und Komponentenbibliothek bleiben offen; keine zusätzlichen personenbezogenen Felder erfinden.

Diese Dokumentationsregeln werden im Diff geprüft. Erste Widget-Tests sind im Nachtrag unten dokumentiert. Automatische Browser- und umfassende Barrierefreiheitstests stehen noch aus.

## Erste lokale Demo

`app/` verwendet vorläufig die Material-3-Komponenten des Flutter-SDK mit einem grünen Farbschema; dies ist keine festgelegte Markenidentität. Die Seite zeigt den Community-Kontext und ausschließlich erfundene Beispiele. Beschriftete Auswahlchips wechseln Demozustände, ohne fachliche Aktionen auszuführen. Status bleibt als Text sichtbar; die Statuskarte ist als Live-Region ausgezeichnet. Die lokale Anzeige hat keinen Lade-, Serverfehler- oder leeren Datenzustand, da keine Daten angefordert werden. Solche Zustände müssen mit einer späteren Datenanbindung ergänzt werden.

Widget-Tests prüfen Startzustand, alle vier Beispiele, Tastaturbedienung und schmale Darstellung mit großer Schrift. Eine vollständige Barrierefreiheitsabnahme steht noch aus.

## Gemeinsames Layoutsystem der aktiven Oberfläche · 04.10.2026

Dieser Abschnitt gilt für die aktive Flutter-Oberfläche unter `client/`. Die frühere grüne Statusdemo unter `app/` bleibt ein getrenntes Lernbeispiel. Die bestehende Rubik-Schrift, Schwarz-/Weiß-/Rot-Farben, konzentrischen Karten, Rundungen und eigenen Symbole werden in der aktiven Oberfläche beibehalten.

### Zentrale Stellschrauben

Alle nachfolgend benannten Werte und Bausteine liegen in [design_system.dart](../client/lib/design_system.dart):

| Änderung | Stelle und Wirkung |
| --- | --- |
| Abstandsskala | `AccessSpacing`: 4, 8, 12, 16, 20, 24, 32, 40, 48, 64, 80, 96 logische Pixel; gemeinsam für Innenabstände, Formulargruppen und Zwischenräume. |
| Seitenränder | `AccessLayoutTheme.gutterMin` / `gutterMax`: 16 bis 600 verfügbare Pixel, linear bis 24 bei 768. `AccessPageFrame` übernimmt die Ränder einmal pro Seite. |
| Abschnittsrhythmus | `sectionMin` / `sectionMax`: 32 bis 600, linear bis 48 bei 1000; `AccessSection` verteilt diesen Abstand auf Ober- und Unterseite. |
| Karteninnenabstand | `cardMin` / `cardMax`: 16 bis 360 Kartenbreite, linear bis 24 bei 600; `AccessSurface` berechnet den Abstand anhand der eigenen Fläche. |
| Inhaltsbreite | `AccessLayout.maxContentWidth` 1280; `detailWidth` 1180, `readingWidth` 760, `formWidth` 520. Seitenrahmenbreiten schließen den Außenabstand ein; begrenzte Leseblöcke verwenden die Lesebreite innerhalb ihrer Seite. |
| Schriftgrößen | `AccessTypography`: Beschriftung 12, Hinweis 14, Fließtext 16, Einleitung 18, Kartentitel 22, Abschnittstitel 28. |
| Responsive Überschriften | `pageMin` / `pageMax`: 30–40 zwischen 600 und 1000 verfügbarer Breite; `heroMin` / `heroMax`: 32–60 zwischen 600 und 1200. `AccessHeading` übernimmt die Auflösung und Überschriftensemantik. |
| Zeilenhöhe | `headingHeight` 1,15, `titleHeight` 1,3, `bodyHeight` 1,5, `readingHeight` 1,6. |
| Umbruchregeln | `searchMinWidth` 720, `twoColumnMinWidth` 900, `accountColumnsMinWidth` 1000. Ab Textskalierung 1,3 werden Text- und Formularspalten gestapelt. |

`AccessDesign.theme()` verbindet die Textrollen mit Flutters `TextTheme` und bindet `AccessLayoutTheme` ein. Eine Theme-Erweiterung ist ein zusätzlicher Satz zentraler Gestaltungswerte. `copyWith` erlaubt das Überschreiben der sechs fließenden Abstandswerte für einen eigenen Theme-Kontext, ohne einzelne Seiten zu verändern. Für eine globale Anpassung die Standardwerte im Designsystem ändern.

### Gemeinsame Regeln, eigene Anordnungen

- `AccessPageFrame`: zentrierter Seitenrahmen mit benannter Breite und Außenabständen. Verschachtelte Inhalte erhalten keine weiteren Seitenränder; Karten behalten ihre eigenen Innenabstände.
- `AccessContent`: begrenzt verschachtelte Formulargruppen auf `formWidth` und Lesebereiche auf `readingWidth`, ohne erneut Seitenränder einzufügen. Verwaltungsformulare und Kontoaktionen bleiben damit auch auf großen Flächen lesbar.
- `AccessField`: misst Beschriftungen mit der tatsächlichen Schriftvergrößerung und dem inneren Platzbedarf des Material-Felds. Wenn eine Beschriftung nicht passt, steht sie vollständig oberhalb des Felds; die zugängliche Feldbezeichnung bleibt erhalten. Lange Platzhalter werden als mehrzeilige Hinweise angezeigt. Dropdowns reservieren zusätzlich `AccessSpacing.s40` für ihren Pfeil.
- `AccessOptionText`: vollständige, umbrechende Dropdownnamen. Dropdownfelder verwenden variable Elementhöhen; maximal 20 Textzeilen decken die bestehenden begrenzten Namenslängen ab.
- `accessAppBar`: lässt Standard-Seitentitel umbrechen und berechnet die nötige Werkzeugleistenhöhe aus Schrift und Breite.
- `AccessStack`: vertikale Gruppen mit gemeinsamem Zwischenraum. Zwischen Anmelden/Passwortwiederherstellung und Kontoanlage gelten `AccessSpacing.s12`.
- `AccessSection`: Abschnitt mit optionaler Überschrift und fließendem vertikalem Rhythmus.
- `AccessColumns`: gemeinsame Umbruchentscheidung mit bereichsspezifischen Spaltenverhältnissen, Mindestbreiten und Abständen. Bei Bedarf darf die gestapelte Darstellung einen eigenen Abstand oder eine bestehende andere Inhaltsreihenfolge behalten.
- `AccessHeading`: Hero-, Seiten-, Abschnitts- oder Kartentitel; die Ebene der Überschrift wird unabhängig von der Schriftgröße vergeben. Beim Anmeldebereich liefert `referenceWidth` die gemeinsame Abschnittsbreite, damit der Spaltenwechsel die Titelgröße nicht sprunghaft verkleinert.

Die öffentliche Eventübersicht behält beispielsweise ihr Verhältnis 7:5, Einladungen 3:5 und Kontowiederherstellung 2:3. Redaktionelle Eventseiten behalten ihren eigenen Aufbau aus Veranstaltungsdaten, Text und Flyer. Diese Unterschiede sind absichtlich; sie verwenden dieselben benannten Grundlagen. Der Header bleibt auf einer Zeile: Logo, Navigation, Sprachdropdown und Konto. Reicht die verfügbare Breite unter Berücksichtigung der tatsächlichen Schriftgröße und Sprache nicht aus, öffnet ein Menüsymbol die Navigation als Dropdown. Bei besonders wenig Platz werden Markenname und Kontobeschriftung durch die weiterhin zugänglich benannten Symbole ersetzt. Der Sprachdropdown zeigt die aktuelle Sprache (DE/EN) und bietet Deutsch und English ausdrücklich zur Auswahl.

Flutter verwendet logische Pixel und verfügbare Constraints, keine CSS-Pixelregeln. Die responsive Schriftgrundgröße wird anschließend durch den eingestellten `TextScaler` vergrößert. Ein Menüwechsel oder Spaltenumbruch setzt die Schriftvergrößerung nicht zurück. Textbereiche dürfen wachsen; Bilder behalten ihr Seitenverhältnis und lange Formulare bleiben scrollbar. Bei großer Schrift ergänzt der Seitenrahmen am Ende mindestens `largeTextScrollTail` (64) als Scrollreserve, damit letzte Formularfelder vollständig aus dem Kopfbereich herausgescrollt werden können.

### Begründete Geometrieausnahmen

Der 6-Pixel-Kartenrahmen sowie seine äußere Rundung 32 und innere Rundung 26 erhalten die vorhandene konzentrische Gestaltung. Symbolpfade, Strichstärken und Markenproportionen sind Zeichnungsgeometrie und folgen keiner Text- oder Abstandsskala. Die Namen und Maße für Markenblock, Symbole, Metadatenspalten und Eventseitenleiste sind in `AccessLayout` zusammengefasst. Bedienelemente verwenden Mindestmaße statt fester Texthöhen; normale Seiteninhalte werden nicht absolut positioniert.

Tatsächliche Prüfungen und verbleibende Grenzen werden im [Abnahmebericht](qa/layout-system-2026-10-04/report.md) festgehalten. Historische Berichte sind keine aktuelle Abnahme.

Die Korrekturen und die erneute Darstellungsprüfung sind im [Prüfbericht vom 04.10.2026](qa/layout-corrections-2026-10-04/report.md) dokumentiert. Die vorherige Prüfung bleibt als historischer Vergleich erhalten.

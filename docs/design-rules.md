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

## Mobiles Menü und Symbole · 11.10.2026

Die bereitgestellte Bildvorlage `i-symbole.png` ist die Gestaltungsreferenz für das aktive Symbolsystem. `client/lib/access_symbols.dart` zeichnet die 41 Referenzsymbole sowie die bereits benötigten ergänzenden Aktionen auf einem 24er-Raster direkt in Flutter. Es wird keine nicht vorhandene Calcons-Schrift vorausgesetzt und keine zusätzliche Bibliothek installiert. `AccessIcon` in `client/lib/design_system.dart` bildet vorhandene Aktionsbezeichner zentral darauf ab. Die bisherigen Phosphor-Dateien bleiben erhalten, werden von diesem Adapter jedoch nicht mehr verwendet.

Grundformen verwenden zwei Rastereinheiten Strichstärke, kantige Enden und quadratische Punkte. Der optionale zweite Stift in Orange ist Dekoration; Grundform, Beschriftung und ausgewiesener Zustand bleiben auch einfarbig verständlich. Aktive Navigation verwendet gefüllte Varianten und eine zusätzliche Markierung. Werkzeuge wie Menü, Schließen, Pfeile und Suche bleiben einfarbig. `decorated: false` erlaubt ausdrücklich einfarbige Symbole; deaktivierte Symbole erhalten keinen orangefarbenen Akzent.

Das kompakte Navigationsmenü folgt der bestehenden Schwarz-Weiß-Orange-Gestaltung: rechteckiger Rahmen, Trennlinien, Archivo-Beschriftungen, thematisch passende Symbole und gekennzeichnete aktuelle Seite. Menüzeilen können bei großer Schrift wachsen und bei wenig Höhe scrollen. Der Auslöser ist mindestens 48 × 48 logische Pixel groß. Die vorhandene Popup-Menübedienung mit Tastatur, Escape, Fokus-Rückgabe und Schließen außerhalb des Menüs bleibt erhalten. Reduzierte Bewegung und Tastaturbedienung unterdrücken die Öffnungsbewegung.

Lokal geprüft: Flutter-Analyse ohne Befund, 300 Tests im erweiterten Modus sowie 8 V1-/Symboltests. Die Symbolprüfung rendert alle Formen einfarbig in 16, 20, 24 und 32 Pixeln. Chromium-Prüfungen auf `127.0.0.1` bestätigen Menüauswahl, Escape mit Fokus-Rückgabe, erneutes Öffnen per Enter, Schließen außerhalb und den festen Header bei 320 und 390 Pixeln; helle/dunkle Darstellung und englische Navigation wurden gesichtet. Widgetprüfungen decken zusätzlich doppelte Textgröße und 320 × 568 Pixel ab. Das ist kein Nachweis auf realen Mobilgeräten.

## Zeitraumfilter im Programm · 11.10.2026

Die bisherigen Sichtbarkeitsschalter im Programm sind durch „Alle Termine“, „Heute“, „Morgen“ und „Diese Woche“ ersetzt, jeweils auch auf Englisch. Die Zeiträume verwenden dieselbe lokale Gerätezeitzone wie die Datumsanzeige: Kalendertage von Mitternacht bis zur nächsten Mitternacht, Wochen von Montag bis zum folgenden Montag (exklusive Endgrenze). Die Standardansicht zeigt alle kommenden Termine. Die Auswahl betrifft die Programmliste und lässt sich mit der Suche kombinieren; das Eventkarussell bleibt unverändert. Auf schmalen Ansichten oder bei größerer Schrift können die Schalter umbrechen.

Der Client sendet die lokalen Grenzen als UTC-Zeitpunkte `from` und `before` an den bestehenden Endpunkt `/api/directory/events?scope=upcoming`. Der Katalog validiert beide Grenzen und filtert ausschließlich bereits zur Anzeige freigegebene Beginnzeiten vor Suche/Seitenausgabe bzw. Rangbildung. Ein nicht freigegebenes Datum wird dadurch weder angezeigt noch zum Filtern erschlossen. Leere Zeiträume erhalten einen eigenen Hinweis; „Alle Termine“ hebt die Einschränkung auf.

Lokal geprüft: Analyse und Formatierung ohne Befund; 310 Flutterregressionen im erweiterten Modus, 14 V1-/Datumsfiltertests, 58 Katalog-/Directory-Integrationstests und 11 V1-Backendtests bestanden. Chromium bestätigte Auswahl, leere Zeiträume, Rücksetzen und Bedienflächen bei 1617, 390 und 320 Pixeln sowie englische Texte und Tastaturbedienung. Positive Tages-/Wochentreffer wurden zusätzlich mit einer auf den synthetischen Eventtag gesetzten Browseruhr geprüft; der echte aktuelle Tag wurde separat geprüft. Reale Mobilgeräte wurden nicht geprüft.

## Aktive Gestaltung: Aushang 3 · 13.10.2026

Die aktive Oberfläche unter `client/` richtet sich nach dem vom Nutzer gelieferten Paket `community-access-codex-uebergabe.zip` und `BEWEGUNG.md`. Diese Festlegung ersetzt die historischen aktiven Stilvorgaben zu Rubik, roten Akzenten und Rundungen weiter oben. Die datierten früheren Abschnitte bleiben als Historie erhalten. Der Produktumfang wird weiterhin ausschließlich durch [product-spec.md](product-spec.md) festgelegt.

Archivo, kantige Flächen, Tinte und Weiß sowie eine orange Hauptaktion bilden die Grundlage. Die vorhandenen Adapter verwenden `CaTheme` und die gelieferten `CaIcons`; bestehende zusätzliche Zeichnungen bleiben für Produktaktionen erhalten, für die der Anhang kein Symbol enthält. Darstellung folgt standardmäßig dem System und bleibt im Konto umschaltbar. Bestehende Seitenränder und Umbruchgrenzen bleiben erhalten; die maximale Eventseitenbreite beträgt einschließlich Seitenrändern 1280 logische Pixel.

Startseite und Programm verwenden ein großes Plakat, Auswahlzeilen, einen dreistufigen Einstieg und die chronologische Monatsliste. Die Eventdetails zeigen Flyer und redaktionelle Informationen nebeneinander beziehungsweise mobil untereinander; Teilnahmestand und vorhandene Aktionen bleiben servergebunden. Veranstaltungsverwaltung verwendet breite Tabellenzeilen und auf schmalen Flächen gestapelte Angaben; Formularfelder bleiben auf die bestehende Formularbreite begrenzt. Anmeldung, Registrierung und Wiederherstellung behalten mangels eigener Entwürfe ihren Aufbau und erhalten die gemeinsame Gestaltung. Communities sowie bestehende Ticketfunktionen werden durch die Designvorlage nicht entfernt oder erweitert.

Der Plakatwechsel läuft alle sechs Sekunden und ist pausierbar. Reduzierte Bewegung verhindert automatischen Wechsel; Tastaturauswahl bewegt das Plakat nicht. Titel setzen sich einmal je angesehenem Event in der Karussellsitzung; Bilder werden in 280 ms überklebt. Flyer kippen nur bei Maus-Hover. Kreise werden nach 500 ms in 600 ms gezeichnet und stehen bei reduzierter Bewegung sofort fertig da. Klebestreifen verwenden Clipping statt animierter Layoutbreite. Zugangs- und Zahlungsregeln, geschützte Ortsangaben und Datenlebenszyklen bleiben fachlich unverändert.

[Tatsächliche Prüfungen, Screenshots und Grenzen](qa/aushang-20261013/report.md). Die pixelgenaue Abnahme der separaten Beispiel-App ist weiterhin offen: Ihre gelieferten Goldens weichen auf diesem System auch beim unveränderten ZIP-Stand ab. Aktive Clienttests und lokale Sichtprüfung ersetzen diesen fehlenden Nachweis nicht.

## Aktive Gestaltung: Kulturplakat / Flyer · 15.10.2026

Die ausdrücklich freigegebene Flyer-Vorschau unter `Webdesign Praktiken/Community-Access/Designvorschlaege-2026-10-15/Kulturplakat-Elemente/` und ihre anschließenden Nutzeranmerkungen sind jetzt die visuelle Grundlage der aktiven Flutter-App. Dieser Abschnitt ersetzt die aktiven Aushang-3-Stil- und Autoplayvorgaben oben; frühere datierte Abschnitte bleiben als Historie erhalten. Produktumfang und serverseitige Berechtigungen bestimmt weiterhin `product-spec.md`.

`flyer_design.dart` und `flyer_icons.dart` enthalten Papier `#f8f6f0`, Tinte `#171713`, orange Aktionen `#ff5a1f`, Marker `#e64a16`, eigene Zeichenpfade und die fotografische Bühne. Archivo bleibt lokal gebündelt, in normaler Breite. Header sind weiß, regulär 67 logische Pixel hoch, mit mindestens 48-Pixel-Bedienzielen; größere Schrift darf wachsen. Die aktive Navigation erhält einen einzelnen kräftigen Strich unter dem Wort. „Mein Zugang“ ist auf Desktop und im mobilen Menü orange umkreist, der Text bleibt schwarz. EN/DE schaltet die bestehende Sprachpräferenz um. Das mobile Menü verwendet zwei gezeichnete Striche und keine grauen Trenner oder schwarzen Unterstreichungen.

Desktop-Inhalte nutzen die verfügbare Breite mit fließendem Rand; vorhandene Formular-/Lesebreiten bleiben für ihre jeweiligen Gruppen erhalten. Fotoüberschriften und die Startseite verwenden eng an der Schrift liegende weiche Schatten, keine rechteckigen Textunterlagen. Die Eventinformation rechts erhält nur auf Desktop einen weich auslaufenden schwarzen Hintergrund. Orange Linien und Texte werden separat und scharf gezeichnet. Öffentliche redaktionelle Illustrationen sind als synthetisch gekennzeichnet; Eventmedien stammen aus dem freigegebenen API-Inhalt. Fehlende Bilder oder geschützte Orte werden nicht durch erfundene Eventangaben ersetzt.

Event- und Ticketflächen haben keine grauen Kartenrahmen/inneren Trennlinien; eigene orange Markierungen können die Inhalte rahmen. Formularumrandungen und chronologische Ordnungsstriche bleiben funktionale Orientierung. Verwaltung bleibt sachlich. Der Hero wechselt ausschließlich manuell über die beiden Pfeile rechts oben. Nummernanzeige und Play-/Pause-Schalter entfallen; es gibt keinen automatischen Plakatwechsel. Keine Pflichtanimation an Überschriften oder Markierungen.

Header-Präzisierung: Auf Desktop folgen rechts auf die Hauptnavigation „Mein Zugang“,
Suche und die Sprachauswahl am rechten Rand. Der gemeinsame Sprachschalter zeigt
die aktuelle Sprache als DE/EN mit Dropdown-Pfeil; das Menü bietet Deutsch und
English, markiert die aktive Sprache und erhält den aktuellen Seiten-/Eventzustand.
Mobil steht die Sprachauswahl vor dem Menü. Bedienziele bleiben mindestens 48 px
hoch; Escape schließt das Sprachmenü und gibt den Fokus an den Schalter zurück.
Header-Buttons haben keine schwarzen Rahmen. Ihr Fokus wird orange markiert;
der weiße Sprach-Dropdown hat keinen schwarzen Außenrahmen. Die aktive
Navigation behält ihren einzelnen orangefarbenen Unterstrich.

Veranstaltungsanzeigen tragen keine Kennzeichnung „Öffentlich“, „Privat“ oder
„Mit Zugang“ und kein zugehöriges Statussymbol. Dies gilt für Hero, Programmzeilen
und Listen in Veranstalter-/Communityansichten. Teilnahmeaktionen und nötige
Hinweise zur Ortsfreigabe bleiben erhalten; Zugangsregeln und redaktionelle
Sichtbarkeitseinstellungen werden dadurch nicht verändert.

Registrierte Community-Karten zeigen unten rechts die aktuelle Zahl zugeordneter
Veranstaltungen (`event_count` aus dem Community-Verzeichnis). Gezählt wird nach
denselben Berechtigungs-, Produkt- und Zeitregeln wie das kommende Programm;
bestätigte zusätzliche Community-Zuordnungen werden berücksichtigt, jeder Termin
je Community einmal. Null ist „0 Veranstaltungen“, fehlende/ungültige Zähldaten
sind „Anzahl nicht verfügbar“. Singular/Plural und EN werden lokalisiert.
Redaktionelle Themen-/Namensideen erhalten keinen Community-Zähler.

[Tatsächliche Umsetzung und lokale Prüfungen](qa/flyer-20261015/report.md). Die 26 Boards zeigen 13 echte Flutter-Ansichten mit synthetischen Fixtures. Sie ersetzen keine umfassende Geräte-, Rollen-/Zustands-, Screenreader- oder Produktionsabnahme.


## Verbindliche Typografie und Seitenstruktur – Audit 15.10.2026

`client/lib/access_typography.dart` ist die maßgebliche Schriftgrößenskala der
Flyer-Oberfläche. Historische Aushang-Tokens bleiben aus Kompatibilitätsgründen
bestehen. Neue Seiten verwenden die benannten Rollen über `design_system.dart`.

| Rolle | Basisgröße vor Nutzerskalierung | Verwendung |
|---|---|---|
| Hero | 52–88 px | Filmischer Einstieg auf der Startseite |
| Seitentitel | 38–64 px | Eine H1 je Ansicht; auch in Formularen und Leerzuständen |
| Abschnitt | 28–32 px | H2 für Inhaltsgruppen |
| Eintragstitel | 22–24 px | Ereignisse, Profile, untergeordnete Gruppen |
| Einleitung | 20 px | Kurzer beschreibender Einstieg |
| Fließtext | 16 px | Absätze, Eingaben und Erläuterungen |
| Metadaten | 14 px | Datum und ergänzende Status-/Kontextlabels |
| Feintext | 13 px | Zusätzliche Kontextlabels |

Die Größe richtet sich nach dem verfügbaren Platz. Überschriften dürfen
mehrzeilig werden; keine automatische Verkleinerung auf beliebige Zwischenwerte,
keine abgeschnittenen Titel und kein deaktivierter TextScaler. Die Sprache,
Archivo-Schrift, weißen Header und orangefarbenen Markierungen bleiben bestehen.
Die Bildherkunftsbeschriftung ist eine getrennte, kleine Bildannotation.

`AccessHeading` trennt visuelle Rolle und semantische Ebene. Standard: Seite/Hero
H1, Abschnitt H2, Eintrag H3. Direkte Einträge unter einer H1 können ausdrücklich
H2 sein; Untergruppen unter H2 sind H3. Keine ausgelassene Ebene und keine
zusätzliche H1 nur wegen eines großen Formularlabels. Eine Toolbar ist Navigation,
der Seitentitel steht im Inhalt. `AccessPageFrame(title: ...)` setzt ihn ein.

`AccessPageFrame` markiert den Hauptinhalt. Frames innerhalb bereits vorhandener
Haupt-/Footerbereiche verwenden `mainLandmark:false`, damit keine verschachtelten
Hauptbereiche entstehen. Reihenfolge: Header/Navigation, Haupttitel und Kontext,
passende Filter/Aktionen, Inhalt und Untergruppen, weitere Hilfe/Abschluss.
Lesetexte sind auf 680 px begrenzt; Veranstaltungslisten, Bilder und Arbeitsflächen
nutzen weiterhin die verfügbare Desktopbreite. Abstände folgen `AccessSpacing`.

Vor Übernahme: Analyse, V1- und erweiterte UI-Regression,
`test/typography_structure_test.dart`, 320/390/768/1440 px, DE/EN und doppelte
Schriftgröße prüfen. Neue öffentliche Überschriften verwenden die gemeinsamen
Rollen. Die Regression verbietet freie numerische Schriftgrößen in den sechs
zentralen öffentlichen Inhaltskomponenten und prüft 16 repräsentative Ansichten
sowie Lade-, Leer- und Fehlerzustände der Startseite. Ohne Hero bleibt der
Haupttitel in der Seitentitel-Rolle; mit Hero ist die folgende Programmliste H2.

### Veranstaltungsdaten in der Hero

Startseiten-Carousel und Veranstaltungsdetail zeigen Ticketpreis und sichtbare, tatsächlich zugeordnete Communities in derselben Metadatengruppe. Fehlende Preise bleiben ausdrücklich unbekannt; Preisuntergrenzen sowie Gebühren- und Vorverkaufshinweise werden erhalten. Externe redaktionelle Kategorien oder aus Veranstalternamen abgeleitete Tags sind keine Communityzuordnungen. Die Lesedarstellung verwendet ausschließlich freigegebene Communitynamen und ändert keine Zugangs- oder Kaufberechtigung.

Communitynamen mit freigegebener stabiler ID sind einzeln klickbar und öffnen eine eigene Communityprogrammseite. Eine einzelne orange Markierung bleibt unabhängig von der schwarzen beziehungsweise weißen Schrift. Der globale Communityfilter bietet „Alle Communities“ zum Zurücksetzen und wirkt zusammen mit Textsuche und Zeitraum. Unterseiten und Filter verwenden ausschließlich bereits serverseitig sichtbare Zuordnungen. Die Development-Vorschau kennzeichnet Beispiel-Communities und Beispiel-Veranstaltungen ausdrücklich als synthetisch.

### Randlose Seiten-Heros · 16.10.2026

Bestehende Seiten-Heros beginnen direkt unter dem Header und reichen links und
rechts über die gesamte verfügbare Ansichtsbreite. Dies gilt neben Startseite und
Veranstaltungsdetail für Communityübersicht, Communityprogramme, Veranstalter-
und Ortsverzeichnisse sowie deren Profilseiten. `AccessHeroLayout` trennt die
Bildbühne vom eingerückten Inhalt: Filter, Listen, Lesetexte und Formulare behalten
ihre jeweiligen Seitenränder und Breitenbegrenzungen. Eingebettete Seiten
übernehmen den Hauptbereich ihrer Eltern; Lade- und Fehleransichten ohne Hero
behalten den normalen Inhaltsrahmen. Der vorhandene Bildzuschnitt, vollständige
Eventplakate, weiche Übergänge und orange Markierungen bleiben erhalten.

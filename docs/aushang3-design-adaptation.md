# Aushang 3 – lokale Designanpassung

Stand: 05.10.2026. Arbeitsbranch: `codex/hero-bottom-alignment`.

## Gemeinsame Unterkante der Hero-Spalten

Auf Nutzerwunsch sind die Eventinformationen und Aktionen rechts jetzt unten
an der Titelgruppe ausgerichtet. Die breite Hero-Zeile verwendet dafür
`CrossAxisAlignment.end`; die vorhandene Geometrieprüfung kontrolliert die
gemeinsame Unterkante bei 960, 1280 und 1440 Pixeln. Die kompakte Anordnung
und die obere Carousel-Steuerung bleiben erhalten.

| Before | After | Why |
| --- | --- | --- |
| Rechte Infospalte vertikal mittig neben der Titelgruppe | Beide Spalten schließen unten auf derselben Layoutlinie ab | Informationen und Aktionen sitzen tiefer und folgen der unteren Titelkante |

**Prüfungen:** 19 gezielte Tests aus `aushang_design_test.dart` und
`discovery_widget_test.dart` bestanden, einschließlich schmaler Ansichten,
großer Schrift und beider Themes. Formatierung bestanden, Analyse ohne
Probleme und Web-Build erfolgreich. Die bekannte CupertinoIcons-Fontwarnung
bleibt bestehen. Fertigen Build bei 1280 × 720 Pixeln visuell geprüft;
Browserkonsole in dieser Ansicht ohne Fehler oder Warnungen. Mobile Ansichten
wurden durch Widgettests geprüft, nicht erneut im Browser. Änderungen gegen
den gesicherten Arbeitsstand und Leerzeichen geprüft. Die vollständige Suite
wurde für diese kleine Layoutänderung nicht wiederholt. Prüfserver beendet;
keine Veröffentlichung.

[Gerenderter Hero mit gemeinsamer Unterkante](screenshots/hero-bottom-20261005/desktop-light.jpg)

## Vorherige Carousel-Steuerung oben rechts, Eventinhalt weiter unten

Auf Nutzerwunsch liegen die beiden Pfeile und der Zähler jetzt oben rechts
innerhalb der Hero-Fläche. Die bisherige Steuerung unter dem Hero entfällt.
Die Communityzeile und die vorhandenen direkten Eventauswahllinks bleiben
unterhalb des Posters. Datum, Titel und Eventinfos/Aktionen sitzen weiter unten;
die mittige Ausrichtung der Desktopspalten bleibt erhalten.

Die Steuerung besitzt eine eckige Fläche mit Themefarben und dünner Kontur,
damit sie auch auf Flyern lesbar bleibt. Zwischen ihr und dem Inhalt liegen
mindestens 96 Pixel auf breiten beziehungsweise 64 Pixel auf kompakten
Ansichten. Alle Teile liegen im normalen Layoutfluss: lange Titel, große
Schrift und eine umgebrochene Steuerung können den Hero vergrößern und werden
nicht durch eine starre überlagerte Position verdeckt. Kompakte Eventinfos
bleiben unter dem Poster. Pfeiltasten, Beschriftungen, deaktivierte Einzel-
Event-Pfeile und manuelle Auswahl bleiben erhalten; kein automatischer Timer.

| Before | After | Why |
| --- | --- | --- |
| Pfeile und Zähler außerhalb unter dem Hero | Oben rechts innerhalb des Hero | Steuerung gehört direkt zur gezeigten Veranstaltung |
| Eventinhalt mittig in der Fläche | Inhalt weiter unten mit freiem Abstand zur Steuerung | Klare räumliche Trennung und ruhigere Anordnung |

**Prüfungen:** 34 gezielte Tests bestanden; die bestehenden Geometrieprüfungen
kontrollieren nun zusätzlich, dass die Steuerung oberhalb der Titelgruppe liegt
und auf Desktop rechts mit der Infospalte abschließt. Schmale Ansichten, große
Schrift, beide Themes und synchroner Wechsel von Titel und Eventinfos bestehen.
Analyse ohne Probleme. Formatierung und Änderungen gegenüber dem gesicherten
Arbeitsstand geprüft. Die gesamte Suite wurde für diese lokale Änderung nicht
wiederholt. Finaler Web-Build erfolgreich; die bekannte CupertinoIcons-
Fontwarnung bleibt bestehen. Fertigen Build bei 1280 × 720 Pixeln visuell
geprüft: Steuerung oben rechts, Eventinhalt weiter unten. Wechsel per Klick
auf „Nächste Veranstaltung“ und Rückwechsel mit linker Pfeiltaste erfolgreich;
Titel, Uhrzeit und Ortsangabe wechselten passend mit. Browserkonsole ohne
Fehler/Warnungen in diesen Wegen. Keine neue mobile Browserabnahme behauptet.
Prüfserver beendet; keine Veröffentlichung oder Kontodatenübermittlung.

[Gerenderter Hero mit oberer Steuerung](screenshots/hero-controls-20261005/desktop-light.jpg)

## Vorherige ruhigere Hero-Typografie auf Nutzerwunsch

Der Nutzer wünscht einen kleineren Titel und eine ausgewogenere Anordnung.
Diese Entscheidung ersetzt für den Hero die bisherige möglichst genaue
Übernahme der Postergröße aus dem Board. Desktop: 72–96 Pixel statt 72–168;
mobil beziehungsweise bei großer Schrift: 56 statt 84 Pixel als Ausgangsgröße.
Lange Wörter werden weiterhin eingepasst; die Vergrößerung durch Nutzer bleibt
wirksam. Zeilenhöhe 0,94 statt 0,82. Das Plakatdatum ist proportional auf
40 Pixel Desktop / 32 mobil reduziert. Die Mindesthöhe des Hero beträgt
520 Pixel Desktop / 360 mobil; längere oder vergrößerte Inhalte dürfen wachsen.
Die mittig ausgerichteten Spalten und ihre Trennung bleiben erhalten.

| Before | After | Why |
| --- | --- | --- |
| Bis 168 Pixel große Posterüberschrift | Maximal 96 Pixel Desktop / 56 mobil | Ruhigere Hierarchie und mehr Platz für sinnvollen Umbruch |
| 640 / 440 Pixel Mindesthöhe | 520 / 360 Pixel Mindesthöhe | Weniger leere Fläche, Programm näher am Einstieg |
| Enger Zeilenabstand und größeres Datum | Etwas offenerer Zeilenabstand, proportional kleineres Datum | Zusammenhängende, ausgewogenere Titelgruppe |

**Prüfungen:** 34 bestehende gezielte Tests bestanden, einschließlich echtem
Archivo-Wortumbruch, getrennter und mittig ausgerichteter Hero-Spalten bei
960/1280/1440 Pixeln, mobilen Ansichten, heller/dunkler Darstellung und großer
Schrift. Analyse ohne Probleme, Formatierung und Web-Build erfolgreich.
Die vollständige Suite wurde für diese kleine visuelle Änderung nicht wiederholt.
Die bekannte CupertinoIcons-Fontwarnung besteht weiter.

Finaler Build bei 1280 × 720 Pixeln im Browser visuell geprüft. Der aktuelle
synthetische Beispieltext steht nun in zwei statt drei Titelzeilen; Informationen
und Aktionen stehen mittig daneben. Browserkonsole ohne Fehler/Warnungen in
dieser Ansicht. Mobile Darstellung wurde durch Widgettests geprüft, nicht erneut
im Browser. Änderung gegenüber der gesicherten Quelle und Leerzeichen geprüft.
Prüfserver beendet; keine Veröffentlichung oder Kontodatenübermittlung.

[Gerenderter Hero mit kleinerem Titel](screenshots/hero-title-20261005/desktop-light.jpg)

## Vorherige Hero-Spalten und Original-Logo

Die neue Hero-Anordnung richtet Titel/Plakatdatum und Eventinfos/Aktionen ab
960 Pixeln vertikal mittig nebeneinander aus. Der künstliche Abstand unter dem
Titel entfällt. Die Infospalte wächst von 300 auf 360 Pixel, der Spaltenabstand
von 32 auf 48 Pixel. Titelmessung und tatsächliche Spaltenbreiten verwenden
dieselben Werte. Bei schmaler Ansicht und großer Schrift bleiben die Inhalte
untereinander; die Textvergrößerung bleibt erhalten.

Das erneut eingefügte SVG hatte bereits dieselben Pfade wie die bestehende
Quelle. Seine Darstellung wich jedoch durch Themefarben und einen entfernten
weißen Hintergrund ab. Die Assetdatei ist jetzt bytegleich mit der eingefügten
Datei. Der native Flutter-Vektor übernimmt Weiß `#FFFFFF`, Orange `#FF5A1F`
und Schrift `#0D0E13` einschließlich des Hintergrunds. Dies gilt für Header
und Footer sowie beide Themes. Der Generator schreibt nur die Dart-Darstellung
und verändert die SVG-Quelle nicht. Keine neue Abhängigkeit installiert.

| Before | After | Why |
| --- | --- | --- |
| Zusätzlicher Abstand unter dem Titel, unten ausgerichtete Infos | Vertikal zentrierte Spalten mit gemeinsamer Breitenberechnung | Ruhigere Anordnung nebeneinander ohne künstlichen Leerraum |
| Themeabhängige Logo-Farben und transparenter Hintergrund | Originalfarben und weißer Hintergrund aus dem eingefügten SVG | Exakte Übernahme der Nutzerquelle |
| Kopfzeile unterschätzt Schriftgröße und Innenabstände | Messung mit 16-Pixel-Navigationsschrift und tatsächlicher horizontaler Polsterung | Behebt den im neuen 960-Pixel-Test gefundenen Überlauf |

Tatsächliche Prüfungen dieses Durchgangs: **34 gezielte Tests bestanden**,
Analyse ohne Probleme, finaler Web-Build erfolgreich. Die neue Geometrieprüfung
verwendet echte Archivo und kontrolliert getrennte, mittig ausgerichtete Spalten
bei 960, 1280 und 1440 Pixeln. Bestehende Tests prüfen schmale Ansichten, große
Schrift, dunkle Darstellung und Carousel-/Navigationsaktionen. Die gesamte
Suite wurde für diese begrenzte Änderung nicht wiederholt.

Finalen Build bei 1280 × 720 Pixeln hell/dunkel visuell kontrolliert; keine
mobile Browserabnahme dieses Durchgangs behauptet. Die bekannte CupertinoIcons-
Fontwarnung besteht weiter. Keine fehlenden Glyphen in der geprüften Hero-
Ansicht beobachtet. SVG-Identität, Generatorsyntax, Formatierung und
Leerzeichenprüfung bestanden. Änderungen gegenüber dem gesicherten Arbeitsstand
vollständig geprüft. Prüfserver nach der
Sichtprüfung beendet. Keine Veröffentlichung oder Kontodatenübermittlung.

- [Hero und Logo, hell](screenshots/hero-logo-20261005/desktop-light.jpg)
- [Hero und Logo, dunkel](screenshots/hero-logo-20261005/desktop-dark.jpg)

## Vorheriger direkter Board-Abgleich und weiterer Umbau

Die drei HTML-Boards `i-start-breit`, `i-start-mobil` und `i-event-breit` wurden
mit ihren Komponentenregeln abgeglichen. Für den gerenderten Vergleich wurde
nur die externe Schriftreferenz durch die mitgelieferte lokale Archivo ersetzt.
UI/UX Pro Max **2.13.0** und Emils Design-Engineering-Sammlung bleiben das
Prüfraster; die Exportboards bestimmen die Gestaltung. Die bereits vorhandene
Arbeit auf dem Aufgabenbranch wurde erhalten. Keine neue Abhängigkeit,
Installation, Backendänderung, Veröffentlichung oder Kontoerstellung.

| Before | After | Why |
| --- | --- | --- |
| Gemischte Groß-/Kleinschreibung und kleinerer Hero | Versalien, Archivo `wdth=68`, 168-Pixel-Zielgröße auf Desktop, 84 mobil, Zeilenhöhe 0,82 | Übernimmt den Postercharakter; lange Wörter werden eingepasst, Textvergrößerung bleibt erhalten |
| Flüssiger Seitenrand und fünf Desktopziele | 48 Pixel Desktop / 16 mobil; vier Boardziele und orange aktive Markierung | Entspricht dem Raster; Communityprofile bleiben über Footer und Mobilmenü erreichbar |
| Einzelzeilen mit wiederholtem Datum | Nach tatsächlichem Tag gruppierte Kalenderzeilen; 112-Pixel-Datumsspalte, 176 × 116 Flyer, mobil 96 × 96 | Übernimmt die Hierarchie und Bildproportionen der Vorlage |
| Große Einstiegstitel und zwei ausgedehnte Bereiche | Kleine Schrittüberschriften, kompakte Gäste-/Veranstalterspalten mit Trennlinie | Gleicht Informationsdichte und Abschnittsgewicht an |
| Flyer in einem eigenen Seitenverhältnisrahmen | Flächenfüllender Hero; Detail mit Poster links und Fakten rechts im Verhältnis 5:7 | Bildwirkung folgt dem Board; die Galerie zeigt weiter den vollständigen Flyer |
| Anklickbarer Kalendertext als zusammengeführte Überschrift | Benannte Schaltfläche mit separater Überschrift | Die Aktion bleibt mit Tastatur und zugänglicher Beschriftung bedienbar |

Weitere Änderungen: kompakte Faktenzeilen, originale Phosphor-Globus-/Schloss-
Vektoren, 52-Pixel-Aktionen, 1,5-Pixel-Konturen und hartes Hoverfeedback.
Die Suche öffnet über das Lupensymbol und erhält direkt Fokus. „Konto anlegen“
öffnet die bestehende Registrierung, „Als Veranstalter starten“ den bestehenden
Zugangsweg. Die drei Filter filtern ausschließlich bereits serverseitig
freigegebene Daten. Empfehlung, Mitgliedschaft und Eventzusage bleiben getrennt.

### Aktuell beobachtete Prüfungen

- **186 Tests bestanden** nach dem Layoutumbau. Nach der abschließenden kleinen
  Semantikkorrektur wurden die drei betroffenen Kalender-/Filtertests erneut
  erfolgreich ausgeführt; die gesamte Suite wurde danach nicht erneut gestartet.
- Analyse ohne Probleme; finaler Web-Build erfolgreich. Die bekannte
  CupertinoIcons-Fontwarnung besteht weiter. Keine fehlenden Glyphen in den
  tatsächlich besichtigten Ansichten beobachtet.
- Formatierung, Tokenabgleich und `git diff --check` bestanden. Alle **21**
  eingebundenen Phosphor-SVGs sind bytegleich mit den mitgelieferten Originalen;
  die Generatorsyntax ist gültig. Aufgabenänderungen gegenüber der zu Beginn
  gesicherten Quellenkopie vollständig geprüft.
- Finalen Build tatsächlich bei **1280 × 720 Pixeln** hell/dunkel besichtigt:
  Hero, Kalender, Einstiegsbereiche, Footer und textbasiertes Eventdetail.
  Suche → Ergebnis → Zurücksetzen, Kalenderaktion → Eventdetail → Rückweg,
  Registrierungseinstieg → Rückweg und Darstellungswechsel funktionieren.
  Keine Konten erstellt oder Formulare mit Daten abgesendet. Browserkonsole
  ohne Fehler/Warnungen in diesen Wegen.
- Mobile Kalender-/Filteransichten bei 320 × 900 und 390 × 844 werden durch
  Widgettests geprüft; die bestehende Suite enthält zusätzlich große Schrift.
  **Mobile Browserprüfung des neuesten Builds noch nicht bestanden:** Die
  Browsersteuerung meldete die Größenänderung ohne Fehler, der gemessene
  Viewport blieb jedoch 1280 × 720. Frühere mobile Aufnahmen sind historische
  Nachweise und keine erneute Sichtprüfung dieses Builds.
- Die neue Detailanordnung mit Flyer wurde durch bestehende Widget-/Galerie-
  Tests geprüft. Der aktuelle lokale Browserkatalog enthält keine Flyer;
  diese Bildvariante wurde dort nicht visuell abgenommen. Native Screenreader
  und physische Mobilgeräte wurden nicht geprüft.

### Was für nachweisbare 1:1-Übereinstimmung noch nötig ist

1. **Derselbe synthetische Vergleichsinhalt:** identische Titel, Flyer,
   Metadaten, Anzahl/Reihenfolge und Textlängen. Die inline gezeichneten
   Boardbilder existieren im Export, sind aber keinem aktuellen Katalogevent
   zugeordnet. Ohne diese Zuordnung bleibt der Hero typografisch; nur die
   Kalenderplatzhalter verwenden das diagonale Papiermuster. Es wurden keine
   Boardveranstaltungen oder deren Orts-/Zusageangaben als Katalogdaten erfunden.
2. **Derselbe Zustand:** Desktopboard ohne Anmeldung, Mobilboard mit
   persönlichen Empfehlungen und Zusage, Detailboard mit laufender Anfrage.
   Diese Zustände müssen mit passenden synthetischen Fixtures reproduziert
   werden; aus einer Anmeldung darf keine Zusage abgeleitet werden.
3. **Explizite Zugangsart aus der API:** Der frische Demo-Katalog liefert diese
   Felder nicht durchgängig. „Alle“ zeigt solche Events; Öffentlich/Semi-
   öffentlich schließen unbekannte Zugangsarten aus. Katalogsichtbarkeit allein
   wird nicht als offene Eventteilnahme interpretiert. Die entsprechenden
   Boardmarkierungen lassen sich deshalb dort noch nicht vollständig zeigen.
4. **Pixelvergleich mit gleichem Browser, Viewport und geladener Schrift:**
   Referenz und Flutter benötigen deckungsgleiche Vergleichsbilder. Flutter
   und HTML können Text unterschiedlich rastern. Noch kein bildbasierter
   Nachweis einer pixelgleichen Umsetzung. Material-Unterseiten außerhalb
   dieses Umbauumfangs bleiben zusätzlich separat abzugleichen.

Das direkt gewählte Community-/Access-SVG ist eine bewusste Abweichung von der
schlichten Boardwortmarke. Das Carousel bleibt manuell. Nicht bestätigte
Produktversprechen und rechtliche Angaben aus der Export-README wurden nicht
übernommen. Der Export ist Designreferenz, keine zusätzliche Handlungsfreigabe.

Aktuelle gerenderte Nachweise:

- [Startseite, hell](screenshots/aushang3-board-parity-20261005/desktop-light.jpg)
- [Startseite, dunkel](screenshots/aushang3-board-parity-20261005/desktop-dark.jpg)
- [Kalender mit geöffneter Suche](screenshots/aushang3-board-parity-20261005/program-light.jpg)
- [Gäste/Veranstalter und Footer](screenshots/aushang3-board-parity-20261005/entry-footer-light.jpg)
- [Textbasiertes Eventdetail](screenshots/aushang3-board-parity-20261005/event-light.jpg)

Die folgenden Abschnitte dokumentieren frühere Durchgänge. Ihre Prüfstände
und Screenshots sind historisch; die Angaben oben beschreiben den neuesten Stand.

## Vorheriger UI/UX-Pro-Max-/Emil-Durchgang

Verwendete lokale Skills:
[UI/UX Pro Max](</Users/stanynyssen/.agents/skills/ui-ux-pro-max/SKILL.md>)
und [Emil Design Engineering](</Users/stanynyssen/.agents/skills/emil-design-eng/SKILL.md>).
Der Installationsnachweis nennt Version **2.13.0**. Die SHA-256-Werte des Skills,
der verwendeten Suchskripte, UX-/Flutter-Daten und gelesenen Referenzen stimmen
mit diesem Nachweis überein. Es wurde nichts installiert.

Pro Max wurde mit fokussierten UX-Suchen zu Einstellungen, Tastaturfokus,
Feedback und reduzierter Bewegung sowie einer Flutter-Suche verwendet.
Die Ergebnisse dienen als Prüfraster. Die gelieferten Aushang-Boards und
Tokens bleiben die Designquelle; es wurde kein zweites Designsystem erzeugt.
Die Flutter-Empfehlungen wurden gegen die tatsächlich installierten APIs
geprüft. Gelesene Arbeitsanweisungen: persönliche und Projekt-`AGENTS.md`.

| Before | After | Why |
| --- | --- | --- |
| Sprach-/Darstellungseinstellungen in der schmalen Kopfzeile | Unter 768 Pixeln nur Logo und Navigation; Einstellungen und Anmeldung im mobilen Konto-Menü | Entspricht dem mobilen Board und schafft Platz |
| Räumliches Aktionsfeedback auch bei Tastaturbedienung | Tastatur und reduzierte Bewegung ohne Verschiebung; Maus behält Aushang-Hover/Druck | Emils Regel für unmittelbare Tastaturaktionen, unter Beibehaltung der Design-Tokens |
| Touch kann einen Maus-Hover übernehmen | Rückmeldung hängt von der aktuellen Eingabeart ab | Verhindert einen nach dem Tippen stehenbleibenden Hover |
| Unmarkiertes Plakatdatum und abweichende untere Icons | Originaler Datums-Markerpfad; Phosphor `door-open-light` und `user-circle-light` | Nähere Übernahme der Exportvorlage |

Das Konto-Menü ist scrollbar, berücksichtigt sichere Bildschirmränder und
vergrößerten Text. Beim Wechsel der Darstellung aktualisiert sich auch seine
Fläche. Die Anmeldung öffnet nach dem Schließen des Menüs den vorhandenen
Kontoweg. Einstellungen verändern weder Sitzung noch Zugangsrechte.
Sie bleiben wie bisher im Arbeitsspeicher. Tastatur- oder bewegungsreduziertes
Öffnen des Menüs erfolgt ohne Übergang; sonst 200 ms hinein / 120 ms heraus.
Die Datumsumrandung ist statisch und verzögert die Lesbarkeit nicht.

### Tatsächliche Prüfungen dieses Durchgangs

- **183 Flutter-Tests bestanden**, Analyse ohne Probleme, Web-Build erfolgreich.
- Neue Prüfungen: Menü bei 320 × 900, 375 × 812 und 700 × 375 Pixeln mit
  doppelter Textgröße; Sprach-/Darstellungswechsel, Schließen und Anmeldung
  mit Rückkehr zur Hauptseite; keine API-Schreiboperationen durch Einstellungen.
- Maus → Tastatur, Maus → Touch und reduzierte Bewegung für gemeinsame Aktionen
  geprüft. Bestehende Navigation, Formular- und Zugangsprüfungen bleiben aktiv.
- Fertigen Web-Build im Browser bei 320 × 900 und 1280 × 900 Pixeln hell/dunkel
  visuell geprüft. Konto-Menü, Sprachwechsel, Anmeldung und Rückweg bedient.
  Browserkonsole ohne Fehler oder Warnungen. Keine Konten erstellt oder
  Benutzerdaten abgesendet.
- Berechnete Kontraste: Text auf Seite hell 19,28:1 / sekundär 6,25:1;
  dunkel 17,55:1 / sekundär 7,95:1; Tinte auf primärer Aktion 6,18:1,
  gedrückt 5,23:1. Dies ist eine Prüfung dieser Tokenpaare, keine vollständige
  WCAG-Abnahme oder Prüfung beliebiger Flyerbilder.
- Formatierung und `git diff --check` bestanden. Änderungen gegenüber dem
  gesicherten Arbeitsstand geprüft; vorhandene Arbeit blieb erhalten.

Offen bleiben die bekannte CupertinoIcons-Fontwarnung, die vollständige
Migration übriger Material-Seiten, physische Geräte und native Screenreader.
Der Sprachwechsel funktioniert, aber bestehende Texte außerhalb des neuen
Menüs sind teilweise noch nicht ins Englische übersetzt. Veranstalter- und
Eventinhalte werden durch einen UI-Sprachwechsel nicht automatisch übersetzt.
Dies ist ein lokaler Designlauf und keine Veröffentlichung.

## Vorheriger Abgleich mit den Design-Skills am 05.10.2026

Verwendet wurden `design-taste-frontend` für Komposition und visuelle Hierarchie
sowie `ecc:design-system` im Auditmodus. Die bereitgestellten Boards und Tokens
bleiben die Designquelle. Allgemeine Skill-Vorschläge zu Stockbildern, anderen
Schriften oder einer neuen Navigation wurden nicht übernommen. Die gelesenen
Anweisungen stammen aus `~/.codex/AGENTS.md` und dem Projekt-`AGENTS.md`.

Die weitere Anpassung umfasst den randlosen Plakat-Hero direkt unter der
Kopfzeile, ein schmales 52-Pixel-Datum, engeren Titelzeilenabstand, die
vollbreite orange Aktion und getrennte mobile Eventinfos unter dem Poster.
Desktop- und Mobilhöhen von 640 beziehungsweise 440 Pixeln sind Mindesthöhen;
vergrößerter oder langer Text darf den Bereich erweitern. Ohne echten Flyer
erscheint eine ruhige typografische Fläche in der hellen/dunklen Palette.
Datum und Uhrzeit bleiben vollständig in den Eventinfos erhalten.

Drei nummerierte Schritte verwenden den bereits beschriebenen Produktablauf:
Einladung und Bewerbung, manuelle Aufnahme, separate Anfrage zur Eventteilnahme.
Die Suche hat keinen zusätzlichen Kartenrahmen mehr. Kalenderzeilen verwenden
96-Pixel-Datumsspalten und Flyerbreiten, kompakte Metadaten und eine 48-Pixel-
Merkaktion am rechten Rand. Auf breiten Ansichten steht die Öffnungsaktion in
derselben Zeile; auf schmalen Ansichten darunter. Zugang und Communities bilden
zwei Bereiche mit oberen Tintenlinien; der Footer folgt dem Spaltenraster des
Boards und führt ausschließlich zu vorhandenen Seiten.

Die Merkaktion behält eine zugängliche Beschriftung und einen Tooltip. Ihr neuer
Test prüft Mindestgröße, Beschriftung und dass ein anonymer Klick ausschließlich
die Anmeldung öffnet und keine Merklistenabfrage oder Schreiboperation ausführt.
Hero und übriger Inhalt liegen in einem gemeinsamen Hauptlandmark; der Footer
ist ein separater Footer-Landmark.

Die aktuelle Prüfung des fertig gebauten Stands umfasst die 1280 × 900 Pixel
Desktopansicht und die 320 × 900 Pixel Mobilansicht, jeweils hell und dunkel.
Im Browser wurde die kompakte Merkaktion bis zur Anmeldung und zurück bedient;
die Browserkonsole lieferte keine Fehler oder Warnungen. Die aktuelle Suite
besteht mit **179 Tests**, `flutter analyze --no-pub` meldet keine Probleme und
`flutter build web --no-pub --no-web-resources-cdn` ist erfolgreich. Die bekannte
CupertinoIcons-Warnung des Builds besteht weiter. Keine Konten wurden angelegt
und keine Formulare mit Benutzerdaten abgesendet.

### Designaudit

Die Zahlen sind eine qualitative Einschätzung des geprüften lokalen Stands,
keine Messung der prozentualen Designübereinstimmung. Die Bewertung gilt für
Startseite und gemeinsame Aktionen; andere Verwaltungsseiten wurden in diesem
Durchgang nicht visuell neu abgenommen.

| Dimension | Einschätzung / 10 | Beispiel, Fundstelle und verbleibende Korrektur |
| --- | --- | --- |
| Farben | 9 | Hero nutzt `AushangPalette.sunken`, `client/lib/event_carousel.dart:232`; vorhandene Theme- und Aktionsfarben sind tokenbasiert. Weitere Material-Seiten separat auditieren. |
| Typografie | 9 | Archivo `wdth=68`, 52-Pixel-Datum und engerer Posterumbruch, `client/lib/event_carousel.dart:103`. Lange echte Titel dürfen mehr Zeilen haben; die handgezeichnete Datumsmarkierung aus dem Board fehlt. |
| Abstände | 9 | Gutter aus `AccessLayout`, `client/lib/event_carousel.dart:90`; Schritte und Einstiegsbereiche verwenden das 8-Pixel-Raster, `client/lib/public_home_page.dart:590`. |
| Komponenten | 8 | Gemeinsame Forui-Aktion mit Iconvariante, `client/lib/aushang_forui.dart:226`. Weitere Material-Formulare bleiben noch außerhalb der vollständigen Forui-Migration. |
| Responsivität | 9 | Mobile Infos folgen unter dem 440-Pixel-Poster, `client/lib/event_carousel.dart:301`; Spalten wechseln bei großer Schrift in Stapel. 320/768/1440 Pixel, einfache und doppelte Textgröße werden durch die vorhandenen Tests geprüft. |
| Dunkelmodus | 9 | Hero, Regeln, Metadaten und Aktionen übernehmen die dunkle Palette, `client/lib/event_carousel.dart:232`. Weitere Detail- und Verwaltungsseiten benötigen getrennten visuellen Abgleich. |
| Bewegung | 9 | Manuelles Carousel ohne Timer; reduzierte Bewegung für Aktionen, `client/lib/aushang_forui.dart:259`. Keine zusätzlichen Scrollanimationen eingeführt. |
| Barrierefreiheit | 8 | 48-Pixel-Ziel, Semantiklabel und Tooltip, `client/lib/bookmark_views.dart:117`; Hauptlandmark umfasst auch den Hero. Native Screenreader und Kontrast auf beliebigen künftigen Flyerbildern sind noch nicht geprüft. |
| Informationsdichte | 9 | Eine Programmüberschrift, kompakte Metadaten und Aktionen in der Kalenderzeile, `client/lib/program_views.dart:165`. Fehlende Flyer werden nicht durch erfundene Bilder ersetzt. |
| Ausarbeitung | 8 | Hover, Fokus, deaktivierte Zustände, Lade-/Fehler-/Leerzustände bleiben vorhanden. Fehlermeldung der Merkaktion: `client/lib/bookmark_views.dart:161`. Sprach-/Darstellungsoptionen liegen weiterhin im Kopfmenü statt ausschließlich im mobilen Konto. |

Kein neues Designsystem und keine neue Paketinstallation wurden angelegt.
Orange bleibt auf die zentrale Plakataktion und die Wortmarke konzentriert;
Karten und andere Aktionen verwenden Tintenlinien oder neutrale Flächen.
Der Bildverlauf wird ausschließlich bei real gelieferten Flyern zur Lesbarkeit
eingesetzt. Backend-Filterung und getrennte Zugangsentscheidungen sind erhalten.

## Ergebnis und offene Designbasis

Die vorhandene Flutter-Website verwendet jetzt die Farben, eckigen Formen,
Abstands- und Bewegungswerte des gelieferten Aushang-3-Exports. Startseite,
Plakat-Carousel, Kalenderzeilen, gemeinsame Formulare, Kopfzeilen und die
mobile Navigation sind angepasst. Die bestehenden Änderungen im Arbeitsbaum
wurden erhalten; kein Commit, Push oder Deployment wurde beauftragt.

Die Umsetzung ist **noch keine vollständige Übernahme der Exportbasis**:

- Archivo ist aus der nachgereichten `Archivo.zip` lokal eingebunden, normal
  und kursiv. Die unveränderten Fontdateien enthalten `wdth=62–125` und
  `wght=100–900`. Überschriften verwenden die vorgesehene Breite `wdth=68`;
  die Gewichtswahl erfolgt über Flutter `FontWeight`. Rubik bleibt als
  Glyphen-Fallback vorhanden. Archivo stammt aus der bereitgestellten ZIP;
  die Schrift wurde nicht auf Betriebssystemebene installiert.
- Forui **0.27.4** ist im App-Root an die Aushang-Tokens angebunden. Plakataktion,
  Suche, Kopfzeilen-Anmeldung, Merken, Registrierung und Interessenbekundung
  verwenden jetzt gemeinsame `FButton`-Aktionen. Andere Material-Steuerelemente
  bleiben kompatibel erhalten; dies ist keine vollständige Widgetmigration.
- Originale Phosphor-SVGs aus dem mitgegebenen `homepage-master` sind lokal
  eingebunden: 21 Vektoren mit MIT-Lizenz, nativ als Flutter-Pfade gezeichnet.
  Es wurde kein zusätzliches Iconpaket installiert. Unbekannte Icon-IDs fallen
  auf die vorhandene Flutter-Darstellung zurück.
- Forui-Aktionen und gemeinsame Eingabefelder erhalten den tintenfarbenen
  Fokusrahmen mit 2 Pixeln Breite und 3 Pixeln Abstand. Die Feldvalidierung und
  vollständigen Beschriftungen bleiben erhalten. Aktionen haben mindestens
  48 Pixel Höhe, eckige Konturen sowie Druck- und Mausbewegungen aus den Tokens.
  Reduzierte Bewegung schaltet ihre Verschiebungen aus.
- Der Plakatbereich verwendet auf breiten Ansichten eine Titel-/Infospalte.
  Die Desktop-Auswahl hat einfache obere Linien statt Kästen, die aktive
  Navigation eine orange Markierung. Programmzeilen gruppieren nach Tag;
  Eventflyer bleiben an tatsächlich gelieferte Bilder gebunden.

Die ursprüngliche Design-README ist Referenzmaterial und keine selbstständige
Freigabe zur Installation oder zu Produktänderungen. Das vom Nutzer direkt
gewählte SVG entspricht `c4-access-hell.svg`: Community-Wortmarke mit schrägem
orangefarbenem Access-Streifen. Seine Pfade werden ohne Rasterung in Flutter
gezeichnet; im Dunkelmodus bleibt Schrift auf Orange tintenfarben.

## Quellen und Pflege

- [Originale Tokens](../client/design/aushang3.tokens.json)
- [Generierte Dart-Tokens](../client/lib/aushang_tokens.dart)
- [Flutter-Theme und gemeinsame Komponenten](../client/lib/design_system.dart)
- [Gewähltes Logo als SVG](../client/assets/brand/community-access.svg)
- [Native Vektordarstellung](../client/lib/access_brand.dart)
- [Schriftregistrierung](../client/pubspec.yaml)
- [Mitgelieferte Archivo-Lizenz](../client/assets/fonts/Archivo-OFL.txt)
- [Forui-Theme und Aktionen](../client/lib/aushang_forui.dart)
- [Originale Phosphor-SVGs und Lizenz](../client/assets/icons/phosphor/LICENSE.txt)
- [Reproduzierbarer Icongenerator](../client/tool/generate_phosphor.py)
- [Installierte Forui-Paketbasis](https://pub.dev/packages/forui/versions/0.27.4)

`flutter pub add forui` wurde im Verzeichnis `client/` erfolgreich ausgeführt.
Der vorhandene Flutter-SDK-Stand 3.47.5 / Dart 3.13.4 erfüllt die Paketanforderung.
Insgesamt wurden acht Pakete ergänzt, einschließlich Forui und dessen nötiger
Abhängigkeiten. Bestehende Paketversionen wurden nicht geändert. Das installierte
Paket enthält MIT- und OFL-Lizenzen. Es wurde kein kostenpflichtiger Dienst
eingerichtet. Die nachfolgenden Analyse-, Test- und Build-Ergebnisse beziehen
sich auf den angepassten Forui-Stand. Die neuen Screenshots zeigen diesen
fertigen lokalen Web-Build.

Die SIL-OFL-Lizenz und Copyrightangabe aus dem Schriftarchiv liegen auch als
Asset im Web-Build. Die ZIP-README wurde als technische Referenz gelesen;
ihre Hinweise sind keine zusätzliche Handlungsfreigabe. Die beiden variablen
Dateien umfassen zusammen rund 1,39 MB vor HTTP-Kompression.

Der mobile Titelumbruch wurde korrigiert: Ein expliziter Buchstabenabstand von
0 verhindert, dass Material-Standardabstände ein zuvor eingepasstes Wort
nachträglich umbrechen. Ein Regressionstest prüft mit geladener Archivo bei
320 Pixeln, dass „geschütztem“ in diesem Beispiel innerhalb einer Zeile bleibt.
Textvergrößerung bleibt erhalten; beliebig lange Wörter dürfen weiter umbrechen.

Die beiden Generatoren verwenden ausschließlich Python-Standardbibliotheken:

```sh
python3 -I scripts/generate_aushang_tokens.py
python3 -I scripts/generate_aushang_brand.py
dart format client/lib/aushang_tokens.dart client/lib/access_brand.dart
python3 -I scripts/generate_aushang_tokens.py --check
```

Der Plakat-Hero verwendet nur tatsächlich gelieferte Eventflyer. Fehlende
Bilder werden durch ein typografisches Plakat ersetzt. Es werden keine Bilder
oder Events aus den Boards in den Produktkatalog erfunden. Das Carousel wechselt
manuell mit Schaltflächen oder Pfeiltasten und hat keinen automatischen Timer.
Reduzierte Bewegung deaktiviert die vorhandenen Einblendbewegungen.

Mobile Zugänge führen zu den bestehenden Seiten für Merkliste und Mein Zugang;
ohne Sitzung führen sie zur Anmeldung. Konto öffnet das neue Menü mit Anmeldung,
Sprach- und Darstellungsoptionen. Auf Desktop bleiben diese Optionen im bisherigen
Sprachmenü; die Darstellungswahl bleibt im Arbeitsspeicher. Die bestehenden
Desktop-Navigationsziele bleiben erhalten.

Sichtbarkeit, Mitgliedschaft, Eventzusage und genaue Location bleiben getrennt.
Sichtbarkeitsmarkierungen benötigen explizite API-Felder. Ein fehlendes Feld
wird nicht als öffentliche Freigabe interpretiert. Die im Board genannten
Löschfristen und weiteren Produktversprechen wurden nicht übernommen.

## Frühere Gesamtprüfung vor dem direkten Board-Umbau

| Prüfung | Ergebnis |
| --- | --- |
| Dart-Formatierung der geänderten Quellen | Bestanden |
| `flutter analyze --no-pub` | Bestanden |
| Vorhandene und neue Flutter-Tests | 183 bestanden |
| Carousel-/Theme-Regression mit echter Archivo | Bestanden |
| Token-Quelle gegen generierten Code | Bestanden |
| Python-Generatoren: Syntaxprüfung | Bestanden |
| Lokaler Web-Build mit gebündeltem Renderer | Bestanden |
| `git diff --check` | Bestanden |
| Browser: synthetischer Katalog, Eventdetail und Rückweg | Bestanden |
| Browser: 320-Pixel-Ansicht und sichtbare untere Navigation | Bestanden |
| Browser: Darstellungswechsel auf Desktop | Bestanden |
| Browser: mobile Navigation und Darstellungswechsel | Bestanden bei direktem 320 × 900 Pixel Viewport |
| Archivo-Dateien im Build inklusive Lizenz | Bestanden |
| Forui-Installation und Abhängigkeitsauflösung | Bestanden, 0.27.4 |
| Forui: Tastaturaktivierung, deaktivierter Zustand und Aktionsfarben | Bestanden, hell und dunkel |
| Umstellung gemeinsamer Aktionen auf Forui | Umgesetzt; übrige Material-Felder und Navigation bleiben erhalten |
| Phosphor | Originale Vektoren und MIT-Lizenz eingebunden |
| Vollständige Backend-, Native-Screenreader- und Live-Abnahme | Nicht Bestandteil dieses Designlaufs |

Die responsive Widget-Prüfung umfasst 320, 768 und 1440 Pixel bei einfacher und
doppelter Textgröße, jeweils hell und dunkel. Zusätzlich prüft ein Forui-Test
Tastaturaktivierung und den deaktivierten Zustand. Die bestehende Testabdeckung
für Registrierung, Merkfunktionen und getrennte Zugangsentscheidungen bleibt
aktiv. Die Selektoren wurden an den neuen gemeinsamen Widgettyp angepasst;
die Animationsprüfung wartet vor dem Abschluss auf die neue Komponente.

Die älteren Forui-Desktopaufnahmen haben 1105 × 984 Pixel. Der neue Skill-Abgleich verwendet die Boardbreite 1280 Pixel und 900 Pixel Höhe. Im aktuellen Browserlauf funktionierte der direkte Viewport mit 320 × 900
Pixeln. Merkliste → Anmeldung → Zurück sowie die mobile Darstellungswahl wurden
bedient. Die zuvor beim iframe aufgetretene Steuerungsblockade ist damit für
diese Wege behoben. Dies ist weiterhin kein Test auf einem physischen Mobilgerät.
Die 320-Pixel-Titelprüfung nutzt die echte Archivo; eine kleine Messreserve
verhindert Umbrüche durch Rundung an der maximalen Wortbreite.

Der Build meldet weiterhin eine CupertinoIcons-Fallbackwarnung aus dem
vorhandenen SDK-/Projektstand. Bei den geprüften Ansichten wurden keine
fehlenden Glyphen beobachtet. Die übrigen Material-Steuerelemente wurden nicht
vollständig migriert.

Für die Browserprüfung lief ein frischer synthetischer `--directory-demo`-
Bestand lokal auf `127.0.0.1:8000` und der fertige Web-Build auf
`127.0.0.1:8300`. Die selbst gestarteten Prüfserver wurden danach beendet.

## Gerenderte Nachweise

Vorheriger Pro-Max-/Emil-Abgleich:

- [Desktop, hell](screenshots/aushang3-promax-emil-20261005/desktop-light.jpg)
- [Desktop, dunkel](screenshots/aushang3-promax-emil-20261005/desktop-dark.jpg)
- [Mobil, hell](screenshots/aushang3-promax-emil-20261005/mobile-light.jpg)
- [Mobil, dunkel](screenshots/aushang3-promax-emil-20261005/mobile-dark.jpg)
- [Konto-Menü, hell](screenshots/aushang3-promax-emil-20261005/account-menu-light.jpg)
- [Konto-Menü, dunkel](screenshots/aushang3-promax-emil-20261005/account-menu-dark.jpg)

Vorheriger Skill-Abgleich:

- [Desktop, hell](screenshots/aushang3-design-skills-20261005/desktop-light.jpg)
- [Mobil, hell](screenshots/aushang3-design-skills-20261005/mobile-light.jpg)
- [Mobil, dunkel](screenshots/aushang3-design-skills-20261005/mobile-dark.jpg)
- [Desktop, dunkel](screenshots/aushang3-design-skills-20261005/desktop-dark.jpg)
- [Verdichtete Kalenderzeilen](screenshots/aushang3-design-skills-20261005/program-light.jpg)
- [Einstiegsbereiche und Footer](screenshots/aushang3-design-skills-20261005/entry-footer-light.jpg)

Vorheriger Forui-Stand:

- [Forui-Stand: Desktop, hell](screenshots/aushang3-forui-20261005/desktop-light.jpg)
- [Forui-Stand: Mobil, hell](screenshots/aushang3-forui-20261005/mobile-light.jpg)
- [Forui-Stand: Mobil, dunkel](screenshots/aushang3-forui-20261005/mobile-dark.jpg)
- [Forui-Stand: Desktop, dunkel](screenshots/aushang3-forui-20261005/desktop-dark.jpg)
- [Forui-Stand: Programmzeilen](screenshots/aushang3-forui-20261005/program-light.jpg)
- [Forui-Stand: Eventdetail](screenshots/aushang3-forui-20261005/event-light.jpg)

Ältere Vergleichsaufnahmen:

- [Desktop mit Archivo, hell](screenshots/aushang3-archivo-20261005/desktop-light.jpg)
- [Mobil mit Archivo, hell](screenshots/aushang3-archivo-20261005/mobile-light.jpg)
- [Desktop mit Archivo, dunkel](screenshots/aushang3-archivo-20261005/desktop-dark.jpg)
- [Früherer Eventdetail-Nachweis mit Ersatzschrift](screenshots/aushang3-20261005/event-light.jpg)

Die neuen Startseiten-Nachweise zeigen die lokale Anpassung mit Archivo.
Sie sind keine
Bestätigung einer Veröffentlichung oder einer vollständig originalgetreuen
Designübernahme.

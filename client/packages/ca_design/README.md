# Aushang 3 für Flutter (iOS und Android)

Paket `ca_design`: Tokens, Theme (hell und dunkel) und Bausteine des Designsystems Aushang 3.
Quelle der Werte ist `../aushang3.tokens.json`. Nach jeder Änderung dort:

```sh
python3 tool/gen_tokens.py
```

Stand 05.10.2026: mit Flutter 3.47.6 geprüft (`flutter analyze` ohne Befund, Tests grün), noch nicht in `client/` eingebunden.

## Einbinden

```dart
MaterialApp(
  theme: CaTheme.light(),
  darkTheme: CaTheme.dark(),
  themeMode: ThemeMode.system, // im Konto-Menü umschaltbar
);
final c = CaColors.of(context); // Bedeutungsfarben, z. B. c.textSecondary
```

Archivo liegt als variable Schrift mit Breite und Gewicht in `fonts/` (SIL Open Font License, `fonts/OFL.txt`).

## Prüfen

```sh
flutter analyze && flutter test
cd example && flutter test --update-goldens test/screens_test.dart   # Bildschirmbilder in example/test/screens/
```

## Eine Gestaltung, zwei Plattformen

Die App sieht auf iOS und Android gleich aus: weiß, Tinte, ein Orange, eckig, Archivo.
Bedienung, Abstände und Gesten folgen der jeweiligen Plattform, damit sich nichts fremd anfühlt.
Kein Hamburger-Menü: Orte und Veranstalter sind Abschnitte im Programm, Einstellungen, Hilfe und
Rechtliches liegen unter Konto.

| Thema | iOS | Android |
|---|---|---|
| Navigation (`CaNavBar`) | Leiste unten, 50 pt, Beschriftung 10 pt | Leiste unten, 80 dp, Beschriftung 12 sp |
| Seitenkopf (`CaLargeTitlePage`) | großer Titel, klappt beim Scrollen zur Mitte ein | großer Titel, klappt links ein |
| Programm-Kopf | Logo links, Suche rechts | gleich |
| Abschnitte (`CaSegments`) | Segmentschalter | Reiter über die volle Breite mit Klebestreifen |
| Suche (`CaSearchField`) | natives Suchfeld | Textfeld mit Lupe |
| Einstellungen (`CaSettingsSection`) | gruppierte Liste mit Pfeil | Liste mit Überschrift, Zeilen 56 dp |
| Weitere Aktionen (`showCaActions`) | Aktionsblatt mit „Abbrechen“ | Blatt von unten mit Symbolen |
| Teilen, Mehr | `Icons.adaptive.share`, `.more` (iOS-Formen) | Android-Formen |
| Entfernen (`CaSwipeToRemove`) | nach links wischen | gleich |
| Kurze Rückmeldung (`showCaToast`) | keine Einblendung; Zustand ändert sich an Ort und Stelle, dazu spürbare Rückmeldung | Snackbar mit „Rückgängig“ |
| Hauptaktion auf Detailseiten (`CaBottomAction`) | unten fest, über der Home-Leiste | unten fest, über der Gestenleiste |
| Aktualisieren | Ziehen mit iOS-Anzeige | Ziehen mit Kreis |
| Zurück | Wischen vom linken Rand, native Schiebebewegung | vorausschauende Zurück-Geste |
| Sprache | öffnet die Spracheinstellung der App im System | gleich (ab Android 13) |
| Reduzierte Bewegung | Plakate wechseln nicht von selbst, Striche blenden ein | zusätzlich Seitenwechsel als Überblenden |
| Dialoge, Schalter, Laden | `.adaptive`-Varianten | gleich, eckig im Aushang-Stil |
| Spürbare Rückmeldung | `CaHaptics`: Auswahl, Merken, Entscheidung | gleich |
| Schriftgröße | folgt dem System; Plakat und Navigation höchstens 130 % | gleich |
| Tippflächen | mindestens 48 × 48 | gleich |

Beispiel-App mit vier Zielen: `example/lib/app.dart`, Bildschirmbilder je Plattform in
`example/test/app/` (`flutter test --update-goldens test/app_test.dart`).

Keine Material-Welle beim Tippen: gedrückt wird die Fläche dunkler und 1 px tiefer.
Bewegung: ease-out (.23, 1, .32, 1), Oberfläche unter 300 ms, nur Kreis von Hand 600 ms.

## Bausteine

| Baustein | Wofür |
|---|---|
| `CaButton` | orange Hauptaktion (eine je Bildschirm), Tinte, Umriss; mit Laden |
| `CaSaveButton` | Merken, quadratisch neben dem Hauptknopf |
| `AccessMark`, `CaAccess` | Zugangszeichen mit Text: öffentlich, semi-öffentlich, privat |
| `LockLabel`, `EmbossedLock` | Schloss mit Text; Blindprägung nimmt keinen Inhalt an, keine Adresse |
| `DateCircle`, `CaTape` | Kreis von Hand ums Datum; Klebestreifen unter dem Aktuellen |
| `PosterCarousel`, `PosterHero`, `PosterInfo` | Plakat-Hero, Wechsel durch Überkleben |
| `EventRow`, `CaNoImage` | Programmzeile; Raster mit Titel statt Ersatzfoto |
| `DoorList`, `Stamp` | „Dein Stand“; Zugesagt und Abgesagt |
| `CaNavBar` | Programm, Merkliste, Mein Zugang, Konto |
| `CaEmpty`, `CaSkeleton`, `CaNote`, `CaOfflineBar`, `showCaToast` | Zustände und Rückmeldung |
| `CaLogo` | Logo „Community Access“, hell oder dunkel nach Theme |
| `CaLargeTitlePage`, `CaSegments`, `CaSearchField` | Seitenkopf, Abschnitte, Suche je Plattform |
| `CaSettingsSection`, `showCaActions`, `CaSwipeToRemove`, `CaBottomAction` | Konto, weitere Aktionen, Entfernen, feste Hauptaktion |
| `CaPageWidth` | Spalte bis 720 dp auf Tablets und im Querformat |

Symbole: Die Bausteine nehmen `IconData` an und nutzen bis dahin Material-Symbole. Für Phosphor
wie im Web wäre das Paket `phosphor_flutter` (MIT) nötig; das braucht Stanys Zustimmung.

## Logo und App-Symbol

Logo c4-access (05.10.2026): `assets/logo/hell.png` und `dunkel.png`, je 1x bis 3x, Quelle
`/mnt/project-files/logo/c4-access-hell.svg`.

| Datei | Verwendung |
|---|---|
| `assets/app-icon/ios-1024.png` | iOS-App-Symbol, deckend, ohne Rundung (macht das System) |
| `assets/app-icon/android-vordergrund.png` | Android adaptives Symbol, Vordergrund auf Weiß `#FFFFFF`, Inhalt in der sicheren Zone |
| `assets/app-icon/android-einfarbig.png` | Android 13+ einfarbiges Symbol für Themen-Symbole |

Alle Symbole erzeugt `node tool/logo_assets.js .` (braucht Playwright) aus den SVGs in `/mnt/project-files/logo/`.

## Für App Store und Google Play (geprüft 05.10.2026)

| Prüfpunkt | Vorgabe | Stand |
|---|---|---|
| iOS-App-Symbol | 1024 × 1024, deckend, Rundung macht das System | `assets/app-icon/ios-1024.png` |
| iOS dunkel und getönt | ab iOS 18 | `ios-dunkel-1024.png`, `ios-getoent-1024.png` |
| iOS 26+ (Liquid Glass) | Symbol aus Ebenen, gebaut in Icon Composer | Ebenen in `assets/app-icon/icon-composer/`; die `.icon`-Datei entsteht am Mac |
| Android adaptiv | Ebenen 108 dp, Inhalt in 66 dp Schutzzone | `android-vordergrund.png` auf Weiß, Inhalt bis 30,5 % Radius (Grenze 30,6 %) |
| Android einfarbig | für Themen-Symbole ab Android 13 | `android-einfarbig.png` |
| Benachrichtigung | 24 dp, weiß auf transparent | `android-benachrichtigung-96.png` |
| Play-Symbol, Vorstellungsgrafik | 512 × 512; 1024 × 500 ohne Alpha | `assets/store/` |
| Store-Bilder iOS | 6,9 Zoll: 1320 × 2868 | `example/test/store/ios-69-*.png` (4) |
| Store-Bilder Play | 9:16, mindestens 1080 px, Seiten höchstens 1 : 2 | `example/test/store/play-916-*.png` (4); die Doku-Bilder 1236 × 2745 wären zu lang |
| Tablets und Faltgeräte | ab API 36 ignoriert Android auf ≥ 600 dp die Ausrichtungssperre, ab API 37 ohne Ausnahme | `CaPageWidth`: Inhalt als Spalte bis 720 dp; Bilder `tablet-quer-*`, `tablet-hoch-*` |
| Randlos (Android 15+) | Inhalt läuft unter die Systemleisten | Navigation und feste Aktion liegen über der Gestenleiste |
| Statusleiste über dem Plakat | lesbar auf jedem Bild | helle Symbole (`SystemUiOverlayStyle.light`), Plakat oben leicht abgedunkelt |
| Tippflächen, Beschriftungen | iOS 44, Android 48, alles benannt | Tests mit `iOSTapTargetGuideline`, `androidTapTargetGuideline`, `labeledTapTargetGuideline`; Segmentschalter auf 48 erhöht |
| Startbildschirm | Android 12+: Symbol auf Hintergrundfarbe; iOS: wie die erste Seite, ohne Logo | Android: adaptives Symbol auf Weiß, dunkel `#0D0E13`; iOS: nur Weiß bzw. `#0D0E13` |
| Liquid Glass | Flutter zeichnet selbst, bekommt es nicht automatisch | Aushang 3 bleibt bewusst flach; nur das Symbol bekommt den Systemeffekt |

Quellen: [Play Zielversion](https://developer.android.com/google/play/requirements/target-sdk),
[Android 16 große Bildschirme](https://android-developers.googleblog.com/2025/01/orientation-and-resizability-changes-in-android-16.html),
[Adaptive Symbole](https://developer.android.com/develop/ui/views/launch/icon_design_adaptive),
[Startbildschirm Android](https://developer.android.com/develop/ui/views/launch/splash-screen),
[Play Store-Grafiken](https://support.google.com/googleplay/android-developer/answer/9866151),
[App Store Bildgrößen](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/),
[Flutter randlos](https://docs.flutter.dev/release/breaking-changes/default-systemuimode-edge-to-edge).

### In `client/` einzustellen (freigegeben 05.10.2026, fertig im Ordner `app-plattform/`, in der Codex-Übergabe `plattform/`)

- `targetSdk` 36: Pflicht für neue Apps und Updates ab 31.08.2026.
- Telefone nur Hochformat (iOS `UISupportedInterfaceOrientations`, Android `screenOrientation`); Tablets nutzen `CaPageWidth`.
- iOS zunächst nur iPhone (`TARGETED_DEVICE_FAMILY = 1`), sonst sind iPad-Bilder 13 Zoll Pflicht.
- Symbole einbinden (Asset-Katalog, `mipmap-anydpi-v26/ic_launcher.xml` mit Vordergrund, Weiß, einfarbig), Startbildschirm-Farben.
- Sprachen für „Sprache“ im Konto: `CFBundleLocalizations` (iOS), `localeConfig` (Android 13+), dazu `flutter_localizations` für deutsche Systemtexte.
- Archivo-Lizenz auf der Lizenzseite: `LicenseRegistry.addLicense` mit `fonts/OFL.txt`.
- Über Plakaten `AppBar(systemOverlayStyle: SystemUiOverlayStyle.light)`, siehe `example/lib/app.dart`.

## Noch offen

- Bausteine für Veranstalter: Entscheidungszeile, Formulareditor.
- Benachrichtigungen (Text und Symbol) für Zusage und Ort.
- Einbindung in `client/` nach Freigabe.

Beispiel mit allen Bausteinen: `example/lib/main.dart`. Alle Inhalte sind synthetisch.

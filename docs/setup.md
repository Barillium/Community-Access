# Lokales Setup: Flutter im Browser

Stand: 24.09.2026. Schritt 02 ist für Flutter Web in Chrome erfolgreich geprüft. Dies ist ein Werkzeugtest mit einer separaten Beispiel-App, keine implementierte Community-Access-Anwendung.

## Rechner und vorhandene Werkzeuge

| Bestandteil | Festgestellter Stand |
| --- | --- |
| Rechner | Mac mini M4 Pro laut Nutzerangabe; ARM64 technisch bestätigt |
| RAM | 24 GB laut Nutzerangabe; technische Abfrage war durch die Ausführungsumgebung gesperrt |
| Betriebssystem | macOS 15.1, Build 24B2082 |
| Freier Speicher | Vor Einrichtung rund 47 GiB, nach Einrichtung rund 35 GiB; Momentaufnahmen, keine dauerhaften Werte |
| Git | 2.39.5 (Apple Git-154), bereits vorhanden |
| Apple Command Line Tools | Bereits vorhanden, ausgewählt unter `/Library/Developer/CommandLineTools` |
| Chrome | 153.0.8010.53, bereits vorhanden |
| Visual Studio Code | 1.136.0, bereits vorhanden und erhalten |
| Homebrew | 6.0.15, bereits vorhanden |
| VSCodium | Neu installiert: 1.126.04524, ARM64; CLI-Version geprüft und Anwendungsfenster geöffnet |
| Flutter | Neu installiert: 3.47.5, Stable, ARM64; Revision `6a19cca564` |
| Dart | 3.13.4, im Flutter-SDK enthalten |
| DevTools | 2.60.0, im Flutter-Werkzeug enthalten |

Die Bestandsaufnahme verwendete lesende Befehle: `sw_vers` (macOS-Version), `uname -m` (Architektur), `df -h .` (freier Speicher), `command -v` (Werkzeugpfade), `git --version` und `xcode-select -p` (ausgewählte Apple-Werkzeuge). App-Versionen wurden mit `PlistBuddy` aus den jeweiligen `Info.plist`-Metadaten gelesen. `sysctl -n hw.memsize` war gesperrt; deshalb wird RAM nicht als unabhängig gemessen dargestellt.

## Installationsumfang, Orte und Rechte

Der Nutzer hat Installation, benötigte Downloads, PATH-Ergänzung und einen lokalen Browser-Test freigegeben. Kein `sudo`, keine Administratoraktion, keine Backend-Installation und keine Cloud-Ressource wurden ausgeführt. Die Ausführungsumgebung benötigte Freigaben für Schreibzugriff, Netzwerk und Programmstarts; diese sind von macOS-Administratorrechten zu unterscheiden.

| Ort | Zweck |
| --- | --- |
| `~/develop/flutter` | Flutter-SDK einschließlich Dart, nach Einrichtung rund 3,9 GiB |
| `~/develop/flutter_macos_arm64_3.47.5-stable.zip` | Aufbewahrtes Installationsarchiv, rund 2,1 GiB |
| `/Applications/VSCodium.app` | Offener Editor |
| `/opt/homebrew/bin/codium` | Durch Homebrew angelegter Editor-Befehl |
| `~/.zprofile` | Ergänzung des Flutter-Suchpfads für neue Zsh-Login-Sitzungen |
| `~/develop/community_access_setup_check` | Separate Web-Demo, rund 92 MiB nach den Tests |

Flutter ist BSD-3-Clause-lizenziert; VSCodium verwendet die MIT-Lizenz. Für diese Werkzeuge ist kein kostenpflichtiges Abonnement erforderlich. Downloadvolumen und lokaler Speicher werden benötigt. Zusätzliche Editor-Erweiterungen wurden nicht installiert; Dart-/Flutter-Editorintegration wurde deshalb noch nicht geprüft.

### Nachvollziehbare Installationsschritte

1. `HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask vscodium` installierte den Editor. Erwartet und beobachtet: erfolgreiche Cask-Installation sowie Verknüpfung des Befehls `codium`. Netzwerk- und Schreibzugriff waren nötig.
2. `mkdir -p "$HOME/develop"` legte den Werkzeugordner an. Normalerweise keine Ausgabe; benötigt Schreibzugriff im Benutzerordner.
3. Das offizielle ARM64-Archiv wurde mit `curl -fL --retry 2 <Download-URL> -o <Archivpfad>` heruntergeladen. `-f` meldet HTTP-Fehler, `-L` folgt Weiterleitungen, `--retry 2` erlaubt zwei Wiederholungen, `-o` speichert die Datei. Erwartet und beobachtet: vollständig abgeschlossener Download.
4. `LC_ALL=C shasum -a 256 <Archivpfad>` berechnete die Prüfsumme. Sie stimmte mit den offiziellen Release-Metadaten überein. `LC_ALL=C` vermeidet hier einen beobachteten Locale-Fehler des macOS-Perl-Werkzeugs.
5. `unzip -q <Archivpfad> -d "$HOME/develop"` entpackte das SDK. Vorher wurde geprüft, dass dort kein Flutter-Ordner existierte. Erwartet und beobachtet: erfolgreicher Abschluss ohne Ausgabe; Schreibzugriff erforderlich.
6. In `~/.zprofile` wurde ausschließlich folgende Ergänzung vorgenommen; bestehender Inhalt blieb erhalten:

```sh
# Flutter SDK for local web development
export PATH="$HOME/develop/flutter/bin:$PATH"
```

`PATH` bestimmt, wo das Terminal Programme sucht. Ein neu geöffnetes Terminal übernimmt diese Einstellung. Eine frische Zsh-Login-Sitzung fand `flutter` und `dart` an den erwarteten Orten. Die bereits laufende Agent-Umgebung hatte den neuen PATH zunächst nicht übernommen; die erneute Diagnose in einer frischen Login-Shell war erfolgreich.

**Beobachtete Nebenwirkung:** Homebrew führte nach der Editorinstallation automatisch eine Bereinigung alter Homebrew-Download-Caches und Homebrew-Logs aus. Dies war nicht geplant. Für weitere Installationen soll zusätzlich `HOMEBREW_NO_INSTALL_CLEANUP=1` gesetzt werden, um diese automatische Bereinigung zu verhindern.

### Verifizierte Downloadquelle

- Metadaten: <https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json>
- Archiv: <https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.47.5-stable.zip>
- SHA-256: `d4dd908b5f8f65515831b6d68ae33307a813f2b68947dded7a1994ee5ea7cead`

Der zunächst versuchte ältere URL-Pfad mit zusätzlichem `/flutter/` lieferte HTTP 404. Installiert wurde erst nach erfolgreichem Abruf der korrigierten offiziellen Metadaten und Prüfung des Downloads. Die ZIP-Datei wurde nach der Installation nicht gelöscht.

## Initialisierung und Diagnose

Folgende Befehle wurden ausgeführt. Erste SDK-Aufrufe dürfen Caches und Einstellungen schreiben sowie notwendige Komponenten herunterladen; sie sind deshalb nicht als rein lesende Bestandsaufnahme zu behandeln.

| Befehl | Erklärung und beobachtetes Ergebnis |
| --- | --- |
| `flutter --disable-analytics` | Deaktivierte Flutter-Nutzungsanalyse; Ausgabe `Analytics reporting disabled.` |
| `dart --disable-analytics` | Deaktivierte Dart-Nutzungsanalyse; entsprechende Bestätigung ausgegeben |
| `flutter --version` | Bestätigte Flutter 3.47.5, Dart 3.13.4 und DevTools 2.60.0 |
| `dart --version` | Bestätigte Dart 3.13.4 für `macos_arm64` |
| `flutter doctor -v` | Flutter, Chrome, Geräteerkennung und Netzwerkprüfung bestanden; zwei Kategorien für nicht eingerichtete native Plattformen blieben offen |
| `flutter devices` | Führte `Chrome (web)` auf; erkannte außerdem macOS als Gerät, was keinen erfolgreichen Desktop-Build belegt |
| `codium --version` | Bestätigte 1.126.04524 und `arm64` |

Laut Flutter-Ausgabe kann beim Deaktivieren der Nutzungsanalyse ein Opt-out-Ereignis übertragen werden. Es wird daher keine vollständige Netzwerkfreiheit behauptet.

## Browser-Demo starten und stoppen

Die Demo wurde einmalig erzeugt:

```sh
flutter create --platforms=web --project-name setup_check "$HOME/develop/community_access_setup_check"
```

Der Befehl erzeugte 19 Dateien und lud die Vorlagenabhängigkeiten. Er benötigt Netzwerk- und Schreibzugriff, keine Administratorrechte. Nicht erneut über eine bestehende Demo ausführen, wenn dort eigene Änderungen liegen.

Zum erneuten Ausprobieren ein neues Terminal öffnen:

```sh
cd "$HOME/develop/community_access_setup_check"
flutter run -d chrome --web-hostname=127.0.0.1 --web-port=53217
```

`cd` wechselt den Arbeitsordner. `flutter run` baut die Debug-App und öffnet Chrome; `-d chrome` wählt den Browser. Die Adresse `127.0.0.1` beschränkt den Webserver auf den eigenen Rechner. Port `53217` muss frei sein. Erwartet werden die Flutter-Demo und ein funktionierender Plus-Button. Dieser Start benötigt Schreibrechte für Build-Caches und einen lokalen Netzwerkport, jedoch keine Veröffentlichung.

Im zugehörigen Terminal beendet `q` die Sitzung; `r` löst Hot Reload aus. Beim Einrichtungstest war die Prozesseingabe nicht mehr geöffnet. Deshalb wurde ausschließlich der über Port und vollständigen Befehl identifizierte, selbst gestartete Flutter-Prozess mit `SIGTERM` beendet. Der Testserver läuft nach Abschluss nicht weiter.

## Prüfergebnisse und Plattformgrenzen

| Prüfung | Ergebnis |
| --- | --- |
| Offizielle SDK-Prüfsumme | Bestanden |
| PATH in frischer Login-Shell | Bestanden |
| `dart format --output=none --set-exit-if-changed lib test` | Bestanden: zwei Dateien geprüft, keine Änderung erforderlich |
| `flutter analyze` | Bestanden: `No issues found!` |
| `flutter test` | Bestanden: mitgelieferter `Counter increments smoke test`, ein Test |
| Debug-Start mit `flutter run -d chrome` | Bestanden |
| Sichtprüfung in Chrome | Bestanden: Demo sichtbar, Plus-Klick erhöhte den Zähler von 0 auf 1 |
| VSCodium | Installiert, CLI-Version und geöffnetes Anwendungsfenster geprüft; keine Flutter-Erweiterung eingerichtet |
| iOS und native macOS-App | Nicht eingerichtet und nicht getestet; vollständiges Xcode fehlt, CocoaPods ebenfalls nicht installiert |
| Android | Nicht eingerichtet und nicht getestet; Android SDK fehlt |
| Windows und Linux | Nicht getestet |
| Safari, Firefox und Edge | Nicht getestet |
| Web-Release-Build und Veröffentlichung | Nicht ausgeführt; Abnahme betrifft lokalen Debug-Betrieb in Chrome |
| Community-Access-Funktionen und Backend | Noch nicht implementiert oder getestet |

Formatierung prüft die Schreibweise des Codes, Analyse sucht statisch nach Problemen, und der Widget-Test prüft das Zählerverhalten automatisiert. Der zusätzliche Klick im echten Browser bestätigt, dass auch Start, Darstellung und Bedienung im geprüften Browser funktionieren. Die native macOS-Geräteanzeige ist kein Nachweis für iOS- oder Desktop-Builds.

Im Community-Access-Projekt wurde nur diese Setup-Dokumentation ergänzt; `docs/product-spec.md` blieb unverändert. Ein Git-Repository war dort noch nicht eingerichtet; deshalb gab es keinen Repository-Diff oder Commit. Git selbst ist verfügbar. Die Git-Projekteinrichtung gehört zum nächsten Arbeitsschritt.

## Offizielle Referenzen

- [Flutter manuell installieren](https://docs.flutter.dev/install/manual)
- [Flutter-SDK-Archiv](https://docs.flutter.dev/install/archive)
- [Flutter zum PATH hinzufügen](https://docs.flutter.dev/install/add-to-path)
- [Flutter Web einrichten](https://docs.flutter.dev/platform-integration/web/setup)
- [Flutter-CLI](https://docs.flutter.dev/reference/flutter-cli)
- [Flutter-Lizenz](https://github.com/flutter/flutter/blob/master/LICENSE)
- [VSCodium, Lizenz und Installation](https://vscodium.com/)

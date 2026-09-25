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

## Projekt-App starten und prüfen

Nachtrag: Die ursprünglichen Angaben oben beschreiben die separate Werkzeugdemo. Die neue App unter `app/` ist eine synthetische lokale Statusdemo, keine implementierte Aufnahmeverwaltung. Vier auswählbare Beispiele zeigen Bewerbung, Mitgliedschaft, Eventanfrage und Eventbestätigung. Ein Neuladen setzt die Anzeige zurück. Keine Anmeldung, Speicherung, privaten Locations oder Backend-Verbindung.

Im Terminal:

```sh
cd "/Users/stanynyssen/Scene Access/app"
flutter pub get --offline
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub --no-web-resources-cdn
flutter run --no-pub -d chrome --web-hostname=127.0.0.1 --web-port=53218
```

`pub get --offline` löst die SDK-Abhängigkeiten aus dem vorhandenen Cache auf; auf einem neuen Rechner kann dieser fehlen. Dann anhalten und notwendige Downloads separat freigeben. Die App verwendet Flutter und `flutter_test` aus dem vorhandenen BSD-3-Clause-lizenzierten SDK, keine zusätzlichen direkten Pakete oder kostenpflichtigen Dienste. Die aufgelösten transitiven Versionen stehen in `app/pubspec.lock`.

Formatierung prüft die vier Dart-Dateien; Analyse meldet statische Fehler; `flutter test` führt fünf Logik-/Widget-Tests aus. Der Build erzeugt `build/web`, mit lokal gebündeltem Renderer statt CDN. Diese Befehle schreiben lokale Caches/Build-Ausgaben, benötigen keine Administratorrechte. `flutter run` startet Chrome auf dem eigenen Rechner; mit `q` im Terminal beenden. Dieser Startaufruf ist dokumentiert, für diese App wurde stattdessen der fertige Web-Build lokal im Codex-Browser geprüft.

Bestanden: Formatierung, Analyse, fünf Tests, Web-Build sowie Sicht-/Klickprüfung des Release-Builds im Codex-Browser auf `127.0.0.1`. Der dabei gestartete Server wird nach der Prüfung beendet. Build-Hinweis: Cupertino-Font nicht eingebunden; die App verwendet Material-Komponenten, deren Darstellung sichtbar geprüft wurde. Keine zusätzliche Icon-Abhängigkeit dafür installiert.

Nicht geprüft: automatisierter Browser-Integrationstest, vollständige Barrierefreiheit, andere Browser sowie iOS, Android, macOS-, Windows- und Linux-Builds. Der schmale Viewport mit doppelter Schrift und die Tastaturauswahl sind Widget-Tests, kein geräteübergreifender Browsernachweis.

## Getrennte lokale PostgreSQL-Testdatenbank

Voraussetzung geprüft: PostgreSQL 17.10 (Homebrew) einschließlich `initdb`, `pg_ctl` und `psql` ist bereits vorhanden unter `/opt/homebrew/opt/postgresql@17/bin`. Keine Installation und kein Download erforderlich. Die Supabase-CLI fehlt; diese Umgebung ist deshalb ausschließlich der PostgreSQL-Unterbau, kein vollständiges lokales Supabase. Der geplante Stack bleibt unverändert.

Im Projektstamm:

```sh
python3 -I scripts/check_database.py
```

Der Aufruf erzeugt jedes Mal ein neues, ausschließlich synthetisches Datenverzeichnis unter `.local/database-tests/run-*/data`. Er startet genau diese Instanz, führt `tests/database/infrastructure.sql` und einen Test mit zwei gleichzeitigen Verbindungen aus und stoppt sie im abschließenden Aufräumschritt. Erwartet: `status: passed`, drei Prüfgruppen und `server_stopped: true`. Fehler liefern Exitcode 2 und einen Bericht statt Erfolg. Reguläres Testbudget: 90 Sekunden; das Stoppen erhält zusätzlich maximal 20 Sekunden. Ein harter Prozessabbruch oder Stromausfall kann das Aufräumen verhindern; der Berichtsstatus muss geprüft werden.

Keine Administratorrechte, kein Netzwerkdownload, keine Cloud und keine Verbindung zu vorhandenen Datenbanken. Schreib-/Prozessrechte und lokale Unix-Sockets müssen in der Ausführungsumgebung erlaubt sein. Der Aufruf ignoriert geerbte PostgreSQL-Verbindungsvariablen, Benutzer-psql-Konfiguration und Passwortdateien. Er verwendet feste Programmdateien und explizit den frisch erzeugten Verbindungspfad.

Technische Trennung: eigener PostgreSQL-Cluster; `listen_addresses` leer (kein TCP); zufälliger Socketordner unter `/tmp/ca-pg-*` mit Modus 0700; Socket ebenfalls 0700; TCP-Anmeldung abgewiesen. Innerhalb dieses privaten Ordners erlaubt lokale `trust`-Authentifizierung die synthetische Rolle `fixture_admin` ohne Passwort. Andere Prozesse desselben Betriebssystemkontos und Administratoren sind dadurch nicht ausgesperrt. Dies ist keine Sicherheits-Sandbox für ungeprüften Agentencode und kein Produkt-Berechtigungsmodell.

Daten, ausschließlich synthetische Serverlogs und Bericht bleiben zur Prüfung lokal erhalten; das Skript löscht keine Daten und richtet keinen dauerhaften Dienst ein. Jeder Wiederholungslauf nutzt eine neue Instanz. Aufbewahrte Testverzeichnisse verbrauchen Speicher; Bereinigung nur nach bewusster Auswahl und Freigabe. Keine privaten Daten in diese Umgebung importieren. Der Verbindungspfad einer beendeten Instanz ist kein Zugang zu einer laufenden Datenbank.

Geprüft: getrennte Instanz, deaktiviertes TCP, private Socketrechte, synthetische Tabelle, Rollback, Ablehnung doppelter Schlüssel und zwei konkurrierende Updates. Noch nicht vorhanden: Produktmigrationen, RLS/Nutzerrollen, Supabase Auth/API, pgTAP, Löschfristen und produktbezogene Transaktions-/Platzvergabetests. Keine App-Anbindung oder Änderung des freigegebenen Runners.

Referenz: [PostgreSQL 17 – Verbindungen und Unix-Sockets](https://www.postgresql.org/docs/17/runtime-config-connection.html).

## Lokales Supabase Auth/API

Nachtrag: Die CLI ist inzwischen nach Freigabe als Version 2.117.0 installiert. Das separate native PostgreSQL-Testskript bleibt unabhängig erhalten. Supabase nutzt die eigene Colima-VM `community-access-test`, ausschließlich synthetische Konten und das Netz `community-access-loopback`.

Vom Projektstamm aus (bestehende Installation):

```sh
colima start community-access-test --activate=false --ssh-config=false
export DOCKER_HOST="unix://$HOME/.colima/community-access-test/docker.sock"
# Das Loopback-Netz wurde bereits angelegt. Vor dem Start seine Option prüfen:
docker network inspect community-access-loopback --format '{{json .Options}}'
# Erwartet: com.docker.network.bridge.host_binding_ipv4 = 127.0.0.1
supabase start --network-id community-access-loopback --exclude realtime,storage-api,imgproxy,mailpit,postgres-meta,studio,edge-runtime,logflare,vector,supavisor > .local/supabase-start.log 2>&1
lsof -nP -iTCP:55431 -iTCP:55432 -sTCP:LISTEN
# Nur 127.0.0.1 zulässig, niemals * oder 0.0.0.0.
python3 -I scripts/check_supabase.py
supabase db lint --local --schema public,access_private --fail-on warning
# Auch nach fehlgeschlagenen Tests stoppen; keine Datenlöschung:
supabase stop
colima stop community-access-test
```

Die Befehle starten lokale Prozesse/VMs und können bei fehlenden Images Downloads benötigen; neue Downloads weiterhin separat freigeben. Keine Administratorrechte, kein Login in Supabase Cloud nötig. Der Test erzeugt fünf neue synthetische Konten pro Lauf und verwendet echte Passwortanmeldung plus HTTP-API. Wiederholungen erzeugen eigene Fixture-IDs, setzen keinen bestehenden Datenbestand zurück und lassen synthetische Daten zur Prüfung erhalten. Berichte unter `.local/supabase-tests/` enthalten keine Tokens oder Passwörter. Datenvolumes und VM bleiben nach dem Stoppen erhalten; keine automatische Bereinigung.

Der Test prüft die Containerbindung vor dem ersten Kontoaufbau. Die zusätzliche `lsof`-Prüfung bleibt erforderlich, weil VM-Portweiterleitung eine eigene Grenze ist. Bei einer falschen Bindung zuerst die eigene VM stoppen. Nicht ohne `--network-id community-access-loopback` starten. Die App nutzt weiterhin keine Authentifizierung und kein Backend. Dieser manuelle Testcontroller besitzt Fixture-Administratorrechte und ist kein freigegebener Coding-Agent-Runner.

Einrichtung, Rechtematrix, Testergebnisse und offene Produktteile: [ADR 0002](decisions/0002-local-supabase-core.md). Lokale Supabase-Startausgaben nicht teilen; sie können synthetische Entwicklungsschlüssel enthalten.

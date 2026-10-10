# Bestandsaufnahme, Abnahme und Nachweise

Aktuelle Einordnung 10.10.2026: Der Produktumfang steht ausschließlich in [product-spec.md](product-spec.md), aktuelle Start-/Prüfbefehle in [setup.md](setup.md). Die folgenden datierten Berichte beschreiben historische Nachweise. Der Einzelaufgaben-Runner bleibt unverändert eingeschränkt; sein blockierter Produkt-Scope ist keine Aussage über fehlende Implementierung im aktiven Backend.

## Betriebssicherung · 05.10.2026

Anbieter-MFA, Free-only-Kostenrahmen, SanDisk-Sicherung und korrigierte DNSSEC-/Mail-/TLS-Reihenfolge organisiert; [Betriebsplan](website-operations.md), [Nachweise](qa/website-operations-2026-10-05/report.md). Neue manuelle Prüfscripts außerhalb des Task-Runners. Keine Produkt- oder Kontrolllogik verändert; bestehende offene Arbeit erhalten.

Synthetischer PostgreSQL-17-Dump in getrennten neuen Cluster wiederhergestellt: **7 Tests bestanden** lokal; zusätzliche verschlüsselte SanDisk-Kopie tatsächlich als Wiederherstellungsquelle verwendet: **8 Tests bestanden**, ohne übersprungene Fälle. Beide Läufe überlappen und dürfen nicht addiert werden. Datenidentität, eingeschränkte Rollen/ACLs, Sitzungsentzug, Mitgliedschaft/Teilnahme/Location-Grenzen und Recovery-Invalidierung geprüft. Eigene Testdatenbanken und Archive entfernt. Keine echte private Sicherung, Aufbewahrungs- oder Wiederherstellungszeit-Abnahme.

Öffentlich über zwei Resolver: one.com-NS, vier Mail-MX, zwei zusätzliche one.com-DKIM-CNAMEs und DNSSEC-DS vorhanden. HTTP ohne HTTPS-Weiterleitung; **TLS bei Apex und www fehlgeschlagen**, aktive Zertifikatsprüfung. Endgültiger Lauf: 30 DNS-Abfragen abgeschlossen; zuvor fehlgeschlagene Netz-/Werkzeugläufe im Bericht getrennt erhalten. Angemeldetes Cloudflare-Portal: pending Free-Zone und alter Null-MX-Entwurf. Lokaler Vorschlag mit elf Records vorbereitet, nicht angewendet.

Angemeldete Anbieterprüfung: Cloudflare Workers Free und Domain Free aktiv, keine Zahlungsmethode; Resend Free mit 3.000 Mails/Monat, 100/Tag und ausgeschalteter/deaktivierter Mehrverbrauchsabrechnung. MFA vor Besitzer-Handoff bei Cloudflare Inactive, Resend Enable MFA und one.com Aktivieren. Keine Nameserver-, DNSSEC-, Tarif- oder Veröffentlichungseinstellung verändert. Private MFA-Einrichtung bleibt dem Besitzer überlassen; Aktivierung noch nicht bestätigt.

## Webseiten-Sicherheit · 05.10.2026

Zusätzliche Anfrage-/Kontobegrenzungen, Parallelitäts- und DB-Zeitlimits, gemeinsames Mailbudget, Sicherheitsheader, HTTPS-Signalprüfung und feste Sicherheitszähler sind lokal implementiert. Flutter zeigt bei 429 eine sichere Warteaufforderung ohne Sitzungsverlust oder automatische Schreibwiederholung. [Umsetzung und Grenzen](website-security.md), [gezielte Prüfergebnisse und Aufgabenvergleich](qa/security-hardening-2026-10-05/report.md).

Die gezielten Node-Läufe, neun Client-/Anmeldetests, alle 205 Fluttertests, Flutter-Analyse und der abschließende Webbuild bestehen. Nach zwischenzeitlichem Speicherplatzfehler und Speicherfreigabe ist die gezielte Browserprüfung des finalen Builds mit tatsächlichen Gateway-Headern bestanden: Font geladen, 429-Warteaufforderung sichtbar, keine Konsolenwarnungen/-fehler. Ausschließlich Loopback und synthetische Betriebs-/API-Fixtures. Keine öffentliche TLS-/DNS-, Zustellungs-, MFA-, Ausgabenlimit- oder Backup-/Restore-Abnahme. Bestehende Dienste nicht neu gestartet, keine Veröffentlichung.

## Cloudflare-Free-Vorbereitung am 02.10.2026

Nach ausdrücklicher Nutzerfreigabe im vorhandenen Cloudflare-Konto: `communityaccess.de` im Free-Tarif angelegt, benannter Tunnel `community-access-web` und Route auf `http://127.0.0.1:8400` gespeichert (Hostheader Domain, Connect Timeout 5 Sekunden). Zone **pending**, Connector nicht verbunden; keine Token gelesen. Fehlende Resend-CNAMEs ergänzt. Der separat freigegebene Apex-Wechsel wurde im inaktiven Cloudflare-DNS als proxied Tunnel-CNAME gespeichert. Keine Änderung an one.com-Nameservern, DNSSEC oder autoritativen Einträgen. [DNS-Vergleich und Screenshots](cloudflare-dns-review.md).

Tatsächlich geprüft: one.com-DNS-Portal mit drei persönlichen Resend- und drei Standard-Einträgen; beide Portale enthalten dieselben Mailwerte. Öffentliche NS-, Apex-A-, www-A- und MX-Abfragen bestätigen weiterhin one.com und die bisherigen Ziele. DS-Abfrage über `1.1.1.1` ohne DS-Antwort; one.com-Portal zeigt DNSSEC dennoch aktiv und kündigt automatische Deaktivierung beim externen Nameserver-Wechsel an. Diese Beobachtungen sind getrennt dokumentiert. Ein erster `dig`-Aufruf scheiterte an der Sandbox; die freigegebenen öffentlichen Wiederholungen gelangen.

Keine neuen Laufzeit- oder Auth-Codeänderungen in dieser Portalvorbereitung, daher keine Wiederholung der unten dokumentierten synthetischen Tests. Relative Dateilinks und Whitespace der vier bearbeiteten Dokumente sowie `git diff --check` bestanden. Keine öffentliche TLS-/OAuth-Abnahme, Provider-App-Konfiguration, echte Mail, privater Betriebsstart oder Autostart. Die Shared-Checkout-Branch wurde inzwischen durch parallele Nutzerarbeit gewechselt; bestehende Änderungen wurden erhalten, nichts gestaged, committet oder gepusht.

## Dauerhafte HTTPS- und Provider-Vorbereitung am 02.10.2026

Nutzerauftrag: bestätigte Google-/Apple-/Meta-Zugänge verwenden und diesen PC dauerhaft über HTTPS anbinden. Der Nutzer bestätigt die Zugänge, keine OAuth-App-Konfiguration oder Secret-Werte. Auf eigenem Branch `codex/permanent-https-auth` wurde die bestehende, umfangreiche offene Arbeit erhalten; nichts gestaged oder veröffentlicht. [Konkrete Vorbereitung](permanent-https-tunnel.md).

Ergänzt: festes Loopback-Gateway auf Port 8400 mit Auth-Routenliste, gesperrtem Testpostfach/Dashboard/Katalog, sicheren festen Callback-Zielen, geprüftem privatem Backend-Modus und HTTPS-Origins; separater Web-Release ohne Secret-Umgebungsvariablen; verdeckte Besitzerhilfe für einen benannten Cloudflare-Token; rollenbeschränkter HTTP-Datenbankzugang `auth_app` statt Bootstrap-Administrator. Vorhandene Kontodaten werden weder gelesen noch zurückgesetzt oder einem anderen Eigentümer übertragen. Diese Aussage beschreibt den Controller-Code; ein echter privater Bestand wurde nicht gestartet oder migriert.

Tatsächlich ausgeführt:

- `node --test server/public_gateway.test.mjs server/http.test.mjs server/social.test.mjs`: **7 bestanden**. Startup und erneute API-Probe blockieren synthetischen Modus, Dashboard, fremde UI-Origin und Administratorrolle. Geprüft: gesperrte/normalisierte/encodierte Pfade, Host/Origin, Bodygrenze, Apple-POST, Cookie-/Header-Handoff und Ablehnung fremder, tokenhaltiger oder ungültiger Rückleitungen.
- `python3 -I scripts/local_auth.py --test-mail`: **2 bestanden** mit ausschließlich synthetischen Daten und simuliertem Resend. Local-/HTTPS-Linkabläufe funktionieren als eingeschränkte Rolle; `CREATE ROLE`, `CREATE DATABASE` und Wechsel zur Administratorrolle werden abgewiesen.
- `python3 -I scripts/local_auth.py --test-social`: **15 bestanden**, echte lokale Better-Auth-/PostgreSQL-Logik mit simulierten Anbieterantworten und gesperrtem externem Testnetz. Die vier reinen Social-Konfigurationstests überschneiden sich mit dem obigen Node-Lauf; Testzahlen nicht addieren.
- `python3 -I scripts/local_auth.py --test`: **10 bestanden** einschließlich konkurrierender Registrierung/Linkverbrauch, Ablauf, Logout/Reset-Sitzungsentzug und Rate-Limits.
- `python3 -I scripts/local_auth.py --test-directory`: **29 bestanden** einschließlich bestehender öffentlicher Alt-Events, persönlicher Profil-/Reihen-/Eventfreigaben und Konkurrenzfällen.
- `python3 -I scripts/https_tunnel_setup_test.py`: **4 bestanden**, isolierte synthetische Token-Dateien, Rechte, keine Secret-Ausgabe, abgewiesene nicht-interaktive/unsichere Einrichtung und Token-Datei statt Token im Prozessargument. Connector und Netzantwort wurden in diesen Besitzerhilfe-Tests simuliert; kein Tunnelstart.
- `python3 -I scripts/build_public_web.py`: **Release-Build bestanden**, unter `.local/public-web/20261002T195601667737Z`, private Kontoform und beide Origins `https://communityaccess.de`. Vorhandene CupertinoIcons-Fontwarnung; kein Wasm-Build oder neue Browserabnahme behauptet. Kein echter Anbieter-/Mail-/Datenbankschlüssel verwendet.

Der erste Node-Lauf wurde von der Sandbox mit `listen EPERM` gestoppt (3 fehlgeschlagene Tests); erst die Wiederholung mit freigegebenen Loopback-Ports bestand. Sämtliche Testcontroller beendeten ihre selbst gestarteten synthetischen Datenbanken. Laufende Nutzerprozesse wurden nicht angehalten.

Die öffentliche TLS-Prüfung von Domain und Provider-Endpunkt ergab Zertifikats-Hostnamenfehler; Prüfung blieb aktiv. Öffentliche DNS-Teilabfragen bestätigen one.com-Nameserver, Apex-A, Null-MX und Resend-Einträge; [Beobachtung](https-dns-observation.json) ist kein vollständiger Zonenexport. Ein erster DNS-Aufruf scheiterte an der Sandbox; die freigegebenen öffentlichen Wiederholungen gelangen. Bei diesem lokalen Implementierungsschritt wurden noch keine Cloudflare-Zone, DNS-/Nameserver-Umstellung, Tarifbuchung, Routeränderung, Autostart-Installation, echten Secrets, Mails oder Live-Anmeldungen vorgenommen. Die anschließende freigegebene Cloudflare-Vorbereitung ist im eigenen Abschnitt oben dokumentiert. Private Backup-/Wiederherstellungsabnahme und vollständige Produktfreigaben bleiben offen. Die Vorbereitung allein ist keine Produktionsabnahme.

## Laravel-Entfernung und erhaltener Flutter-Client am 01.10.2026

Auf Nutzerauftrag wurde die Laravel-Struktur aus dem aktiven Projekt entfernt und die Flutter-Gastoberfläche separat unter `client/` erhalten. Das Paket heißt jetzt `community_access_client`; der bestehende HTTP-Adapter heißt `HttpAccessApi`. Sein API-Vertrag bleibt der bisherige Prototypvertrag und ist noch keine Better-Auth-Integration. Webkatalog- und Testpostfach-Schaltflächen öffnen keine Verweise auf den entfernten Server mehr.

Backend, Composer-Dateien, Gastgeberansichten, Migrationen, synthetische Seeds, Backendtests, Startskripte, Auditmaterial und Prototypdokumentation liegen zur reversiblen Aufbewahrung unter der ignorierten lokalen Ablage `.local/archives/laravel-prototype-20261001/`. Auch vorhandene lokale Konfiguration und Daten wurden nur verschoben, nicht gelesen oder gelöscht. Diese Ablage darf nicht hochgeladen werden. Aktive Quellen unter `laravel-prototype/` existieren nicht mehr.

Ausgeführt für `client/`: vorhandene Abhängigkeiten mit `flutter pub get --offline` aufgelöst; `dart format --output=none --set-exit-if-changed lib test` bestanden; `flutter analyze` ohne Befunde; `flutter test --no-pub` mit **39 bestandenen Tests**. Die Tests verwenden synthetische Fixtures und ersetzen keinen Auth-/API-Nachweis gegen ein echtes Backend. Die Prüfung der bisherigen Prototypports 8000, 8300 und 55442 zeigte keine TCP-Listener; es wurden keine Server gestartet oder beendet.

`flutter build web --no-pub` erzeugte erfolgreich `client/build/web`; auch der Wasm-Probelauf bestand. Der Build meldete eine nicht gefundene `CupertinoIcons`-Schriftfamilie; dies wurde nicht durch eine neue Abhängigkeit verändert. Keine Browserabnahme und kein nativer Build. Relative Links der geänderten Dokumentation und `git diff --check` bestanden. 25 unveränderte Dateien einschließlich Statusdemo, Supabase, Lerncode und der vorhandenen AutoGPT-/Runner-Arbeit wurden zusätzlich anhand ihrer SHA-256-Fingerabdrücke bestätigt. Die lokale Archivablage und die Client-Build-/Werkzeugcaches sind von der normalen Git-Dateiauswahl ausgeschlossen.

Better Auth wurde weder installiert noch konfiguriert. Anmeldung und Produktaktionen benötigen ein neues Backend; dessen Laufzeit und Anbindung sind noch offen. Kein Datenbankschema wurde verändert. Browser-, Backend-, Supabase- und Runner-Gesamtprüfungen wurden für diesen Strukturwechsel nicht ausgeführt. Der zuvor beauftragte GitHub-Upload wurde während dieser Umstellung pausiert; in dieser Aufgabe gab es keinen Upload.

Die folgenden Abschnitte dokumentieren frühere Stände, einschließlich des inzwischen aus dem aktiven Projekt entfernten Vergleichsprototyps.

## AutoGPT-Adapter: Implementierung vom 30.09.2026

Auf `codex/autogpt-runner` ist der zusätzliche Classic-Vorschlagsadapter implementiert; kein Commit und keine Kontroll- oder Aufgabenfreigabe erzeugt. Die bestehende unversionierte Arbeit unter `laravel-prototype/` wurde nicht bearbeitet. [ADR 0004](decisions/0004-autogpt-proposal-adapter.md) und [Anleitung](autogpt-runner.md) dokumentieren Protokoll, Lizenzgrundlage, menschlichen Runtime-Review und die Grenze zwischen isoliertem HTTP-Kind und externem AutoGPT-Server.

Ausgeführt: `python3 -I scripts/check_project.py --include-reviewed scripts/runner_tests/test_autogpt.py docs/autogpt-runner.md docs/decisions/0004-autogpt-proposal-adapter.md`. Dokument-/Linkprüfung, Dart-Formatierung, Analyse und neun geschützte Dart-Fälle bestanden. Von 52 Runner-Tests bestanden 51, ohne übersprungene Tests. Alle 15 neuen AutoGPT-Tests bestanden: synthetisches HTTP-Protokoll, genau ein erster Vorschlag ohne Werkzeugfreigabe, Anbieterhash, Ablehnung von Overrides und fremden Dateien, Antwortgrößen/Fehler, Deadline, OS-Sperre gegen fremde Dateien, externes Netz und einen anderen Loopback-Port sowie Durchlauf bis zum Kandidatenpatch mit den bestehenden Gates.

**Gesamtprüfung fehlgeschlagen:** Der unveränderte bestehende Test `test_actual_codex_initializes_offline_runtime_without_credentials` scheitert, weil die fest konfigurierte Datei `/Applications/ChatGPT.app/Contents/Resources/codex` nicht existiert. Der fehlende Pfad wurde separat beobachtet. Das ist kein bestandener Codex-Startnachweis. Der Test und der bestehende Codex-Pfad wurden nicht herabgesetzt oder umgeschrieben. Vor Freigabe eines echten Laufs muss diese Werkzeugblockade separat behoben und die Gesamtprüfung wiederholt werden.

Der erste neue OS-Test zeigte zunächst eine ungültige Seatbelt-Regel mit numerischer IP; korrigiert auf `localhost:<Port>`, während HTTP numerisch auf `127.0.0.1` bleibt. Ein anschließend durch die äußere Sandbox blockierter Grenztest wurde mit genehmigter Eskalation erfolgreich ausgeführt. Die abschließende Projektprüfung bestand diese OS-Tests ebenfalls. Diese früheren Fehlversuche gelten nicht als bestanden.

Nicht ausgeführt: AutoGPT-Installation, Serverstart, Verbindung zum erlaubten Port, echte Modellantwort, Abhängigkeits-/Advisory-Vollprüfung und Isolation des externen Servers. Flutter-/Backend-Suites wurden für diesen Python-Adapter nicht erneut ausgeführt. Keine Veröffentlichung, automatische Übernahme oder Änderung an Produktrollen. Der vollständige Änderungsumfang wurde geprüft; Markdown und `git diff --check` bestanden.

Stand: 25.09.2026. Umfang dieser Ausbaustufe: genau eine manuell freigegebene synthetische Aufgabe. Keine dauerhafte Ausführung, automatische Übernahme oder Veröffentlichung.

## Aktueller Lesestand

Die folgenden Abschnitte dokumentieren die Entwicklung chronologisch. Ältere Aussagen wie „App nicht vorhanden“ sind historische Befunde; maßgeblich sind die Nachträge „Supabase Auth/API und Rollen“, „Runner-Erweiterung“ und der abschließende Kontrollreview. App und lokaler Backend-Kern existieren; vollständige Produktabläufe und ein echter App-Modelllauf stehen weiter aus.

## Tatsächliches Repository

Ausgangsstand war der saubere Branch `main`, Commit `68f3b149f565c48b2841455184019e30cca69b33`. Die Vorbereitung liegt auf `tooling/single-task-runner`. Vorhandene Änderungen mussten nicht umgeschrieben werden. Gelesene Anweisungsquellen: `~/.codex/AGENTS.md`, Root-`AGENTS.md` und die vom Nutzer bereitgestellten Projektregeln. Im Projekt wurde keine weitere AGENTS-Datei gefunden. Produkt-, Setup-, Git-, Codex- und Lern-Dokumentation wurden als Grundlage verwendet; keine privaten Notizen oder echten Anmeldedateien gelesen.

| Bereich | Einordnung | Nachweis / Grenze |
| --- | --- | --- |
| Produktumfang | Vorhanden als freigegebene Zielbeschreibung | [product-spec.md](product-spec.md); zwei Produktrollen, manuelle Entscheidungen, offene Fachfragen. Keine implementierte Produkteigenschaft. |
| Dart-Lernübung | Vorhanden und erneut funktionsfähig geprüft | Format, Analyse und neun Statusfälle bestanden. Keine Paketabhängigkeiten; `pubspec.lock` enthält keine Pakete. |
| Flutter-Werkzeuge | Vorhanden; frühere separate Demo geprüft | Flutter 3.47.5 / Dart 3.13.4, lokale Pfade in [setup.md](setup.md). Die externe Browser-Demo wurde in dieser Aufgabe nicht wiederholt. |
| Python / Git / macOS-Sandbox | Vorhanden und für lokale Prüfungen benutzt | Python 3.10.14, Apple Git, macOS ARM64. Keine Installation. |
| Codex-CLI | Vorhanden, Optionen geprüft | 0.155.0-alpha.9.2, `/Applications/ChatGPT.app/Contents/Resources/codex`; kein echter Modellaufruf für diesen Runner. |
| Runner und Kontrolltests | Neu implementiert, lokal geprüft | 25 Tests inklusive echter Sandbox-/Dart-Ausführung und CLI-Integration; Modellvorschläge in Tests deterministisch simuliert. |
| Entwicklungsanmeldung / Modellnetzwerk | Noch nicht eingerichtet beziehungsweise nicht geprüft | Keine normale Anmeldung kopiert oder gelesen. Blockiert ohne dedizierte Voraussetzung. Tarif und Modellwahl bleiben manuell. |
| Flutter-App in `app/` | Noch nicht vorhanden | Kein App-Build, Widget-, Integrations- oder Browserfunktionstest des Produkts. |
| Supabase / PostgreSQL | Noch nicht vorhanden | Keine Migrationen, SQL-/Transaktions-/Konkurrenztests oder lokale Backend-Umgebung. |
| Tatsächliche Produktrollen | Noch nicht vorhanden | Keine verifizierten Backend-Rechte oder Rollentests; keine erfundene Rechteentscheidung. |
| Remote / CI / Cloud / Veröffentlichung | Nicht eingerichtet in dieser Aufgabe | Kein Push, Deployment, Scheduler, Hintergrundjob oder automatischer Merge. |

## Reproduzierbare Aufrufe

Im Projektstamm, mit bewusst ausgewählten neuen Dateien im Index:

```sh
python3 -I scripts/check_project.py
python3 -I scripts/check_project.py --scope product
```

Der erste Befehl prüft die aktuellen versionierten Quellen in einer temporären Kopie: Markdown/relative Links, synthetische Sandboxgrenzen, Dart-Formatierung, Dart-Analyse, neun Statusfälle, anschließend die Runner-Tests und beide Git-Diff-Whitespace-Prüfungen. Er verändert keine Projektquellen, legt nur temporäre Testdaten an und installiert nichts. Er benötigt lokale Schreib-/Prozessrechte, keine Administratorrechte und kein Modellnetzwerk. Es handelt sich um eine Ausführung geprüften Infrastrukturcodes; nicht ungeprüfte fremde Tests außerhalb der Sandbox starten.

Erwartetes Ergebnis im vorhandenen Umfang: `PASS: current documentation, Dart exercise and runner only.` Übersprungene Runner-Tests oder ein leerer Testbestand führen zu einem Fehler. Der zweite Befehl muss derzeit mit `BLOCKED` und Exitcode 2 enden. Das ist ein bestandener Negativnachweis für die Sperre, **keine bestandene Produktabnahme**.

Gezielt nur Runner-Tests:

```sh
python3 -I -m unittest discover -s scripts/runner_tests -v
```

Dieser einzelne unittest-Aufruf kann außerhalb macOS Tests überspringen. Für die verbindliche Abnahme deshalb den übergeordneten `check_project.py` verwenden, der Überspringen nicht als Erfolg akzeptiert.

Die Runner-Gates verwenden das vorhandene Dart-SDK direkt und führen im exportierten `exercises/dart_basics/` aus:

```sh
dart format --output=none --set-exit-if-changed bin lib test
dart analyze
dart test/application_status_test.dart
```

Die letzte Zeile ist die vorhandene selbst geschriebene Prüfdatei, kein `package:test`-Aufruf. Eine neue Abhängigkeit wird nicht installiert. Alle drei Befehle laufen im Runner ohne Netzwerk und ohne Schreibrecht auf Quellcode oder eingefrorene Tests.

## Verbindliche Abnahme je Aufgabenart

| Aufgabenart | Pflichtprüfungen | Fehlende Voraussetzung |
| --- | --- | --- |
| Dokumentation / Dart-Lerncode, V1 | Unveränderte Baseline grün; Dateiliste und Testintegrität; Markdown/Links; eingefrorene Textkriterien; Dart-Format/Analyse/neun Fälle; vollständiger manueller Diff und fachliches Review | Blockieren; keine stillen Nebenreparaturen oder grünen Ersatzprüfungen. Neue Funktion außerhalb der Testabdeckung zuerst separat spezifizieren. |
| Spätere Flutter-App | Tatsächliche Format-/Analyse-/App-Tests, passende Widget-/Integrations- und Browserprüfungen sowie überprüfter Build | V1 blockiert diesen Scope. Keine Übertragung des Demo-Erfolgs auf das Produkt. |
| Späteres Backend / Rollen | Lokale reproduzierbare DB mit synthetischen Seeds, Migrationstests, direkte positive/negative Zugriffe als nicht angemeldetes Konto, eigener/fremder Gast, Gastgeber verschiedener Communities und entzogene Mitgliedschaft | V1 blockiert diesen Scope. Admin-/service_role-Erfolg ersetzt keinen Nutzerrollentest. |
| Spätere konsistente Abläufe | Wiederholung, atomarer Rollback bei Fehler, konkurrierende Aufnahme/Entzug und letzter Eventplatz, Löschfrist vor/nach Fälligkeit | Nicht vorhanden; [geplante Produktabnahme](product-spec.md#7-wie-wir-die-drei-wichtigsten-anforderungen-testen) bleibt verbindlicher Entwurf. |
| Steuerung / Testvorgaben / Rechte | Eigene menschlich geprüfte Änderung am Kontrollstand und erneute Schutztests | Für Coding-Aufgaben gesperrt; keine Selbsterteilung von Freigaben oder Abschwächung der Kriterien. |

## Beobachtete Nachweise und offene Grenze

Die Gesamtprüfung `python3 -I scripts/check_project.py` bestand am 25.09.2026: Dokumente/Links, Dart-Format/Analyse/neun Fälle und 25 Runner-Tests ohne übersprungene Tests. `--scope product` wurde ausgeführt und blockierte wie erwartet mit Exitcode 2. Darunter: unerlaubte Dateiziele, manipulierte Vorschlagsfelder, kontrollierter Steuerstand, doppelte Dateiziele, Symlinks, Traversal, veränderte Tests, bereinigte Umgebung, konkurrierender Start, Zeitlimit, fehlende Tests/Runtime, fehlgeschlagene Baseline, fehlende Entwicklungsanmeldung, einmaliger Freigabeverbrauch, Reparatur nach Fehler und Abbruch nach maximal drei Vorschlägen.

Die CLI-Demo wurde sowohl in der Testsuite als auch mit einer temporären Kopie der tatsächlich geprüften Projektdateien ausgeführt. Sie erzeugte eine Lerndatei nur im Kandidaten, einen Patch und einen expliziten `simulation_only`-Bericht. Das ursprüngliche Repository blieb dort sauber. Der Modellanbieter wurde nicht kontaktiert; dies ist kein Live-Codex-Nachweis. Die CLI-Tests erzeugen nur dafür synthetische lokale Commits, keine Freigabe für den echten Projektstand. Ein separat aufbewahrter Simulationsbericht mit SHA-256 des Runnercodes liegt lokal unter `.local/runner-verification/simulation-report.json`, der vorgeschlagene Diff unter `.local/runner-verification/simulation.patch`. Diese lokalen Nachweise sind absichtlich nicht versioniert.

Bei der Entwicklung schlug das erste macOS-Profil fehl. Die Ursache für den Startabbruch wurde auf fehlenden Lesezugriff auf das Wurzelverzeichnis selbst eingegrenzt. Das korrigierte Profil erlaubt diesen Verzeichniseintrag, nicht pauschal dessen Unterordner. Anschließend bestanden die tatsächlichen Schutztests und Dart-Prüfungen. Zwei frühere Python-Testprozesse (PIDs `38028`, `38445`) blieben trotz `SIGKILL` im Zustand `UEs` im Kernel. Sie sind kein gewollter Hintergrunddienst; ihr vollständiges Ende konnte nicht bestätigt werden. Vor echten Läufen muss der Nutzer diesen Zustand klären, gegebenenfalls durch einen kontrollierten macOS-Neustart. Ein gescheitertes Aufräumen darf nicht als abgeschlossen gelten.

Nicht ausgeführt: echter Codex-Modellaufruf mit eigener Entwicklungsanmeldung, dessen Netzwerk-/Auth-Profil, Flutter-Produktbuild, Produktbrowserprüfung, Datenbank-, Rollen-, Transaktions- und Konkurrenztests sowie andere Betriebssysteme. Gründe: separate Anmeldung/Netzfreigabe fehlen beziehungsweise Produktkomponenten existieren noch nicht. Native iOS-/Android-/Desktop-Plattformen bleiben ungeprüft. Keine vollständige Sicherheitszertifizierung oder Garantie gegen absichtlich bösartigen Code.

## Nachtrag nach der separaten Anmeldung

Die früheren Prozesse wurden anschließend als beendet geprüft und die lokale Startsperre archiviert. Die Demo gegen den freigegebenen Commit `5c86c25` bestand ebenfalls; der lokale Bericht liegt unter `.local/task-runner/demo-2722c1d3/report.json`.

Der Nutzer meldete die separate Anmeldung als abgeschlossen. Ohne Lesen von Zugangsdaten wurde die reguläre `auth.json` im vorgesehenen Entwicklungsordner festgestellt. Zusätzlich vorhandene `log`-/`tmp`-Ordner blockierten die ursprüngliche Validierung. Die dafür vorbereitete Korrektur erlaubt diese regulären Ordner als vorhandene Einträge, ohne ihren Inhalt zu lesen oder dem Modellprozess freizugeben.

Die Gesamtprüfung nach der Korrektur bestand: 28 Runner-Tests ohne übersprungene Tests, neun Dart-Statusfälle, Dart-Formatierung und Analyse sowie Dokumentationsprüfungen. Drei zusätzliche Tests prüfen die Metadatenvalidierung, Ablehnung unbekannter Einträge/Symlinks und die tatsächliche OS-Lesesperre für synthetische Log-/Temp-Inhalte. Echte Zugangsdaten wurden in keinem Test verwendet. Ein echter Modellaufruf bleibt ungeprüft; vor seiner Ausführung benötigt der geänderte Kontrollstand einen eigenen Review und Freigabe.

## Erster echter Ausführungsversuch und vorbereitete Korrektur

Die Nutzeranweisung „Führe das aus“ wurde als einmaliger Auftrag für den vorhandenen synthetischen Lernhinweis erfasst. Basis und Kontrolle: `f226551bc6eacef181f50719ce30e117197f27d5`; Aufgabe `explain-event-confirmation`, Modellwahl `gpt-6-sol`, 600 Sekunden Budget, maximal zwei Reparaturrunden. Der Dry-Run war erfolgreich.

Der Lauf wurde tatsächlich gestartet, endete aber nach rund 0,91 Sekunden mit `blocked`. Dokumente/Links, Dart-Format, Analyse und alle neun Statusfälle der Ausgangsbasis bestanden. Die CLI brach mit `failed to initialize in-process app-server client: Operation not permitted` ab. Es entstand kein Änderungsvorschlag und kein Patch; eine erfolgreiche Modellverbindung wurde nicht nachgewiesen. Bericht: `.local/task-runner/run-explain-event-confirmation-33d647b6/report.json`. Die Aufgabenfreigabe ist verbraucht. Die Arbeitskopie wurde durch diesen Lauf nicht verändert.

Die anschließende Diagnose verwendete keine echten Zugangsdaten. Sie wies den Bedarf an einer beschreibbaren SQLite-Laufzeitablage und einem Dateilimit oberhalb 1 MB nach. Die vorbereitete Korrektur bestand `python3 -I scripts/check_project.py`: 31 Tests, neun Dart-Fälle, Format, Analyse und Dokumentationsprüfungen. Neue Tests prüfen den kontrollierten Auth-Verweis, den Schutz der ursprünglichen synthetischen Anmeldedatei bei schreibbarer Laufzeitablage und den echten Offline-Start der installierten CLI. Der Offline-Test erwartet die kontrollierte Zeitbegrenzung, nachdem die Initialisierung gelungen ist; er behauptet keine erfolgreiche Modellantwort. DNS-Auflösung von `chatgpt.com` bestand separat im vorgesehenen Netzwerkprofil ohne Anmeldung.

Noch ausstehend: Review/Freigabe des geänderten Kontrollstands und genau ein neuer authentifizierter Versuch mit einer neuen Freigabe-ID. App-, Datenbank- und Rollentests bleiben mangels Implementierung aus. Keine Veröffentlichung oder automatische Übernahme.

## Zweiter echter Versuch: CLI-Start erfolgreich, TLS blockiert

Nach ausdrücklicher Nutzerfreigabe wurde die Laufzeitkorrektur als `aff3b9ac066dd48ae41c540588fed4feaec05dc1` committet. Die unveränderte Dokumentationsaufgabe erhielt die neue ID `explain-event-confirmation-retry1`. Der Dry-Run und sämtliche Ausgangsprüfungen bestanden; Modellwahl blieb `gpt-6-sol`, Budget 600 Sekunden.

Die CLI startete nun, scheiterte aber wiederholt mit `invalid peer certificate: UnknownIssuer`. Der eindeutig identifizierte eigene Codex-Prozess wurde gezielt mit SIGTERM beendet. Der Runner räumte auf und meldete nach 63,19 Sekunden `blocked` mit Exit -15. Keine Modellantwort, keine abgeschlossene Vorschlagsrunde und kein Patch. Bericht: `.local/task-runner/run-explain-event-confirmation-retry1-418f0005/report.json`. Auch diese Freigabe ist verbraucht.

Ein separater, auf 15 Sekunden begrenzter Test ohne Anmeldung verwendete ausschließlich das öffentliche vorhandene System-CA-Bündel. Danach trat HTTP `401 Unauthorized` statt `UnknownIssuer` auf. Der Test wurde durch sein Zeitlimit beendet; dies ist ein TLS-Verbindungsnachweis, kein erfolgreicher Aufgabenlauf und keine Modellantwort.

Die daraus vorbereitete Korrektur bestand die Gesamtprüfung: 33 Runner-Tests ohne übersprungene Tests, neun Dart-Statusfälle, Formatierung, Analyse und Dokumentationsprüfungen. Zwei zusätzliche Tests prüfen die feste CA-Vorgabe statt geerbter Umgebungswerte und den blockierten Start bei fehlendem Bündel. Der vollständige Diff wurde geprüft. Die technische TLS-Prüfung bleibt aktiv. Review und Freigabe des neuen Kontrollstands sowie ein weiterer einzelner angemeldeter Versuch stehen noch aus; Produkt-App, Datenbank und Rollen bleiben ungeprüft und nicht implementiert.

## Minimale Flutter-App (separater manueller Schritt)

`app/` enthält nun eine synthetische Flutter-Web-Statusdemo. Der frühere Tabellenstand „App nicht vorhanden“ ist damit überholt; Backend und Berechtigungsmodell fehlen weiterhin. Es gibt keine Aufnahme- oder Eventmutationen, sondern ausdrücklich gekennzeichnete Beispielzustände. Daher keine Transaktions- oder Konkurrenztests für diese reine Anzeige.

Ausgeführt: Offline-Auflösung der SDK-Pakete; Dart-Formatierung; Flutter-Analyse ohne Befund; fünf Tests (ein Logiktest, vier Widget-Tests); Web-Release-Build; sichtbare Startansicht und Wechsel zur Veranstalterbestätigung im lokalen Codex-Browser. Abgedeckt sind getrennte Eventzusage, Startzustand, alle vier Demozustände einschließlich Rückwechsel, schmale Ansicht mit großer Schrift sowie Auswahl per Tastatur. Ein fehlgeschlagener erster Paketaufruf im Projektstamm wurde im richtigen App-Verzeichnis erfolgreich wiederholt.

Nicht ausgeführt: automatisierte Browserintegration, Backend-/Rollen-/Transaktionsprüfungen und native Plattformen. Die bestehende V1-Projektprüfung wird nicht als App-Prüfung verwendet: Sie exportiert nur bekannte Quelldateitypen und unterstützt unter anderem `app/web/index.html` noch nicht. Runner/Controller blieben unverändert; vor Aufnahme der App in dessen freigegebenen Kontrollstand ist ein eigener Ausbau samt Review nötig. `--scope product` bleibt gesperrt. Die neue App wurde unabhängig mit den im Setup dokumentierten Aufrufen geprüft. Keine automatische Übernahme in einen freigegebenen Runner-Stand und kein Commit in diesem Schritt.

## Getrennte lokale Datenbank-Testumgebung

Das manuelle Skript `scripts/check_database.py` wurde mit dem vorhandenen PostgreSQL 17.10 ausgeführt. Ein frischer Cluster unter `.local/database-tests/` bestand Isolation (eigener Datenpfad, kein TCP, privater Socket), synthetische SQL-Fixtures mit Rollback und Unique-Constraint sowie zwei konkurrierende Updates über unabhängige Verbindungen. Anschließend wurde der eigene Server bestätigt beendet. Der Bericht liegt im jeweiligen lokalen Laufverzeichnis als `report.json`.

Das ist ausschließlich ein Infrastrukturtest. Die Fixture-Tabelle ist ausdrücklich kein Produktdatenmodell; der synthetische Administrator ersetzt keine Nutzerrollentests. Supabase, Produktmigrationen, Eventkapazität, Löschfristen und Rollenprüfungen bleiben offen. Die App-Arbeit aus dem vorherigen Schritt blieb uncommittet erhalten. Der V1-Runner wurde nicht erweitert und die vollständige Produktprüfung bleibt blockiert. Ausführungsdetails und Grenzen stehen im Setup.

## Supabase Auth/API und Rollen: lokaler Kern

CLI 2.117.0 und separate Colima-Test-VM eingerichtet. Finale Netzprüfung: Host und Container nur 127.0.0.1:55431/55432. Die vorausgegangene unerwartete Wildcard-Bindung wurde durch Stoppen und ein Loopback-Netz korrigiert; sie ist im [ADR 0002](decisions/0002-local-supabase-core.md) dokumentiert.

47 Auth-/API-Prüfungen bestanden, einschließlich fünf echten synthetischen Kontoanmeldungen, fremder Community, eigener/fremder Bewerbung, Selbstaufnahmeverbot, verbotener direkter Schreibzugriffe, erzwungenem Transaktionsrollback, konkurrierender Aufnahme und letztem Eventplatz sowie Zugriffsentzug mit bestehendem JWT. Bericht: `.local/supabase-tests/c0e5c691128c4131ac5e67aadba70127.json`. `supabase db lint --local --schema public,access_private --fail-on warning` meldete keine Befunde.

Noch offen: Einladungen, Kollektivaufnahme, Bewerbungsantworten/-rückzug, Löschfristen, vollständiger Entzugsablauf, Eventverwaltung und Flutter-Backend-Verbindung. Das Produktdatenmodell ist nur als Kern implementiert; keine vollständige Produktabnahme. Der V1-Runner und seine Produkt-Sperre bleiben unverändert. App-Tests wurden für diesen reinen Backend-Schritt nicht erneut ausgeführt; App-Dateien blieben unverändert.

## Runner-Erweiterung: geprüfter App-Scope und manuelle Kernprüfung

Auf `codex/runner-app-gates` implementiert, noch uncommittet und nicht als neuer Kontrollstand freigegeben. Grenzen und technische Ausnahmen stehen in [ADR 0003](decisions/0003-runner-app-gates.md).

Der gemeinsame Aufruf `check_project.py --scope core` bestand mit expliziter Einbeziehung der neuen Dateien: Dokumentation, neun geschützte Dart-Lernfälle, Offline-Auflösung der Flutter-Abhängigkeiten, App-Formatierung/Analyse, fünf App-Tests, Web-Build, 47 echte lokale Auth-/API-Prüfungen, SQL-Analyse ohne Befund und 37 Runner-Tests ohne übersprungene Tests. Backend-Bericht: `.local/supabase-tests/c6babc3547e14f558eec609a2d0c97ad.json`.

Ein vollständiger `app-ui`-Aufgabenlauf mit vorgegebenem Kommentarvorschlag bestand Ausgangs- und Kandidatenprüfungen und erzeugte einen Patch. Bericht: `.local/task-runner/app-proof-38d32392/report.json`, ausdrücklich `simulation_only`, `codex_executed: false`. Kein tatsächlicher App-Modellaufruf, keine Übernahme des Beispielpatches. Der reale frühere Dokumentationslauf ersetzt diesen ausstehenden App-Modellnachweis nicht.

Negativnachweise: `--scope product` blockierte mit Exitcode 2. Der Backend-Prüfer blockierte bei gestoppter VM ebenfalls mit Exitcode 2. Fehlende/übersprungene/fehlgeschlagene App-Tests werden in neuen Kontrolltests abgewiesen. Supabase und Test-VM wurden nach der Prüfung beendet. Keine Veröffentlichung oder automatische Freigabe.

Bei der Isolation wurden zuvor blockierte SDK-Cache-Schreibversuche, Compiler-Dateilimit, notwendige SDK-Hilfsprogramme sowie das Beenden eigener Flutter-Kindprozesse untersucht. Das schließlich geprüfte Profil lässt Quellcode/Tests/SDK schreibgeschützt und erlaubt nur begrenzte Build-Ausgaben, macOS-Systemdienstsuche, Kindprozesssignale und Loopback-Netzwerk. Keine Garantie gegen absichtlich bösartigen Code; keine Portisolierung gegenüber anderen lokalen Diensten. Historische fehlgeschlagene Diagnoseläufe gelten nicht als bestanden.

## Kontrollreview und Freigabe auf Nutzerauftrag

Der Nutzer hat ausdrücklich beauftragt: „Änderungen und den neuen Kontrollstand prüfen und freigeben“. Geprüft wurde der gesamte bisher uncommittete App-/Backend-/Runner-Stand auf `codex/runner-app-gates`, einschließlich neuer Dateien, erlaubter Dateiziele, eingefrorener Tests, Schutz der Steuerung, begrenzter Wiederholungen und dokumentierter Isolationsgrenzen. Keine neuen Produktrechte oder Testkriterien festgelegt. Überholte Statusangaben in README und Workflow wurden berichtigt; ältere Prüfabschnitte sind ausdrücklich als Historie eingeordnet.

Erneut ausgeführt und bestanden: `check_project.py --scope app` mit den 17 explizit einbezogenen neuen Dateien, Dokument-/Linkprüfungen, neun Dart-Lernfälle, App-Formatierung/Analyse, fünf App-Tests, Web-Build und 37 Runner-Tests ohne übersprungene Tests. `check_database.py` bestand mit frischem Cluster, Rollback/Unique-Constraint und zwei konkurrierenden Updates; Serverende bestätigt. Bericht: `.local/database-tests/run-vx4vns34/report.json`. Die vollständige Produktprüfung blockierte weiterhin wie vorgesehen.

Nicht erneut ausgeführt: Supabase Auth/API und SQL-Analyse, weil deren unveränderte lokale Umgebung gestoppt bleibt. Der vorhandene Bericht `.local/supabase-tests/c6babc3547e14f558eec609a2d0c97ad.json` wurde gezielt geprüft: 47 bestandene Aussagen. Dies ist ein früherer Nachweis, keine erneute Backend-Abnahme. Der frühere echte Dokumentationslauf (`run-explain-event-confirmation-retry2-aff86e86`) und die App-Simulation (`app-proof-38d32392`) wurden anhand ihrer Berichte bestätigt. Kein neuer Modellaufruf, Browserintegrationstest oder nativer Plattformtest.

Die Nutzerfreigabe gilt für den nach dieser Prüfung lokal gesicherten Kontrollcommit; seine vollständige SHA wird im Abschlussbericht genannt. Keine konkrete Aufgabenfreigabe erzeugt und `approve` nicht ausgeführt. Der nächste App-Auftrag benötigt weiterhin eine eigene menschliche Aufgabenfreigabe. Bestehende Grenzen bleiben: Loopback-Zugriff anderer lokaler Dienste möglich, keine vollständige Isolation gegen absichtlich bösartigen Code, keine Gesamt-Diskquote, kein Backend-Coding-Scope und keine vollständige Produktabnahme. Kein Merge, Push oder Deployment.

## Flutter-Verzeichnisse: Veranstalter und Veranstaltungsorte

Am 01.10.2026 manuell auf Nutzerauftrag lokal umgesetzt: zwei Navigationsseiten in `client/`, Anbindung an das synthetische Better-Auth-/PostgreSQL-Modul unter `server/`, Profilverwaltung und persönliche Freigaben. 60 Flutter-Tests und 29 Backend-Tests bestanden; Formatierung, Analyse, Web-Build und gezielte Browserprüfung bestanden. Dies erweitert keinen Runner-Kontrollstand und ist keine vollständige Produktabnahme. Im privaten Mailmodus bleiben die Verzeichnisrouten geschlossen. Umfang, Befehle, Einschränkungen und Browsernachweise stehen unter [Veranstalter und Veranstaltungsorte in Flutter](organizers-venues-flutter.md).


## Getrennte Gästekreise für Veranstaltungsprogramm – 02.10.2026

Der lokale synthetische Sichtbarkeitsstand für Profile, Reihen und einzelne Events bestand 67 Flutter-Tests, 23 PostgreSQL-/HTTP-Verzeichnisprüfungen und fünf weitere HTTP-/Mailtemplate-/Gatewaytests sowie Analyse und Web-Build. Der Browserweg Gastgeberfreigabe → angemeldeter Gastzugriff → Entzug → gesperrter Neuabruf wurde bestätigt. Ein zusätzlicher Auth-Regressionslauf wurde durch den belegten Vorschauport vor seinen Einzelprüfungen blockiert.

Bei später festgestellten parallelen Änderungen an denselben Quellen bestand die erneute Flutter-Analyse; der Verzeichnislauf scheiterte im Fall eines älteren öffentlichen Events ohne Profilzuordnung, das nun aus dem Ortsverzeichnis verschwindet. Kein vollständiger Erfolgsnachweis für diesen neueren Zwischenstand. Zuständigkeit und gewünschte Behandlung des Altbestands sind vor gemeinsamer Korrektur zu klären. Details, Grenzen und Browsernachweise: [Veranstalter und Veranstaltungsorte](organizers-venues-flutter.md). Dies erweitert keinen Runner-Kontrollstand und ist keine Produkt- oder Produktionsabnahme.


## Altbestands-Regression behoben und Auth-Test nachgeholt – 02.10.2026

Auf ausdrücklichen Nutzerauftrag wurde die oben dokumentierte Regression korrigiert: Bereits öffentliche Events ohne Profil- und Reihenzuordnung bleiben bei öffentlicher Community, aktuellem Gastgeberrecht und freigegebener Ortsangabe im öffentlichen Ortsverzeichnis samt Details sichtbar. Private Profile und geschützte Reihen umgehen dadurch keinen Schutz. Keine automatische Profilzuordnung oder Gastfreigabe.

Erneut bestanden: **27 Verzeichnis-/PostgreSQL-/HTTP-Tests, 10 Auth-Tests und fünf HTTP-/Gateway-/Mailtemplate-Tests**, jeweils ohne übersprungene Tests. Der zuvor belegte Port wurde nach ausdrücklicher Nutzerfreigabe für den Auth-Test freigegeben. Die lokale Backend-Vorschau wurde danach wieder gestartet; bisherige synthetische Datenbestände bleiben erhalten. Keine Flutter-Änderung, deshalb keine erneute Flutter-Prüfung oder neuer Web-Build. Der Nachweis gilt für diese Backend-Korrektur und erweitert keinen Runner-Kontrollstand oder eine Produktabnahme. [Umfang und Ergebnisse](organizers-venues-flutter.md).


## Mehrere Profile, Vorschau, Merkliste und Eventinformationen – 02.10.2026

Im gemeinsam geprüften lokalen synthetischen Stand bestanden 74 Flutter-Tests, Flutter-Analyse, Web-Build, 27 Verzeichnis-/PostgreSQL-/HTTP-Prüfungen einschließlich der Altbestandskorrektur, zehn Auth-Tests und fünf HTTP-/Gateway-/Mailtemplateprüfungen. Die Browserprüfung bestätigt ein zweites Profil im selben Gastgeberkonto, Eventanlage mit konkreten Zugänglichkeits-/Awarenessangaben, Vorschau, profilbezogenes Merken, Persistenz nach erneuter Anmeldung und Entfernen. Die Daten früherer lokaler Demoläufe wurden erhalten. Der Nachweis umfasst keine Produktteilnahme, geschützte genaue Adressen, Produktionsdaten, vollständige Barrierefreiheitsprüfung oder Runner-Abnahme. [Umfang, Grenzen und Nachweise](organizer-features.md).


## Veranstaltungsseiten und Gastgebereditor — 02.10.2026

Manuelle lokale Umsetzung des ausdrücklichen Nutzerauftrags. Die Informationshierarchie der genannten Resident-Advisor-Seite wurde anhand ihrer tatsächlich geöffneten Darstellung geprüft. [Umfang, Quellen, Architektur und Grenzen](event-editorial-pages.md).

Tatsächlich ausgeführt am abschließenden gemeinsamen Checkoutstand:

- Dart-Formatprüfung der zwölf betroffenen Dateien: bestanden, keine Änderungen erforderlich.
- `flutter analyze --no-pub`: bestanden, keine Befunde.
- `flutter test --no-pub --reporter expanded`: **87 Tests bestanden**. Sieben neue Widgettests betreffen vollständige Eventinhalte und Flyer-Vergrößerung, leere Altbestände/Absage, Ersetzen/Entfernen, Speicherung und Entwurfsvorschau sowie 320-/375-/1280-Pixel-Breiten mit verdoppelter Schrift in heller und dunkler Testgestaltung. Bestehende Scrollprüfungen wurden an längere Seiten angepasst, ohne ihre Erwartungen zu entfernen.
- `flutter build web --no-pub --pwa-strategy=none`: bestanden. Die bestehende Cupertino-Fontwarnung und Abkündigung des PWA-Parameters bleiben. Kein nativer oder separat getesteter Wasm-Build.
- `python3 -I scripts/local_auth.py --test-directory`: **28 Tests bestanden**, keine übersprungen; echte getrennte lokale PostgreSQL-/HTTP-Prüfung mit synthetischen Konten. Der neue Fall prüft Speicherung, verborgene Orts-/Endfelder in Detail und Vorschau, ungültige Inhalte und Zeitfolgen, unveränderte Version bei Fehlern, fremde Eigentümer, Erhaltung durch alte Clients und keine Inhalte für unsichtbare Events. Bestehende Rechte-, Konkurrenz- und Schemawiederholungsprüfungen bestehen weiter.
- `node --test server/event_content.test.mjs server/http.test.mjs`: **vier Tests bestanden**, keine übersprungen. Dazu gehören der tatsächlich im Browser normalisierte Demo-Flyer, ungültige/aktive/externe/zu große Medien, EXIF, fehlender Alternativtext, abgeschnittene JPEG-Header und das größere Request-Limit ausschließlich am Event-Schreibendpunkt.
- JavaScript-Syntax der fünf betroffenen Laufzeitdateien, lokale Dokumentationslinks, Leerzeichenprüfung neuer Dateien, aufgabenbezogener Quellvergleich und `git diff --check`: bestanden.

Im gebauten Browser auf `127.0.0.1:8300` tatsächlich geprüft: synthetische Gastgeberanmeldung, Bearbeitung eines bestehenden Events, lokale PNG-Auswahl und Normalisierung, ungespeicherte Vorschau, erfolgreiche Speicherung, öffentlicher Detailabruf ohne Anmeldung, lesbare Beschreibung/Einlass in der Browser-Zugänglichkeitsstruktur, Veranstalterlink, vollständiger Flyer und Öffnen/Schließen der Vergrößerung. Der mobile Browser wurde auf 375 Pixel geprüft; die temporäre Größenänderung danach zurückgenommen. [Desktopnachweis](screenshots/event-editorial-desktop.jpg) und [Mobilnachweis](screenshots/event-editorial-mobile.jpg) zeigen den finalen Webbuild mit synthetischen Inhalten.

Frühere Gesamtläufe während paralleler Änderungen scheiterten zunächst an einem neu ergänzten Social-Login-Test und später an noch unvollständigen Semantik-Ergänzungen der Startseite. Diese Läufe sind keine Erfolge. Die parallel bearbeiteten Quellen wurden erhalten; der oben genannte abschließende Gesamtlauf ist erfolgreich. Die vorhandene lokale Vorschau bleibt erreichbar; der vorherige synthetische Datenbestand wurde beim geordneten Backend-Neustart aufbewahrt. Keine echten Daten, Installation, Remote-Migration, Veröffentlichung, Staging oder Commit.

Die Prüfungen belegen diesen lokalen Teilumfang. Teilnahmezusagen, geschützte genaue Adressen und vollständige serverseitige Medienverarbeitung bleiben offen; eine vollständige Produktabnahme wird nicht behauptet.

## Web-Anmeldung Google → Apple → Facebook (02.10.2026)

Auf Nutzerauftrag wurden die drei Anbieterwege, kontrollierte Account-Verknüpfung, kurzlebige Cookie-/Bearer-Übergabe und eine verdeckte private Einrichtungshilfe ergänzt. Details und konkrete offene Anbieter-Voraussetzungen stehen in [social-sign-in.md](social-sign-in.md). Bestehende gemeinsame Änderungen wurden erhalten. Im öffentlichen Einstieg wurden zudem ein fehlender `SemanticsRole`-Import und ein unzulässiges `const Semantics` minimal korrigiert, damit der gemeinsame Checkout wieder analysierbar ist.

Tatsächlich ausgeführt, ausschließlich mit synthetischen Daten:

| Prüfung | Ergebnis |
| --- | --- |
| `python3 -I scripts/local_auth.py --test-social` | 15 Tests bestanden, keine übersprungen. Reale Better-Auth-/PostgreSQL-State-, Account- und Sessionlogik; externe Anbieterantworten gemockt. Google, Apple-Formular und Facebook, Anbieterbindung, State-Ablauf/Replay, fehlende E-Mail, bewusste Verknüpfung ohne Rechteübernahme, Logout während Verknüpfung, Rate-Limit, Verschlüsselung und Verzicht auf gespeicherte ID-Tokens. Separate Apple-Signatur-/Nonce-Prüfung enthalten. |
| `python3 -I scripts/local_auth.py --test` | 10 bestehende Auth-Tests bestanden. Der HTTP-Testtransport nutzt jetzt einen eigenen Loopback-Port und den unveränderten erwarteten Host; die laufende Vorschau muss dafür nicht beendet werden. |
| `python3 -I scripts/local_auth.py --test-directory` | 28 Tests bestanden. Bestehende Profil-, Reihen-, Event-, Orts- und Legacy-Schutzgrenzen erhalten. |
| `python3 -I scripts/local_auth.py --test-mail` | Zwei Varianten bestanden: Bestätigung, Reset und Sitzungsentzug sowohl lokal als auch an ausdrücklich konfigurierten HTTPS-Origins. Resend ist gemockt; kein Mailversand. |
| `node --test server/account_mail.test.mjs server/social.test.mjs server/http.test.mjs server/dashboard_gateway.test.mjs server/event_content.test.mjs` | 13 Tests bestanden, keine übersprungen. Vier Konfigurations-/Apple-Tests sind außerdem im SSO-Lauf enthalten und nicht als zusätzliche einzigartige Tests zu zählen. |
| `python3 -I scripts/social_setup_test.py` | Drei Tests bestanden: verdeckte Reihenfolge aller Anbieter, private Dateirechte und Redaktion, Symlink-/Rechteablehnung sowie Erhaltung vorhandener Konfiguration bei Fehlern. Nur temporäre synthetische Schlüssel/Dateien verwendet. |
| `flutter analyze --no-pub` | Bestanden, keine Befunde. |
| `flutter test --no-pub` | Abschließend 89 Tests bestanden. Acht zusätzliche SSO-/Origin-Prüfungen; Anbieterbuttons bei 320 Pixeln und doppelter Schrift, eindeutige Beschriftungen, fehlende signierte Übergabe, begrenzte Fehler und Ausschluss unkonfigurierter Anbieter geprüft. |
| `flutter test --no-pub --dart-define=CA_PRIVATE_MAIL=true --dart-define=CA_AUTH_API_ORIGIN=https://auth.example.invalid --dart-define=CA_AUTH_UI_ORIGIN=https://app.example.invalid test/social_auth_origin_test.dart` | Zwei Tests bestanden; ausdrücklich konfigurierte HTTPS-Ziele, Recoverylinks und Ausschluss fremder Origins, ausschließlich HTTP-Mocks. |
| `flutter build web --no-pub --output /private/tmp/ca-social-web` | Bestanden. Separate Ausgabe; laufende Vorschau nicht überschrieben. |
| Webbuild mit `CA_PRIVATE_MAIL=true`, API-/UI-Origin `https://auth.example.invalid` / `https://app.example.invalid`, Ausgabe `/private/tmp/ca-social-https-web` | Bestanden. Synthetische HTTPS-Konfiguration, kein Deployment. |
| Dart-Formatprüfung, JavaScript-/Python-Syntax, neue Dateileerzeichen, lokale Dokumentationslinks, Vergleich mit Aufgaben-Ausgangsstand und `git diff --check` | Bestanden. |

Beide Builds meldeten die bestehende Cupertino-Fontwarnung; ein separat ausgeführter Wasm- oder Native-Build wird nicht behauptet. Keine zusätzliche Abhängigkeit installiert. Keine Anbieter-App, kostenpflichtige Mitgliedschaft, DNS-Änderung oder Veröffentlichung angelegt. Echte Provider-Secrets wurden nicht gelesen oder gespeichert. SSO-Live-Tests im Browser wurden mangels bestätigter Anbieterzugänge und erreichbarer HTTPS-Rückleitungen nicht ausgeführt. Ohne explizite Konfiguration bleibt `CA_SOCIAL_PROVIDERS` leer und die neue UI zeigt keine inaktiven Loginbuttons.


## Öffentliche Interessenzähler und Event-Merkliste — 02.10.2026

Manuelle Umsetzung des Nutzerauftrags mit ausdrücklich bestätigter Erweiterung auf einzelne Events. [Umfang, Daten und Grenzen](public-interest-counts.md).

Tatsächlich ausgeführt:

- Formatierung der sechs betroffenen Dart-Dateien: bestanden.
- `flutter analyze --no-pub`: bestanden, keine Befunde im abschließenden Lauf.
- `flutter test --no-pub --reporter expanded`: **94 Tests bestanden** im gemeinsamen Checkout. Fünf neue Widgettests prüfen anonymen Zähler ohne private Merklistenabfrage, Anmeldungseinstieg, tatsächliche Rückgabe nach Speichern/Entfernen, unveränderte Anzahl bei Fehler, private Eventmerker und Navigation aus der Merkliste sowie 320-/1280-Pixel-Breiten mit verdoppelter Schrift.
- `flutter build web --no-pub --pwa-strategy=none`: bestanden. Bestehende PWA-/Cupertino-Fontwarnungen bleiben; kein nativer oder separat getesteter Wasm-Build.
- `python3 -I scripts/local_auth.py --test-directory`: **29 Tests bestanden**, keine übersprungen. Der neue integrierte PostgreSQL-/HTTP-Fall prüft Profil-, Reihen- und Eventzahlen, Anmeldung und E-Mail-Bestätigung, paralleles/wiederholtes Merken, Entfernen, gleichzeitiges Merken/Entfernen, Wegfall einer E-Mail-Bestätigung, öffentliche Listen/Details/Ortsprogramme, Schemawiederholung mit erhaltenen Eventmerkern, Privatstellung von Reihe/Profil, individuell zugängliche geschützte Events und erneuten Entzug. Die bestehenden Rechte-/Konkurrenzfälle bestehen weiterhin.
- Syntax der vier geänderten JavaScript-Laufzeit-/Testdateien, Aufgaben-Diff einschließlich neuer Quellen, lokale Dokumentationslinks, Leerzeichenprüfung neuer Dateien und `git diff --check`: bestanden.

Im final gebauten Browser tatsächlich geprüft: öffentliches Profil und Programm mit Zählern, Eventzahl ohne Anmeldung, **Anmelden und merken** mit synthetischem Gastkonto, Rückkehr zur Eventseite mit **Event merken**, Änderung 0 → 1 → 0 beim Merken/Entfernen und erneut gespeicherte Zahl 1 im anschließenden anonymen Abruf. Die persönliche Auswahl und Kontonamen erscheinen dort nicht. Desktop und 375-Pixel-Browser wurden angesehen; temporäre Größenänderung zurückgenommen. [Öffentliche Eventansicht](screenshots/public-event-interest.jpg), [mobile Eventansicht](screenshots/public-event-interest-mobile.jpg).

Ein erster Backendlauf hatte im neuen Test eine falsche Erwartung an das bestehende Ortsverhalten: Der letzte ausgeblendete Event lässt den Ort mit 404 verschwinden, nicht mit einer leeren Eventliste. Diese Erwartung wurde korrigiert; der Lauf war fehlgeschlagen. Zwei Format-/Analysehinweise im neuen Widgettest wurden vor dem erfolgreichen Abschluss behoben.

Die vorhandene lokale Vorschau wurde geordnet mit aktualisiertem Backend und getrenntem synthetischem Demobestand wieder gestartet. Frühere Datenverzeichnisse bleiben erhalten; die bereits öffentliche synthetische Flyer-/Eventdarstellung wurde in der Vorschau wiederhergestellt. Nur lokale Testdaten und echte Merklisteneinträge dieser Testkonten; keine erfundenen produktiven Interessenzahlen. Keine Installation, Remote-Migration, Veröffentlichung, Staging oder Commit. Die Vorschau bleibt wie bisher auf `127.0.0.1` erreichbar.

Der Zähler repräsentiert bestätigte Konten, nicht nachgewiesene verschiedene Personen oder zugesagte Gäste. Andere offene Seiten aktualisieren sich beim nächsten Abruf; keine Echtzeitübertragung. Eine vollständige Produktabnahme oder Abnahme bisher offener Teilnahme-/Adressfunktionen wird nicht behauptet.


## Smartphone- und Tabletlayout · 03.10.2026

Die öffentliche Flutter-Seite und ihre Konto-/Detailansichten wurden im Branch `codex/mobile-tablet-layout` responsiv angepasst. Formatierung, Analyse, 115 Flutter-Tests und die synthetische Chromium-Browsermatrix bei 320, 375, 414, 768, 820, 1024 und 1440 Pixeln bestanden. 105 Bereichskontrollen erfassten keine Konsolen-/HTTP-Fehler. Doppelte Schrift und ein simulierter Tastaturbereich wurden gesondert in Widgettests geprüft. Die mobile Erstladezeit verfehlt mit 4,013 Sekunden Median weiterhin das 2,5-Sekunden-Ziel; echte Geräte, Safari, Browserzoom und vollständige Barrierefreiheitsabnahme bleiben offen. Keine Veröffentlichungsfreigabe. Umfang, Rohdaten, Aufgabendifferenz und Screenshots: [Prüfbericht](qa/mobile-tablet-2026-10-03/report.md).

## Evententdeckung, Präferenzen und Freigabe · 04.10.2026

Manuelle lokale Umsetzung auf Nutzerauftrag, einschließlich der ausdrücklich gewünschten Veranstalter-Besuchszuordnung ohne historischen Eventbezug. Abschließend bestanden Formatprüfung, Flutter-Analyse, **161 Fluttertests, 39 Verzeichnis-/PostgreSQL-/HTTP-Tests, zehn Auth-Tests und vier HTTP-/Medientests** sowie Webbuild und `git diff --check`. Browserprüfung bestätigte Hero-/Detailwechsel, DE/EN, die 320-Pixel-Darstellung sowie Anmeldung → Präferenzabfrage → Speicherung → persönliche Startseite mit Empfehlungsgrund. Die selbst gestarteten Testserver wurden beendet; frühere synthetische Datenbestände erhalten.

Der neue Fragenkatalog blockiert unbekannte Fragen und ersetzt keine juristische Prüfung. Die Siebentage-Bereinigung ist für die aktive lokale Datenbank geprüft, einschließlich Fremdschlüsselkaskaden und gleichzeitiger Läufe. Altbestände ohne Endzeit, Backups/WAL, Empfängerkopien und Browserreste sind nicht als gelöscht abgenommen. Keine vollständige Produktabnahme, Veröffentlichung oder Remote-Migration. [Umfang, tatsächliche Ergebnisse und Browsernachweise](event-discovery-preferences.md).

## Einzeiliger Header und Sprachdropdown · 04.10.2026

Lokale Folgeänderung auf Nutzerauftrag im Branch `codex/header-language-dropdown`: Sprachwechsel mit ausdrücklicher Auswahl von Deutsch/English; Logo, Navigation, Sprache und Konto in einer Zeile. Die Navigation wird bei Platzmangel als Menü geöffnet. Die verfügbare Breite wird einschließlich Schriftvergrößerung und aktueller Sprache bewertet. In besonders schmalen Ansichten bleiben Logo und Konto über benannte Symbole erreichbar.

Tatsächlich bestanden: Formatprüfung der fünf betroffenen Dartdateien, `flutter analyze --no-pub`, **161 Fluttertests**, Webbuild mit lokal gebündelten Webressourcen und `git diff --check`. Die vorhandene Layoutmatrix prüft nun zusätzlich die gemeinsame vertikale Mitte der Headerbedienelemente bei 320, 375, 414, 768, 820, 1024 und 1440 Pixeln sowie normaler und doppelter Schrift. Bestehende Navigations-, Verzeichnis- und Sprachtests wurden auf das Dropdownbedienen angepasst; ihre Inhalts-/Zugriffsprüfungen bleiben erhalten. Ein erster Lauf scheiterte an der zu kleinen Menübedienfläche und alten Annahmen über stets sichtbare Navigationslinks. Die Bedienfläche wurde auf mindestens 48 Pixel korrigiert; der abschließende Gesamtlauf bestand.

Browserbeobachtung im finalen Build: einzeiliger Desktopheader, geöffnetes Sprachdropdown mit Deutsch/English, ausdrückliche Auswahl von English, einzeiliger 320-Pixel-Header und Öffnen der vollständigen mobilen Navigation. Keine Warnungen oder Fehler im abgefragten Browserkonsolenprotokoll. [Desktopnachweis](screenshots/header-language-dropdown-20261004.jpg), [Mobilnachweis](screenshots/header-language-mobile-20261004.jpg). Temporäre Browsergröße zurückgenommen und beide selbst gestarteten lokalen Testserver beendet; synthetische Daten erhalten.

Backendprüfungen wurden wegen unverändertem Backend nicht wiederholt. Bestehende Cupertino-Fontwarnung und Abkündigung des PWA-Buildparameters bleiben. Keine Installation, Veröffentlichung, Remoteänderung, Staging oder Commit; vorhandene Arbeit erhalten.


## Vollständiger synthetischer Zugangsablauf — 05.10.2026

Der ausdrücklich beauftragte lokale Umfang ist implementiert und bestanden: Veranstalteraufnahme, persönliche Einladung, Communitybewerbung/Mitgliedschaft, getrennte Eventzusage, Kapazität, geschützte Location und Rechteentzug. [Vollständiger Abnahmebericht, Logs, Buildhashes und betrachtete Screenshots](qa/access-flow-2026-10-05/report.md); [Implementierung und Schutzgrenzen](access-flow.md).

Tatsächlich bestanden: 13 Access-Integrationstests mit frischer PostgreSQL-Datenbank, signierten Better-Auth-Sitzungen und eingeschränktem HTTP-Prozess; 49 Verzeichnis-/Discoverytests im aktuellen gemeinsamen Stand; 10 Auth- und 13 HTTP-/Gatewaytests; 166 Fluttertests, Formatierung, Analyse, Webbuild sowie der vollständige Browserablauf mit neun Kontrollpunkten. Keine Pflichtprüfung übersprungen. API-Gegenproben, letzter Platz, doppelte Aufnahme/Einlösung, Rückzug gegen Annahme, Entzug gegen Zusage, Rollback, getrennte Rechte, Kalender-/Freigabe-/Eventgrenzen und wiederholte Bereinigung geprüft. Browser ausschließlich auf 127.0.0.1; selbst gestartete Dienste anschließend nachweislich beendet.

Der bisherige Gesamtprodukt-Runner bleibt unabhängig blockiert. Produktionsbetrieb, Backup-Löschung, echte Provider-/Mailzustellung und reale Geräte-/Screenreaderprüfung sind dadurch nicht nachgewiesen. Keine Veröffentlichung, neue Abhängigkeit oder Änderung an Remote-Schemas.

# Veranstalter und Veranstaltungsorte in Flutter

> Einordnung für V1 · 10.10.2026: Dieser datierte Detailbericht beschreibt den damaligen Implementierungsstand einschließlich des erhaltenen erweiterten Modus. Maßgebliche Produktregeln und Umfang stehen ausschließlich in der [Produktspezifikation](product-spec.md); aktuelle Start- und Prüfbefehle im [Setup](setup.md). Historische Statusangaben und Prüfergebnisse sind keine heutige Funktions- oder Betriebsfreigabe.

Stand: 01.10.2026. Manuelle lokale Umsetzung des Nutzerauftrags „umsetzen und anbinden“. Keine Runnerfreigabe, Veröffentlichung oder Freigabe für reale Produktdaten.

## Oberfläche und Datenanbindung

Die Navigation unter `client/` enthält **Veranstalter** und **Veranstaltungsorte**. `DirectoryApi` verwendet dieselbe signierte Better-Auth-Sitzung wie das Gastkonto. Öffentliche Listen sind ohne Anmeldung erreichbar; ein gültiges angemeldetes Konto sieht zusätzlich persönlich freigegebene Veranstalterprofile. Ein abgelaufenes oder ungültiges mitgesendetes Sitzungstoken wird abgewiesen und im Client entfernt. Persönliche Antworten werden nicht in Browser-Speicher geschrieben. Der gemeinsame HTTP-Client gehört zur App und wird erst beim Entfernen der gesamten App geschlossen, nicht beim Verlassen des Gastkontos.

Das Veranstalterverzeichnis bietet Namenssuche, Communityfilter und serverseitige Seitenaufteilung mit 20 Profilen. Die Suche interpretiert Prozent- und Unterstrichzeichen wörtlich. Private Profile werden weder über Namenssuche noch über private Communitynamen auffindbar. Private Communitynamen bleiben auch nach persönlicher Profilfreigabe verborgen. Seit dem 02.10.2026 erwähnt und kennzeichnet die öffentliche Oberfläche persönliche Profilfreigaben nicht. Ein geteiltes privates Profil liefert ohne Anmeldung dieselbe 404-Antwort wie ein unbekannter Eintrag, einschließlich seines Zugangsendpunkts. Angemeldete Konten ohne Profilfreigabe erhalten am ausdrücklich geteilten Einstieg nur einen neutralen Namen („Profilzugang“), angebotene Zugangswege und das dafür freigegebene Formular; der Profilname und die Beschreibung bleiben verborgen. Freigegebene Profile erscheinen angemeldet ohne gesondertes Sichtbarkeitsabzeichen. Dies ändert den bisherigen API-Vertrag für anonyme private Zugangseinträge bewusst; Backend und Flutter-Ansicht müssen gemeinsam aktualisiert werden.

Ein Gastgeber verwaltet seit der Erweiterung vom 02.10.2026 mehrere eigene Profile und ordnet ausschließlich Communities zu, in denen er aktuell Gastgeberrechte besitzt. Die Verwaltung ist im angemeldeten Konto unter **Gastgeberverwaltung** erreichbar. Öffentlichkeit, Bewerbung, eigenes Formular und persönlicher Link sind getrennte Einstellungen. Formularfragen besitzen Pflichtfeldmarkierungen und eine Version; veraltete Eingaben werden zurückgewiesen. Die tatsächlich eingereichten Fragen werden mit der Anfrage gespeichert. Bewerbung und Formular benötigen manuelle Freigabe. Ablehnung, Rückzug und Entzug sperren erneute Anfragen; die Oberfläche verweist auf den bestehenden persönlichen Kontaktweg. Es wird kein Kontaktkanal oder nicht freigegebener Kontaktwert erfunden.

Persönliche Links sind an ein bestehendes Konto mit bestätigter E-Mail gebunden, sieben Tage gültig, widerrufbar und einmal nutzbar. Diese Laufzeit ist eine lokale Implementierungsentscheidung, keine festgelegte Frist für den Pilotbetrieb. Tokens werden ausschließlich gehasht gespeichert; die unveränderte URL wird nur beim Erstellen an den Gastgeber zurückgegeben. Der Client übernimmt Profil-/Linkparameter beim Start, bevor Flutter den Navigationseintrag umschreibt. Die URL nutzt das Fragment, damit ein Token nicht an den statischen Webserver übertragen wird. Anmeldung aus dem Profileinstieg kehrt zum Profil zurück.

Profilzugriff erzeugt keine Communitymitgliedschaft, Eventzusage oder Berechtigung für geschützte Locations. Die vorhandenen Produktaktionen im Better-Auth-Adapter bleiben gesperrt; `product_available` bleibt falsch. Der eigene Kontoabruf ergänzt lediglich `directory_available` und `is_host`.

## Öffentliche Orte und Eventangaben

Das Ortsverzeichnis fasst exakt übereinstimmende, ausdrücklich öffentliche Ortsangaben zusammen. Es berücksichtigt veröffentlichte und öffentlich angekündigte abgesagte Events in öffentlichen Communities, einschließlich vergangener Veranstaltungen. Entwürfe, private Events, private Communities und nicht freigegebene Orte bleiben ausgeschlossen. Ein Veranstalterprofil muss dafür nicht öffentlich sein: Entscheidend sind Event-, Community- und Ortsfreigabe.

Ortsdetailseiten zeigen die zugehörigen öffentlichen Events. Eine geschützte Reihe kann nicht über ein darin als öffentlich markiertes Event, dessen Ort, Ortszähler oder Ortsnamensuche sichtbar werden; das gilt auch bei angemeldeten Zugriffen auf das allgemeine öffentliche Ortsverzeichnis. Beginn wird nur bei gesonderter Freigabe angezeigt und zur öffentlichen Sortierung verwendet; verborgene Termine dürfen keine Reihenfolge verraten. Gastgeber können die benötigten Event-/Ortsangaben für ihre verantwortlichen Communities anlegen und ändern. Dies ist ein begrenzter Katalogeditor, keine vollständige Eventverwaltung oder Platzvergabe. Ortsangaben bleiben Textwerte; eine eigenständige Ortsdatenbank mit Adressen, Geokoordinaten und Betreiberrollen wird nicht erfunden.

## Lokale Architektur und Grenzen

`server/directory.sql` ergänzt Tabellen für Communities, Gastgeberzuordnungen, Profile, Profilzuordnungen, Anfragen, persönliche Links und Eventkatalogangaben. `server/directory.mjs` prüft die Rechte serverseitig und verarbeitet Freigaben/Links in Transaktionen. Profilsperren und bedingte Statusänderungen verhindern widersprüchliche Entscheidungen; eine Versionsprüfung verhindert unbemerkte konkurrierende Profiländerungen. Entzug und Rückzug entfernen gespeicherte Antworten sofort, ohne die Sperrmarkierung oder andere Rechte zu verändern.

Die Schemaergänzung erfolgt ausschließlich im bestehenden, geprüften lokalen synthetischen PostgreSQL-Bestand. Im privaten Mailmodus wird das Verzeichnismodul nicht geladen und es werden keine Produktmigrationen ausgeführt. Dort bleiben die neuen API-Routen geschlossen. Keine neue Abhängigkeit, externe Datenbank oder automatische Umstellung von privaten Beständen.

Ein gewöhnlich registriertes Konto erhält keine Gastgeberrechte. Diese Zuordnungen brauchen weiterhin einen getrennt abgesicherten betrieblichen Aufnahmeprozess. Der ausdrücklich gewählte Demostart legt nur synthetische Rollen und Inhalte an; normale Starts importieren weder das Laravel-Archiv noch dessen Daten. Für einen echten Pilot bleiben unter anderem Betriebszugang, Löschfristen einschließlich Sicherungen, Auditnachweise, Last-/Missbrauchsschutz und die übrigen Produktrechte zu prüfen. Diese Aufgabe ist keine vollständige Produkt- oder WCAG-Abnahme.

## Start und Prüfung

Aus dem Projektstamm, mit den bereits vorhandenen Werkzeugen:

```sh
# Normaler synthetischer Bestand: vorhandene Konten bleiben erhalten.
python3 -I scripts/local_auth.py

# Alternative: eigener frischer synthetischer Demobestand für diese Verzeichnisse.
python3 -I scripts/local_auth.py --directory-demo

# Getrennte PostgreSQL-/HTTP-Prüfung ohne bestehende Bestände zu ändern.
python3 -I scripts/local_auth.py --test-directory
```

Normalstart und Demostart belegen denselben lokalen Port 8000 und dürfen nicht gleichzeitig laufen. Jeder Demostart nutzt einen eigenen Bestand; er überschreibt keinen bisherigen. Strg+C beendet den gestarteten Server und PostgreSQL, die lokalen Daten bleiben erhalten.

Den Flutter-Client separat starten:

```sh
cd client
flutter run -d chrome --web-hostname=127.0.0.1 --web-port=8300
```

Der Demostart verwendet ausschließlich `@example.invalid`-Konten, darunter `host.a`, `host.b`, `guest.a` und `guest.b`, jeweils mit `Synthetic-2026!`. Diese bekannten synthetischen Fixturewerte sind keine produktiven Zugangsdaten. Beispielprofil A ist öffentlich, B privat mit Zugangsformular. Die Anmeldung vergibt keine weiteren Rechte. Der private Mailstart wird für diese Prüfung nicht genutzt; es findet kein E-Mail-Versand oder Dashboard-/Tunnelanschluss statt.

## Prüfergebnisse

Am 01.10.2026 tatsächlich ausgeführt:

- `dart format --output=none --set-exit-if-changed lib test`: 32 Dateien, keine Änderungen nötig.
- `flutter analyze --no-pub`: keine Befunde.
- `flutter test --no-pub --reporter expanded`: alle 60 Tests bestanden. Die neuen Fälle prüfen API-Anbindung, Filter, Fehlerzustände, Gastgebereditor, Profilformular und Login-Rückkehr ohne Schließen des gemeinsamen HTTP-Clients. Die neuen Seiten passen bei 320 und 375 Pixel Breite mit verdoppelter Textgröße.
- `flutter build web --no-pub`: bestanden. Der Build meldet die vorhandene fehlende Cupertino-Icon-Fontfamilie; in den geprüften Ansichten wurden keine fehlenden Icons beobachtet. Ein Wasm-Build wurde nicht ausgeführt.
- `python3 -I scripts/local_auth.py --test-directory`: 14 bestandene PostgreSQL-/HTTP-Tests, keine übersprungen. Enthalten sind fremde/private Profile, fehlende Gastgeberrechte, konkurrierende Entscheidungen, Formularversionen, Rückzug/Entzug, Einmaligkeit und Zielkonto von Links, Widerrufsrennen, Pagination sowie öffentliche Event-/Ortsfelder.
- `python3 -I scripts/local_auth.py --test`: 10 bestandene Auth-Regressionsprüfungen.
- `node --test server/http.test.mjs server/dashboard_gateway.test.mjs server/account_mail.test.mjs`: fünf bestandene Regressionstests. Kein echter Versand und kein externer Dashboardaufruf.
- JavaScript-Syntax, Python-Kompilierung, lokale Dokumentlinks und `git diff --check`: bestanden.

Im Browser auf `127.0.0.1` geprüft: anonyme öffentliche Liste, nicht auffindbares Privatprofil, Gastgeberverwaltung, geteilter Profileinstieg, Anmeldung mit Rückkehr, Absenden eines Gastgeberformulars, manuelle Freigabe und anschließender persönlicher Profilzugriff. Zusätzlich Namenssuche, Communityfilter sowie öffentliche Ortsdetails mit bevorstehenden, vergangenen und abgesagten Events. Die mobile Darstellung wurde bei 375 Pixel Breite visuell geprüft; Formularbeschriftungen und Navigation sind im Accessibility-Baum vorhanden. Das ist eine gezielte Browser-/Barrierefreiheitsprüfung, keine vollständige WCAG- oder Screenreader-Abnahme.

Browsernachweise mit ausschließlich synthetischen Daten:

- [Öffentliche Veranstalterliste, finaler Build](screenshots/flutter-organizers-final.png)
- [Öffentliche Ortsliste, finaler Build](screenshots/flutter-venues-final.png)
- [Veranstalter, Desktop](screenshots/flutter-organizers-desktop.png)
- [Veranstaltungsorte, Desktop](screenshots/flutter-venues-desktop.png)
- [Persönlich freigegebenes Profil](screenshots/flutter-organizer-approved.png)
- [Öffentliche Eventhistorie am Ort](screenshots/flutter-venue-history.png)
- [Eventhistorie, mobil](screenshots/flutter-venue-history-mobile.png)
- [Veranstalter, mobil](screenshots/flutter-organizers-mobile.png)

Zum Abschluss wurden Backend und Web-Build mit einem frischen, getrennten Demobestand erneut geöffnet und beide öffentlichen Verzeichnisse im Browser bestätigt. Die vorherigen Prüfbestände bleiben erhalten. Die lokale Vorschau läuft auf `http://127.0.0.1:8300/`, ihr Backend auf `http://127.0.0.1:8000/`. Browser-Testgrößen wurden zurückgesetzt und temporäre Diagnose-Tabs geschlossen.

Nicht ausgeführt: privater Mailbetrieb mit echten Konten, Laravel-Archiv, unveränderte ältere `app/`-Demo, Supabase, native Builds und Runner-/Produktabnahme. Diese Umgebungen gehören nicht zum lokalen Flutter-/Better-Auth-Verzeichnisumfang. Frühere Nachweise gelten nicht als Nachweis dieser Neuimplementierung. Keine Veröffentlichung, kein Commit oder Push.

## Sichtbarkeitskorrektur vom 02.10.2026

Die Ankündigung persönlicher Profile, das entsprechende Anmeldeversprechen und Sichtbarkeitsabzeichen wurden entfernt. Der Zugangseinstieg ist im allgemeinen Verzeichnis nur angemeldet verfügbar. Direkte anonyme private Profil- und Zugangseinträge antworten ohne Metadaten mit 404. Der bestehende manuelle Aufnahmeablauf bleibt nach Anmeldung über einen ausdrücklich geteilten Einstieg möglich.

Geschützte Reihen und Events sind im lokalen synthetischen Verzeichnismodul angebunden. Die Nutzerentscheidungen vom 02.10.2026 sind umgesetzt: getrennte Gästekreise für Profil, Reihe und Event; eine Reihenfreigabe umfasst auch zukünftige veröffentlichte Events. Die Gastgeberverwaltung bietet **Reihen, Events und Gästekreise verwalten**. Der verantwortliche Profilinhaber kann Reihen und Events anlegen, bearbeiten und bestätigte Gastkonten gezielt freigeben, Freigaben entziehen und erneut erteilen. Ein fremder Gastgeber derselben Community kann diese Profilinhalte nicht ändern.

Programm und Reihenseiten zeigen ausschließlich bereits serverseitig erlaubte Inhalte, mit jeweils 20 Reihen/Events pro Seite. Ausgeblendete Inhalte erzeugen keine Platzhalter, Hinweise oder Zähler. Einzelne Eventfreigaben geben weder Reihennamen noch Reihen-ID frei, wenn die Reihe selbst verborgen ist. Ein Entzug sperrt den betreffenden Zugriff bei neuen Abrufen; andere ausdrücklich erteilte Einzelfreigaben bleiben bestehen. Entwürfe bleiben für Gäste ausgeschlossen. Bereits angezeigte Informationen lassen sich durch einen Entzug nicht rückwirkend aus dem Wissen eines Gastes entfernen. Beginne und Ortsangaben werden nur bei gesetzten Anzeigefeldern ausgegeben; dies ersetzt keine spätere geschützte Location nach bestätigter Teilnahme.

Das Schema wird nur im synthetischen lokalen Modus additiv erweitert. Bestehende Events werden keinem Gastgeberprofil oder einer Reihe automatisch zugeordnet und erhalten keine Gastfreigaben. Einmalige neue Rollen bleiben reine Demo-Fixtures. Neue API-Routen, Modellregeln und Grenzen: [ADR 0006](decisions/0006-scoped-program-visibility.md).


### Prüfnachweis vom 02.10.2026 und paralleler Zwischenstand

Der zuerst geprüfte Stand der Sichtbarkeitskorrektur bestand folgende lokale Prüfungen mit ausschließlich synthetischen Daten:

- Dart-Formatierung: 35 Dateien, keine weiteren Änderungen erforderlich.
- `flutter analyze --no-pub`: keine Befunde.
- `flutter test --no-pub --reporter expanded`: 67 Tests bestanden, keine übersprungen. Neue Fälle prüfen getrennte Programmfreigaben, Entzug/erneute Freigabe, private Voreinstellungen, Pagination und Darstellung bei 320/375 Pixel mit verdoppelter Textgröße.
- `flutter build web --no-pub`: bestanden; bestehende Cupertino-Icon-Fontwarnung, kein Wasm-Build.
- `python3 -I scripts/local_auth.py --test-directory`: 23 Tests bestanden. Dazu gehören direkte URL-Aufrufe, verborgene Reihen-/Ortsinformationen, getrennte Profilrechte, zukünftige Reihentermine, Entwürfe, einzelne Eventrechte, Entzug, Versionskonflikte, aktuelle Gastgeberrechte und wiederholte additive Schemaausführung.
- `node --test server/http.test.mjs server/dashboard_gateway.test.mjs server/account_mail.test.mjs`: fünf Tests bestanden; kein externer Versand.
- Der zusätzliche bestehende Auth-Regressionslauf (`--test`) scheiterte bereits beim Start mit `EADDRINUSE` auf Port 8000; seine Einzelprüfungen wurden dabei nicht ausgeführt. Die laufende Vorschau wurde erhalten. Die automatische Freigabeprüfung lehnte ihr kurzfristiges Stoppen wegen der Vorgabe zum Weiterlaufen ab; eine Nutzerentscheidung für Stoppen/Testen/Neustarten steht aus.

Im Browser des gebauten Standes auf `127.0.0.1:8300` tatsächlich geprüft: anonyme Veranstalterliste ohne persönliche Sichtbarkeitsabzeichen oder Zugangswerbung; öffentliches Profil ohne die geschützte Demo-Reihe; synthetische Gastgeberanmeldung und Reihenfreigabe; separate Gastanmeldung mit sichtbarer Reihe und Event; Entzug und anschließender gesperrter Reihenabruf; Profilaktualisierung ohne zuvor erlaubte Reihen-/Eventeinträge; öffentliches Ortsverzeichnis ohne den Ort dieser Reihe. Beschriftungen und Navigation wurden über den Accessibility-Baum benutzt. Eine vollständige Screenreader-/WCAG-Abnahme ist damit nicht erbracht.

Browsernachweise:

- [Öffentliche Veranstalterliste ohne persönliche Profilankündigung](screenshots/scoped-profile-public-list.png)
- [Anonym sichtbares Programm](screenshots/scoped-program-anonymous.png)
- [Gastgeberverwaltung mit einer getrennten Reihenfreigabe](screenshots/scoped-program-host-grant.png)

**Zusätzliche parallele Quellenänderungen:** Bei der Abschlussprüfung wurden anschließend Erweiterungen für mehrere Veranstalterprofile, Merkliste, Vorschau und zusätzliche Eventfelder in denselben Backend-Dateien festgestellt. Diese wurden in diesem Auftrag nicht überschrieben oder als geprüfter Bestandteil ausgegeben. Die wiederholte Flutter-Analyse bestand. Der erneut ausgeführte Verzeichnistest meldete 21 bestandene Tests und zwei Fehlerzählungen (ein fehlgeschlagener Einzelfall einschließlich übergeordnetem Test): Ein ausdrücklich öffentliches, älteres Event ohne Profilzuordnung erzeugt im nun geänderten Stand keinen erwarteten öffentlichen Ort mehr. Der zuvor bestandene Nachweis ist deshalb **kein grüner Gesamtnachweis dieser parallelen Erweiterung**. Vor gemeinsamer Korrektur ist die Zuständigkeit mit dem Nutzer zu klären. Der laufende Backend-Prozess und Browserbuild verwenden weiterhin den zuvor gestarteten Prüfstand.

Keine Installation, Remote-Migration, Veröffentlichung, E-Mail-Zustellung, Commit oder Push. Der private Mailmodus, Supabase, die ältere `app/`-Demo, native Builds und der Runner wurden in diesem Auftrag nicht ausgeführt.

## Erweiterung vom 02.10.2026: Profilverwaltung und Veranstalterfunktionen

Die Einzelprofilgrenze, die öffentlichen Eventfilter und die Verwaltung wurden mit dem Nutzerauftrag erweitert. Die vorherigen Abschnitte dokumentieren den jeweiligen damaligen Stand; maßgeblich für mehrere Profile, Vorschau, Merkliste und Zugänglichkeits-/Awarenessangaben ist [Veranstalterfunktionen](organizer-features.md). Zugeordnete öffentliche Event-/Ortsangaben benötigen ein öffentliches zuständiges Profil. Die nachfolgende Korrektur erhält zusätzlich die bisherigen öffentlichen Ortsangaben bereits freigegebener Altbestands-Events ohne Profil- und Reihenzuordnung. Die Reihenfreigabe umfasst zukünftige Termine und bleibt von Profilzugang und Teilnahme getrennt.


## Abschluss der Altbestands-Regression und Auth-Prüfung – 02.10.2026

Der Nutzer hat den zusätzlichen Auth-Test sowie die Verhinderung der Regression älterer öffentlicher Events ausdrücklich beauftragt. Damit ist die zuvor offene Zuständigkeit für diese begrenzte Korrektur geklärt. Die vorherigen Angaben zu blockierten Tests beschreiben historische Zwischenstände.

`server/catalog.mjs` erhält die öffentliche Ortsdarstellung bereits öffentlicher Events ohne Profil- **und** Reihenzuordnung: öffentliche Community, vorhandene aktuelle Gastgeberzuständigkeit, veröffentlichtes/abgesagtes Event und ausdrücklich freigegebene Ortsangabe bleiben erforderlich. Sobald ein Event einem Profil zugeordnet ist, gelten weiterhin die Öffentlichkeit dieses Profils und der gegebenenfalls zugehörigen Reihe. Diese Korrektur erzeugt keine Zuordnungen oder Freigaben. Alte Events werden dadurch auch keinem Veranstalterprogramm zugeschrieben.

Tatsächlich erneut ausgeführt und bestanden, ausschließlich lokal und synthetisch:

- `python3 -I scripts/local_auth.py --test-directory`: **27 Tests bestanden**, keine übersprungen. Der Altbestand bleibt nach erneuter Schemaausführung erhalten und im Ortsverzeichnis samt Ortsdetail sichtbar. Die zusätzlichen Negativfälle prüfen private Events/Communities/Profile, Entwürfe, verborgene Ortsangaben, vorhandene Reihen und entzogenes Gastgeberrecht. Bestehende Mehrprofil-, Vorschau-, Merkliste-, Freigabe- und Konkurrenzprüfungen sind enthalten.
- `python3 -I scripts/local_auth.py --test`: **10 Auth-Tests bestanden**, keine übersprungen. Geprüft werden unter anderem bestätigte Anmeldung, konkurrierende Registrierung/Verifikation, Abmeldung und Sitzungswiderruf, Passwortreset, Ratenbegrenzung und Herkunfts-/Dashboardgrenzen.
- `node --test server/http.test.mjs server/dashboard_gateway.test.mjs server/account_mail.test.mjs`: **fünf Tests bestanden**, kein Versand oder externer Dashboardaufruf.
- JavaScript-Syntax, aufgabenbezogener Diff und `git diff --check`: geprüft. Dokumentlinks werden separat kontrolliert.

Ein erster Auth-Versuch dieses Folgeauftrags wurde durch eine parallel neu gestartete Vorschau mit `EADDRINUSE` blockiert und gilt nicht als bestanden. Nach Identifikation und autorisiertem Stoppen dieses Prozesses lief der oben genannte Auth-Test erfolgreich. Anschließend wurde die Backend-Vorschau mit dem korrigierten Stand auf Port 8000 wieder gestartet; der Webserver auf Port 8300 blieb erhalten. Der Demoneustart nutzt einen eigenen frischen synthetischen Bestand. Vorherige Datenbestände wurden nicht gelöscht oder überschrieben.

Keine Flutter-Quellen oder API-Formate geändert; Flutter-Tests und Web-Build wurden für diese reine Backend-Korrektur nicht wiederholt. Keine Aussage über den aktuellen Gesamtstand weiterer paralleler UI-Erweiterungen. Keine Installation, Veröffentlichung, Remote-Migration, E-Mail-Zustellung, Commit oder Push. Keine Produkt-/Produktionsabnahme und keine Änderung am Runner-Kontrollstand.

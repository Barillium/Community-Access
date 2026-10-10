# Mehrere Veranstalterprofile, Vorschau, Merkliste und Eventinformationen

> Einordnung für V1 · 10.10.2026: Dieser datierte Detailbericht beschreibt den damaligen Implementierungsstand einschließlich des erhaltenen erweiterten Modus. Maßgebliche Produktregeln und Umfang stehen ausschließlich in der [Produktspezifikation](product-spec.md); aktuelle Start- und Prüfbefehle im [Setup](setup.md). Historische Statusangaben und Prüfergebnisse sind keine heutige Funktions- oder Betriebsfreigabe.

Stand: 02.10.2026. Manuelle lokale Umsetzung des Nutzerauftrags; ausschließlich synthetische Daten. Keine Veröffentlichung oder Produktabnahme.

Ergänzung vom 08.10.2026: Mehrere bestätigte Konten können denselben Auftritt nach Einladung und ausdrücklicher Annahme gemeinsam verwalten. Das verantwortliche Konto verwaltet Einladungen, Entzug und Zahlungszuordnung; Communitymoderation bleibt getrennt. [Bedienung, Rechte und tatsächlich ausgeführte Prüfungen](implementation/collaboration.md).

## Umfang und Bedienung

Im **Gastkonto → Gastgeberverwaltung** verwaltet ein Gastgeberkonto mehrere eigenständige Veranstalterprofile. Die Auswahl lädt den gespeicherten Stand des betreffenden Profils; **Weiteres Veranstalterprofil anlegen** öffnet einen neuen privaten Entwurf. Erst dessen Speicherung erlaubt die Event-/Reihenanlage. Profile behalten eigene Communityzuordnungen, Formulare, Anträge, persönliche Links, Reihen, Events und Gästekreise. Vorhandene Daten werden nicht auf ein anderes Profil übertragen.

Öffentliche Events und Reihen benötigen ein öffentliches Veranstalterprofil. Ein privates Profil kann öffentlich gestellt oder durch ein zusätzliches öffentliches Profil unter demselben Konto ergänzt werden. Der Server prüft das bei Anlage/Bearbeitung und bei öffentlichen Abrufen. Wird ein Profil privat gestellt, verschwinden seine zugeordneten Inhalte aus öffentlichen Listen und Ortsangaben; die vorhandenen Markierungen und individuellen Freigaben bleiben gespeichert. Die parallel ausdrücklich beauftragte Altbestandskorrektur bleibt erhalten: Bereits öffentliche Events ohne Profil- und Reihenzuordnung behalten bei öffentlicher Community und aktueller Gastgeberzuständigkeit ihre ausdrücklich freigegebene Ortsdarstellung. Daraus entstehen keine Profilzuordnung oder persönlichen Rechte.

**Wer sieht was?** ist je gespeichertem Event in der Gastgeberverwaltung und Programmverwaltung erreichbar. Die Vorschau zeigt die hypothetischen Ansichten ohne Anmeldung, mit bloßem Profilzugang, mit Profil-/Reihenfreigabe sowie mit Profil-/Einzeleventfreigabe. Sie verwendet dieselbe serverseitige Sichtbarkeitspolitik und Feldfreigaben wie echte Abrufe. Sie erteilt keine Rechte und übernimmt keine fremde Sitzung. Die Auswahl **Eventfreigabe und bestätigte Teilnahme** benennt die bestehende Grenze: Teilnahmezusagen und geschützte genaue Adressen sind im aktuellen Better-Auth-Teilumfang noch nicht angebunden. Diese Auswahl zeigt deshalb keine geschützte genaue Adresse und beweist keine funktionierende Teilnahmeprüfung. Eine Reihenfreigabe gilt ausdrücklich auch für künftig veröffentlichte Termine, bleibt jedoch von Profilzugang und Zusage getrennt.

Angemeldete Konten können sichtbare Profile mit **Veranstalter merken** und sichtbare Reihen auf deren Detailseite mit **Reihe merken** speichern. Schreib- und Leselistenaufrufe verlangen ein Konto mit bestätigter E-Mail. **Gastkonto → Meine Merkliste** öffnet die eigene gespeicherte Auswahl. Wiederholtes Speichern erzeugt keinen zweiten Eintrag; Entfernen setzt ausdrücklich den ungemerkten Zustand. Die Liste prüft die aktuelle Berechtigung erneut. Entzogene Inhalte liefern keine Platzhalter, Namen oder Zähler. Merken begründet weder Freigabe, Mitgliedschaft noch Eventteilnahme und löst keinen Versand aus.

Im Eventeditor stehen **Stufenloser Zugang**, **Barrierearmes WC**, **Sitzmöglichkeiten** und **Rückzugsraum** mit Ja/Nein/Unbekannt zur Verfügung. Unbekannt ist der Ausgangswert, keine Bewertung. Hinzu kommen optionale Hinweise zur Zugänglichkeit, Awareness vor Ort und ein ausdrücklich freigegebener Awarenesskontakt. Die Eventdetailseite und Vorschau zeigen sie als Veranstalterangaben. Sie erscheinen nur innerhalb eines aktuell sichtbaren Events. Geschützte genaue Adressen und persönliche Notizen gehören nicht in diese Texte oder die ausdrücklich angezeigte Ortsangabe. Es gibt keine automatische Bewertung oder Zertifizierung.

## Architektur und bestehende Arbeit

Gelesene Anweisungsquellen: Nutzerregeln und Projekt-`AGENTS.md`, `docs/product-spec.md`, `docs/setup.md`, `docs/workflow.md`, `docs/codex-workflow.md` und ADR 0006. Im geprüften Repository gibt es keine zusätzliche untergeordnete AGENTS.md. Der vorgefundene Checkout enthielt umfangreiche uncommittete Arbeit; der Quellstand wurde vor Änderungen unter `/private/tmp/community-access-features-before/` gesichert. Es wurde zunächst `codex/organizer-preview-bookmarks-accessibility` angelegt. Der parallel beauftragte Backend-Folgeauftrag wechselte später denselben Checkout auf `codex/legacy-public-events-auth-regression`. Branches trennen uncommittete Arbeiten im gemeinsam verwendeten Checkout nicht. Die zusätzlichen Backend-/Dokumentationskorrekturen wurden erhalten und im abschließenden gemeinsamen Verzeichnislauf geprüft. Keine Dateien gestagt und kein Commit oder Push.

`server/directory.sql` hebt die bisherige Eindeutigkeit von `ca_organizer.owner_id` auf, ergänzt einen Eigentümerindex, `ca_bookmark` und `ca_event.access_details`. Die Änderung wird ausschließlich im durch den vorhandenen Runner geprüften lokalen synthetischen Bestand ausgeführt. Profil-IDs und bestehende Verknüpfungen bleiben erhalten. Bei mehreren Profilen verlangen neue Schreibaufrufe eine eindeutige Auswahl; Bearbeitungen tragen zusätzlich die bestehende Versionsprüfung. Merkliste und Vorschau verwenden aktuelle Rechte. Merklisten speichern Referenzen statt Kopien privater Titel; eindeutige Teilindizes verhindern Duplikate bei Konkurrenz.

Neue API-Wege: `GET /api/directory/manage?profile_id=…`, `POST /api/directory/manage/preview`, `GET /api/directory/bookmarks` und `POST /api/directory/bookmark`. Profilanlage verwendet ausdrücklich `create=true`; Bearbeitung die Profil-ID. Event-/Reihenanlage und Linkerstellung tragen das ausgewählte Profil. Ein gewöhnliches Gastkonto erhält keine Gastgeberrechte. Der private Mailmodus lädt das Verzeichnismodul weiterhin nicht; seine neuen Routen bleiben geschlossen.

Betroffene Quellen: `server/directory.sql`, `server/directory.mjs`, `server/catalog.mjs`, `server/http.mjs`, `server/directory.test.mjs`; unter `client/lib/` die Profil-/Programmverwaltung, Profil-/Programmansichten, Kontoanbindung, API-Fehlermeldungen und die neuen Dateien `bookmark_views.dart`, `visibility_preview_page.dart`, `event_access_details.dart`; `client/test/organizer_features_test.dart` und die Profilnamenbeschriftung im bestehenden Verzeichnis-Widgettest. Produktspezifikation und ADR 0006 dokumentieren die Rechteänderungen. Die Runner-Kontrolllogik und geschützten `app/`-Prüfungen wurden nicht verändert.

## Tatsächlich ausgeführte Prüfungen

- Dart-Formatierung der elf betroffenen Dart-Dateien: bestanden. Die abschließende Formatierung änderte nur die Darstellung zweier zuletzt korrigierter Dateien.
- `flutter analyze --no-pub`: bestanden, keine Befunde.
- `flutter test --no-pub --reporter expanded`: **74 Tests bestanden**. Die sieben neuen Fälle prüfen Profilauswahl/neuen Entwurf, explizites Merken, Entzug aus der sichtbaren Liste, Reihenmerkliste auf der Detailseite, Vorschau, Ausstattungs-/Awarenessangaben und 320-/375-Pixel-Darstellung mit verdoppelter Textgröße. Der zunächst festgestellte Überlauf der Statusauswahl wurde korrigiert.
- `flutter build web --no-pub --pwa-strategy=none`: bestanden. Flutter meldete die bestehende Cupertino-Icon-Fontwarnung und die Abkündigung des PWA-Parameters. Kein nativer oder separater Wasm-Build.
- `python3 -I scripts/local_auth.py --test-directory`: zunächst 26 bestandene Tests; nach Integration der parallel beauftragten Altbestandskorrektur **27 Tests bestanden**, keine übersprungen. Geprüft sind unter anderem fremde Profile, mehrdeutige Profilauswahl, getrennte Kataloge/Links, Privatstellung, Versionskonflikte, Reihenvererbung, Feldfreigaben, Vorschau ohne Rechtevergabe, Merkliste je Konto, wiederholtes/gleichzeitiges Speichern, erneute Schemaausführung und aktuelle Zugangs-/Gastgeberrechte.
- `python3 -I scripts/local_auth.py --test`: **10 Auth-Tests bestanden**, keine übersprungen. Ein erster Versuch scheiterte am belegten festen Testport und gilt nicht als Erfolg. Der erfolgreiche Lauf erfolgte nach geordnetem Stoppen der identifizierten synthetischen Vorschau; der vorherige Datenbestand wurde erhalten.
- `node --test server/http.test.mjs server/dashboard_gateway.test.mjs server/account_mail.test.mjs`: **fünf Tests bestanden**. Kein echter Versand oder externer Dashboardaufruf. Frühere Socketbeschränkungen wurden durch die erlaubte lokale Ausführung überwunden, nicht als Testfehler im Produkt ausgegeben.
- JavaScript-Syntax, aufgabenbezogener vollständiger Quellvergleich, lokale Dokumentationslinks und `git diff --check`: bestanden.

Im gebauten Browser auf `127.0.0.1:8300` tatsächlich geprüft: synthetische Gastgeberanmeldung, Anlage und Speicherung eines zweiten öffentlichen Profils im selben Konto, profilbezogene Eventanlage, Speicherung konkreter Zugänglichkeit und Awarenessangaben, anonyme Eventvorschau samt Feldfreigaben und Hinweis auf fehlenden Teilnahme-/Adressanschluss, Veranstalter merken, gespeicherter Eintrag nach erneuter Anmeldung und Entfernen mit anschließendem Leerzustand. Browsernavigation und Felder wurden über den Accessibility-Baum und die sichtbare Oberfläche bedient. Reihenmerkliste, private Negativfälle und Konkurrenz sind durch Backend-/Widgetprüfungen belegt, nicht als zusätzliche Browserwege behauptet. Die Prüfung mit verdoppelter Schrift ist ein Widgetnachweis; keine vollständige WCAG-/Screenreader-Abnahme.

Browsernachweise mit synthetischen Inhalten:

- [Gespeicherte Eventvorschau mit Zugänglichkeit und Awareness](screenshots/organizer-features-preview.jpg)
- [Kontobezogene Merkliste nach erneuter Anmeldung](screenshots/organizer-features-bookmarks.jpg)

Die vorhandene lokale Vorschau wurde erhalten beziehungsweise mit dem gemeinsamen neuen Backendstand wieder gestartet. Während der Prüfung fand ein paralleler Backend-Folgeauftrag statt; seine Neustarts erklären zwischenzeitliche Verbindungsfehler. Alle bisherigen synthetischen Bestände bleiben erhalten. Keine neuen externen Dienste, Abhängigkeiten, Remote-Migrationen oder Veröffentlichungen. Nicht ausgeführt: privater Mailbetrieb mit echten Konten, Supabase, ältere `app/`-Demo, native Builds, produktive Platzvergabe, geschützte genaue Adressen oder vollständige Produktabnahme.


## Folgeauftrag: öffentliche Interessen und einzelne Events

Der Nutzer hat am 02.10.2026 die Merkliste ausdrücklich als öffentlichen Interessenzähler beauftragt und einzelne Events zusätzlich bestätigt. Die persönliche Merkliste bleibt privat; bei öffentlichen Inhalten ist die aggregierte Anzahl sichtbar. Geschützte Inhalte erhalten keine öffentliche Anzahl. Die oben dokumentierten früheren Prüfungen bleiben historische Nachweise. [Aktueller Umfang und neue Prüfungen](public-interest-counts.md).


## Bedienverbesserungen vom 05.10.2026

Nutzerauftrag: Die im Gastgeberreview vorgeschlagenen Änderungen umsetzen. Die bestehende Gestaltung und Rechtepolitik bleiben Grundlage. Eigener Aufgabenbranch `codex/host-event-editor`; vorhandene uncommittete Arbeiten wurden erhalten.

### Eventeditor

Der Editor ist in **Grunddaten und Termin**, **Sichtbarkeit und Gästezugang**, **Inhalte** sowie **Zugänglichkeit und Awareness** gegliedert. Sprungaktionen erleichtern die Navigation im langen Formular. Beginn und Ende stehen zusammen. Datum wird als `TT.MM.JJJJ`, Uhrzeit als `HH:MM` eingegeben oder per Kalender/Zeitauswahl gewählt. Die Zeitzone des Geräts und der für den gewählten Termin geltende UTC-Abstand werden angezeigt; die API erhält einen UTC-Zeitpunkt. Ungültige Kalenderdaten und durch Zeitumstellung übersprungene lokale Uhrzeiten werden verworfen. Bei doppelt vorkommenden Herbst-Uhrzeiten gilt die vom Gerät gewählte Zuordnung; der UTC-Abstand ist vor dem Speichern sichtbar. Für Events in einer anderen Zeitzone muss die passende Gerätezeitzone verwendet werden; eine separate Veranstaltungszeitzonenauswahl ist nicht enthalten.

Pflichtfelder, fehlende Veröffentlichungsvoraussetzungen, Ende vor Beginn, ungültige Kapazität, Formularauswahl, Line-up-/Genregrenzen, Mindestalter und Flyerbeschreibung werden vor dem API-Aufruf am zugehörigen Feld erklärt. Die Seite springt zum ersten betroffenen Feld beziehungsweise Inhaltsabschnitt. Der Server bleibt die maßgebliche Berechtigungs- und Datenprüfung. Im Entwurf ist die Endzeit optional; für veröffentlichte und abgesagte Events ist sie erforderlich. Die erste Veröffentlichung erfordert eine zusätzliche Bestätigung mit Sichtbarkeitsfolgen.

### Ungespeicherte Arbeit

Änderungen werden automatisch **nur im Arbeitsspeicher der aktuellen Anmeldung** behalten. Es gibt keine automatische Speicherung auf dem Server und keinen Browser-Speicher mit geschützter Location oder Texten. Beim Verlassen kann der Gastgeber weiterarbeiten, den Entwurf verwerfen oder für die laufende Anmeldung behalten. Erneutes Öffnen des gleichen Events/Profils stellt diesen Entwurf wieder her. „Eventangaben speichern“ sichert ihn ausdrücklich auf dem Server; Erfolg entfernt die lokale Kopie. Kontowechsel, Abmeldung, Sitzungsablauf, Passwortreset und Schließen des API-Clients leeren die lokalen Entwürfe. Ein noch geöffneter Editor wird dann geleert und kann nichts mehr speichern. Ein wiederhergestellter älterer Bearbeitungsstand behält seine alte Version; die vorhandene Server-Konfliktprüfung wird nicht umgangen.

Neuladen und Schließen verlieren den Arbeitsspeicher. Solange ungespeicherte Änderungen vorliegen, registriert der Webclient einen Browser-Verlassenshinweis; dessen tatsächliche Anzeige ist browserabhängig und erfordert üblicherweise vorherige Benutzerinteraktion. Die Oberfläche erklärt diese Grenze ausdrücklich. Für dauerhafte Entwürfe ist die bewusste Serverspeicherung erforderlich.

### Eventübersicht und Wiederverwendung

Gastgeber- und Programmverwaltung verwenden dieselbe durchsuchbare Übersicht mit Statusfilter, Termin, offenen Anfragen, bestätigten Zusagen und freien Plätzen. Die geschützte Managementantwort berechnet diese Zahlen für die eigenen Events mit aktueller Communityzuständigkeit. Nur Zusagen belegen Plätze; unbegrenzte Kapazität wird ausdrücklich benannt. Fehlende Zahlen werden als nicht verfügbar angezeigt, nicht als Null erfunden. Die Übersicht wird nach Bearbeitung beziehungsweise über die bestehenden Aktualisierungsaktionen neu geladen; sie ist kein Live-Abonnement.

**Event duplizieren** öffnet eine bearbeitbare Kopie als neuen Entwurf und leert Beginn, Ende sowie Anfrage-/Freigabefristen. **Folgetermin vorbereiten** bietet eine, zwei oder vier Wochen Abstand und verschiebt vorhandene Termine/Fristen um lokale Kalendertage bei gleicher Uhrzeit. Dafür muss ein Beginn vorhanden sein. Titel, Inhalts- und Zugangseinstellungen bleiben bearbeitbar. IDs, Versionen, Anfragen, Antworten, Zusagen, persönliche Freigaben und Interessenzähler werden nicht kopiert. Eine vorhandene Reihenzuordnung bleibt erhalten; deren bestehende Reihenfreigaben gelten entsprechend der bisherigen Produktregel auch für spätere veröffentlichte Termine. Es gibt keine automatische Veröffentlichung oder Hintergrundterminserie. Jeder Folgetermin wird separat geprüft und gespeichert.

Warteliste, zusätzliche Teamrechte, Kalenderexport und Benachrichtigungen sind nicht Teil dieses Auftragsblocks. Keine neuen Abhängigkeiten, Schemaänderungen, externen Dienste oder Veröffentlichungen. Die bestehenden Messenger bleiben der Kommunikationsweg.

[Tatsächliche Prüfungen und Grenzen](qa/host-event-editor-2026-10-05/report.md).

# Historische Entscheidungsnotizen bis 09.10.2026

Diese unveränderten inhaltlichen Notizen dokumentieren den bisherigen Ausbau. Sie sind keine zweite geltende Produktspezifikation und enthalten überholte Statusangaben. Maßgeblich sind ausschließlich [Produktspezifikation](../product-spec.md) und [V1-Entscheidung](../decisions/0007-v1-scope.md). Frühere Verweise stehen als historische Pfadangaben im Text.

---

# Community Access: Produktspezifikation

Stand: 09.10.2026 · Status: freigegebener Produktumfang; lokaler synthetischer Zugangsbereich implementiert, Gesamtprodukt nicht abgenommen

Technische Sicherheitsfortschreibung 05.10.2026: zusätzliche API-/Kontogrenzen, Parallelitäts-/Datenbankzeitlimits, gemeinsames Mailversandbudget, Header-/HTTPS-Schutz der öffentlichen Weiterleitung und datensparsame Sicherheitsmeldungen. Produktrollen und Freigabeabläufe bleiben erhalten. Umsetzung, Grenzen und Betriebsnachweise (`website-security.md`); dies ist keine Produktionsfreigabe.

Technikwechsel vom 01.10.2026: Der bisherige Laravel-Vergleichsprototyp wurde aus dem aktiven Projekt entfernt; seine Flutter-Gastoberfläche bleibt unter `client/` erhalten. Der lokale Auth-Teilumfang verwendet jetzt Better Auth in einem Node.js-Server mit PostgreSQL: Testkontoanlage, Anmeldung, E-Mail-Bestätigung, Passwortreset und Abmeldung sind angebunden und synthetisch geprüft. Der lesende Anschluss des Dashboard-Projekts „Community Access“ über einen freigegebenen temporären HTTPS-Tunnel ist nachgewiesen: Ein lokal angelegtes synthetisches Konto erschien in der Dashboard-Benutzerliste. Der synthetische Verzeichnisumfang für Veranstalter und öffentliche Orte ist nun separat angebunden; der lokale synthetische Zugangsbereich ist seit 05.10.2026 ergänzt; weitergehende Produkt- und Betriebsnachweise bleiben offen; siehe ADR 0005 (`decisions/0005-local-better-auth.md`). Die separate Flutter-Statusdemo und der bestehende lokale Supabase-Teilumfang bleiben erhalten; deren bisherige Prüfergebnisse sind kein Better-Auth-Nachweis. Die folgenden Produktanforderungen gelten unabhängig vom entfernten Prototyp weiter.

## 1. Problem, Ziel und Belegstand

Auth-Erweiterung vom 02.10.2026 auf Nutzerauftrag: Google, Apple und Facebook werden zusätzliche Anmeldemethoden. Anbieterlogin und Produktfreigaben bleiben getrennt; gleiche E-Mail-Adressen verbinden Konten nicht automatisch. Bestehende Konten können einen Anbieter nach bestätigter, frischer Anmeldung ausdrücklich verbinden. Web-Code und synthetische Prüfungen sind vom Aktivieren echter Anbieter-Apps zu unterscheiden; Einrichtung und Abnahmegrenze (`social-sign-in.md`).

Community Access soll bestehenden Aachener Veranstaltern ermöglichen, Bewerbungen, manuelle Aufnahme und Eventanfragen nachvollziehbar zu bearbeiten. Die Veranstalter verteilen Einladungen über ihre bestehenden Messenger; Community Access ergänzt diese um geregelten Zugang und ersetzt sie nicht.

Der geplante Pilot umfasst ausschließlich **The Base E.V.** und **Not Human Collective**. Diese Festlegung belegt keine Teilnahmezusage. In Entwicklung, Tests und KI-Kontext werden ausschließlich synthetische Veranstalter, Personen, Kontaktdaten, Orte und Bewerbungen verwendet. Die beiden Namen dienen hier nur der Beschreibung des Pilotumfangs.

| Kategorie | Aussage und Grundlage |
| --- | --- |
| Nutzervorgaben | Pilotumfang, zwei Produktrollen, zusätzliche Veranstalterbewerbung, manuelle Entscheidungen, veranstaltungsbezogene Altersselbstauskunft, Eigenbetrieb und Löschfrist wurden im Projektgespräch festgelegt. |
| Technische Zielvorgabe | Aktive Oberfläche: Flutter/Dart, Better Auth/Node.js und PostgreSQL; separate Supabase-Statusdemo bleibt erhalten. Open-Source-orientiert. Eine Lizenz für den eigenen Code ist damit noch nicht gewählt. |
| Dokumentierte Vorschläge | Der Entwicklungsplan beschreibt den Kernablauf, getrennte Berechtigungen und negative Zugriffstests; siehe Quellen unten. Das sind Planungsgrundlagen, keine Implementierungsnachweise. |
| Projektannahme | Ein gemeinsamer, klarer Statusablauf verringert Rückfragen und organisatorischen Aufwand. Dieser Nutzen ist noch nicht mit Gastgebern und Gästen überprüft. |
| Beobachteter Ist-Zustand | Der zunächst leere Projektordner enthält inzwischen den aktiven lokalen Flutter-/Better-Auth-Teilumfang, synthetische Zugangsabläufe und lokal geprüftes Ticketing. Diese Teilnachweise sind keine vollständige Produktabnahme. |

Erfolg bedeutet zunächst: Eine Person kann die Produktidee in zwei Sätzen erklären; der vollständige Ablauf ist verständlich; seine Berechtigungsgrenzen lassen sich später mit synthetischen Konten nachweisen. Es gibt noch keine belegte Zeitersparnis oder Sicherheitsgarantie.

## 2. Zwei Nutzerrollen und betriebliche Verantwortung

- **Gast:** erhält eine Einladung, bewirbt sich beim Veranstalter, sieht den eigenen Status und fragt nach Aufnahme eine Eventteilnahme an. Bewerber, Mitglied und bestätigter Eventgast sind unterschiedliche Zustände dieser Rolle.
- **Gastgeber:** vertritt ein Veranstalter, beantragt dessen Aufnahme und verwaltet nach Freigabe Einladungen, Gastbewerbungen und Eventanfragen seiner Community. Rechte gelten nur für die jeweils zugeordnete Community.

Betrieb und Beschwerden übernimmt vorerst das Projektteam selbst. Es prüft Veranstalterbewerbungen und entscheidet über die Veranstalteraufnahme. Das ist eine zusätzliche betriebliche Verantwortung, keine dritte Produktrolle für Gäste oder Gastgeber. Der lokale Verwaltungszugang wird durch separat serverseitig zugewiesene Teamrechte abgesichert; gewöhnliche Gastgeberrechte erlauben keine Veranstalterfreigabe oder Einsicht in fremde Bewerbungen.

## 3. Zwei manuelle Aufnahmeabläufe

### Veranstalteraufnahme durch das Projektteam

Pflichtfelder sind Name, Selbstdarstellung, Veranstaltungstypen sowie ausdrücklich beantwortete Ja-/Nein-Angaben zu Awarenesskonzept und Awarenessteam. Bisherige Events, Orte und Organisationsbeschreibung sind optional. Kontakt erfolgt über das bestätigte Konto. Mitgliederangaben werden nicht erhoben.

Das Projektteam prüft die Bewerbung manuell und nimmt sie an oder lehnt sie ab. Ein Rückzug durch das antragstellende Veranstalter ist möglich. Erst die Annahme eröffnet die Gastgeberverwaltung für diese Community. Annahme erzeugt atomar die Community, deren Gastgeberrechte und ein zunächst privates Veranstalterprofil. Rückzug erlaubt eine neue Bewerbung. Ablehnung erzeugt eine unabhängige Sperre, die ausschließlich das Team ausdrücklich aufheben kann. Das Formular ist fest definiert, kein frei konfigurierbarer Baukasten.

### Gastaufnahme und Eventbestätigung

**Persönliche Einladung → Bewerbung → manuelle Aufnahme → Eventanfrage → separate Bestätigung → geschützte Location**

Festlegung vom 05.10.2026: Einladungen sind an ein bestehendes bestätigtes Konto gebunden, sieben Tage gültig und widerrufbar. Gespeichert wird ausschließlich der Tokenhash. Erst eine erfolgreiche Bewerbung verbraucht die Einladung atomar; Vorschau und Validierungsfehler verbrauchen sie nicht. Fragenstand, Antworten und Entscheidungszeit gehören zur eigenen Communitybewerbung. Mitgliedschaft entsteht ausschließlich durch manuelle Annahme und ist unabhängig von Profilzugang.

Je Event entscheidet der Gastgeber, ob aktive Mitgliedschaft in der verantwortlichen Community erforderlich ist. Bestehende direkte Wege bleiben ohne diese Pflicht nutzbar. Kapazität ist eine positive ganze Zahl oder ausdrücklich unbegrenzt; nur aktuelle Zusagen belegen Plätze. Persönliche Eventsichtbarkeit ist keine Zusage. Mindestalter erfordert eine explizite Selbstauskunft; erforderliche Formularantworten müssen vorliegen. Offene Anfragen und Zusagen können vor Eventbeginn zurückgezogen und anschließend neu manuell angefragt werden. Ab Beginn sind neue Anfragen und Zusagen gesperrt.

Mitgliedschaftsentzug widerruft atomar offene Anfragen und Zusagen für mitgliedschaftspflichtige Events dieser Community. Direkte Events und unabhängige Profilrechte bleiben getrennt. Profilentzug sperrt abhängige private Abrufe; neue Eventfreigaben dürfen dies nicht umgehen. Teamseitiger Gastgeberentzug sperrt Verwaltung und die davon abhängigen Abrufe. Die genaue Location liegt separat und ist ausschließlich für aktuell zuständige Gastgeber oder aktuell bestätigte berechtigte Gäste abrufbar; bei semi-öffentlichen Events zusätzlich erst nach Freigabezeitpunkt.

Abgeschlossene Veranstalter- und Communitybewerbungen einschließlich Antworten werden nach zwei Kalendermonaten (Europe/Berlin, Monatsende begrenzt auf den letzten gültigen Tag) gelöscht. Laufende Bewerbungen bleiben. Mitgliedschaften und minimale Sperrmarkierungen bestehen unabhängig davon. Die Eventaufbewahrung beträgt exakt 168 Stunden nach dem tatsächlichen Veranstaltungsende, unabhängig von Sommer-/Winterzeit. Ab dieser Grenze sind Eventdaten, Locations und Teilnahmezuordnungen nicht mehr abrufbar; die physische Löschung erfolgt bei der nächsten Bereinigung (bei Start, Abrufen und minütlich). Bereits gelesene Informationen lassen sich nicht zurückholen. Implementierung und lokale Nachweise (`access-flow.md`).

1. **Einladung:** Der Gastgeber teilt einen kontrollierten Link über einen bestehenden Kanal. Der Link erlaubt den Bewerbungseinstieg, keine automatische Mitgliedschaft. Ein Konto mit Anmeldung ist die technische Voraussetzung für persönliche Anträge und Statusanzeigen.
2. **Bewerbung:** Der Gast sendet eine separate, kurze Bewerbung an das Veranstalter. Sie bleibt bis zur Entscheidung in Bearbeitung; ein Rückzug ist möglich. Die Gastgeber legen das Gastbewerbungsformular selbst fest und kennzeichnen erforderliche sowie optionale Antworten. Name, E-Mail und Passwort gehören separat zur Kontoanlage. Bereits eingereichte Bewerbungen behalten ihre ursprünglichen Fragen. Intime Profile und Fragen nach sexuellen Vorlieben sind ausgeschlossen. Nutzerentscheidung vom 04.10.2026: Nach freiwilligem Rückzug ist eine erneute Gastbewerbung mit gültiger Einladung möglich; sie wird wieder manuell entschieden. Nach Ablehnung bleibt eine erneute Bewerbung für diese Community gesperrt; stattdessen wird ein vom Gastgeber hinterlegter Kontaktweg angeboten. Entzogene Mitgliedschaften bleiben gesperrt. Diese Änderung betrifft Communitybewerbungen, nicht den gesonderten Profilzugang.
3. **Manuelle Aufnahme:** Ein berechtigter Gastgeber nimmt an oder lehnt ab. Nur die Annahme begründet eine Mitgliedschaft in dieser Community. Der Gast kann sich nicht selbst annehmen. Mitgliedschaft ist weder Identitätsprüfung noch Sicherheitsbescheinigung.
4. **Eventanfrage:** Ein aktives Mitglied fragt die Teilnahme an einem Event an. Mitgliedschaft allein reserviert keinen Platz. Der Veranstalter legt je Event das Mindestalter selbst fest; gesetzliche Jugendschutzvorgaben und behördliche Auflagen können dadurch nicht aufgehoben werden. Nutzerentscheidung vom 04.10.2026: Veranstalter werden bei der Altersangabe auf Jugendschutz hingewiesen, einschließlich nötiger Begleitung und Einlasszeiten. Der Gast bestätigt bei der Eventanfrage, die geltenden Altersvoraussetzungen zu erfüllen. Das ist eine Selbstauskunft ohne Ausweis-Upload und keine verifizierte Altersprüfung. Tatsächliche Zugangsvoraussetzungen setzen die Veranstalter durch.
5. **Bestätigung:** Der zuständige Gastgeber entscheidet separat über die Eventanfrage. Erst bestätigte Gäste mit aktueller Berechtigung erhalten die dafür vorgesehenen genauen Veranstaltungsinformationen. Eine Ablehnung erzeugt keinen Teilnahmeanspruch.

Private Eventinformationen sind nach aktueller Community- und Eventberechtigung zugänglich. Genaue Locations werden getrennt geschützt: berechtigte Gastgeber und aktuell bestätigte Gäste dürfen sie abrufen. Ein Entzug verhindert neue unberechtigte Abrufe; bereits gelesene Informationen lassen sich nicht zurückholen.

### Gastgeberbedienung und Evententwürfe

Ergänzung auf Nutzerauftrag vom 05.10.2026: Die Eventanlage bietet gegliederte Abschnitte, lokale Datum-/Uhrzeitauswahl, feldbezogene Prüfung und eine Bestätigung vor der ersten Veröffentlichung. Ungespeicherte Angaben dürfen ausschließlich während der laufenden Anmeldung im Arbeitsspeicher wiederaufgenommen werden; dauerhafte Speicherung erfolgt bewusst. Abmeldung, Kontowechsel und Sitzungsablauf entfernen lokale Entwürfe. Eine Wiederaufnahme darf keine neueren Serverversionen überschreiben.

Eigene Events sind nach Titel und Status filterbar; offene Anfragen, Zusagen und freie Plätze bleiben getrennt. Eventkopien und Folgetermine nach einer, zwei oder vier Wochen starten als neue Entwürfe. Einzelrechte, Anfragen und Zusagen werden nicht kopiert. Eine erhaltene Reihenzuordnung folgt weiterhin der bestehenden Freigabevererbung. Jeder Termin wird separat geprüft und gespeichert; keine automatische Veröffentlichung. Bedienung, Zeitzonen- und Speichergrenzen (`organizer-features.md#bedienverbesserungen-vom-05102026`).

### Öffentlicher Einstieg

Ergänzende Nutzerentscheidung vom 30.09.2026: Öffentliche Events und Communities sowie Informationen zu Community Access sind ohne Anmeldung zugänglich. Gastgeber geben Profile und Events ausdrücklich frei und wählen die öffentlichen Eventangaben. Eine separate öffentliche Ortsangabe kann freigegeben werden; die geschützte Location wird nicht automatisch veröffentlicht. Öffentliche Sichtbarkeit begründet keine Mitgliedschaft oder Eventzusage.

### Veranstalterprofile und Veranstaltungsorte

Die Eventstartseite zeigt **Alle bevorstehenden Events**: aktuell öffentliche, nicht abgesagte Veranstaltungen mit freigegebenem Beginn ab dem aktuellen Zeitpunkt, zeitlich aufsteigend. Das Suchfeld findet diese Events anhand des Titels, öffentlicher zuständiger Veranstalterprofile oder freigegebener öffentlicher Ortsangaben. Die bestehende Suche über öffentliche Communities und Genres bleibt erhalten. Nicht freigegebene Profil- und Ortsangaben dürfen keine Treffer auslösen. Die übergeordneten Communityfilter werden je umgebrochener Zeile horizontal zentriert.

Ergänzende Nutzerentscheidung vom 30.09.2026: Die Navigation erhält die Seiten **Veranstalter** und **Veranstaltungsorte**. Das Veranstalterverzeichnis zeigt öffentlich freigegebene sowie dem angemeldeten Konto persönlich zugängliche Gastgeberprofile. Suche nach Anzeigenamen und Filter nach Communities werden angeboten.

Nutzerentscheidung vom 02.10.2026: Die öffentliche Oberfläche kündigt persönlich freigegebene Profile nicht an und kennzeichnet diese nicht. Ein nicht öffentliches Profil erscheint nur für ein angemeldetes, dafür freigegebenes Konto (oder den zuständigen Gastgeber). Ohne Anmeldung bleiben auch bei bekannter Profil-ID Name und Formular verborgen. Öffentliche Gastgeberprofile sollen ausgewählte Veranstaltungsreihen und einzelne Events ausschließlich dem dafür freigegebenen Gästekreis zeigen können. Ausgeblendete Inhalte dürfen weder Titel, Zähler, Treffer noch Ortsangaben öffentlich verraten. Eine Reihenfreigabe umfasst alle veröffentlichten und zukünftigen Events dieser Reihe. Profilfreigaben, Reihenfreigaben und einzelne Eventfreigaben bleiben getrennt. Eine einzelne Eventfreigabe verrät weder eine geschützte zugehörige Reihe noch deren andere Termine. Freigaben regeln ausschließlich Sichtbarkeit; Communitymitgliedschaft und Eventteilnahme werden weiterhin separat entschieden. Der lokale synthetische Anschluss ist in ADR 0006 (`decisions/0006-scoped-program-visibility.md`) beschrieben.

Ein Gastgeberkonto verwaltet **mehrere voneinander getrennte Veranstalterprofile**, jeweils mit mehreren zugeordneten Communities. Er bestimmt dessen Öffentlichkeit und kann Bewerbung, persönlichen Link und ein selbst festgelegtes Formular als Zugangswege anbieten. Bewerbung und Formular erfordern **manuelle Freigabe durch den Gastgeber**. Persönlicher Profilzugriff begründet keine Communitymitgliedschaft, Eventteilnahme oder Berechtigung für geschützte Locations. Private Communitynamen werden durch eine Profilfreigabe nicht automatisch öffentlich.

Das Ortsverzeichnis zeigt ausdrücklich öffentliche Ortsangaben zu veröffentlichten kommenden und vergangenen Events. Verborgene Eventangaben und geschützte Locations werden nicht automatisch übernommen. Im bisherigen Vergleichsprototyp wurden identische öffentliche Ortsangaben zusammengefasst; eine eigenständige Verwaltung strukturierter Veranstaltungsorte war damit noch nicht verbunden. Die neue Flutter-Anbindung verwendet ebenfalls ausdrücklich öffentliche Textangaben aus dem lokalen Eventkatalog. Aktuelle Umsetzung, Grenzen und Prüfungen (`organizers-venues-flutter.md`).

### Mehrere Profile, Vorschau, Merkliste und Veranstaltungsinformationen

Nutzerauftrag vom 02.10.2026: Ein privates Veranstalterprofil kann keine öffentlichen Events oder öffentlichen Reihen anbieten. Dafür muss es öffentlich gestellt oder unter demselben Gastgeberkonto ein weiteres öffentliches Profil angelegt werden. Jedes Profil hält eigene Communityzuordnungen, Zugangsformulare, Anträge, persönliche Links, Reihen, Events und Freigaben. Ein Wechsel des ausgewählten Profils überträgt keine dieser Rechte oder Daten. Wird ein öffentliches Profil privat gestellt, verschwinden seine bisher öffentlichen Events und Reihen aus allen öffentlichen Abrufen; vorhandene Markierungen bleiben gespeichert und werden erst bei erneuter bewusster Öffentlichstellung wirksam. Korrektur auf Nutzerauftrag vom 02.10.2026: Bereits ausdrücklich öffentliche Altbestands-Events ohne Profil- und Reihenzuordnung bleiben im öffentlichen Ortsverzeichnis sichtbar, solange ihre Community öffentlich ist und dort aktuelle Gastgeberzuständigkeit besteht. Private Event-, Orts- und Communityangaben bleiben verborgen. Die Altbestandsregel ordnet keine Profile oder Reihen automatisch zu und gilt nicht für Events eines privaten Profils oder einer geschützten Reihe.

Die Gastgebervorschau **Wer sieht was?** zeigt für ein gespeichertes Event die Ansichten ohne Anmeldung, mit bloßem Profilzugang, mit Profil- und Reihenfreigabe sowie mit Profil- und Einzeleventfreigabe. Sie verwendet die serverseitigen Sichtbarkeitsregeln und verändert keine Freigaben. Der zusätzliche Modus für bestätigte Teilnahme weist darauf hin, dass Teilnahmezusagen und geschützte genaue Adressen im aktuellen Better-Auth-Teilumfang noch nicht angebunden sind. Die Vorschau ist keine Identitätsübernahme und kein Test tatsächlicher Eventteilnahme.

Angemeldete Konten mit bestätigter E-Mail können sichtbare Veranstalterprofile, Reihen und einzelne Events in einer persönlichen **Merkliste** speichern oder entfernen. Die persönliche Auswahl bleibt nur für das betreffende Konto abrufbar. Ergänzende Nutzerentscheidung vom 02.10.2026: Bei öffentlich sichtbaren Inhalten dient die Anzahl der merkenden bestätigten Konten als **öffentlicher Interessenzähler**. Ein Konto zählt pro Inhalt höchstens einmal; Entfernen nimmt dieses Interesse zurück. Namen, E-Mails und Listen der interessierten Konten werden nicht veröffentlicht. Geschützte Inhalte erhalten keinen öffentlichen Zähler, auch nicht für persönlich freigegebene Gäste. Jeder Abruf prüft den aktuellen Zugang erneut; entzogene Inhalte liefern keine Einträge, Namen oder Zähler. Merken erzeugt weder Freigabe, Mitgliedschaft noch Zusage. Es löst keinen Versand oder externe Benachrichtigungen aus. Umsetzung und Grenzen (`public-interest-counts.md`).

Je Event gibt der Gastgeber stufenlosen Zugang, zugängliches WC, Sitzmöglichkeiten und Rückzugsraum mit **Ja / Nein / Unbekannt** an. Ausgangswert ist Unbekannt; bestehende Events erhalten keine erfundenen Ausstattungsangaben. Ergänzend können Hinweise zur Zugänglichkeit, Awareness vor Ort und ein ausdrücklich zur Anzeige bestimmter Awarenesskontakt angegeben werden. Diese Angaben erscheinen ausschließlich innerhalb eines aktuell sichtbaren Events und sind Veranstalterangaben, keine Zertifizierung. Geschützte genaue Adressen gehören nicht in diese Texte oder in die gesondert freigegebene Ortsangabe. Eventansicht und genauer Adressabruf bleiben getrennte Rechte.

Aktuelle Umsetzung und tatsächlich ausgeführte Prüfungen: Veranstalterfunktionen (`organizer-features.md`).

### Szenespezifische Communities und Eventzuordnungen

Ergänzende Nutzerentscheidung vom 30.09.2026: Die fünf Bereiche Musik & Clubkultur, Queere Szene & Performance, Independent Arts & Film, Tanz & Movement sowie DIY-Kultur & selbstverwaltete Freiräume werden mit den im Gespräch benannten 28 spezifischen Communities als synthetische Profile vorgesehen. Spezifische Profile verweisen auf ihren übergeordneten Bereich; bestehende Profile bleiben erhalten. Die ursprüngliche Umsetzung gehörte zum inzwischen entfernten Vergleichsprototyp.

Auf den anschließenden Hinweis zur fehlenden bildenden Kunst ergänzt der lokale Prototyp den ausdrücklich benannten Oberbereich **Bildende Kunst & Ausstellungskultur** mit sechs Untercommunities: Malerei & Zeichnung, Skulptur & Objektkunst, Fotografie & Fotokunst, Installation & Raumkunst, Kunstvereine & Ausstellungskollektive sowie Ateliergemeinschaften & Open Studios. Damit umfasst diese Szeneneinordnung sechs Oberbereiche und 34 Untercommunities. Die Ergänzung betrifft Communityprofile und erzeugt keine Veranstaltungen.

Die zusätzlich gewünschten Communities **Freier Eintritt**, **Studentische Ermäßigung** und **Eintritt** werden unter **Eintritt & Ermäßigungen** gruppiert. „Eintritt“ bezeichnet dabei den regulären Eintrittspreis. Diese Profile dienen ausschließlich als ergänzende Veranstaltungseinordnung; konkrete Preise und Ermäßigungsbedingungen werden nicht erfunden. Diese Katalogergänzung enthält keine Preisfelder, Nachweisprüfung, Zahlung oder Ticketverkaufsfunktion. Der gesonderte Ticketingauftrag vom 05.10.2026 erweitert den Umfang unabhängig davon. Der lokale Katalog umfasst damit sieben Oberbereiche und 37 Untercommunities.

Die gewünschten Communities **Barrierefrei** und **Nicht barrierefrei** werden unter **Barrierefreiheit** ergänzt. Sie dienen als Einordnung nach Veranstalterangabe, ohne geprüfte Zertifizierung oder automatische Bewertung bestehender Events. Eine fehlende Zuordnung bedeutet keine Aussage zur Barrierefreiheit. Der lokale Katalog umfasst damit acht Oberbereiche und 39 Untercommunities.

Die gewünschten Communities **FLINTA-Only** und **Queer-Only** werden unter **Queere Szene & Performance** ergänzt. Sie dienen zur Einordnung entsprechend angekündigter Veranstaltungen; konkrete Zugangsvoraussetzungen beschreibt der Veranstalter. Bestehende Profile und Eventzuordnungen bleiben erhalten. Es werden keine Identitätsabfragen oder automatischen Zugangsentscheidungen ergänzt. Der lokale Katalog umfasst damit acht Oberbereiche und 41 Untercommunities.

Veranstaltungen können mehreren Communities zugeordnet werden. Diese zusätzliche Einordnung dient der Auffindbarkeit; sie überträgt keine Verwaltungs- oder Teilnahmerechte. Eine feste verantwortliche Community verwaltet weiterhin Aufnahme, Eventzusagen, Kapazität und geschützte Informationen. Gastgeber können ausschließlich weitere Communities zuordnen, die sie selbst verwalten. Nur öffentliche Zusatzprofile erscheinen bei öffentlichen Events, in Suche und Filtern. Ein Event bleibt ein einzelner Datensatz mit einer gemeinsamen Platzkapazität. Die Zuordnung zu einem Unterbereich erzeugt keine automatische Zuordnung zum Oberbereich und umgekehrt.

## 4. Schutzgrenzen und Löschung

Das Backend prüft Berechtigungen bei jedem Zugriff und verweigert sie standardmäßig. Versteckte Schaltflächen allein sind kein Zugriffsschutz. Gäste sehen ihre eigenen Bewerbungen; Gastgeber prüfen nur Bewerbungen ihrer Community. Veranstalterbewerbungen sind für Antragsteller und zuständige Prüfer im Projektteam bestimmt.

Privilegierte Secrets und `service_role` gehören ausschließlich auf den Server, niemals in den Flutter-Build. Tokens, private Adressen und Bewerbungsantworten dürfen nicht in Logs stehen. Zusammengehörige Änderungen werden als Transaktion vollständig ausgeführt oder vollständig verworfen. Wiederholte oder gleichzeitige Anfragen dürfen weder doppelte Mitgliedschaften noch eine Überschreitung der Eventkapazität erzeugen.

**Veranstalter- und Gastbewerbungen einschließlich Antworten werden zwei Kalendermonate nach Annahme, Ablehnung oder Rückzug gelöscht.** Laufende Bewerbungen bleiben während ihrer Bearbeitung erhalten. Die Regel schreibt keine zweimonatige Aufbewahrung anderer Daten vor. Mitgliedschaften und Eventbestätigungen müssen unabhängig von den später gelöschten Bewerbungsantworten bestehen können. Eine minimale, getrennte Sperrmarkierung hält nach Ablehnung oder Entzug die erneute Bewerbung gesperrt und enthält keine Bewerbungsantworten. Ein freiwilliger Rückzug begründet nach Nutzerentscheidung vom 04.10.2026 keine Wiederbewerbungssperre; eine neue Bewerbung wird mit dem dann gültigen Formular eingereicht, ohne alte Antworten wiederherzustellen. Fristen dieser Markierung und weiterer Datenarten sowie die technische Löschung einschließlich möglicher Sicherungen sind vor einem echten Pilot zu konkretisieren.

## 5. Nicht-Ziele der ersten Version

- Kein eigener Messenger, keine Messenger-Synchronisierung, Bots oder Gruppenimporte.
- Keine Zahlungen außerhalb des ausdrücklich freigegebenen Ticketingumfangs vom 05.10.2026; siehe folgende Ergänzung.
- Keine KI-Kompatibilitätsbewertung und kein automatisches Matching.
- Keine Trust Scores oder universellen Verifizierungsabzeichen.
- Keine globalen Szeneprofile oder communityübergreifenden Personenbewertungen.
- Kein allgemeiner Aachen-Eventkatalog und keine Stadtkarte. Ein öffentlicher Bereich zeigt ausdrücklich freigegebene Communityprofile und Eventangaben sowie Informationen zu Community Access; Gastgeber bestimmen die veröffentlichten Felder. Persönliche Bewerbungen und Teilnahmestatus bleiben geschützt.
- Kein Ausweisarchiv und keine eigene Identitätsprüfung.
- Kein frei konfigurierbarer Baukasten für Veranstalterbewerbungen. Für Gastbewerbungen bestimmen Gastgeber die Fragen; der bisherige Vergleichsprototyp begrenzte dies auf eine bis acht Textfragen mit Pflichtfeldoption. Die Formularumsetzung im neuen Backend bleibt offen.
- Keine native Store-Veröffentlichung im lokalen Prototyp.

## 6. Fünf entscheidende offene Fragen

Betreiberentscheidung vom 04.10.2026: Stany Nyssen ist vorläufig als Privatperson für den Projektbetrieb und als Ansprechpartner für Datenschutzanfragen vorgesehen. Als öffentlicher gemeinsamer Kontakt ist info@communityaccess.de benannt; tatsächlicher Empfang, ladungsfähige Anschrift, Vertretung, Datenschutzrollen der Veranstalter und die rechtliche Einordnung bleiben zu prüfen bzw. zu vervollständigen. Das Eventmindestalter bestimmt der Veranstalter unter Beachtung des Jugendschutzes. Ob Minderjährige Konten anlegen dürfen und wie der Plattformzugang für sie gestaltet wird, bleibt gesondert zu klären; daraus wird keine allgemeine 18-Jahre-Grenze abgeleitet.

1. Welche Veranstaltungstypen sollen die beiden Veranstalter im Pilot anbieten?
2. Welche Veranstalterformularfelder sind Pflicht, und reichen bei „Mitgliedern“ Anzahl und Funktionen statt personenbezogener Mitgliederlisten?
3. Welche Leitlinien und Prüfung gelten für die von Gastgebern festgelegten Gastbewerbungsfragen? Die Zuständigkeit für das Formular ist entschieden; verbindliche Inhaltsregeln und Moderation bleiben zu konkretisieren.
4. Wie lange bleiben Konten, Mitgliedschaften, Eventanfragen und Beschwerden gespeichert?
5. Wer bearbeitet Beschwerden, die eigene Entscheidungen des Projektteams als Betreiber betreffen?

## 7. Wie wir die drei wichtigsten Anforderungen testen

Die folgenden Punkte bilden den **Abnahmekatalog**. Ausgeführte Teilprüfungen und ihre Grenzen stehen in den aktuellen Prüfberichten; sie ersetzen keine vollständige Produktabnahme.

| Anforderung | Test mit erfundenen Konten | Erwartetes Ergebnis |
| --- | --- | --- |
| Manuelle Aufnahme und separate Eventzusage | Das Team nimmt Veranstalter A auf. Ein Gast bewirbt sich dort, versucht Selbstaufnahme und wird anschließend durch Gastgeber A aufgenommen. Er fragt ein Event an und erhält erst danach eine Zusage. Ablehnung und Rückzug werden ebenfalls durchgespielt. | Keine Selbstaufnahme; korrekter eigener Status; weder Einladung noch Mitgliedschaft geben automatisch einen Eventplatz oder die genaue Location frei. Die Altersbestätigung erscheint bei der Eventanfrage als Selbstauskunft. |
| Schutz gegen fremde Zugriffe | Ein fremder Gast, Gastgeber B, ein nicht angemeldetes Konto und ein entferntes Mitglied versuchen direkte Backend-Abrufe bekannter Bewerbungs- und Event-IDs. Berechtigte Konten dienen als Gegenprobe. | Unberechtigte erhalten keine Antworten oder privaten Locations. Neue Abrufe nach Entzug sind gesperrt. Zuständige Prüfer können weiterhin arbeiten. Die Prüfung erfolgt über normale Nutzerzugänge, nicht nur als Datenbankadministrator. |
| Konsistenz und verlässliche Löschung | Zwei Zusagen konkurrieren um den letzten Platz; eine Aufnahme wird wiederholt; ein Fehler wird zwischen zusammengehörigen Änderungen ausgelöst. Mit kontrollierter Testzeit prüfen wir die Löschfrist vor und nach Fälligkeit für angenommene, abgelehnte, zurückgezogene und laufende Bewerbungen beider Arten. | Höchstens eine Zusage für den letzten Platz, eine Mitgliedschaft je Gast und Community, keine halbfertige Aufnahme. Abgeschlossene Bewerbungen samt Antworten werden nach zwei Kalendermonaten gelöscht; laufende bleiben erhalten. Davon unabhängige Mitgliedschaften bleiben bestehen. |

Für Einsteiger: Ein positiver Test zeigt, dass eine erlaubte Aktion funktioniert. Ein negativer Test zeigt, dass eine verbotene Aktion auch bei direktem Zugriff scheitert. Ein Konkurrenztest startet Aktionen gleichzeitig und prüft, ob das Ergebnis trotzdem widerspruchsfrei bleibt.

## Quellen und Grenzen

### Ergänzung vom 02.10.2026: Inhalte der Veranstaltungsseiten

Gastgeber können Beschreibung, geordnetes Line-up, Genres, Veranstaltungsortname, Endzeit, Einlassinformationen, optionales Mindestalter und einen eigenen Flyer mit Alternativtext pflegen. Eine Entwurfsvorschau zeigt die Gestaltung vor dem Speichern. Die Informationshierarchie orientiert sich auf Nutzerauftrag an der genannten Resident-Advisor-Eventseite. Inhalte bleiben innerhalb der bestehenden Eventrechte; Ortsname und Endzeit folgen den gesonderten Orts-/Beginnfreigaben. Profilzugang bleibt ohne automatische Teilnahmezusage. Die lokale Speicherung und tatsächlichen Nachweise sind unter Veranstaltungsseiten und Gastgebereditor (`event-editorial-pages.md`) dokumentiert. Ticketverkauf ist nicht Bestandteil dieser Ergänzung. Der anschließend beauftragte Interessenzähler verwendet ausschließlich Merklisteneinträge gemäß der oben dokumentierten Nutzerentscheidung.

- Nutzerentscheidungen im Projektgespräch vom 24.09.2026 einschließlich Freigabe und Antworten zu Formular, Alter und Fristbeginn.
- Ergänzende Nutzerentscheidungen zum bisherigen Vergleichsprototyp: Gastgeber legen Gastbewerbungsformulare fest; erneute Bewerbung nach Ablehnung oder Rückzug sperren und Kontakt zum Gastgeber anbieten (damalige Umsetzung 30.09.2026). Am 04.10.2026 wurde die Wiederbewerbung nach freiwilligem Rückzug ausdrücklich erlaubt; Ablehnung und Entzug bleiben getrennt gesperrt. Der Gastclient bildet die neue Vorgabe synthetisch ab; ein aktiver Community-Backendnachweis fehlt weiter.
- *Community Access – Entwicklungsplan*, Version 1.0, 24.09.2026: S. 5 (Produktvertrag), S. 9 (Berechtigungen), S. 12–13 (Produktkern und Abnahme). Das ausführliche zusätzliche Veranstalterformular konkretisiert die ursprüngliche Planung durch Nutzerentscheidung.

Diese Spezifikation dokumentiert den gewünschten Zustand. Sie ist weder ein Sicherheitsnachweis noch eine Freigabe für echte personenbezogene Daten oder eine Veröffentlichung. Installation, neue Dienste und Veröffentlichung sind nicht Bestandteil dieser Aufgabe.


## Verbindliche Erweiterung vom 04.10.2026

Der Nutzerauftrag dieses Tages ersetzt widersprechende ältere Entwurfsangaben zu Startseite, Präferenzen, Sichtbarkeit und Aufbewahrung. „Veranstalter“ ist der sichtbare Begriff.

- Die Hero-Section zeigt ein Carousel relevanter kommender Veranstaltungen. Motiv beziehungsweise Titel links und weiterführende Informationen rechts wechseln gemeinsam; mobil stehen sie untereinander. Das öffentliche Carousel bleibt unabhängig vom Anmeldestatus gleich. Ohne verfügbare Veranstaltungen erscheinen keine erfundenen Inhalte.
- Ohne Anmeldung: allgemeine Einführung und nächste öffentlich auffindbare Veranstaltungen. Mit Anmeldung: nächste sichtbare Veranstaltungen, anhand freiwilliger Veranstaltungspräferenzen, Musikgeschmack, Lieblingsveranstaltungen, Freizeitbeschäftigungen, Merkliste, gefolgten Communities und bereits besuchten Veranstaltern sortiert. Gewichte und Gründe sind nachvollziehbar; keine KI-Kompatibilitätswertung. Präferenzen bleiben nur im eigenen Konto sichtbar und sind veränderbar beziehungsweise leerbar. Auch Gäste, die über einen Anbieter einsteigen, erhalten die optionale Präferenzabfrage.
- Veranstalterprofile zeigen ausschließlich Selbstdarstellung, sichtbare Communityzuordnung und die verpflichtend beantworteten Angaben zu Awarenesskonzept und Awarenessteam. Keine Mitgliederliste, Mitgliederanzahl oder personenbezogenen Teamfunktionen. Bei Altprofilen sind fehlende Angaben als fehlend sichtbar; sie werden nicht als Nein erfunden.
- Gastgeber erstellen mehrere benannte Formulare, bearbeiten Fragen und Pflichtfelder und weisen Formulare Veranstaltungen zu. Fehler oder ungeprüfte/unzulässige Fragen blockieren die Bestätigung auch serverseitig. Der aktuelle lokale Umfang verwendet einen begrenzten Fragenkatalog; die Zulässigkeit beliebiger Freitextfragen wird nicht automatisch behauptet. Antworten werden mit dem tatsächlich beantworteten Formularstand aufbewahrt.
- Öffentliche Veranstaltungen enthalten die zur Auffindbarkeit nötige Beschreibung, Beginn und Ortsangabe. Die Endzeit ist für veröffentlichte und abgesagte Veranstaltungen verpflichtend, um die Löschfrist zu berechnen. Bereits vorhandene Einträge ohne Ende erfordern eine bewusste Korrektur.
- Zusätzlich zu privaten und öffentlichen Veranstaltungen gibt es semi-öffentliche Werbung. Gäste müssen sich anmelden und Interesse bekunden; der Veranstalter entscheidet manuell. Er wählt einfache Anfrage, Formular mit manueller Prüfung oder ausschließlich persönliche Freigabe und getrennte Freigabezeitpunkte für Zeit und Ort. Anmeldung, Interesse, Zusage und tatsächlicher Besuch sind unterschiedliche Zustände. Flyer sind für semi-öffentliche Events gesperrt, weil sie geschützte Angaben enthalten können; öffentlich bezeichnete Freitexte dürfen diese Angaben ebenfalls nicht enthalten.
- Diese frühere Regel zur automatischen Profilaufnahme wird durch den privaten Ausbau vom 08.10.2026 ersetzt: Eine Eventfreigabe öffnet ausschließlich dieses Event. Ein Veranstalterprofil benötigt eine eigenständige Freigabe. Dieser eigenständige Profilzugang bleibt bestehen, bis der Veranstalter ihn entzieht oder das Gastkonto gelöscht wird. Der Entzug eines Eventzugangs entzieht nicht automatisch den unabhängigen Profilzugang. Ein Profilentzug darf nicht durch erneute Eventfreigabe umgangen werden.
- Exakt 168 Stunden nach dem eingetragenen tatsächlichen Veranstaltungsende sind Eventinformationen, Teilnehmer-/Anfragezuordnungen, Antworten, Eventfreigaben und Eventmerkliste nicht mehr abrufbar; sie verschwinden bei der nächsten Bereinigung aus der aktiven Datenbank. Auf ausdrücklichen Nutzerwunsch bleibt nur „Gast hat bereits eine Veranstaltung dieses Veranstalters besucht“ für Empfehlungen erhalten: keine konkrete Veranstaltung, kein Datum, keine Anzahl. Ein Gast bestätigt den Besuch nach dem Ende selbst; eine Zusage wird nicht als Besuch ausgelegt. Dieses Signal lässt sich separat löschen.
- Der Header bietet einen Deutsch/Englisch-Wechsel. Veranstalterinhalte werden nicht automatisch übersetzt.

Die Implementierung bleibt lokal und synthetisch. Aktive Datenbanklöschung ist kein Nachweis für Löschung aus WAL/Backups, Betriebssystem- oder Browserresten oder Kopien bei Empfängern. Die lokale Serverlaufzeit prüft bei Start, Anfragen und minütlich; abgelaufene Einträge werden bei Abrufen sofort ausgesperrt. Produktionsbetrieb, Hosting und Backupkonzept benötigen eigene Abnahme. Siehe technischer Umfang und Prüfungen (`event-discovery-preferences.md`).

## Nutzerentscheidung vom 05.10.2026: öffentliche Anfragefrist

Gastgeber legen eine separat veröffentlichte Anfragefrist fest, unabhängig vom geschützten Eventbeginn und von Zeit-/Ortsfreigaben. Bei verborgenen Eventzeiten richten sich Anfrage und Rückzug nach dieser Frist; Änderungen des geschützten Beginns oder Endes dürfen ihre Verfügbarkeit und Fehlerantworten nicht verraten. Gastgeber können weiterhin nur vor dem tatsächlichen Beginn zusagen. Ist der Beginn für den betreffenden Gast freigegeben, gilt zusätzlich die bisherige Grenze vor Beginn; ein Rückzug bleibt dann bis zum Beginn möglich. Ein Besuch kann erst bei bestätigter Teilnahme und freigegebener, vergangener Endzeit bestätigt werden.

Neue oder bearbeitete veröffentlichte semi-öffentliche Events benötigen eine ausdrücklich eingetragene Anfragefrist. Für Altbestände wird sie nicht aus geheimen Zeiten abgeleitet; ohne Frist bleiben Anfragen und Rückzug bei verborgener Zeit geschlossen, bis der Gastgeber sie ergänzt. Die Anfragefrist ist auf zugänglichen Eventseiten und in deren Vorschau sichtbar. Entzogene Profil-/Reihenzuordnungen dürfen weder Empfehlungsgründe noch die Reihenfolge beeinflussen. Umsetzung und Sicherheitsnachweise (`security-event-policy-fixes.md`).

## Nutzerentscheidung vom 05.10.2026: Ticketing und Veranstaltererlöse

Freigegeben ist Ticketing mit selbst betriebenem pretix und Stripe Connect. Jeder Veranstalter bleibt Verkäufer. Direct Charges laufen auf seinem verbundenen Konto; die vom Plattformteam ausdrücklich gesetzte Prozentprovision wird mit `application_fee_amount` vom Erlös abgezogen. Kein Standardsatz und kein Käuferaufschlag. EUR, Karten, ein verantwortlicher Verkäufer je Event, ein persönliches Ticket je bestätigtem Konto und Event, keine Übertragung oder Gruppenkäufe. Bank- und Identitätsangaben werden bei Stripe erhoben.

Bestehende Events starten ohne Ticketing. Öffentlicher Verkauf erfordert öffentlich freigegebene Eventinformationen und ein bestätigtes Plattformkonto, aber keine manuelle Kaufentscheidung; Mitgliedschaftspflicht ist damit nicht kombinierbar. Verkauf nach Freigabe erfordert eine persönliche manuelle Kaufberechtigung. Diese Freigabe reserviert keinen Platz. pretix entscheidet über Kontingente und reserviert im Checkout 15 Minuten. Erst bestätigte Zahlung begründet Teilnahme; genaue Location und Freigabezeitpunkte folgen zusätzlich den bestehenden Regeln. Eine Browserrückleitung ist kein Zahlungsnachweis.

Die Gebühr wird centgenau vom tatsächlich berechneten Ticketpreis nach Ermäßigung ermittelt. Gebührenversion und Betrag werden je Bestellung festgehalten. Absage oder Berechtigungsentzug sperrt Zugang und Ticket und erzeugt eine Erstattungsaufgabe; der zuständige Veranstalter genehmigt vollständige oder teilweise Rückzahlung einschließlich entsprechender ausdrücklicher Provisionsrückzahlung. Ereignisse werden wiederholbar verarbeitet und regelmäßig authentifiziert abgeglichen. Webhook-Nutzdaten bestätigen keine Zahlung.

Minimale Bestellzuordnungen und offene Erstattungen haben einen getrennten Lebenszyklus ohne kaskadierende Eventlöschung. Bewerbungsantworten und geschützte Locations gelangen nicht in Zahlungsmetadaten oder Ticketdokumente. Finanzaufbewahrungsfristen bleiben vor echtem Verkauf festzulegen.

Der lokale Node-/Flutter-Ablauf ist mit simulierten Zahlungsantworten umgesetzt. Nach ausdrücklicher Installationsfreigabe läuft zusätzlich pretix 2026.8.0 isoliert mit eigener Datenbank und ergänzendem Plugin. Native Warenkörbe, Kontingente, Checkout, Bestellungen, PDF-Tickets und Einlassprüfung werden verwendet; ein getrennter Vertragstest-Dienst bleibt für Ausfall- und Konkurrenzprüfungen erhalten. Connect-Onboarding, echte Stripe-Sandbox und Veröffentlichung bleiben getrennte Schritte. Architektur, Start und tatsächliche Nachweise (`ticketing.md`).


## Privater Ausbau und Nutzerklärung vom 08.10.2026

Communities werden von ausdrücklich zugewiesenen Moderatoren verwaltet. Die Veranstalterzulassung allein erlaubt weder Aufnahme und Einladungen noch Communityregeln oder Veröffentlichungsfreigaben. Veranstalter behalten Verantwortung für eigene Auftritte, Events, Verkäufe und Erstattungen; die Communitymoderation vergibt das Veröffentlichungsrecht je Auftritt und bestätigt die Communityzuordnung eines Events. Weitere Communities sind erst nach ihrer eigenen Freigabe ein gültiger Zugangsweg.

Event-, Profil-, Community- und Kategoriezugang bleiben unabhängig. Ein persönlicher Kategoriengrant öffnet kein Event. Kategoriebedingungen begrenzen den Kauf; nach bestätigter Zahlung zählen für den Online-Einlass die fortgeltenden Eventrechte, Sperren und die zeitlich gültige Eventscannerrolle. Ein gültiger zweiter Communityweg oder Eventgrant bleibt bei Entzug eines anderen Communitywegs erhalten. Dauerhafte Communityausschlüsse benötigen zwei unabhängige Moderatoren; vertrauliche Fälle und Einsprüche sind von wirksamen Sperren getrennt.

Nutzerergänzung vom 08.10.2026: Mehrere Konten eines Veranstalters können denselben Auftritt gemeinsam verwalten. Das verantwortliche Konto lädt bestätigte Konten ein; Verwaltungszugriff beginnt erst mit ausdrücklicher Annahme. Angenommene Verwalter bearbeiten genau diesen Auftritt einschließlich Events, Reihen, Anfragen, Freigaben, Ticketangeboten und Erstattungen. Communitymoderation bleibt eine unabhängige Rolle. Einladungen, Verwaltungsentzug und Änderung der Zahlungszuordnung bleiben beim verantwortlichen Konto; die Verkäuferzuordnung wird durch gemeinsame Verwaltung nicht verändert. Entzug beendet den delegierten Zugriff auch in bereits geöffneten Ansichten und verhindert die spätere Einlösung noch offener, von diesem Konto ausgestellter Profilaufnahme-Links. Bereits unabhängig erteilte Gastrechte werden dadurch nicht pauschal widerrufen.

Neue Aufbewahrungsfristen und eine Löschroutine sind nicht freigegeben: zunächst ausschließlich aggregierte Vorschau. Bestehende frühere Fristen werden nicht als neue Richtlinie ausgegeben. Umsetzungsstand und Nachweise (`implementation/report.md`), gemeinsame Verwaltung (`implementation/collaboration.md`), Aktionsmatrix (`implementation/access-matrix.md`) und Betrieb (`implementation/operations.md`) konkretisieren diesen lokalen synthetischen Umfang.

## Freigegebene Erweiterung vom 09.10.2026: rechtliche Ticketgrenzen

Aktuelle Verkäuferangaben und eine ausdrücklich bestätigte, zur Event-/Verkäufer-/Textversion passende Übernahme der Veranstalterverantwortung sind Voraussetzungen für beide Kaufwege. Die Erklärung bestätigt Verantwortung für Durchführung, Genehmigungen, Nutzungsrechte und Sicherheit; sie verlangt keine pauschale Genehmigungsprüfung durch Community Access oder Bestätigung, dass bereits sämtliche Voraussetzungen geklärt sind. „Privatparty“ bezeichnet eingeschränkten Zugang, keine bestätigte rechtliche Einordnung. Öffentliche Inhaltsmeldungen verändern Rechte nicht selbst; eine unabhängige begründete Teamentscheidung kann Verkäufe pausieren oder Angebote einschließlich Einlass sperren. Eine Pause erhält bereits bezahlte Tickets und persönliche Freigaben, stoppt jedoch offene unbezahlte Checkouts. Späte Zahlungen bleiben als Finanznachweis mit Erstattungsprüfung erhalten. Ausdrückliches Wiederöffnen reaktiviert keine gestoppten Bestellungen. Ablauf, Schnittstellen und Rechtsgrenzen (`legal-ticketing.md`).

## Konto- und Zugriffsnachbesserungen · 09.10.2026

Registrierung liefert einen einheitlichen Abschluss für neue und bestehende Konten und erzeugt keine automatische Sitzung. Der nächste Schritt ist E-Mail-Bestätigung und anschließende Anmeldung; eine manuelle Anmeldung unbestätigter Konten ändert keine Produktrechte. Die bestehende Bestätigungspflicht vor Aufnahme-, Freigabe-, Ticket- und Verwaltungsaktionen bleibt erhalten. Eigene Präferenzen dürfen mit einer gültigen Sitzung bearbeitet werden; ihre Abfrage ist freiwillig und unterbricht kein Ressourcenziel.

Anmeldung wird durch ein HttpOnly-Cookie im selben Browser wieder aufgenommen, bei jedem Zugriff serverseitig geprüft und spätestens acht Stunden nach Login ungültig; Zugriff verlängert die Sitzung nicht. Lokale Entwürfe bleiben im Arbeitsspeicher. Wiederaufnahme von Event/Reihe speichert im Tab nur Art und UUID, keine Zugangscodes, Antworten, Locations oder Sitzungsdaten. Eine Inhaltskennung verleiht keine Sichtrechte.

Eine aktive Plattformsperre verhindert alle Produktaktionen, auch Veranstalterverwaltung, Moderation, Team und Einlass. Identität/Wiederherstellung, eigene minimale Bestellbelege und eigene Beschwerden bleiben erreichbar. Betroffene erhalten keinen Verwaltungszugriff, keine fremden Belege und keine neuen Eintrittsrechte. Zahlungsabgleich und Erstattungsaufgaben laufen unabhängig vom gesperrten Nutzerkonto weiter; eigene Belege sind keine gültigen Einlasstickets.

Umsetzung und aktuelle Nachweise (`qa/auth-improvements-2026-10-09/report.md`). Beschwerde- und Erstattungszuständigkeit, Kontakt und Bearbeitungsfristen bleiben ausdrücklich offen.


## Store-Startvorbereitung vom 09.10.2026

Nutzerauftrag: Vorbereitung für Apple App Store und Google Play, ohne Veröffentlichung über Entwicklerkonten. App-Name bleibt Community Access; Ticketverkauf gehört zum vorgesehenen Start. Konten sollen ab 16 Jahren möglich sein; Datenschutz-, Vertrags- und Jugendschutzvoraussetzungen sind noch zu prüfen. Es ist kein Hosting vorhanden; zunächst ausschließlich lokale Bereitstellung vorbereiten. Diese Entscheidung ersetzt weder eine Store-Altersbewertung noch die veranstaltungsbezogenen Alters- und Einlassregeln.

Native Projekte, Altersbestätigung, sichere Löschanfragen ohne automatische Löschung und Übergabeunterlagen stehen in Store-Startvorbereitung (`store-launch/README.md`). Produktiver Zahlungsbetrieb, mobiler Checkout-Handoff, tatsächliche Löschbearbeitung, Rechtsprüfung und Geräteabnahme bleiben erforderlich. Keine Speicherung von Geburtsdatum oder Ausweisdaten ergänzt.

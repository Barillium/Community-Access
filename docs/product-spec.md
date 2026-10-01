# Community Access: Produktspezifikation

Stand: 24.09.2026 · Status: freigegebener Produktumfang, noch nicht implementiert

Technikwechsel vom 01.10.2026: Der bisherige Laravel-Vergleichsprototyp wurde aus dem aktiven Projekt entfernt; seine Flutter-Gastoberfläche bleibt unter `client/` erhalten. Better Auth ist als nächster Authentifizierungsansatz vorgesehen, aber noch nicht installiert oder angebunden. Serverlaufzeit, Anbindung und Umsetzung der Produktberechtigungen sind noch festzulegen. Die separate Flutter-Statusdemo und der bestehende lokale Supabase-Teilumfang bleiben erhalten; deren bisherige Prüfergebnisse sind kein Better-Auth-Nachweis. Die folgenden Produktanforderungen gelten unabhängig vom entfernten Prototyp weiter.

## 1. Problem, Ziel und Belegstand

Community Access soll bestehenden Aachener Kollektiven ermöglichen, Bewerbungen, manuelle Aufnahme und Eventanfragen nachvollziehbar zu bearbeiten. Die Kollektive verteilen Einladungen über ihre bestehenden Messenger; Community Access ergänzt diese um geregelten Zugang und ersetzt sie nicht.

Der geplante Pilot umfasst ausschließlich **The Base E.V.** und **Not Human Collective**. Diese Festlegung belegt keine Teilnahmezusage. In Entwicklung, Tests und KI-Kontext werden ausschließlich synthetische Kollektive, Personen, Kontaktdaten, Orte und Bewerbungen verwendet. Die beiden Namen dienen hier nur der Beschreibung des Pilotumfangs.

| Kategorie | Aussage und Grundlage |
| --- | --- |
| Nutzervorgaben | Pilotumfang, zwei Produktrollen, zusätzliche Kollektivbewerbung, manuelle Entscheidungen, veranstaltungsbezogene Altersselbstauskunft, Eigenbetrieb und Löschfrist wurden im Projektgespräch festgelegt. |
| Technische Zielvorgabe | Flutter/Dart, PostgreSQL und zunächst lokales Supabase; Open-Source-orientiert. Eine Lizenz für den eigenen Code ist damit noch nicht gewählt. |
| Dokumentierte Vorschläge | Der Entwicklungsplan beschreibt den Kernablauf, getrennte Berechtigungen und negative Zugriffstests; siehe Quellen unten. Das sind Planungsgrundlagen, keine Implementierungsnachweise. |
| Projektannahme | Ein gemeinsamer, klarer Statusablauf verringert Rückfragen und organisatorischen Aufwand. Dieser Nutzen ist noch nicht mit Gastgebern und Gästen überprüft. |
| Beobachteter Ist-Zustand | Vor Erstellung dieser Spezifikation war der Projektordner leer und kein Git-Repository vorhanden. Eine Anwendung und technisch getestete Produkteigenschaften existieren noch nicht. |

Erfolg bedeutet zunächst: Eine Person kann die Produktidee in zwei Sätzen erklären; der vollständige Ablauf ist verständlich; seine Berechtigungsgrenzen lassen sich später mit synthetischen Konten nachweisen. Es gibt noch keine belegte Zeitersparnis oder Sicherheitsgarantie.

## 2. Zwei Nutzerrollen und betriebliche Verantwortung

- **Gast:** erhält eine Einladung, bewirbt sich beim Kollektiv, sieht den eigenen Status und fragt nach Aufnahme eine Eventteilnahme an. Bewerber, Mitglied und bestätigter Eventgast sind unterschiedliche Zustände dieser Rolle.
- **Gastgeber:** vertritt ein Kollektiv, beantragt dessen Aufnahme und verwaltet nach Freigabe Einladungen, Gastbewerbungen und Eventanfragen seiner Community. Rechte gelten nur für die jeweils zugeordnete Community.

Betrieb und Beschwerden übernimmt vorerst das Projektteam selbst. Es prüft Kollektivbewerbungen und entscheidet über die Veranstalteraufnahme. Das ist eine zusätzliche betriebliche Verantwortung, keine dritte Produktrolle für Gäste oder Gastgeber. Der technische Verwaltungszugang wird später gesondert abgesichert; gewöhnliche Gastgeberrechte erlauben keine Kollektivfreigabe oder Einsicht in fremde Bewerbungen.

## 3. Zwei manuelle Aufnahmeabläufe

### Kollektivaufnahme durch das Projektteam

Ein Kollektiv reicht ein ausführliches Formular ein. Es umfasst bisherige Veranstaltungen, Kontaktdaten, Awarenessstrukturen, Mitglieder, Organisationsstruktur, Veranstaltungsorte und Veranstaltungsarten. Awarenessstrukturen beschreiben beispielsweise zuständige Ansprechstellen und den Umgang mit Grenzverletzungen.

Das Projektteam prüft die Bewerbung manuell und nimmt sie an oder lehnt sie ab. Ein Rückzug durch das antragstellende Kollektiv ist möglich. Erst die Annahme eröffnet die Gastgeberverwaltung für diese Community. Konkrete Pflichtfelder und die Bedeutung von „Mitglieder“ bleiben offen; daraus wird keine personenbezogene Mitgliederliste abgeleitet. Das Formular ist fest definiert, kein frei konfigurierbarer Baukasten.

### Gastaufnahme und Eventbestätigung

**Einladung → Bewerbung → manuelle Aufnahme → Eventanfrage → Bestätigung**

1. **Einladung:** Der Gastgeber teilt einen kontrollierten Link über einen bestehenden Kanal. Der Link erlaubt den Bewerbungseinstieg, keine automatische Mitgliedschaft. Ein Konto mit Anmeldung ist die technische Voraussetzung für persönliche Anträge und Statusanzeigen.
2. **Bewerbung:** Der Gast sendet eine separate, kurze Bewerbung an das Kollektiv. Sie bleibt bis zur Entscheidung in Bearbeitung; ein Rückzug ist möglich. Die Gastgeber legen das Gastbewerbungsformular selbst fest und kennzeichnen erforderliche sowie optionale Antworten. Name, E-Mail und Passwort gehören separat zur Kontoanlage. Bereits eingereichte Bewerbungen behalten ihre ursprünglichen Fragen. Intime Profile und Fragen nach sexuellen Vorlieben sind ausgeschlossen. Nach Ablehnung oder Rückzug ist eine erneute Gastbewerbung für diese Community gesperrt; stattdessen wird ein vom Gastgeber hinterlegter Kontaktweg angeboten. Entzogene Mitgliedschaften bleiben gesperrt.
3. **Manuelle Aufnahme:** Ein berechtigter Gastgeber nimmt an oder lehnt ab. Nur die Annahme begründet eine Mitgliedschaft in dieser Community. Der Gast kann sich nicht selbst annehmen. Mitgliedschaft ist weder Identitätsprüfung noch Sicherheitsbescheinigung.
4. **Eventanfrage:** Ein aktives Mitglied fragt die Teilnahme an einem Event an. Mitgliedschaft allein reserviert keinen Platz. Der Veranstalter legt je Event eine Altersgrenze fest; der Gast bestätigt, sie zu erfüllen. Das ist eine Selbstauskunft ohne Ausweis-Upload und keine verifizierte Altersprüfung. Tatsächliche Zugangsvoraussetzungen setzen die Veranstalter durch.
5. **Bestätigung:** Der zuständige Gastgeber entscheidet separat über die Eventanfrage. Erst bestätigte Gäste mit aktueller Berechtigung erhalten die dafür vorgesehenen genauen Veranstaltungsinformationen. Eine Ablehnung erzeugt keinen Teilnahmeanspruch.

Private Eventinformationen sind nach aktueller Community- und Eventberechtigung zugänglich. Genaue Locations werden getrennt geschützt: berechtigte Gastgeber und aktuell bestätigte Gäste dürfen sie abrufen. Ein Entzug verhindert neue unberechtigte Abrufe; bereits gelesene Informationen lassen sich nicht zurückholen.

### Öffentlicher Einstieg

Ergänzende Nutzerentscheidung vom 30.09.2026: Öffentliche Events und Communities sowie Informationen zu Community Access sind ohne Anmeldung zugänglich. Gastgeber geben Profile und Events ausdrücklich frei und wählen die öffentlichen Eventangaben. Eine separate öffentliche Ortsangabe kann freigegeben werden; die geschützte Location wird nicht automatisch veröffentlicht. Öffentliche Sichtbarkeit begründet keine Mitgliedschaft oder Eventzusage.

### Veranstalterprofile und Veranstaltungsorte

Die Eventstartseite zeigt **Alle bevorstehenden Events**: aktuell öffentliche, nicht abgesagte Veranstaltungen mit freigegebenem Beginn ab dem aktuellen Zeitpunkt, zeitlich aufsteigend. Das Suchfeld findet diese Events anhand des Titels, öffentlicher zuständiger Veranstalterprofile oder freigegebener öffentlicher Ortsangaben. Die bestehende Suche über öffentliche Communities und Genres bleibt erhalten. Nicht freigegebene Profil- und Ortsangaben dürfen keine Treffer auslösen. Die übergeordneten Communityfilter werden je umgebrochener Zeile horizontal zentriert.

Ergänzende Nutzerentscheidung vom 30.09.2026: Die Navigation erhält die Seiten **Veranstalter** und **Veranstaltungsorte**. Das Veranstalterverzeichnis zeigt öffentlich freigegebene sowie dem angemeldeten Konto persönlich zugängliche Gastgeberprofile. Suche nach Anzeigenamen und Filter nach Communities werden angeboten.

Ein Gastgeber verwaltet **ein eigenes Veranstalterprofil mit mehreren zugeordneten Communities**. Er bestimmt dessen Öffentlichkeit und kann Bewerbung, persönlichen Link und ein selbst festgelegtes Formular als Zugangswege anbieten. Bewerbung und Formular erfordern **manuelle Freigabe durch den Gastgeber**. Persönlicher Profilzugriff begründet keine Communitymitgliedschaft, Eventteilnahme oder Berechtigung für geschützte Locations. Private Communitynamen werden durch eine Profilfreigabe nicht automatisch öffentlich.

Das Ortsverzeichnis zeigt ausdrücklich öffentliche Ortsangaben zu veröffentlichten kommenden und vergangenen Events. Verborgene Eventangaben und geschützte Locations werden nicht automatisch übernommen. Im bisherigen Vergleichsprototyp wurden identische öffentliche Ortsangaben zusammengefasst; eine eigenständige Verwaltung strukturierter Veranstaltungsorte war damit noch nicht verbunden. Dieser Implementierungsstand gehört zum entfernten Prototyp.

### Szenespezifische Communities und Eventzuordnungen

Ergänzende Nutzerentscheidung vom 30.09.2026: Die fünf Bereiche Musik & Clubkultur, Queere Szene & Performance, Independent Arts & Film, Tanz & Movement sowie DIY-Kultur & selbstverwaltete Freiräume werden mit den im Gespräch benannten 28 spezifischen Communities als synthetische Profile vorgesehen. Spezifische Profile verweisen auf ihren übergeordneten Bereich; bestehende Profile bleiben erhalten. Die ursprüngliche Umsetzung gehörte zum inzwischen entfernten Vergleichsprototyp.

Auf den anschließenden Hinweis zur fehlenden bildenden Kunst ergänzt der lokale Prototyp den ausdrücklich benannten Oberbereich **Bildende Kunst & Ausstellungskultur** mit sechs Untercommunities: Malerei & Zeichnung, Skulptur & Objektkunst, Fotografie & Fotokunst, Installation & Raumkunst, Kunstvereine & Ausstellungskollektive sowie Ateliergemeinschaften & Open Studios. Damit umfasst diese Szeneneinordnung sechs Oberbereiche und 34 Untercommunities. Die Ergänzung betrifft Communityprofile und erzeugt keine Veranstaltungen.

Die zusätzlich gewünschten Communities **Freier Eintritt**, **Studentische Ermäßigung** und **Eintritt** werden unter **Eintritt & Ermäßigungen** gruppiert. „Eintritt“ bezeichnet dabei den regulären Eintrittspreis. Diese Profile dienen ausschließlich als ergänzende Veranstaltungseinordnung; konkrete Preise und Ermäßigungsbedingungen werden nicht erfunden. Keine Preisfelder, Nachweisprüfung, Zahlung oder Ticketverkaufsfunktion wird ergänzt. Der lokale Katalog umfasst damit sieben Oberbereiche und 37 Untercommunities.

Die gewünschten Communities **Barrierefrei** und **Nicht barrierefrei** werden unter **Barrierefreiheit** ergänzt. Sie dienen als Einordnung nach Veranstalterangabe, ohne geprüfte Zertifizierung oder automatische Bewertung bestehender Events. Eine fehlende Zuordnung bedeutet keine Aussage zur Barrierefreiheit. Der lokale Katalog umfasst damit acht Oberbereiche und 39 Untercommunities.

Die gewünschten Communities **FLINTA-Only** und **Queer-Only** werden unter **Queere Szene & Performance** ergänzt. Sie dienen zur Einordnung entsprechend angekündigter Veranstaltungen; konkrete Zugangsvoraussetzungen beschreibt der Veranstalter. Bestehende Profile und Eventzuordnungen bleiben erhalten. Es werden keine Identitätsabfragen oder automatischen Zugangsentscheidungen ergänzt. Der lokale Katalog umfasst damit acht Oberbereiche und 41 Untercommunities.

Veranstaltungen können mehreren Communities zugeordnet werden. Diese zusätzliche Einordnung dient der Auffindbarkeit; sie überträgt keine Verwaltungs- oder Teilnahmerechte. Eine feste verantwortliche Community verwaltet weiterhin Aufnahme, Eventzusagen, Kapazität und geschützte Informationen. Gastgeber können ausschließlich weitere Communities zuordnen, die sie selbst verwalten. Nur öffentliche Zusatzprofile erscheinen bei öffentlichen Events, in Suche und Filtern. Ein Event bleibt ein einzelner Datensatz mit einer gemeinsamen Platzkapazität. Die Zuordnung zu einem Unterbereich erzeugt keine automatische Zuordnung zum Oberbereich und umgekehrt.

## 4. Schutzgrenzen und Löschung

Das Backend prüft Berechtigungen bei jedem Zugriff und verweigert sie standardmäßig. Versteckte Schaltflächen allein sind kein Zugriffsschutz. Gäste sehen ihre eigenen Bewerbungen; Gastgeber prüfen nur Bewerbungen ihrer Community. Kollektivbewerbungen sind für Antragsteller und zuständige Prüfer im Projektteam bestimmt.

Privilegierte Secrets und `service_role` gehören ausschließlich auf den Server, niemals in den Flutter-Build. Tokens, private Adressen und Bewerbungsantworten dürfen nicht in Logs stehen. Zusammengehörige Änderungen werden als Transaktion vollständig ausgeführt oder vollständig verworfen. Wiederholte oder gleichzeitige Anfragen dürfen weder doppelte Mitgliedschaften noch eine Überschreitung der Eventkapazität erzeugen.

**Kollektiv- und Gastbewerbungen einschließlich Antworten werden zwei Kalendermonate nach Annahme, Ablehnung oder Rückzug gelöscht.** Laufende Bewerbungen bleiben während ihrer Bearbeitung erhalten. Die Regel schreibt keine zweimonatige Aufbewahrung anderer Daten vor. Mitgliedschaften und Eventbestätigungen müssen unabhängig von den später gelöschten Bewerbungsantworten bestehen können. Eine minimale, getrennte Sperrmarkierung hält nach Ablehnung oder Rückzug die erneute Bewerbung gesperrt und enthält keine Bewerbungsantworten. Fristen dieser Markierung und weiterer Datenarten sowie die technische Löschung einschließlich möglicher Sicherungen sind vor einem echten Pilot zu konkretisieren.

## 5. Nicht-Ziele der ersten Version

- Kein eigener Messenger, keine Messenger-Synchronisierung, Bots oder Gruppenimporte.
- Keine Zahlungen, Ticketverkäufe oder Provisionen.
- Keine KI-Kompatibilitätsbewertung und kein automatisches Matching.
- Keine Trust Scores oder universellen Verifizierungsabzeichen.
- Keine globalen Szeneprofile oder communityübergreifenden Personenbewertungen.
- Kein allgemeiner Aachen-Eventkatalog und keine Stadtkarte. Ein öffentlicher Bereich zeigt ausdrücklich freigegebene Communityprofile und Eventangaben sowie Informationen zu Community Access; Gastgeber bestimmen die veröffentlichten Felder. Persönliche Bewerbungen und Teilnahmestatus bleiben geschützt.
- Kein Ausweisarchiv und keine eigene Identitätsprüfung.
- Kein frei konfigurierbarer Baukasten für Kollektivbewerbungen. Für Gastbewerbungen bestimmen Gastgeber die Fragen; der bisherige Vergleichsprototyp begrenzte dies auf eine bis acht Textfragen mit Pflichtfeldoption. Die Formularumsetzung im neuen Backend bleibt offen.
- Keine native Store-Veröffentlichung im lokalen Prototyp.

## 6. Fünf entscheidende offene Fragen

1. Welche Veranstaltungstypen sollen die beiden Kollektive im Pilot anbieten?
2. Welche Kollektivformularfelder sind Pflicht, und reichen bei „Mitgliedern“ Anzahl und Funktionen statt personenbezogener Mitgliederlisten?
3. Welche Leitlinien und Prüfung gelten für die von Gastgebern festgelegten Gastbewerbungsfragen? Die Zuständigkeit für das Formular ist entschieden; verbindliche Inhaltsregeln und Moderation bleiben zu konkretisieren.
4. Wie lange bleiben Konten, Mitgliedschaften, Eventanfragen und Beschwerden gespeichert?
5. Wer bearbeitet Beschwerden, die eigene Entscheidungen des Projektteams als Betreiber betreffen?

## 7. Wie wir die drei wichtigsten Anforderungen testen

Alle folgenden Tests sind **geplante Abnahmekriterien, noch nicht ausgeführt**. Sie benötigen eine implementierte Anwendung und ein lokales Backend mit synthetischen Daten.

| Anforderung | Test mit erfundenen Konten | Erwartetes Ergebnis |
| --- | --- | --- |
| Manuelle Aufnahme und separate Eventzusage | Das Team nimmt Kollektiv A auf. Ein Gast bewirbt sich dort, versucht Selbstaufnahme und wird anschließend durch Gastgeber A aufgenommen. Er fragt ein Event an und erhält erst danach eine Zusage. Ablehnung und Rückzug werden ebenfalls durchgespielt. | Keine Selbstaufnahme; korrekter eigener Status; weder Einladung noch Mitgliedschaft geben automatisch einen Eventplatz oder die genaue Location frei. Die Altersbestätigung erscheint bei der Eventanfrage als Selbstauskunft. |
| Schutz gegen fremde Zugriffe | Ein fremder Gast, Gastgeber B, ein nicht angemeldetes Konto und ein entferntes Mitglied versuchen direkte Backend-Abrufe bekannter Bewerbungs- und Event-IDs. Berechtigte Konten dienen als Gegenprobe. | Unberechtigte erhalten keine Antworten oder privaten Locations. Neue Abrufe nach Entzug sind gesperrt. Zuständige Prüfer können weiterhin arbeiten. Die Prüfung erfolgt über normale Nutzerzugänge, nicht nur als Datenbankadministrator. |
| Konsistenz und verlässliche Löschung | Zwei Zusagen konkurrieren um den letzten Platz; eine Aufnahme wird wiederholt; ein Fehler wird zwischen zusammengehörigen Änderungen ausgelöst. Mit kontrollierter Testzeit prüfen wir die Löschfrist vor und nach Fälligkeit für angenommene, abgelehnte, zurückgezogene und laufende Bewerbungen beider Arten. | Höchstens eine Zusage für den letzten Platz, eine Mitgliedschaft je Gast und Community, keine halbfertige Aufnahme. Abgeschlossene Bewerbungen samt Antworten werden nach zwei Kalendermonaten gelöscht; laufende bleiben erhalten. Davon unabhängige Mitgliedschaften bleiben bestehen. |

Für Einsteiger: Ein positiver Test zeigt, dass eine erlaubte Aktion funktioniert. Ein negativer Test zeigt, dass eine verbotene Aktion auch bei direktem Zugriff scheitert. Ein Konkurrenztest startet Aktionen gleichzeitig und prüft, ob das Ergebnis trotzdem widerspruchsfrei bleibt.

## Quellen und Grenzen

- Nutzerentscheidungen im Projektgespräch vom 24.09.2026 einschließlich Freigabe und Antworten zu Formular, Alter und Fristbeginn.
- Ergänzende Nutzerentscheidungen zum bisherigen Vergleichsprototyp: Gastgeber legen Gastbewerbungsformulare fest; erneute Bewerbung nach Ablehnung oder Rückzug sperren und Kontakt zum Gastgeber anbieten (damalige Umsetzung 30.09.2026).
- *Community Access – Entwicklungsplan*, Version 1.0, 24.09.2026: S. 5 (Produktvertrag), S. 9 (Berechtigungen), S. 12–13 (Produktkern und Abnahme). Das ausführliche zusätzliche Kollektivformular konkretisiert die ursprüngliche Planung durch Nutzerentscheidung.

Diese Spezifikation dokumentiert den gewünschten Zustand. Sie ist weder ein Sicherheitsnachweis noch eine Freigabe für echte personenbezogene Daten oder eine Veröffentlichung. Installation, neue Dienste und Veröffentlichung sind nicht Bestandteil dieser Aufgabe.

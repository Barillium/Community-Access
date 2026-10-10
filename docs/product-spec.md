# Community Access: Produktspezifikation

Stand: 10.10.2026 · Verbindlicher V1-Umfang auf Nutzerauftrag. Lauffähige lokale Version mit ausschließlich synthetischen Daten; keine Produktionsfreigabe.

## 1. Ziel und maßgebliche Quellen

Community Access ergänzt bestehende Kollektive um geregelten Zugang zu Veranstaltungen. Bestehende Messenger bleiben bestehen. Der vorgesehene Pilot mit The Base E.V. und Not Human Collective belegt keine Teilnahmezusage; Entwicklung und KI-Kontext verwenden ausschließlich erfundene Veranstalter und Personen.

Diese Datei beschreibt die verbindlichen Produktregeln. Die [Aktionsmatrix](implementation/access-matrix.md) konkretisiert die Rechte, [Setup](setup.md) die Ausführung und [AGENTS.md](../AGENTS.md) die Arbeitsregeln. Technische Detailberichte sind Nachweise ihres jeweiligen Datums, keine zusätzlichen Produktentscheidungen. Der [V1-Entscheid](decisions/0007-v1-scope.md) begründet die Reduktion; frühere Entscheidungen sind als [Historie](history/product-decisions-through-20261009.md) erhalten.

Aktive Architektur: Flutter/Dart in `client/`, Better Auth/Node.js in `server/`, PostgreSQL und selbst betriebenes pretix. `app/`, `supabase/`, Dart-Lernübungen und Einzelaufgaben-Runner bleiben getrennte Entwicklungswerkzeuge. Ihre Tests nehmen das aktive Produkt nicht ab.

## 2. Umfang der ersten Version

| V1 enthält | Zurückgestellt im erweiterten Entwicklungsmodus |
| --- | --- |
| E-Mail-Konto, Bestätigung, Anmeldung, Wiederherstellung und Abmeldung | Google-, Apple- und Facebook-Anmeldung |
| Öffentliche chronologische Eventliste, Suche, Communities und Veranstalter | Persönliche Empfehlungen, Präferenzen, Folgen, Merkliste, Interessenzähler, Besuchssignale und separates Ortsverzeichnis |
| Öffentliche und private Einzelveranstaltungen | Veranstaltungsreihen und semi-öffentliche Veranstaltungen mit zeitgesteuerter Feldfreigabe |
| Persönliche Communityeinladung, Bewerbung, manuelle Aufnahme | Zusätzliche Bewerbungs-, Formular- und Linkwege für privaten Profilzugang |
| Communitymitgliedschaft oder ausdrückliche einzelne Eventfreigabe | Reihenfreigaben und darüber vererbte Eventsichtbarkeit |
| Eventanfrage, manuelle Zusage und geschützte genaue Location | Zusätzliche Ticketkategorien und persönliche Kategorienfreigaben |
| Ein Standardticketangebot pro Event, Zahlung, Belege, Erstattung und Einlass | Gruppenbuchung und Übertragung bleiben ausgeschlossen |
| Getrennte Moderation, Beschwerden und gemeinsame Auftrittsverwaltung | Lern-/Automationswerkzeuge gehören nicht zur Produktoberfläche |
| Deutsche/englische Bedientexte, responsive Weboberfläche | Store-Einreichung und echte native Geräteabnahme bleiben separate Schritte |

V1 ist Standard für Server und Flutter-Build. `CA_PRODUCT_EDITION=extended` aktiviert den bisherigen erweiterten Entwicklungsumfang ausdrücklich. Ein Clientrequest oder eine Kontorolle kann den Servermodus nicht ändern. Zurückgestellte Funktionen werden in V1 serverseitig begrenzt und aus der Oberfläche entfernt. Vorhandene Daten werden durch den Moduswechsel nicht gelöscht. Bestehende Bestellbelege, Zahlungsabgleich, Erstattungen und Einlassrechte werden nicht allein wegen eines ausgeblendeten Katalogeintrags widerrufen.

Einzelveranstaltungen, die noch einer Reihe zugeordnet oder semi-öffentlich sind, erscheinen in V1 nicht. Keine automatische Umwandlung, Veröffentlichung oder Entfernung bestehender Zuordnungen. Der erweiterte Modus bleibt zur bewussten Bearbeitung und für Regressionstests erhalten.

## 3. Zuständigkeiten und getrennte Rechte

- **Gast:** verwaltet das eigene Konto, eigene Bewerbungen, Anfragen, Tickets, Belege und Beschwerden. Bewerber, Mitglied, kaufberechtigter Gast und bestätigter Teilnehmer sind unterschiedliche Zustände.
- **Veranstalter:** verantwortet eigene Auftritte, Eventinhalte, Teilnahmeentscheidungen und Verkäufe. Ein angenommenes Verwalterkonto arbeitet ausschließlich am konkret delegierten Auftritt. Verkäuferzuordnung, Einladung und Entzug von Verwaltern bleiben beim verantwortlichen Konto.
- **Communitymoderator:** wird vom Plattformteam ausdrücklich einer Community zugewiesen. Nur diese Zuweisung erlaubt Communityeinladungen, Aufnahme, Formulare, Regeln und Veröffentlichungsfreigaben. Veranstalterzulassung erteilt diese Rechte nicht automatisch.
- **Plattformteam:** entscheidet über Veranstalteraufnahme, Moderatorzuweisung, Plattformmaßnahmen und eigene Prüfzuständigkeiten. Teamrechte eröffnen keinen pauschalen Zugang zu fremden privaten Eventdaten.
- **Einlass:** ist eine zeitlich begrenzte Rolle für ein konkretes Event; keine allgemeine Veranstalter- oder Moderationsberechtigung.

Ein Konto kann mehrere getrennte Zuständigkeiten besitzen. Jeder Abruf und jede Änderung prüft die aktuelle Zielressource serverseitig; versteckte Menüs vergeben oder schützen keine Rechte.

## 4. Aufnahme und Teilnahme

### Veranstalteraufnahme

Das Projektteam prüft Name, Selbstdarstellung, Veranstaltungstypen und ausdrücklich beantwortete Angaben zu Awarenesskonzept und Awarenessteam. Optionale organisatorische Angaben bleiben freiwillig; Mitgliederlisten werden nicht erhoben. Annahme erstellt Community, Veranstalterzulassung und privates Profil atomar, aber keine Moderatorrolle. Rückzug erlaubt einen neuen Antrag; eine Ablehnung erzeugt eine getrennte, nur vom Team aufhebbare Sperre.

### Communityaufnahme

**Bestätigtes Konto → persönliche Einladung → Bewerbung → manuelle Entscheidung durch Communitymoderation → Mitgliedschaft.**

Einladungen sind kontogebunden, sieben Tage gültig, widerrufbar und gehasht gespeichert. Erst erfolgreiche Einreichung verbraucht sie atomar; Vorschau und Fehler verbrauchen nichts. Das eingereichte Formular behält seinen Fragenstand. Intime Profile und Fragen nach sexuellen Vorlieben sind ausgeschlossen. Nach freiwilligem Rückzug ist eine neue Bewerbung mit gültiger Einladung möglich; nach Ablehnung oder Mitgliedschaftsentzug bleibt die Wiederbewerbung gesperrt, bis die zuständige Stelle die Sperre ausdrücklich aufhebt.

### Einzelveranstaltung ohne Ticket

**Aktueller Eventzugang → Eventanfrage → separate manuelle Zusage → geschützte genaue Location.**

Der Veranstalter bestimmt Mitgliedschaftspflicht, Pflichtantworten, Mindestalter und Kapazität. Eine einzelne Eventfreigabe öffnet weder das private Veranstalterprofil noch andere Events. Nur aktuelle Zusagen belegen Plätze; Kapazität ist eine positive ganze Zahl oder ausdrücklich unbegrenzt. Anfrage und Zusage sind nur vor Beginn möglich. Rückzug vor Beginn erlaubt eine neue manuelle Anfrage. Alter wird ausdrücklich selbst bestätigt; kein Ausweis- oder Geburtsdatenupload und keine verifizierte Altersprüfung.

### Veranstaltung mit Ticket

Öffentlicher Verkauf verlangt öffentlich freigegebene Eventinformationen und ein bestätigtes Konto, aber keine manuelle Kaufentscheidung; Mitgliedschaftspflicht ist damit nicht kombinierbar. Beim Verkauf nach Freigabe erteilt die manuelle Entscheidung ausschließlich **Kaufberechtigung**. Erst authentifiziert bestätigte Zahlung begründet Teilnahme. Einladung, Mitgliedschaft, Sichtzugang, Browserrückleitung und Kaufberechtigung reservieren keinen Ticketplatz.

Genaue Locations liegen getrennt von öffentlichen Ortsangaben. Abruf erfordert aktuelle zuständige Verwaltung oder aktuell bestätigte berechtigte Teilnahme. Entzug verhindert weitere Abrufe; bereits gelesene Informationen lassen sich nicht zurückholen. Unabhängige berechtigte Communitywege oder Einzelrechte werden beim Entzug erneut geprüft.

## 5. Events, Konto und Bedienung

Veranstalter pflegen Beschreibung, Beginn, Ende, Line-up, Genres, Einlass, optionales Mindestalter, Flyer mit Alternativtext sowie Zugänglichkeits-/Awarenessangaben. Unbekannte Ausstattung bleibt unbekannt. Öffentliche Events benötigen ein öffentliches Profil und ausdrücklich öffentliche Beschreibung, Beginn und Ortsangabe. Geschützte genaue Adressen gehören nicht in öffentliche Texte, Flyer oder Metadaten.

Events beginnen als Entwurf. Veröffentlichung erfordert gültige Veranstalter- und Communityveröffentlichungsrechte sowie Communityfreigabe. Kopien und Folgetermine sind neue Entwürfe ohne kopierte persönliche Freigaben, Anfragen oder Zusagen. Lokale ungespeicherte Entwürfe bleiben ausschließlich im Arbeitsspeicher und werden bei Abmeldung, Kontowechsel oder Sitzungsablauf entfernt. Versionsprüfung verhindert das Überschreiben neuerer Serverstände.

Registrierung erzeugt keine automatische Sitzung und verrät keinen Kontobestand. E-Mail-Bestätigung und anschließende Anmeldung bleiben getrennt. Die servergeprüfte Sitzung endet spätestens acht Stunden nach Login; Abrufe verlängern sie nicht. Tokens liegen nicht in Browserstorage. Wiederaufnahme im selben Tab speichert nur Ressourcentyp und UUID, keine Zugangscodes oder privaten Inhalte. Veraltete Antworten dürfen nach Kontowechsel keine neue Ansicht überschreiben.

Eine Plattformsperre verhindert Produktaktionen einschließlich Veranstalterverwaltung, Moderation, Team und Einlass. Identität/Wiederherstellung, eigene minimale Bestellbelege und eigene Beschwerden bleiben eng begrenzt erreichbar. Systemabgleich und Erstattungsaufgaben laufen unabhängig vom gesperrten Nutzer weiter.

## 6. Ticketvertrag

Jeder Veranstalter bleibt Verkäufer. Vorgesehen sind selbst betriebenes pretix und Stripe Connect mit Direct Charges. Bank-/Identitätsdaten werden später beim Anbieter erhoben. Es gibt keinen erfundenen Provisionssatz und keinen Käuferaufschlag. EUR, ein persönliches Ticket pro bestätigtem Konto und Event, keine Übertragung oder Gruppenkäufe.

Nur der Ticketdienst reserviert Kontingente, im Checkout für 15 Minuten. Preis, Verkäufer, Event, Betrag, Währung und Bestellung werden serverseitig und beim Anbieterabgleich geprüft. Gebührenversion und Beträge bleiben je Bestellung festgehalten. Webhookdaten und Browserrückkehr bestätigen allein keine Zahlung. Wiederholte Aufrufe dürfen keinen zusätzlichen aktiven Auftrag oder doppelte Zahlung/Erstattung erzeugen.

Absage oder tatsächlicher Berechtigungsentzug sperrt betroffenen Einlass und erzeugt eine Erstattungsprüfung. Der verantwortliche Veranstalter beziehungsweise angenommene Verwalter genehmigt Teil-/Vollerstattungen einschließlich ausdrücklicher Provisionsrückzahlung. Eine reine Verkaufspause erhält bezahlte Tickets. Onlineeinlass prüft Scannerzuständigkeit, Ticketinhaber, Zahlung, Eventrecht und Sperren atomar; Verbindungsfehler sind keine Bestätigung.

V1 läuft ausschließlich mit synthetischen Zahlungsantworten und vorhandener lokaler pretix-Installation. Echte Stripe-Sandbox, Verkäufer-/Betreiberangaben, Provision, Erstattungsverantwortung, Finanzaufbewahrung und Betriebsabnahme bleiben Voraussetzungen vor echtem Verkauf. Eine reine Konfigurationsumschaltung aktiviert keinen produktiven Zahlungsbetrieb.

## 7. Schutz und Aufbewahrung

| Datenklasse | Geltende Regel und Grenze |
| --- | --- |
| Abgeschlossene Veranstalter-/Communitybewerbungen samt Antworten | Zwei Kalendermonate nach Annahme, Ablehnung oder Rückzug in Europe/Berlin; Monatsende wird begrenzt. Laufende Anträge bleiben. |
| Mitgliedschaft und minimale Sperrmarkierung | Unabhängig von gelöschten Antragsantworten; keine neue Frist erfunden. |
| Eventinformationen und gewöhnliche Eventbezüge | Ab exakt 168 Stunden nach tatsächlichem Ende nicht mehr abrufbar. Bisherige Bereinigung löscht nur dafür freigegebene, nicht durch neue Referenzen gebundene Events. |
| Events mit neuen Kategorie-, Sperr- oder Einlassreferenzen; neue Moderations-/Einlassdaten | Keine neue physische Löschroutine freigegeben; zunächst aggregierte Vorschau. Die Abrufgrenze bleibt bestehen. |
| Minimale Bestellzuordnung und offene Erstattungen | Getrennter Lebenszyklus, keine kaskadierende Eventlöschung. Finanzfristen bleiben vor echtem Verkauf zu entscheiden. |
| Kontolöschanfrage | Authentifizierte Anfrage und erneute Bestätigung; keine behauptete automatische Löschung. Bearbeitung, Restdaten und Backups bleiben gesondert zu klären. |

Frühere Event-/Antragsbereinigung und die Vorschau neuer Datenklassen sind verschiedene Bereiche. Es wird keine Löschung aus Backups, WAL, Browserresten oder Empfängerkopien behauptet. Nur synthetische Daten in Entwicklung, Tests und KI-Kontext. Secrets bleiben serverseitig; Logs enthalten keine Tokens, privaten Adressen oder Antragsantworten.

## 8. Nicht-Ziele und Abnahme

Keine Messenger-Synchronisierung, Bots/Gruppenimporte, Trust Scores, KI-Kompatibilitätswertung, globalen Szeneprofile oder Personenbewertungen. Keine Veröffentlichung, echten Zahlungen, automatische Kontolöschung oder zusätzlichen Dienste aus diesem V1-Auftrag ableiten.

Abnahme prüft erlaubte und verbotene Direktzugriffe, Aufnahme-/Entzugs- und Konkurrenzfälle, aktuellen Sitzungsbezug, Ticketreservierung, Zahlung, Erstattung und einmaligen Einlass. V1-Prüfungen und Regressionen des erweiterten Modus werden separat ausgewiesen. Der ältere Runner-Scope `product` bleibt gesperrt; das ist dessen technische Umfangsgrenze, keine Aussage, dass das aktive Backend fehlt.

Native Projekte bleiben vorbereitet. Kontoalter ab 16 ist eine noch zu prüfende Startvorgabe und keine Store-Altersfreigabe oder Eventeinlassberechtigung. Reale Anbieter-, Rechts-, Geräte-, Barrierefreiheits- und Betriebsabnahme bleiben offen. Eine Lizenz für den eigenen Code ist weiterhin nicht gewählt.

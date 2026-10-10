# Ticketing: rechtliche Ersteinschätzung und lokale Schutzabläufe

Stand: 09.10.2026. Arbeitsannahme: Betrieb in Deutschland, Veranstaltungen zunächst in Deutschland. Dies ist eine technische Umsetzung mit rechtlicher Orientierung, keine anwaltliche Freigabe. Ortsabhängige Genehmigungen, weitere Länder und die tatsächliche Betreiberrolle sind vor echtem Verkauf gesondert zu prüfen.

## Rechtliche Orientierung

Der Veranstalter bleibt Ticketverkäufer. Community Access trägt dennoch Verantwortung für eigenes Handeln und den Umgang mit bekannten Rechtsverstößen. Die mögliche Hosting-Haftungsbegrenzung nach Artikel 6 DSA setzt insbesondere fehlende konkrete Kenntnis beziehungsweise zügiges Tätigwerden nach Kenntniserlangung voraus. Artikel 8 verlangt keine allgemeine Überwachung. Artikel 6 Absatz 3 enthält eine wichtige Ausnahme für bestimmte verbraucherrechtliche Haftung bei irreführender Darstellung der Anbieterrolle. Artikel 16 und 17 betreffen Meldungen und begründete Einschränkungen. Größenbezogene Ausnahmen in Artikeln 19 und 29 ersetzen keine pauschale Befreiung von Hostingpflichten. Ob Community Access Hostingdienst, Online-Plattform beziehungsweise Vertragsplattform ist, bleibt zu prüfen. [DSA](https://eur-lex.europa.eu/legal-content/DE/TXT/HTML/?uri=CELEX:32022R2065).

Vorsätzliche Hilfe zu einer vorsätzlich begangenen rechtswidrigen Straftat kann Beihilfe sein. Eine fehlende oder unklare Veranstaltungsgenehmigung beweist allein keine solche Straftat. [§ 27 StGB](https://www.gesetze-im-internet.de/stgb/__27.html).

„Privatparty“ ist im Produkt ausschließlich eine Zugangsbeschreibung. Die Öffentlichkeit einer Musikwiedergabe richtet sich unter anderem nach persönlichen Beziehungen; ein Login oder privater Tickettyp entscheidet darüber nicht. Veranstalter müssen Veranstaltungsort, Nutzung, Sicherheitsauflagen, Jugendschutz und gegebenenfalls Musikrechte tatsächlich prüfen. [§ 15 Absatz 3 UrhG](https://www.gesetze-im-internet.de/urhg/__15.html). Baurecht ist ortsabhängig; die [Bauordnung NRW](https://recht.nrw.de/lrgv/gesetz/01092026-landesbauordnung-2018-bauo-nrw-2018/) ist nur eine regionale Grundlage, keine universelle Genehmigungsliste.

Verkäuferdaten ersetzen keine vollständigen Betreiberangaben. Name, Anschrift und weitere einschlägige Angaben bleiben vor öffentlichem Betrieb zu vervollständigen. [§ 5 DDG](https://www.gesetze-im-internet.de/ddg/__5.html). Die klare Zahlungspflicht am verbindlichen Bestellschritt ist vor deutschem Verbraucherbetrieb gesondert zu prüfen. [§ 312j BGB](https://www.gesetze-im-internet.de/bgb/__312j.html).

## Verbindliche Produktregeln

Präzisierung vom 09.10.2026: Ticketing wird grundsätzlich ermöglicht. Die Abgrenzung erfolgt durch klare Verkäuferdarstellung, ausdrückliche Übernahme der Veranstalterverantwortung und nachvollziehbare Bestellnachweise. Community Access führt keine allgemeine behördliche Genehmigungsprüfung durch. Die Verantwortungserklärung ist weder eine Genehmigung noch eine Zusage, dass bereits alle Voraussetzungen geklärt sind. Veranstalter bleiben verpflichtet, die für ihre Veranstaltung erforderlichen Voraussetzungen rechtzeitig zu erfüllen. Eigene gesetzliche Plattformpflichten und gezielte Maßnahmen bei konkreten Hinweisen bleiben bestehen.

Die freigegebenen Projektregeln aus `AGENTS.md`, [Produktspezifikation](product-spec.md), [Setup](setup.md), [Git-Workflow](workflow.md) und [Codex-Workflow](codex-workflow.md) gelten. Änderungen bleiben lokal, mit vorhandenen Abhängigkeiten und synthetischen Daten. Es werden keine echten E-Mails oder Zahlungen erzeugt.

Ein Verkäuferdatensatz gehört zum Veranstalterprofil. Name, Kontaktanschrift, synthetische Kontakt-E-Mail und erklärte Unternehmereigenschaft werden getrennt von geschützten Eventadressen gespeichert. Nur der Profileigentümer kann diese Verkäuferdaten ändern. Aktive berechtigte Profilverwalter dürfen Erklärungen für ihre Veranstaltungen abgeben. Die Oberfläche zeigt die Verkäuferangaben vor Standard- und Kategorienkauf sowie den beim Bestellbeginn gespeicherten Stand im eigenen Bestellbeleg.

Eine Erklärung ist ausdrücklich zu bestätigen; die Checkbox beginnt stets leer, auch bei vorhandener Erklärung. Die Erklärung bestätigt die Verantwortung für Durchführung, erforderliche Genehmigungen, Nutzungsrechte und Sicherheit. Ohne diese Übernahme oder bei ausdrücklichem Zurückziehen bleibt der Verkauf geschlossen; Vorbereitung und Verwaltung bleiben möglich. Die letzte Erklärung muss bestätigt sein und zur aktuellen Event-, Verkäufer- und Textversion passen. Verkäufer- oder Eventänderungen verlangen eine neue Bestätigung. Bestehende Events werden durch die Migration nicht automatisch bestätigt. Ausschließlich der getrennte synthetische Demo-/Testaufbau setzt seine ausdrücklich erfundenen Angaben über `legal_fixtures.mjs`.

`local-responsibility-draft-20261009` bezeichnet den neuen vorbereiteten Bedingungenstand zur Veranstalterverantwortung. Frühere Erklärungen unter `local-draft-20261009` werden erhalten und nicht umgedeutet; neue Verkäufe benötigen eine ausdrückliche Bestätigung des neuen Textstands. Der Server liefert diesen Stand zum Formular und prüft ihn beim Speichern, damit ältere Formulare nicht ungelesen den neuen Text bestätigen. Bereits bezahlte Tickets bleiben bei einem bloßen Textwechsel gültig. Dieser Bedingungenstand ist kein geprüfter oder abschließend formulierter Vertragstext. Die Umsetzung erfindet weder Rechtsform und Betreiberanschrift noch geltende Vertragsbedingungen. Eine SQL-Schutzfunktion verhindert nachträgliche Änderung der Verkäufer- und Erklärungskopien in Bestellungen. Alte Bestellungen ohne solche Kopien bleiben als Altbestand erkennbar; es erfolgt keine rückwirkende erfundene Bestätigung.

## Meldung und Bearbeitung

„Veranstaltung melden“ ist in Event- und Ticketansichten sowie in „Hilfe & Kontakt“ und den allgemeinen Informationslinks verfügbar. Die allgemeine Einreichung benötigt kein Konto. Das Formular erhebt Inhaltsreferenz, konkrete Begründung, Name, synthetische E-Mail und die Erklärung nach bestem Wissen. Bei Hinweisen auf sexuellen Missbrauch von Kindern können Kontaktangaben entfallen. Keine Uploads, kein Abruf fremder URLs. Einladungs- und Tokenreferenzen werden zurückgewiesen; der Hinweis fordert ausdrücklich dazu auf, unnötige personenbezogene Daten wegzulassen.

Unbekannte und geschützte Eventreferenzen erhalten dieselbe strukturelle Empfangsantwort. Die Einreichung sucht keine Events und gibt weder Titel noch Location oder Existenzbestätigung zurück. Meldungen alleine verändern keine Rechte.

Nur das Plattformteam liest den getrennten rechtlichen Meldungsbereich und übernimmt die Zuständigkeit. Eine Entscheidung benötigt Versionen und eine konkrete Begründung einschließlich rechtlicher oder regelbezogener Grundlage. Profileigentümer und aktive Mitverwalter dürfen die eigene Veranstaltung nicht als Team entscheiden. Veraltete Entscheidungen werden abgewiesen. Eine frei eingegebene Event-ID wird zuerst für das Team geladen; erst die folgende ausdrückliche Entscheidung verwendet den angezeigten Stand.

Eine unbegründete oder nicht zuordenbare Meldung kann mit „keine Maßnahme“ und Begründung geschlossen werden. Das verändert keine Event-, Kauf- oder Einlassrechte. Das Team sieht Entscheidungen und Stellungnahmen im Verlauf. Veranstalter sehen ausschließlich ihre eigenen Entscheidungen und können eine erneute Prüfung verlangen. Die Stellungnahme öffnet den Vorgang, hebt aber keine Maßnahme auf. Wiederholte identische Stellungnahmen sind idempotent.

Empfang und Entscheidung erzeugen dauerhafte Einträge in einem lokalen synthetischen Testpostfach. Meldendenkontakte werden nicht automatisch an Veranstalter weitergegeben. Das Postfach ist nur für das Team zugänglich. Ein echter Zustellkanal und seine Erreichbarkeit sind nicht implementiert oder geprüft.

## Maßnahmen und Bestandsschutz

| Zustand | Neue Käufe / unbezahlte Checkouts | Bereits bezahlte Tickets | Sichtbarkeit |
| --- | --- | --- | --- |
| Aktiv, aktuelle Erklärung | Im bisherigen Berechtigungsrahmen möglich | Bleiben im bisherigen Berechtigungsrahmen | Bestehende Eventregeln |
| Verkaufspause zur Klärung | Gesperrt; auch gestartete unbezahlte Bestellungen dauerhaft gestoppt | Bleiben gültig, sofern keine unabhängige andere Sperre besteht | Bestehende Eventregeln |
| Bestätigtes Verbot, konkrete Gefahr oder Absage | Gesperrt | Einlasshalt und Erstattungsprüfung | Für normale Gäste ausgeblendet; Verwaltung und eigene Finanzbelege bleiben |
| Ausdrücklich wieder geöffnet | Neue Bestellungen bei aktuellen Voraussetzungen möglich | Gestoppte Bestellungen / Einlasssperren werden nicht automatisch reaktiviert | Bestehende Eventregeln |

Verkaufspausen ändern keine Mitgliedschaften oder persönlichen Kauf-/Eventfreigaben. Standard- und private Kategorien verwenden dieselben Servergrenzen. Auch Checkoutübergabe, erneute native pretix-Sitzungsprüfung, Zahlungsabgleich und Online-Einlass berücksichtigen diese Grenzen. Eine unabhängig eingehende Zahlung nach dem Stopp wird finanziell erfasst, erzeugt aber keine neue Teilnahme und erhält eine Erstattungsaufgabe. Eine Pause nach bereits bestätigter Zahlung lässt diese bezahlte Teilnahme bestehen. Der gemeinsame Schreibschutz und erneute Zustandsprüfung entscheiden konkurrierende Vorgänge; ein älterer Zwischenstand darf keinen gestoppten Checkout reaktivieren.

Bei einer Sperre entstehen Aufgaben zur Erstattungsprüfung, keine ungeprüften automatischen Geldtransfers. Die vorhandene berechtigte Erstattungsfreigabe und anteilige Gebührenberechnung gelten weiter. Wiederholungen erzeugen keine doppelte offene Erstattungsaufgabe. Verkäuferkopien, Bestellbelege, rechtliche Entscheidungen und offene Finanzaufgaben haben keine löschende Event-Fremdschlüsselbindung. Der Test weist dies für Eventlöschung nach; weitere bestehende Löschhindernisse bei Kategorien bleiben bestehen.

## Schnittstellen und technische Grenzen

- `/api/ticketing/profiles/:id/seller`: Verkäuferstand lesen/ändern.
- `/api/ticketing/events/:id/declaration`: Verantwortungserklärung lesen/versioniert speichern. Die Antwort enthält den aktuellen `terms_version`-Textstand; jedes Speichern muss diesen ausdrücklich übergeben. Fehlender oder veralteter Textstand wird abgewiesen.
- `/api/legal/reports`: öffentliche Einreichung; Lesen nur Team.
- `/api/legal/reports/:id`: Teamdetails mit Verlauf.
- `/api/legal/reports/:id/assign`, `/decision`: zugewiesene, versionierte Teamverwaltung.
- `/api/legal/events/:id`: ausschließlich Team; minimaler Prüfstand ohne geschützte Location.
- `/api/legal/mine`, `/api/legal/actions/:id/statement`: profilbezogene Entscheidungen / Stellungnahmen.
- `/api/legal/mailbox`: synthetische Teamnachweise, keine Zustellung.

Migration `0009-legal-ticketing.sql` ist lokal additiv. Rechtsmeldungen verwenden eigene Tabellen; personenbezogene Communitymoderation bleibt getrennt. Eingaben sind begrenzt, JSON-/Bodygrenzen und vorhandene aggregierte Anfragebudgets gelten. Meldungstexte, Kontaktangaben und Übergabecodes werden nicht in Anwendungslogs geschrieben. Der Rechtsbereich wird nur im synthetischen lokalen Produktmodus registriert; die öffentliche Gateway-Freigabeliste wurde nicht erweitert. Die aktuellen Listen zeigen höchstens 100 Einträge; Pagination, Suche und betriebliche Bearbeitungsfristen müssen vor größerem Betrieb ergänzt werden.

## Noch vor echtem Betrieb zu erledigen

Anwaltlich zu klären sind die tatsächliche Vermittler-/Verkäuferdarstellung, anwendbare DSA-Pflichten und Ausnahmen, Vertragsbedingungen, Verbraucherinformationen sowie standortbezogene Veranstalterpflichten. Verkäuferstatus ist derzeit eine Selbstauskunft, keine Identitäts- oder Unternehmerprüfung. Es gibt keine behördliche Genehmigungsprüfung und keine pauschale Legalitätsgarantie.

Vollständige Betreiberangaben, Datenschutzrechtsgrundlagen, Empfänger und zweckbezogene Aufbewahrung fehlen noch. Das neue dauerhafte Meldungs-/Nachweisarchiv hat bewusst keine erfundene Löschfrist und darf nicht mit realen Daten befüllt werden, bevor diese Regeln umgesetzt sind. Reale Zustellung, erreichbare Beschwerden, Zuständigkeiten und Reaktionsfristen sowie der Umgang mit akuten Gefahren und möglichen Behördenmeldungen müssen organisatorisch eingerichtet werden. Verdachtsfälle mit Gefahr für Leben oder Sicherheit benötigen einen gesonderten Eskalationsprozess; das lokale Testpostfach erfüllt diesen nicht.

Für echte Verkäufe bleiben Stripe- und pretix-Nachweise, Vertrags-/Datenschutzprüfung, klare deutsche Zahlungsinformation am nativen Bestellbutton und dokumentierte Verantwortlichkeiten erforderlich. Der aktuell beobachtete native Testbutton „Place binding order“ ist kein Abnahmenachweis für deutsches Verbraucherrecht.

Prüfergebnisse und Nachweisgrenzen stehen in [lokaler Abnahme](qa/legal-ticketing-20261009.md).

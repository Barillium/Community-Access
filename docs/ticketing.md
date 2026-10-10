# Ticketing: pretix und Stripe Connect im lokalen Testumfang

> Einordnung für V1 · 10.10.2026: Dieser datierte Detailbericht beschreibt den damaligen Implementierungsstand einschließlich des erhaltenen erweiterten Modus. Maßgebliche Produktregeln und Umfang stehen ausschließlich in der [Produktspezifikation](product-spec.md); aktuelle Start- und Prüfbefehle im [Setup](setup.md). Historische Statusangaben und Prüfergebnisse sind keine heutige Funktions- oder Betriebsfreigabe.

Stand: 05.10.2026. Nutzerauftrag auf Branch `codex/pretix-ticketing-20261005`. Bestehende offene Arbeit wurde erhalten. Gelesene Arbeitsgrundlagen: Stamm-`AGENTS.md`, Produktspezifikation, Setup, Git-Workflow und Codex-Workflow. Dies ist manuelle Umsetzung; keine neue Runnerfreigabe, kein Commit oder Deployment.

## Gelieferter lokaler Ablauf

Flutter unter `client/` enthält Ticketkauf, Bestellstatus, eigene Ticketbelege, Veranstaltereinstellungen und Erstattungsaufgaben sowie eine getrennte Teamoberfläche für die Provision. Testzahlungen und Dokumente sind ausdrücklich synthetisch beschriftet. Ein Testbeleg ist kein gültiges Eintrittsticket.

`server/ticketing.mjs` verwaltet persönliche Kaufberechtigungen, Verkäuferzuordnung, Gebührenstand und Erstattungsaufgaben. Der getrennte HTTP-Vertragstest-Dienst `server/synthetic_pretix.mjs` verwaltet Plätze, 15-Minuten-Reservierungen und simulierte Zahlungen in einer eigenen PostgreSQL-Datenbank. **Dieser Dienst ist keine pretix-Installation und verwendet nicht die native pretix-API.** Er erlaubt die lokale Prüfung der Rechte, Ausfälle und Geldberechnung ohne echten Verkauf.

Bestehende Events bleiben im Modus `none`. Im Modus `public` sind bestätigtes Konto und veröffentlichte Eventinformationen erforderlich; Mitgliedschaftspflicht ist ausgeschlossen. Im Modus `approval` bleibt die persönliche manuelle Entscheidung erforderlich und heißt `purchase_eligible`. Sie reserviert keinen Platz. Erst der authentifizierte Ticketdienstabruf eines bezahlten, weiterhin berechtigten Auftrags erzeugt Teilnahme. Weiterhin gelten die bisherigen Location-/Zeitregeln.

Es gibt keinen allgemeinen Provisionsstandard. Die Demo setzt ausdrücklich 500 Basispunkte, also 5 Prozent, für synthetische Fixtures. Das Team muss einen Prozentsatz setzen. Integer-Cents und ganzzahlige Berechnung vermeiden Rundungsfehler; 12,50 EUR bei 5 Prozent ergeben 0,63 EUR Provision. Jede Bestellung hält Preis, Gebühr, Prozentsatz in Basispunkten und Gebührenversion fest. In der nativen Ermäßigungsprüfung sinkt 12,50 EUR auf 10,00 EUR; die Gebühr beträgt dann 0,50 EUR. Eine Teilrückzahlung von 6,25 EUR ergibt hier kumulativ 0,32 EUR Gebührenrückzahlung; der zweite Teil bringt diese auf insgesamt 0,63 EUR. Kein Käuferaufschlag.

## Schnittstellen und Schutz

Alle Browserzugriffe verwenden `/api/ticketing/` und die bestehende bestätigte Sitzung:

| Methode/Pfad | Zweck |
| --- | --- |
| GET/POST `fee` | Plattformteam: Pflichtsatz und Gebührenversion |
| GET/POST `profiles/{id}/connection` | Verantwortliches Konto und angenommene Auftrittsverwalter lesen den Status; nur das verantwortliche Konto ändert die ausschließlich simulierte Verbindung |
| GET/POST `events/{id}/config` | Veranstalter: Modus, Testticket, Centpreis und Kontingent |
| GET `events/{id}/offer` | Frisch geprüfte Kaufmöglichkeit und Ticketdienst-Verfügbarkeit |
| POST `events/{id}/checkout` | Ein persönlicher Auftrag; keine Clientpreise oder fremden Konto-IDs |
| GET `mine`, `orders/{id}`, `orders/{id}/ticket` | Nur eigene Bestellungen; synthetischer Beleg oder kontogebundener nativer Download |
| POST `orders/{id}/simulate` | Ausschließlich eigene Testzahlung im synthetischen lokalen Betrieb |
| GET `profiles/{id}/refunds`, POST `refunds/{id}/approve` | Zuständiger Veranstalter prüft und genehmigt Erstattungen |
| POST `webhook` | Unvertrauenswürdiger Hinweis löst authentifizierten Abruf aus |
| POST `orders/{id}/handoff`, `orders/{id}/redeem` | Kontogebundene, einmalige Browserübergabe mit 60 Sekunden Gültigkeit |

Die privaten `internal/redeem`-/`internal/validate`-Routen erfordern zusätzlich Loopback und Dienstauthentifizierung. Sie bleiben ohne native Itemzuordnung geschlossen. Die Zuordnung wird ausschließlich aus der authentifizierten pretix-Konfigurationsantwort übernommen. Sie sind nicht in der öffentlichen Gateway-Routenliste enthalten.

Der Ticketdienst besitzt eine eigene Datenbankrolle. Der App-Prozess hat keinen Datenbankwechsel zum Ticketbestand und keine DDL-, Rollen- oder Migrationsrechte; Teamzuordnung und Migrationsnachweis sind für ihn nur lesbar. Plattform-/Dienstzugangswerte bleiben serverseitig. Kein Ticket enthält geschützte Location oder Antragsantworten.

Lokale Migration `server/migrations/0002-ticketing.sql` ist additiv und durch den bestehenden Hashnachweis geschützt. Finanzzuordnungen haben bewusst keine kaskadierenden Fremdschlüssel auf Event, Profil oder Konto. Die bisherige Eventlöschung nach 168 Stunden löscht diese Zuordnungen nicht. Finanzaufbewahrungsfristen und spätere Datenbereinigung müssen separat festgelegt werden.

Ein gemeinsamer Zugangs-Schreiblock verhindert widersprüchliche Freigaben. Der getrennte Ticketdienst entscheidet transaktional über den letzten Platz. Wiederholbare Auftrags- und Erstattungs-IDs überstehen verlorene Antworten und Neustarts. Ein regelmäßiger Abgleich läuft alle fünf Sekunden. Ältere Antworten dürfen bestätigte Zahlung und kumulative Erstattungen nicht zurücksetzen. Entzug/Absage sperrt zuerst lokal, dann beim Ticketdienst; bestätigte Zahlungen werden zur manuellen Erstattung vorgelegt. Eine Browserrückleitung ist kein Zahlungsbeleg.

## Native pretix-Integration

Nach ausdrücklicher Installationsfreigabe läuft pretix **2026.8.0** mit dem ergänzenden Plugin unter `pretix-plugin/` in einer isolierten Umgebung. Es verwendet echte native `Event`, `Item`, `Quota`, `CartPosition`, `Order`, `OrderPayment` und `OrderRefund` sowie den nativen CartManager, Bestellprozess, PDF-Renderer und Einlassdienst. Der authentifizierte Loopback-Adapter ist Teil des Plugins; er greift auf diese Modelle und Dienste zu. Die separate Vertragstest-Datenbank ersetzt den nativen Nachweis nicht.

Flutter fordert zunächst eine native Browser-Challenge an. Die bestätigte Plattform-Sitzung erhält einen einmaligen, 60 Sekunden gültigen Übergabecode. Das Plugin konsumiert ihn serverseitig, bindet die bestehende Reservierung an die native Sitzung und öffnet den bestehenden pretix-Checkout. Codes und Challenges stehen in POST-Daten, niemals in URLs. Weitergegebene native Bestell-/Ticketlinks sowie nicht gebundene Eventseiten werden abgewiesen. Bei jedem geschützten nativen Abruf wird die aktuelle Kauf-/Ticketberechtigung serverseitig geprüft.

Die Cart-/Order-Hooks lassen ausschließlich ein persönliches Ticket zum geschützten Preis zu. Der native Preis nach einer automatisch angewandten Ermäßigung finalisiert den Auftrag vor Zahlung; danach bleiben Preis und Gebührenstand unveränderlich. Gebührenänderungen im Browser oder weitere Positionen werden verweigert. Eine Änderung des Warenkorbpreises nach der verbindlichen Zuordnung erfordert einen neuen autorisierten Auftrag. Der Zahlungsanbieter gibt keinen Käuferaufschlag zurück.

Der bestehende Stripe-Kartenanbieter wird abgeleitet. `_connect_kwargs` erhält den geschützten `application_fee_amount`; die echte Direct-Charge-Strecke verlangt zusätzlich das passende verbundene Testkonto und Testschlüssel. Im ausdrücklich lokalen Modus wird die Stripe-Antwort simuliert und eine native Zahlung bestätigt. Die native Bestellung hält den ursprünglichen 15-Minuten-Ablauf ein; unbezahlte Bestellungen werden danach mit dem pretix-Dienst auf abgelaufen gesetzt. Verspätete simulierte Einnahmen bleiben gesperrt und bekommen eine Erstattungsaufgabe, ohne einen gültigen Eintritt zu erzeugen.

Entzug sperrt und storniert native Ticketpositionen. Bei einer ordnungsgemäß bezahlten Bestellung erzeugt die Veranstalterfreigabe native Teil-/Vollerstattungen mit einer ausdrücklichen simulierten Gebührenrückzahlungsquittung. Deren Zielbetrag wird kumulativ berechnet, damit der letzte Teil die gesamte Provision zurückgibt. Eine verspätete simulierte Einnahme ohne gültige native Zahlung hält stattdessen eine minimale Erstattungszuordnung; daraus entsteht kein Ticket.

**Alle Stripe-Konten, Zahlungsantworten und Gebührenrückzahlungen dieses Umfangs sind synthetisch.** Ein gespeicherter simulierter Gebührenbeleg beweist keine Stripe-API-Ausführung. Echtes Connect-Onboarding, echte Stripe-Ereignisse, tatsächliche explizite Application-Fee-Rückzahlungen und deren Sandbox-Abnahme bleiben vor echtem Verkauf erforderlich. Native Laufzeittests werden getrennt von diesen offenen Nachweisen ausgewiesen.

## Installation und Lizenzprüfung

Geprüfte stabile Version: **pretix 2026.8.0**, Python mindestens 3.11 laut veröffentlichten Paketmetadaten. Die Wheel-Datei wurde statisch geprüft und nach der ausdrücklichen Nutzerfreigabe unverändert in `.local/pretix-2026.8.0/venv` installiert. Geprüfte Laufzeit: Python 3.12.14 auf macOS ARM64. Django 5.2.17 und Stripe-SDK 7.9.0 gehören zur festgehaltenen Auflösung; Vendor-Quelltext wurde nicht geändert. SHA-256:

`a78932e698778d873530d67f25a57c28d1c09b1bfb1a22ec817c00d90397db85`

[Offizielle Paketmetadaten](https://pypi.org/project/pretix/2026.8.0/), [pretix-Quellcode und Lizenz](https://github.com/pretix/pretix), [AGPLv3](https://www.gnu.org/licenses/agpl-3.0.html). pretix verwendet AGPLv3 mit zusätzlichen Bedingungen; deren Ausnahmen für entfernte Nutzung gelten nicht pauschal für eine Ticketplattform für Dritte. Vor Veröffentlichung müssen die einschlägigen Quellbereitstellungs-, Änderungskennzeichnungs- und Hinweisbedingungen erfüllt werden. Diese Prüfung ist keine juristische Freigabe.

Die Freigabe „Lokale Installation und Prüfung freigeben“ umfasst die isolierte Version und ihre erforderlichen Python-Abhängigkeiten. Vor Installation wurden Version, Lizenzmetadaten und Auflösung geprüft. Die 133 Pakete sind in `pretix-plugin/constraints-2026.8.0.txt` festgelegt; Lizenzmetadaten und Wheel-Hashes stehen in `pretix-plugin/dependency-review-20261005.json`. Keine globale Installation, Stripe-Schlüssel, Cloudressource oder kostenpflichtiger Tarif wurde eingerichtet. Selbstbetrieb benötigt später Infrastruktur; Stripe- und Hostingkosten sind vor echtem Verkauf separat zu prüfen. Die lokale Entwicklungs-WSGI-Laufzeit, eager Celery-Ausführung und synthetischen Datenbanken sind kein Produktionssetup.

## Nachweise und verbleibende Voraussetzungen

Die beobachteten Ergebnisse stehen in [Abnahme vom 05.10.2026](qa/ticketing-20261005.md). Start und Prüfkommandos stehen unter [Setup](setup.md#lokale-ticketing-demo-05102026). Backend, Flutter, Browser, importfreie Plugin-Policy und native pretix-Prüfung werden getrennt ausgewiesen. **Echte Stripe-Sandbox und Produktion sind noch nicht geprüft.**

Für echten Verkauf fehlen außerdem ausdrücklich gesetzter Provisionssatz, Verkäuferangaben, Bedingungen, Finanzaufbewahrungsfristen und die Stripe-Sandbox-Nachweise. Ein lokaler Test gibt keine Veröffentlichungsfreigabe.

Technische Grundlage: [Stripe Direct Charges und Erstattungen](https://docs.stripe.com/connect/direct-charges?platform=web&ui=stripe-hosted) und [pretix Webhooks](https://docs.pretix.eu/dev/api/webhooks.html). Direct Charges benötigen die ausdrückliche Rückgabe der Application Fee; die echte API-Ausführung muss diese zusätzlich zur bereits geprüften simulierten Centberechnung nachweisen.


## Private Kategorien · lokale Erweiterung 08.10.2026

Der freigegebene Ausbau ergänzt Kategorien mit eigener Sichtbarkeit, Kaufregel, Preis, Verkaufsfenster und Kontingent. Der native Adapter bindet jede Kategorie an einen pretix-Artikel und ein eigenes Kontingent unter der gemeinsamen Eventkapazität. Inventar bleibt ausschließlich beim Ticketdienst; die Plattform prüft aktuelle Event- und Kategoriebedingungen sowie ein aktives Ticket je Konto und Event. Geldbeträge, EUR, Verkäufer, Event, Kategorie und Bestellung werden beim authentifizierten Abgleich erneut geprüft. Benachrichtigungen allein bestätigen keine Zahlung.

Communityentzug prüft weitere gültige Communitywege und persönliche Eventgrants. Reine Kaufbedingungen einer Kategorie entziehen nach bestätigter Zahlung kein fortgeltendes Eventrecht. Verlorener Eventzugang setzt einen Einlasshalt und eine Erstattungsprüfung; ein minimaler Bestellnachweis bleibt verfügbar. Online-Einlass prüft zeitlich gültige Scannerrolle, Konto, Zahlung, Event und Sperren atomar. Der neue Plattformcode wird manuell eingegeben; eine neue Kameraerkennung ist nicht integriert.

Nachweise und verbleibende Grenzen: [Prüfbericht](implementation/report.md). Drei lokale Pilotschalter pausieren neue Zugangs- und Kaufaktionen, während Abgleich, Erstattungen und Moderation erhalten bleiben: [Betrieb](implementation/operations.md). Keine neuen Finanzaufbewahrungsfristen, echten Stripe-Zahlungen oder Veröffentlichung.

## Rechtliche Schutzabläufe · lokale Erweiterung 09.10.2026

Verkäuferverwaltung, versionierte Bestätigungen der Veranstalterverantwortung und getrennte Inhaltsmeldungen ergänzen das Ticketing. Veranstalter übernehmen Verantwortung für Durchführung, erforderliche Genehmigungen, Nutzungsrechte und Sicherheit; die Plattform verlangt keine pauschale behördliche Vorabprüfung. Ohne aktuelle Verantwortungsbestätigung ist auch der private Kategorienkauf gesperrt. Verkaufspause und Einlasshalt sind getrennt; gestoppte Bestellungen werden durch Wiederöffnen nicht reaktiviert. Bestellungen behalten unveränderliche Verkäufer-/Erklärungskopien. Hinweise werden ausschließlich im neuen lokalen synthetischen Testpostfach nachgewiesen. [Verbindliche Regeln und Ersteinschätzung](legal-ticketing.md), [Prüfergebnisse](qa/legal-ticketing-20261009.md).

# Öffentliche Interessenzähler aus der Merkliste

> Einordnung für V1 · 10.10.2026: Dieser datierte Detailbericht beschreibt den damaligen Implementierungsstand einschließlich des erhaltenen erweiterten Modus. Maßgebliche Produktregeln und Umfang stehen ausschließlich in der [Produktspezifikation](product-spec.md); aktuelle Start- und Prüfbefehle im [Setup](setup.md). Historische Statusangaben und Prüfergebnisse sind keine heutige Funktions- oder Betriebsfreigabe.

Nutzerauftrag und lokale Umsetzung vom 02.10.2026. Der Nutzer hat ausdrücklich bestätigt, dass auch einzelne Events merkbar und zählbar sein sollen. Ausschließlich synthetische Entwicklung und Prüfung; keine Veröffentlichung.

## Verhalten

**Veranstalter merken**, **Reihe merken** und **Event merken** speichern je bestätigtem Konto und Ziel höchstens einen Merklisteneintrag. Die Gesamtzahl erscheint als **N Personen interessiert** in den öffentlichen Veranstalterlisten und Profilen, Programm-/Reihenansichten, Eventdetails und öffentlichen Ortsprogrammen. Bei Events steht sie unter den Angaben zu Datum, Ort und Veranstalter. Ohne Anmeldung ist die Zahl lesbar; **Anmelden und merken** öffnet den vorhandenen Kontozugang. Nach Rückkehr lädt die Detailseite die aktuelle Anmeldung neu.

Speichern und Entfernen zeigen die vom Backend gelieferte Gesamtzahl. Fehlgeschlagene Schreibaufrufe verändern die dargestellte Zahl nicht. Die Rückkehr aus einer Eventdetailseite aktualisiert das zugehörige Profil-/Reihenprogramm. Andere geöffnete Seiten erhalten den neuen Stand beim erneuten Abruf; es gibt keinen Echtzeitkanal.

**Meine Merkliste** enthält jetzt auch Events. Die persönliche Auswahl bleibt privat. Öffentliche Zahlen enthalten keine Namen, E-Mails oder Kontolisten. Vor der Merkschaltfläche erklärt die Oberfläche: **Merken zählt als öffentliches Interesse. Namen bleiben verborgen.** Ein Interesse ist keine Teilnahmezusage, Mitgliedschaft oder zusätzliche Freigabe.

## Rechte und Daten

Die bestehende `ca_bookmark` erhält lokal eine optionale Eventreferenz, eine Bedingung für genau ein Ziel je Eintrag und einen eindeutigen Index je Konto/Event. Bestehende Profil-/Reihenmerker bleiben erhalten. Zielindizes unterstützen die Zählabfragen; es wird kein zusätzlicher, möglicherweise abweichender Zähler gespeichert.

Gezählt werden tatsächliche Einträge von Konten mit aktuell bestätigter E-Mail. Eine Anzahl ist nur bei aktuell öffentlich sichtbaren Inhalten verfügbar. Für Reihen müssen Reihe, Profil und Community öffentlich und die Gastgeberzuständigkeit aktuell sein. Events verwenden dieselbe öffentliche Sichtbarkeit wie der bestehende Katalog, einschließlich Reihen- und Gastgeberprüfung. Ein öffentlicher Veranstalter macht geschützte Reihen oder Events weiterhin nicht öffentlich. Private Inhalte liefern keinen Interessenzähler, auch wenn ein Gast sie persönlich sehen und privat merken darf. Bei Entzug verschwinden diese Inhalte aus dessen Merkliste. Eine eigene Eventfreigabe verrät keinen Zähler einer geschützten Reihe. Entfernen aus der eigenen Merkliste bleibt auch nach Entzug möglich.

Öffentliche Leseresultate ergänzen ausschließlich das aggregierte Feld `interest_count`; nicht öffentliche Ziele erhalten dort `null` oder bleiben vollständig unabrufbar. Es gibt keinen separaten Zähler-Endpunkt zur Abfrage verborgener IDs. Der Merk-Schreibaufruf liefert den expliziten Zustand und die danach gelesene Anzahl. Eindeutige Datenbankindizes verhindern Doppelzählung bei wiederholtem und gleichzeitigem Speichern. Die Anzahl zählt Konten, sie ist kein Nachweis verschiedener realer Personen oder einer tatsächlichen Teilnahme.

## Umfang und Arbeitsstand

Geändert wurden `server/interest_counts.mjs`, Katalog und Verzeichnisprojektionen, die lokale Bookmark-Erweiterung in `directory.sql`, `directory.test.mjs` sowie Flutter-Merkliste, Profil-/Programm-/Eventdarstellung, Sichtbarkeitsvorschau und Widgettests. Produktspezifikation und ADR 0006 halten die neue öffentliche Aggregation fest. Keine neue Abhängigkeit, Remote-Migration, Installation, E-Mail, Veröffentlichung oder Änderung an Runner-Kontrollen.

Gelesene Anweisungsquellen: Nutzerregeln, Projekt-`AGENTS.md`, Produkt-, Setup-, Git- und Codex-Workflow sowie die bestehenden Berechtigungs-/Funktionsdokumente. Der vorhandene Quellstand wurde unter `/private/tmp/community-access-interest-before/` gesichert und der Branch `codex/public-interest-counts` angelegt. Vorhandene und parallel beauftragte Arbeiten bleiben erhalten; nichts gestagt oder committet. Tatsächliche Prüfungen stehen in [Abnahme und Nachweise](verification.md).

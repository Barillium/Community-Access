# Phasenstand · lokale Umsetzung

Die Statusangaben beziehen sich auf den synthetischen Erstausbau und die ausdrücklich gewünschte gemeinsame Auftrittsverwaltung. Sie sind keine Produktions-, Rechts- oder vollständige Supabaseabnahme. Aufbewahrungsausführung wurde vom Nutzer ausdrücklich ausgeschlossen. Konkrete Endergebnisse stehen im [Prüfbericht](report.md) und der [Ergänzung zur gemeinsamen Verwaltung](collaboration.md).

| Phase | Stand | Dateien und Nachweis |
| --- | --- | --- |
| 0 Bestand | Abgeschlossen | inventory.md, decisions.md; bestehende Architektur und schmutziger Arbeitsstand erhalten |
| 1 Rechte | Abgeschlossen | access-matrix.md; echte bestätigte HTTP-Sitzungen, begrenzte DB-Rollen, positive und negative Rechtefälle |
| 2 SQL | Lokaler Umfang einschließlich gemeinsamer Verwaltung umgesetzt | Migrationen 0003–0008; Annahme, Ablauf, Communityrollen, Publisher, Regeln, FKs, angenommene Auftrittsverwalter und Linkaussteller; Altbestandsupgrade und Wiederholung |
| 3 Events | Umgesetzt | event_policy.mjs, access_policy.mjs, catalog/directory; Event-/Profiltrennung, genehmigte Communitywege, maskierte Felder, Suche/Counts/Seitenbegrenzung |
| 4 Aufnahme | Umgesetzt | Bestehende personenbezogene Hashlinks und Flutterabläufe; Moderationszuweisung erneut prüfen, atomarer Verbrauch, offener Antrag, Regelversion |
| 5 Moderation | Umgesetzt | private_access.mjs, private_access_management_page.dart; scoped Pause, Ablauf, Aufhebung, Fall, unabhängiges Review, Einspruch |
| 6 Kategorien | Umgesetzt | private_ticketing.mjs, synthetic_pretix, native Plugin; Sicht-/Kaufregeln, Kontingente, Preis-/Kategoriezuordnung, serverseitiges Limit |
| 7 Zahlung | Lokal synthetisch umgesetzt | Bestehender Zahlungsabgleich/Refund-Outbox; Zugang erneut prüfen, gemeinsamer Lock, EUR-/Betrags-/Auftragsprüfung; keine echten Abbuchungen |
| 8 Flutter/Einlass | Lokal geprüft | Private Kategorien und Verwaltung, scoped Online-Einlass mit Codeeingabe, Bestellnachweise; Kontowechsel-/Offline-/Konkurrenztests. Native pretix-PDF besitzt QR; keine neue Kameraintegration |
| 9 Aufbewahrung | Freigegebener Vorschauumfang umgesetzt | retention_config.mjs, aggregate Vorschau ohne Mutationen; keine neue Löschfrist oder Ausführung |
| 10 Einführung | Lokale Schlussprüfung bestanden | Drei Pilotschalter, Queryplan, Upgrades, Regressionen, Browsernachweise und operations.md. Keine Veröffentlichung |

Die im Fahrplan genannten Tabellen sind Zielvorschläge. Gemeinsame Identität und Fachbereiche bleiben in der vorhandenen Plattformdatenbank; pretix besitzt wie zuvor seine getrennte Inventardatenbank innerhalb derselben lokalen PostgreSQL-Infrastruktur. Keine Datenbanken je Nutzerart, kein neues Authsystem, keine Änderung der separaten Supabase-Demo.

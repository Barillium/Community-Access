# Aktionsmatrix

Stand 10.10.2026. Die Matrix beschreibt bestehende Ressourcenrechte. Der verfügbare V1-Funktionsumfang ist ausschließlich in der [Produktspezifikation](../product-spec.md#2-umfang-der-ersten-version) festgelegt. Zurückgestellte Funktionen sind damit keine aktivierten V1-Wege.

Alle Rechte sind auf ein konkretes Ziel begrenzt. Aufnahme-, Freigabe-, Ticket- und Verwaltungsaktionen benötigen bestätigte Konten; eigene Präferenzen benötigen eine gültige Sitzung. Eine Plattformsperre verhindert alle aktiven Produktaktionen, einschließlich Verwaltung. Eigene Bestellnachweise und Beschwerden bleiben als eng begrenzte Ausnahmen erreichbar. Kein globales Veranstalterflag. Ablehnungen privater Ressourcen verwenden neutrale Nichtverfügbarkeit.

| Aktion | Berechtigt | Zusätzliche Bedingungen |
| --- | --- | --- |
| Öffentliche Community/Event lesen | Anonym, Konto | Tatsächlich öffentliche und veröffentlichte Projektion |
| Öffentliche Veranstaltung ohne Plattform-Ticket besuchen | Keine manuelle Teilnahmefreigabe | Eintrittsbedingungen beachten; keine automatische Freigabe geschützter genauer Locations |
| Privates Event lesen | Persönlicher Eventgrant oder aktives Mitglied | Aktuelle ungesperrte Quelle; ausdrückliche Communityzuordnung |
| Veranstalterprofil lesen | Öffentlich oder persönlicher Profilzugang/Eigentümer | Eventgrant genügt nicht |
| Auftritt, Events, Reihen, Anträge und Freigaben verwalten | Verantwortliches Konto oder angenommener Verwalter dieses Auftritts | Aktuelle Veranstalterzulassung des verantwortlichen Kontos; keine Delegation für fremde Auftritte |
| Gemeinsame Verwaltung einladen/entziehen | Verantwortliches Konto dieses Auftritts | Bestätigtes Empfängerkonto; Versionsprüfung; Annahme binnen sieben Tagen |
| Zahlungsempfängerzuordnung ändern | Verantwortliches Konto dieses Auftritts | Gemeinsame Verwaltung verändert die Verkäuferzuordnung nicht |
| Community folgen | Bestätigtes Konto | Kein Sichtzugang oder Mitgliedschaft |
| Aufnahme beantragen | Bestätigtes Konto mit gültigem Aufnahmeweg | Ein offener Antrag; Linkhash/Ablauf/Ausstellerrecht |
| Community aufnehmen | Gültig zugewiesener Moderator dieser Community | Vorher freiwilliger Antrag; bestehende Sperren beachten |
| Event veröffentlichen | Verantwortliches Konto oder angenommener Verwalter mit Communityrecht des Auftritts | Auftritt hat ausdrückliches Veröffentlichungsrecht; Communitymoderation gibt Veröffentlichung frei |
| Kategorie lesen | Event-Sichtzugang plus Kategoriebedingung | Kategoriengrant öffnet kein Event |
| Ticket kaufen | Bestätigtes Konto | Event/Kategorie, Kaufregel, Zeit, Preis, Kontingent und Unique-Index |
| Temporär Event/Veranstalter sperren | Event: Eigentümer oder angenommener Auftrittsverwalter; Profil: Eigentümer | Explizites Ablaufdatum |
| Regeln/Formulare/Veröffentlichungsrechte ändern | Moderator dieser Community | Keine automatische Befugnis durch Veranstalterzulassung |
| Community moderieren | Vom Team zugewiesener Moderator | Gültige Communityzuweisung |
| Dauerhaft Community sperren | Zwei unabhängige Moderatoren | Kein Selbstreview; wirksame Sperre getrennt vom Fall |
| Plattform sperren/Moderator zuweisen | Plattformteam | Keine Selbstzuweisung durch Mitglied/Veranstalter |
| Fall lesen | Moderator der zugewiesenen Community | Niemals allgemeine Profil-/Eventantwort |
| Einspruch einreichen | Betroffene Person | Eigener Fall, kein voller fremder Fallzugang |
| Minimalen Bestellnachweis lesen | Käufer | Auch nach Verlust privater Eventrechte |
| Erstattung genehmigen | Verantwortliches Konto oder angenommener Verwalter des Auftritts | Bestehende wiederholbare Erstattungsaufgabe |
| Token anzeigen | Käufer | Bezahltes nicht gesperrtes Ticket, aktueller Eventzugang |
| Online einlassen | Zeitlich gültiger Eventscanner | Token, Event, Konto, Zahlung, Eventzugang, Sperren; atomare Entwertung |
| Neue Datenklassen bereinigen | Noch niemand | Nur Vorschau, noch keine Aufbewahrungsentscheidung |

## Testvertrag

A01–A25 aus dem Fahrplan bleiben der fachliche Vertrag. `server/private_access.test.mjs` prüft insbesondere A01–A19, A21, A24 und A25 über echte lokale HTTP-/PostgreSQL-Abläufe. Bestehende `server/ticketing.test.mjs`, `server/access.test.mjs` und `server/directory.test.mjs` ergänzen Link-, Zahlungs-, Such- und Konkurrenzfälle. Ein Szenario ist erst mit dem konkreten abschließenden Prüfbericht ausgeführt; diese Zuordnung allein behauptet keinen Erfolg.

Nicht existente Realtime-/Storagepfade werden nicht als geprüft ausgegeben. Der aktuelle Medienabruf erfolgt in der frisch autorisierten Eventantwort. Native pretix und Flutterprüfungen werden separat ausgewiesen.

Konto-/Sperrenvertrag und Nachweise: [Nachbesserungen 09.10.2026](../qa/auth-improvements-2026-10-09/report.md). Menüs richten sich nach vom Backend bestätigten Zuständigkeiten; Menüs vergeben keine Rechte.

### Konto- und Zugriffsnachbesserungen · 09.10.2026

Der Auth-Server gibt Registrierung ohne Autositzung und mit einheitlichem Abschluss zurück. E-Mail-Anmeldung reicht das native HttpOnly-Sitzungscookie weiter. `GET /api/account/me` kann nach serverseitiger Prüfung den signierten Cookieinhalt als Header für den flüchtigen Client-Bearer zurückgeben. Cookiecache und Sitzungsverlängerung sind ausgeschaltet; Logout und Passwortreset widerrufen die Datenbanksitzungen. Bei einem angegebenen Bearer gibt es keinen Rückfall auf ein Browser-Cookie. Es gibt keine Speicherung von Tokens in Browserstorage.

`server/account_policy.mjs` führt den Requestakteur über asynchrone Produktaufrufe. Jeder betroffene Schreibvertrag prüft die Plattformsperre nach Erwerb der gemeinsamen Zugriffssperre erneut. Systemabgleich und Bereinigung haben keinen Nutzerakteur; Beschwerdewege behalten ihre eigenen engen Zuständigkeitsprüfungen. Eigene Belege und Beschwerden bleiben bei Sperre erreichbar.

Mailcallbacks werden innerhalb eines begrenzten Wrapper-Link-Austauschs abgewartet. Transportablehnung und verlorene Transportbestätigung rollen den Austausch zurück; ein zuvor gültiger Link bleibt im geprüften Fall verwendbar. Der neu zugestellte, aber nicht aktivierte Ersatzlink nach ACK-Verlust ist ungültig. Providerannahme ist kein Zustellnachweis. Bei verlorener Bestätigung eines möglicherweise erfolgreichen Datenbank-Commits wird `LINK_STATUS_UNKNOWN` zurückgegeben: Der Server verspricht dann nicht, dass der alte Link weiter gilt. Der Test weist nach echtem Commit und injiziertem ACK-Verlust nach, dass der aktivierte Ersatzlink weiter verwendbar ist. Native Resetfehler nach Verbrauch benötigen einen neuen Link; kein unsicheres Reaktivieren verbrauchter Tokens. Alle Versandprüfungen dieses Auftrags verwenden injizierte synthetische Antworten.

[Änderungen, ausgeführte Prüfungen und verbleibende Grenzen](../qa/auth-improvements-2026-10-09/report.md).

Die anschließenden Ablaufkorrekturen und ihre lokalen Nachweise stehen in der [Funktions- und Ablaufprüfung vom 09.10.2026](../qa/site-functional-review-2026-10-09/report.md).

# Lokaler synthetischer Zugangsablauf

> Einordnung für V1 · 10.10.2026: Dieser datierte Detailbericht beschreibt den damaligen Implementierungsstand einschließlich des erhaltenen erweiterten Modus. Maßgebliche Produktregeln und Umfang stehen ausschließlich in der [Produktspezifikation](product-spec.md); aktuelle Start- und Prüfbefehle im [Setup](setup.md). Historische Statusangaben und Prüfergebnisse sind keine heutige Funktions- oder Betriebsfreigabe.

Stand 08.10.2026. Der gemeinsame Checkout enthält außerdem die parallel ergänzte zentrale Event-Policy unter `server/event_policy.mjs`; die abschließende Prüfung bezieht diesen aktuellen Stand ein. Maßgeblich ist die freigegebene [Produktspezifikation](product-spec.md). Node.js, Better Auth und PostgreSQL unter `server/` arbeiten mit Flutter unter `client/`. Keine neuen Abhängigkeiten, Dienste oder Veröffentlichungen. Der bestehende Einzelaufgaben-Runner und sein blockierter Produktumfang bleiben unverändert.

## Ablauf und getrennte Rechte

Veranstalterbewerbung → Teamaufnahme → getrennte Moderatorzuweisung und Veröffentlichungsfreigabe → persönliche Einladung → Communitybewerbung → manuelle Mitgliedschaft → Eventanfrage → separate Teilnahmezusage → geschützte Location.

Teamrechte stehen ausschließlich in `ca_team`; nur der getrennte synthetische Fixture-Prozess vergibt sie. Annahme erzeugt Community, Gastgeberrolle und privates Profil in einer Transaktion. Gastgeberrollen gelten je Community und erteilen keine Communityverwaltung. Einladungen, Aufnahme, Formulare und Regeln verwaltet eine separat zugewiesene Communitymoderation. Organisatorischer Rückzug erlaubt Wiederbewerbung; Ablehnung erzeugt eine separat vom Antrag aufbewahrte, ausschließlich teamseitig aufhebbare Sperre.

Communityeinladungen sind an ein vorhandenes bestätigtes Konto gebunden, sieben Tage gültig und widerrufbar. Nur der SHA-256-Tokenhash wird gespeichert. Vorschau und Fehler verbrauchen nichts; erfolgreiche Einreichung verbraucht atomar. Gastanträge bewahren den beantworteten Fragenstand auf. Rückzug erlaubt eine neue Einladung/Bewerbung. Ablehnung und Mitgliedschaftsentzug sperren erneute Communitybewerbungen.

Profilzugang, Mitgliedschaft, Eventsichtbarkeit und Teilnahme sind getrennt. Aktive Mitgliedschaft macht mitgliedschaftspflichtige Events zugänglich, eröffnet jedoch kein privates Veranstalterprofil. Bestehende Event-/Profilfreigaben behalten ihre bisherigen Sichtbarkeitsregeln. Eine Sichtbarkeitsfreigabe reserviert keinen Platz und öffnet keine genaue Location. Direkte Events ohne Mitgliedschaftspflicht bleiben möglich.

`ca_event_interest` führt den getrennten Teilnahmezustand. Bei Ticketing ist eine manuelle Zusage ausschließlich Kaufberechtigung; erst bestätigte Zahlung begründet Teilnahme. Nur `approved` zählt zur Kapazität; `capacity = NULL` bedeutet unbegrenzt. Anfrage und Zusage sind nur vor Beginn möglich. Pflichtantworten und explizite Mindestalterbestätigung werden serverseitig geprüft. Gäste können offene Anfragen/Zusagen vor Beginn zurückziehen und neu manuell anfragen.

Mitgliedschaftsentzug setzt Mitgliedschaft inaktiv, erhält eine minimale Sperre und widerruft atomar offene Anfragen/Zusagen, wenn kein gültiger zweiter Communityweg oder persönlicher Eventgrant mehr besteht. Direkte Events und Profilrechte werden nicht verändert. Profilentzug sperrt abhängige private Abrufe und ist durch Eventfreigaben nicht übergehbar. Gastgeberentzug sperrt zugehörige Verwaltung und Veröffentlichungen/Abrufe.

## Speicherung und Konsistenz

Neue Produktobjekte verwenden UUIDs. Die Flutter-Schnittstelle akzeptiert daneben die IDs der erhaltenen älteren Statusdemo. Die versionierte lokale Migration `server/migrations/0001-access-flow.sql` erweitert bestehende Eventtabellen und ergänzt den abgegrenzten Zugangsteil. `ca_access_migration` dokumentiert Version und Dateihash; eine nachträglich veränderte angewandte Migration wird abgelehnt.

Alle berechtigungsrelevanten Schreibtransaktionen nehmen zuerst dieselbe PostgreSQL-Transaktionssperre (`73100526`), danach Datensatzsperren. Das serialisiert bewusst die kleinen lokalen Schreibvorgänge; es ist keine Aussage über Skalierung auf große Last. Wiederholte Entscheidungen erzeugen keine zusätzlichen Rollen, Mitgliedschaften oder Plätze. Fehler rollen die gesamte Transaktion zurück.

Exakte Location liegt ausschließlich in `ca_event_location`; allgemeine Eventprojektionen liefern sie nicht. `/api/access/events/:id/location` prüft aktuelle Gastgeber-/Teilnahmerechte, Mitgliedschaftspflicht, Profilentzug, aktuellen Gastgeber und Aufbewahrung. Semi-öffentliche Events benötigen außerdem den Freigabezeitpunkt. Geschützte HTTP-Antworten sind `no-store`.

Flutter lädt Locations frisch. Ansichts-/Sitzungsversionen ignorieren verspätete Antworten nach Aktualisierung, Wechsel oder Abmeldung. Verweigerte Zugriffe verwerfen private Antwortdaten. Bereits gelesene Informationen können nicht zurückgeholt werden.

Abgeschlossene Veranstalter- und Communityanträge einschließlich Antworten werden nach zwei Kalendermonaten in Europe/Berlin gelöscht. Monatsenden werden auf den letzten gültigen Tag begrenzt; laufende Anträge bleiben. Mitgliedschaften/Sperren leben unabhängig davon. Bestehende Eventbereinigung verwendet exakt 168 Stunden ab tatsächlichem Ende und entfernt durch Fremdschlüssel auch Teilnahme, genaue Location und weitere Eventbezüge. Events mit neuen Ticket-/Sperr-/Einlassreferenzen werden nicht kaskadierend gelöscht; neue Datenklassen besitzen nur eine Aufbewahrungsvorschau. Bereinigung läuft bei Abrufen und im lokalen HTTP-Prozess minütlich. Backup-Löschung ist nicht nachgewiesen.

## Schnittstellen und Oberfläche

Alle Zugangsrouten sind authentifiziert, Produktaktionen erfordern bestätigte E-Mail:

- `POST /api/access/organizer-applications`, `/:id/withdraw`, `/:id/decide`.
- Team: `GET /api/access/team`, `POST /api/access/team/unblock`, `/team/revoke-host`.
- Communitymoderation: `GET /api/access/communities/:id`, `POST /communities/:id/form`, `/communities/:id/invite`.
- Einladung: `POST /api/access/invitations/preview`, `/invitations/:id/revoke`.
- Gastbewerbung: `POST /api/access/applications`, `/applications/:id/decide`, `/applications/:id/withdraw`.
- Mitgliedschaft: `POST /api/access/memberships/:id/revoke`.
- Location: `GET /api/access/events/:id/location`.
- Konto: `GET /api/account/me` liefert tatsächliche eigene Anträge, Mitgliedschaften, Sperren und sichtbare Teilnahmestatus.
- Eventanfrage/-entscheidung bleiben unter `/api/directory`; ergänzt ist `POST /api/directory/events/:id/withdraw`.

Flutter bietet unter „Zugang verwalten“ eigene Zugänge, Veranstalteraufnahme, rollenabhängige Teamprüfung und Communityverwaltung. Die bestehende Profil-/Eventverwaltung enthält Mitgliedschaftspflicht, Kapazität, genaue Location und getrennte Teilnahmeentscheidungen. Gestaltung und DE/EN-Sprachsteuerung bleiben erhalten; Fragen folgen dem vorhandenen begrenzten Katalog.

## Prüfungen und Grenzen

[Startanleitung](setup.md#synthetischer-zugangsablauf--05102026) · [Tatsächliche Prüfergebnisse](qa/access-flow-2026-10-05/report.md).

Der Access-Test-/Demo-Bootstrap ist vom HTTP-Prozess getrennt. Dieser verwendet `auth_app` mit eingeschränkten Datenrechten, ohne DDL/Schema-/Rollenrechte; Team-/Migrationstabellen sind nur lesbar. Andere Startmodi sind dadurch nicht automatisch mitgeprüft. Frische synthetische Datenbanken und signierte Better-Auth-Sitzungen dienen als Integrationsnachweis. Kein Supabase-, Produktions-, Versand-, Backup- oder Gesamtproduktnachweis.

Der aktuelle private Ausbau mit Moderatorrollen, Communityfreigaben, Kategorien und Online-Einlass ist in [Aktionsmatrix](implementation/access-matrix.md) und [Prüfbericht](implementation/report.md) dokumentiert.

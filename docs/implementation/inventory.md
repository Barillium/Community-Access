# Bestandsaufnahme · 08.10.2026

Auftrag: `Community_Access_Codex_Umsetzungsfahrplan.txt`, Stand 05.10.2026. Arbeitsbranch: `codex/private-access-roadmap-20261008`. Die vorherigen Änderungen auf `codex/pretix-ticketing-20261005` wurden erhalten. Kein Commit, Remote-Upgrade oder Deployment.

Gelesen: mitgeteilte persönliche Regeln, Root-AGENTS.md, docs/product-spec.md, docs/setup.md, docs/workflow.md, docs/codex-workflow.md, docs/ticketing.md. Keine weiteren AGENTS-Dateien in der geprüften tatsächlichen Projekthierarchie. Der Dokumente-Pfad verweist auf `/Volumes/CommunityAccessNative/Projects/Community Access`; der Projektordner ist nach der Nutzerkorrektur direkt als Arbeitsbereich eingebunden. Die normale Werkzeugausführung scheitert weiterhin am separat mitgegebenen symbolischen SAN-Sites-Schreibpfad. Projektarbeiten wurden mit geprüften Einzelaufrufen ausgeführt, keine Codex-Konfiguration geändert.

## Bestätigte Architektur und Zuordnung

| Zielkonzept | Vorhandener Bestand | Ergänzung |
| --- | --- | --- |
| Identität | Better Auth `user`, `session`, `account`; server/auth.mjs | Bestehende bestätigte Sitzung |
| Veranstalter | ca_organizer, ca_host, ca_profile_community; server/directory.sql | Getrennte Event- und Profilfreigaben, ca_community_publisher, angenommene ca_organizer_member und Profilaufnahme-Linkaussteller |
| Folgen/Mitgliedschaft | ca_community_follow, ca_membership, ca_community_block | Annahmezeitpunkt, Ablauf und alternative Communitywege |
| Event-Sichtzugang | ca_event_grant, ca_series_grant, zentrale event_policy.mjs | Ablauf/Widerruf, scopebezogene Sperren |
| Communityveröffentlichung | Ein primärer Community-FK im Event | ca_event_community_access mit ausdrücklicher Freigabe |
| Aufnahme | server/access.mjs; Einladungshash, Antrag, Entscheidung | Nur zugewiesene Moderation; Regelversion, Annahme und Aufnahmegrund |
| Teilnahme/Adresse | ca_event_interest, ca_event_location | Aktuelle Eventrechte beim Einlass erneut prüfen |
| Moderation | ca_team, bisherige Profil-/Communityentzüge | ca_community_staff, ca_restriction, ca_moderation_case, ca_moderation_appeal |
| Ticketkatalog | ca_ticket_config, ein Testartikel | ca_ticket_type, ca_ticket_type_community, ca_ticket_type_grant |
| Reservierung | Getrennter synthetischer pretix-Vertragsdienst, pt_order | pt_type; atomare Kategorie- und Gesamtprüfung |
| Bestellung/Zahlung | ca_ticket_order, Preis-/Gebühren-Snapshot, authentifizierter Anbieterabruf | Kategorie-FK und getrennter Einlassstatus |
| Erstattung/Outbox | ca_ticket_refund, review → processing → done, wiederholbare ID | Bestehenden Ablauf übernehmen |
| Einlass | Native pretix-Prüfung vorhanden | Kontogebundener synthetischer Online-Einlass, ca_scanner, ca_ticket_token, ca_checkin |
| Medien/Suche | Eventmedien in event_content, serverseitig maskierte Projektion | Kein neuer öffentlicher Storagebucket |
| Bereinigung | Bestehende Event-/Antragsbereinigung | Für neue Klassen ausschließlich Vorschau |

Die getrennte Supabase-Demo (`app/`, `supabase/migrations/202609250001_core.sql`) bleibt erhalten. Sie ist keine aktive Ticketdatenbank. Flutter liegt in `client/`. Bestehende Node-Abhängigkeiten: Better Auth 1.7.7, pg 8.23.1; keine neuen Pakete.

## Risiken und Nachweisgrenzen

- Bestehende Migrationen sind hashgebunden. Neue Anforderungen werden in `server/migrations/0003-private-access.sql` bis `0008-organizer-link-issuers.sql` ergänzt, alte Migrationen nicht geändert.
- Bestehender SQL-Index `ca_event_community` belegt bereits den Relationsnamen. Neue Zuordnung heißt deshalb `ca_event_community_access`.
- Nur frische synthetische Testdatenbanken werden verändert. Vorhandene persistente oder produktive Bestände wurden nicht inhaltlich untersucht.
- Der Backendprozess ist eine vertrauenswürdige `auth_app`-Rolle. Browser besitzen ausschließlich HTTP-Zugang. Kein Supabase-RLS-Nachweis für das aktive Backend behaupten.
- Native Kategorien ergänzen das vorhandene Plugin mit einer additiven Django-Migration und nativen Artikeln unter zwei Kontingenten. Das Backend speichert die Kategorie-/Artikelzuordnung getrennt.
- Das Arbeitsimage wurde während der abschließenden Prüfungen getrennt und wieder eingehängt. Es wurden keine Projektdaten zurückgesetzt. Unterbrochene Läufe zählen nicht als erfolgreiche Prüfungen.

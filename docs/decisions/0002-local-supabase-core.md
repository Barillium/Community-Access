# ADR 0002: lokaler Supabase-Kern und echte API-Rollentests

Status: lokale Implementierung zur Prüfung, keine Pilot-/Produktionsfreigabe. Grundlage bleibt [product-spec.md](../product-spec.md). Keine neuen Bewerbungsfelder oder Aufbewahrungsfristen festgelegt.

## Umfang

Supabase CLI 2.117.0 wurde nach Freigabe installiert (MIT). Eine eigene Colima-VM `community-access-test` verwendet 2 CPUs, 4 GiB RAM und eine virtuelle 20-GiB-Datenplatte. Eingebunden ist nur der Projektordner; kein SSH-Agent. Docker-Standardkontext und SSH-Konfiguration wurden nicht umgestellt. Ein eigenes Docker-Netz `community-access-loopback` bindet veröffentlichte Ports an 127.0.0.1. Auth, PostgREST, Kong und PostgreSQL laufen lokal; Studio, Storage, Realtime, Functions und SMTP sind ausgeschaltet. Kein Cloudprojekt, keine Verknüpfung, kein Versand.

## Modell und Rechte

- `communities`, `community_hosts`: Community und ausdrücklich zugeordnete Gastgeber. Keine globale Rolle aus Benutzermetadaten.
- `applications`: nur Eigentümer, Community und Status/Entscheidungszeit; noch keine Antworten. Lesen: eigener Gast oder zuständiger Gastgeber.
- `memberships`: unabhängig von Bewerbungen, Aktivitätsstatus. Lesen: eigener Gast oder zuständiger Gastgeber.
- `events`: Community, Titel, Kapazität und Altersgrenze. Lesen: aktive Mitglieder oder zuständige Gastgeber.
- `event_requests`: separate Anfrage mit Alters-Selbstauskunft und Status. Lesen: eigene Anfrage oder zuständiger Gastgeber.
- `event_locations`: separat geschützte Information. Lesen: zuständiger Gastgeber oder bestätigter Gast mit weiterhin aktiver Mitgliedschaft.

Alle Tabellen haben RLS und explizite Grants. Anonyme Nutzer erhalten keine Tabellenrechte; direkte API-Schreibzugriffe sind auch für angemeldete Nutzer gesperrt. Zulässige Änderungen laufen durch drei Funktionen: `decide_application`, `request_event`, `confirm_event`. Diese prüfen `auth.uid()` und die Community-Zuordnung. `SECURITY DEFINER`-Funktionen besitzen einen leeren Suchpfad und explizit eingeschränkte Ausführungsrechte. Interne Rechtehelfer liegen außerhalb des API-Schemas.

Aufnahme und Mitgliedschaft entstehen atomar. Zeilensperren serialisieren wiederholte Aufnahmen und Eventzusagen. Die Eventzeile schützt die Kapazitätsprüfung; die Mitgliedschaft wird dabei ebenfalls gesperrt. Wiederholte gleiche Aktionen erzeugen keine zusätzlichen Einträge. Die API liefert keine privaten Werte in selbst formulierten Fehlern.

## Bewusste Grenzen

Dies ist ein vertikaler Kern, nicht das vollständige Produktdatenmodell. Kollektivaufnahme, Einladungseinlösung, Absenden/Rückzug von Bewerbungen, Antwortfelder, Eventverwaltung, Ablehnung von Eventanfragen und Löschfristen fehlen. Diese Schreibwege bleiben geschlossen. Gastgeberzuordnungen und offene Bewerbungen erzeugt ausschließlich der lokale synthetische Testaufbau. Es gibt keinen solchen Verwaltungszugang in der App.

Ein produktiver Entzugsablauf einschließlich Auswirkung auf bestehende Zusagen und frei werdende Plätze ist noch nicht spezifiziert/implementiert. Der Test deaktiviert eine Mitgliedschaft administrativ und beweist danach den verweigerten Zugriff mit demselben zuvor gültigen JWT. Das ist kein End-to-End-Entzugstest. Keine globale Szenedatei und keine Bewertungsdaten.

Der Testcontroller hat lokalen Administratorzugang ausschließlich für Fixtures und einen gezielten Fehlerauslöser. Die eigentlichen Rechteprüfungen verwenden Auth-Tokens normaler Testkonten gegen HTTP. Er ist nicht als Sandbox für fremden Code geeignet und wird nicht in den V1-Coding-Runner eingebunden. Der Projektordner ist in der VM les-/schreibbar; deshalb weiterhin keine echten privaten Daten darin ablegen.

E-Mail-Bestätigung ist ausschließlich im lokalen Testprofil deaktiviert. Dadurch können Adressen unter `example.invalid` ohne Versand verwendet werden; das belegt weder E-Mail-Verifikation noch Produktionsauthentifizierung. Testpasswörter/JWTs werden nur im Prozess verwendet, nicht im Bericht. CLI-Startausgaben können lokale Schlüssel enthalten und bleiben unter `.local/`; nicht teilen. Supabase erzeugt zudem eigene Containerlogs und lokale CLI-Metadaten. Keine Aussage über vollständige Protokollbereinigung aller Drittkomponenten.

## Beobachtungen und Nachweise

Der erste Migrationsversuch scheiterte an einer PL/pgSQL-CASE-Klammerung; anschließend erfolgreich angewendet. Die Standard-Netzbindung war zunächst auf allen Host-Schnittstellen offen. Die Test-VM wurde sofort gestoppt und vor dem abschließenden Lauf auf das Loopback-Netz umgestellt. `docker ps` und `lsof` bestätigten anschließend ausschließlich 127.0.0.1 auf 55431/55432. Keine echten personenbezogenen Daten verwendet; die kurzzeitige Standardbindung wird nicht als bestanden dargestellt.

47 Auth-/API-Prüfungen bestanden im korrigierten Netz. SQL-Analyse von `public` und `access_private` mit `--fail-on warning` bestand. Geprüft sind positive und negative Rechte, direkte Schreibversuche, Selbstaufnahme, wiederholte/gleichzeitige Aufnahme, Rollback nach erzwungenem Fehler, getrennte Zusage, Alters-Selbstauskunft, letzter Eventplatz unter Konkurrenz und verweigerter Locationabruf nach administrativem Entzug. Nicht geprüft: oben fehlende Abläufe, Migration von einem bestehenden Produktbestand, Flutter-Anbindung, andere Plattformen und vollständige Sicherheitsabnahme.

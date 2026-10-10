# ADR 0005: Lokale Better-Auth-Anbindung der Flutter-Gastoberfläche

> Teilweise ersetzt durch [ADR 0007](0007-v1-scope.md). Die folgenden Abschnitte dokumentieren den damaligen Ausbau, nicht den heutigen Umfang. Aktueller Konto-/Sitzungs- und Rechtevertrag: [Produktspezifikation](../product-spec.md); Start und Prüfung: [Setup](../setup.md). Historische Backend-fehlt-, Cookie- und erweiterte Profil-/Reihenaussagen gelten nicht als aktuelle V1-Regeln.

Nachtrag HTTPS-Vorbereitung 02.10.2026: Der Nutzer bestätigt die drei Entwicklerzugänge und wählt einen dauerhaften Tunnel zu diesem PC. `public_gateway.mjs` verbindet einen getrennten HTTPS-Web-Release mit einer festen Auth-Routenliste; Testpostfach, Dashboard und synthetischer Katalog sind ausgeschlossen. Start und API-Anfragen verlangen privaten Modus, gleiche `https://communityaccess.de`-Origins, deaktiviertes Dashboard und eine geprüfte eingeschränkte Datenbankrolle. Der private Controller startet den HTTP-Prozess als `auth_app` ohne Superuser-/Rollen-/Datenbankanlageprivilegien; der lokale Bootstrap bleibt getrennt. Keine Remote-Migration, kein echter privater Betriebsstart oder Live-Provider-Login erfolgt durch diese Vorbereitung. Cloudflare-DNS/Nameserver-Freigabe, private Secrets, Wiederherstellung und Autostart sind noch offen. [Konfiguration und Abnahmegrenze](../permanent-https-tunnel.md).

Nachtrag 02.10.2026: Google, Apple und Facebook sind auf Nutzerauftrag im Web-Anmeldeweg ergänzt. Explizite Origin-/Provider-Konfiguration, kurzlebige HTTP-only-Übergabecookies und bewusstes Account-Linking erweitern die ursprünglichen ausschließlich lokalen E-Mail-Grenzen. Die Produktfreigaben bleiben getrennt; echte Provider-Apps und HTTPS-Veröffentlichung sind noch nicht nachgewiesen. [Vertrag, Einrichtung und Prüfgrenzen](../social-sign-in.md).

Nachtrag 01.10.2026: Auf ausdrücklichen Nutzerauftrag ist ein getrennter privater Mailmodus für den Betrieb auf diesem PC implementiert. `--private-mail` nutzt Resend und einen privaten Bestand außerhalb des Entwicklungsordners; `CA_PRIVATE_MAIL=true` schaltet die passende lokale Kontooberfläche ein. Der synthetische Standardmodus bleibt erhalten. Ein echter Betriebsstart, Zustellung und öffentliche Nutzerregistrierung sind noch nicht abgenommen. [Details und tatsächliche Prüfungen](../resend-private-mail.md).

Stand: 01.10.2026. Umfang: manuelle Umsetzung des Nutzerauftrags für Authentifizierung und Anschluss des bestehenden Better-Auth-Dashboards. Keine Freigabe des Einzelaufgaben-Runners oder der vollständigen Produktberechtigungen.

Nachtrag Verzeichnisse vom 01.10.2026: Im synthetischen Modus sind nun Veranstalterprofile, persönliche Profilfreigaben und öffentliche Veranstaltungsorte separat angebunden. Die nachstehenden ursprünglichen Vertragsgrenzen betreffen weiterhin Mitgliedschaften, Einladungen und Eventteilnahmen. Gastgeberverwaltung für diesen begrenzten Katalog ist vorhanden; im privaten Mailmodus bleibt sie gesperrt. [Umsetzung und aktuelle Nachweise](../organizers-venues-flutter.md).

## Umsetzung

Die vorhandene Flutter-Oberfläche unter `client/` verwendet beim normalen Start `BetterAuthAccessApi`. Der ältere `HttpAccessApi` bleibt als dokumentierter Vertrag des entfernten Prototyps und für dessen bestehende Tests erhalten. Ein neuer Testkonto-Einstieg erlaubt die getrennte Kontoanlage; er gewährt keine Communitymitgliedschaft oder Eventteilnahme.

`server/` enthält einen lokalen Node.js-Server mit Better Auth, PostgreSQL und dem Infrastruktur-Plugin. `scripts/local_auth.py` nutzt PostgreSQL 17 über einen privaten Unix-Socket ohne TCP und beendet die Datenbank nach dem Node-Prozess. Die spätere Erweiterung zur weiteren Auth-Einrichtung öffnet standardmäßig den markierten synthetischen Bestand `.local/better-auth/persistent-synthetic/` erneut und hält seinen zufälligen Auth-Signierschlüssel stabil. `--fresh` und die Prüfläufe bleiben getrennte Wegwerftests. Die alte laufende Instanz und ihre früheren Testdaten werden nicht übernommen oder gelöscht. Dateirechte, Eigentümer, Symlinks, Markierung und eine exklusive Prozesssperre werden geprüft; unvollständige Bestände blockieren statt automatisch zurückgesetzt zu werden. Der Schlüssel ist ausschließlich ein synthetischer Entwicklungswert; Produktivdaten und produktive Secrets gehören außerhalb dieses KI-Arbeitsbereichs. [Start, Umstellung und Prüfergebnisse](../setup.md#flutter-mit-better-auth-starten).

Der HTTP-Server bindet ausschließlich `127.0.0.1:8000` und akzeptiert nur die exakten Host-Header `127.0.0.1:8000` und `localhost:8000`; die Flutter-Oberfläche läuft auf `127.0.0.1:8300`. Das Dashboard nutzt die jeweils aktuelle temporäre HTTPS-Adresse als Base URL und `/api/auth` als getrennten Base Path. Der localhost-Alias wird vom Server akzeptiert, führte im Dashboard-Onboarding aber noch nicht zu einem erfolgreichen Anschluss. Auth-Migrationen werden nur am explizit geprüften privaten lokalen Socket ausgeführt. Bestehendes Supabase, Produktmigrationen und Remote-Datenbanken sind nicht Teil dieses Starts.

## Sitzungen und Links

Flutter übernimmt den signierten `set-auth-token`-Header des Better-Auth-Bearer-Plugins. Sitzungen liegen serverseitig in PostgreSQL; das Token verbleibt im Client-Arbeitsspeicher und wird nicht in Browser-Speicher geschrieben. Browser-Neuladen verlangt deshalb eine neue Anmeldung. Abmeldung und Passwortreset entziehen serverseitige Sitzungen; ein HTTP-401 beim Kontoabruf entfernt auch den Clientstatus. Cookies und unsignierte Token aus Antwortfeldern werden nicht als Flutter-Sitzung übernommen.

Bestätigungs- und Resetlinks enthalten zufällige lokale Einmaltokens im URL-Fragment. Flutter sendet sie im POST-Body. Eine zusätzliche lokale Tabelle bindet deren Hash an Konto, Zweck und 60 Minuten Gültigkeit; eine erneute Anforderung ersetzt den vorigen Link. Ein einzelnes bedingtes Datenbank-Update verhindert doppelte Nutzung bei konkurrierenden Abrufen. Das Anlegen neuer Links wird pro Konto und Zweck mit einer Transaktion und einem Datenbanklock serialisiert.

Die Übergabe an Better Auth erfolgt nach Verbrauch des lokalen Links. Scheitert diese nachgelagerte Verarbeitung, muss ein neuer Link angefordert werden; beide Schritte bilden keine gemeinsame Datenbanktransaktion. Dieses Verhalten und der ausschließlich synthetische Testumfang sind keine Produktionsabnahme.

Nur Kontoadressen unter `@example.invalid` sind beim Anlegen und Aktualisieren zulässig. Serverfehler enthalten feste Codes statt Paketfehlern, Tokens oder Kontoadressen. Das lokale Testpostfach enthält ausschließlich synthetische Nachrichten und ist ohne Anmeldung am Loopback-Server erreichbar; es ist nicht für echte Konten geeignet. Es findet kein E-Mail-Versand statt.

## Dashboard

Das `dash()`-Plugin wird nur mit `BETTER_AUTH_DASHBOARD_ENABLED=true` und einem serverseitigen `BETTER_AUTH_API_KEY` eingeschaltet. `scripts/start_auth_dashboard.zsh` fragt diesen verdeckt ab, speichert ihn nicht und reicht ihn ausschließlich an den Server weiter. Ohne diese Aktivierung fehlen die Dashboard-Routen. Flutter erhält keinen Dashboard-Schlüssel und keine Dashboard-Verwaltungsrechte.

Für Dashboard-Routen wird zusätzlich der Browserursprung `https://dash.better-auth.com` zugelassen. Die signierten Verwaltungsanfragen prüft das Infrastruktur-Plugin selbst. Ein Gasttoken ersetzt diese Signatur nicht. Das Plugin kann Auth-Ereignisse und synthetische Kontodaten an die Better-Auth-Infrastruktur übertragen; es legt hier weder ein neues Projekt noch einen kostenpflichtigen Tarif an. Activity Tracking und Managed Directory Sync bleiben deaktiviert. Der bestehende Tarif wurde nicht geprüft. Die lesende Cloud-Verbindung wurde anschließend mit einem synthetischen Konto nachgewiesen.

Der tatsächliche Anschluss erfordert die verdeckte Schlüsseleingabe und eine Prüfung im Dashboard. Der ursprüngliche lokale Auth-Start richtet selbst keine öffentliche URL und keinen Tunnel ein; ein Tunnel wurde erst im folgenden, separat freigegebenen Schritt ergänzt.

Nach der ausdrücklichen Tunnel-Freigabe wurde ein Cloudflare Quick Tunnel mit projektlokalem, prüfsummenverifiziertem `cloudflared@2026.9.3` eingerichtet. Die öffentliche HTTPS-Adresse erreicht nur `server/dashboard_gateway.mjs` auf Loopback-Port 8001. Dieser erlaubt ausschließlich Dashboard-GET-Routen mit JWT-Bearer-Header; die tatsächliche Signatur- und Schlüsselbindung prüft das bestehende Better-Auth-Plugin auf Port 8000. Testpostfach, Konto-/Loginwege und alle Dashboard-Schreibmethoden bleiben öffentlich ausgeschlossen. Damit ist der Tunnel für Anschluss und lesende Dashboard-Nutzung bestimmt, nicht für vollständige Benutzerverwaltung.

Der Controller `scripts/start_dashboard_tunnel.py` übernimmt keine API-Schlüssel, nutzt eine bereinigte Prozessumgebung und ein frisches lokales HOME ohne bestehende Connector-Konfiguration. Strg+C oder die feste Laufzeitgrenze von 30 Minuten beendet Tunnel und Gateway, ohne den Auth-Dienst zu stoppen. Cloudflare sieht den Tunnelverkehr; ausschließlich synthetische Daten bleiben erforderlich. Details, Softwarequelle, Hashprüfung und beobachtete öffentliche Sperren stehen in damaligen lokalen Setup-Nachweis. Eine erfolgreich aktivierte Projektschaltfläche beweist noch keine Dashboard-Verbindung oder Projektanlage.

## Vertragsgrenzen

| Flutter-Aktion | Serverziel |
| --- | --- |
| Konto anlegen | `POST /api/auth/sign-up/email` |
| Anmelden | `POST /api/auth/sign-in/email` |
| Eigene Kontodaten | `GET /api/account/me` |
| Abmelden | `POST /api/auth/sign-out` |
| Bestätigungslink anfordern | `POST /api/auth/send-verification-email` |
| Bestätigen | `POST /api/account/verify` |
| Resetlink anfordern | `POST /api/auth/request-password-reset` |
| Passwort zurücksetzen | `POST /api/account/reset` |

Der Kontoabruf liefert `product_available: false` und keine Mitgliedschaften oder Events. In der aktiven Flutter-Konfiguration werden entsprechend nur Kontofunktionen angezeigt. Direkte Produktaktionen bleiben abgewiesen. Gastgeberverwaltung, Einladungsprüfung, Bewerbungen, Eventzusagen und Locations brauchen eine eigene Berechtigungsimplementierung.

## Nachweise

Die lokalen Backend-Tests prüfen echte Better-Auth-HTTP-Aufrufe mit PostgreSQL, fremde Browserursprünge, synthetische Adressen, Kontobindung und Einmaligkeit von Links, Ablauf, Wiederholungen, konkurrierende Registrierung und Linknutzung, Sitzungsentzug und Rate-Limits. Das aktivierte Dashboard-Plugin wird mit einem erfundenen Schlüssel und gesperrtem externem Testnetz auf die Ablehnung unsignierter Verwaltung geprüft. Das ist kein Cloud-Anschlussnachweis.

Zusätzliche Flutter-Tests prüfen den signierten Header, fehlerhafte oder abgelaufene Sitzungen, gebundene Fehlermeldungen, Formularvalidierung und die Kontoansicht. Bestehende Oberflächentests bleiben erhalten. Die Browserprüfung belegt Anmeldung, E-Mail-Bestätigung, Aktualisierung und Abmeldung mit einem synthetischen Testkonto. Passwortreset ist über echte HTTP-Backend-Tests und Flutter-Adapter-/Widgettests geprüft; eine neue Passworteingabe im Browser wurde nicht automatisiert.

Der Nutzer hat das Dashboard-Projekt „Community Access“ im Browser angelegt. Nach dem automatischen Ende des ersten Tunnels wurde für den abschließenden Test ein neuer Tunnel gestartet und dessen Base URL im bestehenden Projekt gespeichert. Ein anschließend ausschließlich über die lokale Auth-API angelegtes Konto „Synthetischer Verbindungstest“ mit `@example.invalid`-Adresse erschien auf `https://dash.better-auth.com/community-access/users`. Das belegt einen authentifizierten Dashboard-Leseabruf aus dem lokalen Auth-Dienst über die Tunnel-Weiterleitung. Der Bildnachweis wurde ohne echte Nutzerdaten gespeichert. Eine dauerhafte Verbindung, vollständige Analytics-/Audit-Log-Abnahme, Dashboard-Schreibrechte und Produktberechtigungen sind damit nicht nachgewiesen.

Eine zusätzliche vollständige Controller-Wiederaufnahme mit zwei getrennten Starts sowie eine PostgreSQL-/Auth-Neustartprüfung mit gespeicherten Konten, Sitzungen und Einmallinks bestanden synthetisch. Das lokale Testpostfach bleibt flüchtig; Browser-Neuladen erfordert weiterhin eine Anmeldung. Diese Nachweise ersetzen keine Veröffentlichung, externe Sicherung oder Berechtigungsabnahme. Die Domain `communityaccess.de` wurde als gewünschtes Ziel genannt; der weitere Einrichtungsplan steht [hier](../auth-public-setup.md).

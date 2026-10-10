# Google, Apple und Facebook anmelden

> Einordnung für V1 · 10.10.2026: Dieser datierte Detailbericht beschreibt den damaligen Implementierungsstand einschließlich des erhaltenen erweiterten Modus. Maßgebliche Produktregeln und Umfang stehen ausschließlich in der [Produktspezifikation](product-spec.md); aktuelle Start- und Prüfbefehle im [Setup](setup.md). Historische Statusangaben und Prüfergebnisse sind keine heutige Funktions- oder Betriebsfreigabe.

Stand: 02.10.2026. Reihenfolge auf Nutzerauftrag: Google → Apple → Facebook; Apple bleibt auf Nutzerwunsch zunächst offen. Die Web-Anbindung ist im bestehenden Better-Auth-Server und Flutter-Client implementiert. **Google-Webclient und Meta-App sind im Portal angelegt; die Facebook-HTTPS-Rückleitung ist gespeichert und validiert, public_profile und email sind bereit zum Testen. Private lokale Zugangsdaten, echte Testanmeldungen und öffentliches HTTPS-Deployment sind noch nicht eingerichtet beziehungsweise nachgewiesen.** Cloudflare-Free-Zone und Tunnelroute sind separat vorbereitet, aber noch inaktiv. Keine zusätzlichen kostenpflichtigen Anbieterabonnements oder Live-Veröffentlichung vorgenommen.

Der Nutzer hat anschließend Zugänge zu allen drei Entwicklerportalen und diesen PC mit dauerhaftem HTTPS-Tunnel bestätigt. Die konkrete Vorbereitung für `communityaccess.de`, die festen Callback-Adressen und die noch offene DNS-Freigabe stehen in [permanent-https-tunnel.md](permanent-https-tunnel.md). Dies ist eine Nutzerbestätigung vorhandener Zugänge, keine beobachtete OAuth-App-Freigabe.

## Beobachtete Google-Portalvorbereitung

Am 02.10.2026 wurden die angezeigten Google-Cloud-Nutzungsbedingungen nach ausdrücklicher Bestätigung unmittelbar vor der Aktion akzeptiert. Ein eigenes Projekt **Community Access** wurde angelegt und ausgewählt; Google vergab die Projekt-ID `vertical-hook-510420-a8`. Keine kostenlose Testphase, Abrechnungsverknüpfung oder kostenpflichtige Arbeitslast gestartet. Bereits vorhandene andere Projekte wurden nicht verändert. Die automatisch im neuen Projekt vorhandenen Standard-APIs wurden nicht zusätzlich konfiguriert oder verwendet.

Google Auth Platform wurde geöffnet. Nach gesonderter ausdrücklicher Freigabe wurde die Adresse des angemeldeten Google-Kontos als Nutzersupport und administrativer Kontakt eingetragen; die konkrete persönliche Adresse wird hier nicht gespeichert. Anwendungsname `Community Access`, Zielgruppe **Extern**, Start im **Testmodus**. `info@communityaccess.de` ist bisher Versandabsender ohne eingerichteten Posteingang. Die zusätzlich verlangte [Richtlinie zu Nutzerdaten für Google API-Dienste](https://developers.google.com/terms/api-services-user-data-policy?hl=de) wurde nach ausdrücklicher Bestätigung unmittelbar vor der Aktion akzeptiert. Google bestätigte anschließend „OAuth-Konfiguration erstellt.“; die Zielgruppenseite zeigt **Test**, **Extern** und keine Testnutzer. Die initiale Anwendungskonfiguration ist gespeichert; für eine Veröffentlichung verlangt Google noch die Vervollständigung des Brandings. Keine App veröffentlicht. [Gespeicherter Teststatus](screenshots/google-oauth-test-status.jpg); [vorheriger Zustimmungsdialog](screenshots/google-oauth-policy-review.jpg); [vorheriger Projektstand](screenshots/google-project-oauth-preparation.jpg).

Das Webclient-Formular ist mit Typ **Webanwendung**, Name **Community Access Web** und `https://communityaccess.de/api/auth/callback/google` vorbereitet; der Button **Erstellen** ist aktiv. Keine zusätzlichen Rückleitungen oder JavaScript-Quellen eingetragen; „This client will be used by an AI-powered agent“ ist nicht ausgewählt. Der erste Formularaufruf scheiterte an einem Google-Ladefehler; der angezeigte Wiederholungslink ohne `organizationId=0` öffnete das Formular erfolgreich. [Vorbereitetes Formular zur privaten Übergabe](screenshots/google-webclient-handoff.jpg).

Nach der privaten Übergabe bestätigte der Besitzer die Erstellung. Anschließend wurde ausschließlich das Vorhandensein des Links **Community Access Web** in der Google-Clientliste geprüft. Der Secret-Bildschirm, die Client-ID und das Client-Secret wurden nicht per KI gelesen. Die private Datei `~/.community-access-private/social-login.json` fehlt bei der anschließenden reinen Metadatenprüfung noch. Google muss daher noch im lokalen Helfer privat hinterlegt werden; Apple und Facebook können zunächst übersprungen und anschließend ergänzt werden. Der Rückleitungswert muss einschließlich Schema, Groß-/Kleinschreibung und abschließendem Slash exakt zur Backend-Konfiguration passen. [Google-Dokumentation](https://developers.google.com/identity/protocols/oauth2/web-server). Der vorhandene Client ist kein Nachweis einer funktionierenden Anmeldung; die gespeicherten Clientdetails wurden nach der Erstellung nicht erneut geöffnet.

## Beobachtete Apple-Portalvorbereitung

Das [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list) wurde im Betreiberbrowser geöffnet und die Anmeldung zur persönlichen Übernahme bereitgestellt. Nach der bestätigten Anmeldung zeigte das Portal **Access Unavailable**: Zugriff auf „Certificates, Identifiers & Profiles“ ist nur für Mitglieder eines Developer Programs oder eines entsprechenden Organisationsteams verfügbar. Der Besitzer bestätigte anschließend, bisher nur einen kostenlosen Developer-Account zu haben, und stimmte zu, Apple zunächst offenzulassen und Google/Facebook weiterzuführen. Die zuvor bestätigte Existenz eines Apple-Developer-Zugangs ist damit kein Nachweis einer aktiven Program-Mitgliedschaft. Keine Mitgliedschaft gebucht und keine App ID, Service ID oder Schlüssel angelegt. Keine Passwörter oder Bestätigungscodes per KI gelesen oder eingetragen. [Beobachtete Zugriffssperre ohne Kontodaten](screenshots/apple-developer-access-unavailable.jpg); [vorherige Anmeldeübergabe](screenshots/apple-developer-login-handoff.jpg).

Apple verlangt für Web-Anmeldung eine Service ID, die einer primären App ID mit aktiviertem „Sign in with Apple“ zugeordnet ist. Nach Anmeldung zunächst vorhandene passende Projektkennungen und Zugriffsrechte prüfen. Domain `communityaccess.de`, exakte Rückleitung `https://communityaccess.de/api/auth/callback/apple`; Schlüsselübernahme ausschließlich privat. [Apple-Anleitung](https://developer.apple.com/help/account/capabilities/configure-sign-in-with-apple-for-the-web).

## Beobachtete Meta-Portalvorbereitung

Wegen der offenen Apple-Voraussetzung wurde anschließend [Meta for Developers](https://developers.facebook.com/apps/) geöffnet. Das Portal leitete zur Meta-Anmeldung weiter; „Weiter mit Facebook“ öffnete die Facebook-Anmeldeseite mit Rückkehr zum Entwicklerportal. Nach persönlicher Anmeldung zeigte das Portal „Los geht’s“ und anschließend die Registrierung **Erstelle ein Meta for Developers-Konto**. Nach ausdrücklicher Zustimmung unmittelbar vor der Aktion wurde **Weiter** betätigt und dadurch die [Plattform-Nutzungsbedingungen](https://developers.facebook.com/terms/) sowie [Entwicklungsrichtlinien](https://developers.facebook.com/devpolicy/) akzeptiert. Die anschließende Kontaktbestätigung und tatsächlichen „About you“-Angaben wurden zur persönlichen Übernahme bereitgestellt. Der Besitzer bestätigte deren Abschluss; das Portal zeigt nun **Meine Apps** und die Appverwaltung **Noch keine Apps**. Damit ist der Zugang zur Appverwaltung beobachtet. [Vorheriger Kontaktschritt ohne Feldwerte](screenshots/meta-developer-contact-handoff.jpg); [vorheriger Zustimmungstext](screenshots/meta-developer-terms-review.jpg); [vorherige Anmeldeübergabe](screenshots/meta-developer-login-handoff.jpg).

Das Formular **App erstellen** wurde mit Name **Community Access** vorbereitet. Der Besitzer wies ausdrücklich an, **info@communityaccess.de** als App-Kontakt zu verwenden; die Adresse wurde eingetragen und der Schritt abgeschlossen. Als einziger Anwendungsfall wurde **Daten von Nutzern mit Facebook Login authentifizieren und anfordern** ausgewählt. Da kein Business-Portfolio verfügbar ist, wurde **Ich möchte noch kein Business-Portfolio verknüpfen** gewählt. Kein neues Portfolio angelegt. Der Hinweis zu Veröffentlichungsanforderungen wurde gelesen; Meta nennt **Unternehmensverifizierung** und **App-Review** für diesen Anwendungsfall.

Die Übersicht wurde zur persönlichen Erstellung an den Besitzer übergeben und auf dessen Wunsch einmal erneut ausgefüllt. Anschließend bestätigte der Besitzer den Abschluss. Das Meta-Dashboard zeigt jetzt **Community Access** mit Status **Unveröffentlicht** und dem Facebook-Login-Anwendungsfall. Die App ist damit im Portal angelegt; keine Veröffentlichung vorgenommen und kein App-Secret geöffnet oder gelesen. [Vorherige Übersicht zur persönlichen Erstellung](screenshots/meta-app-creation-handoff.jpg); [erneut ausgefüllte Übersicht](screenshots/meta-app-creation-refilled.jpg); [vorheriger Appname](screenshots/meta-app-details-prepared.jpg).

Die gewählte App-Kontaktadresse ist bisher als Versandabsender ohne eingerichteten Posteingang dokumentiert. Das Meta-Formular verlangt, das Kontaktpostfach regelmäßig auf Richtlinien-, Einschränkungs- und Wiederherstellungshinweise zu prüfen. Durch die Auswahl der Adresse wurde kein Posteingang eingerichtet; die Zustellbarkeit eingehender Meta-Hinweise ist nicht nachgewiesen.

Nach ausdrücklicher Zustimmung unmittelbar vor den Aktionen wurde `https://communityaccess.de/api/auth/callback/facebook` als einzige gültige OAuth-Rückleitung gespeichert. Die anschließende Meta-Validierung bestätigt **Dies ist eine gültige Redirect URI für diese App**. Client-OAuth und Web-OAuth sind bereits standardmäßig aktiviert; HTTPS und Strict-Modus für exakt passende Rückleitungen sind aktiviert und gesperrt. Eingebettete Browser, Geräte-Login und JavaScript-SDK-Login sind deaktiviert. Diese Schalter wurden nicht verändert. **public_profile** ist automatisch vorhanden; ausschließlich **email** wurde ergänzt. Die Berechtigungstabelle zeigt beide als **Bereit zum Testen**, mit jeweils null API-Aufrufen. Alle anderen angezeigten Berechtigungen bieten weiterhin **Hinzufügen** an. Keine App-Review oder Veröffentlichung vorgenommen; die Portalvalidierung beweist keinen funktionierenden Login oder öffentlich erreichbaren Callback. [Gespeicherte und validierte Rückleitung](screenshots/meta-facebook-oauth-saved.jpg); [gespeicherte Testberechtigungen](screenshots/meta-facebook-permissions-saved.jpg); [vorheriges Formular](screenshots/meta-facebook-oauth-review.jpg).

## Instagram: geprüfte Einschränkung

Am 02.10.2026 wurde auf Nutzerwunsch zusätzlich Instagram geprüft. Die offizielle [Instagram API mit Instagram Login](https://developers.facebook.com/documentation/instagram-platform/instagram-api-with-instagram-login) richtet sich ausschließlich an professionelle Business- und Creator-Konten zur Verwaltung ihrer Instagram-Präsenz. Private Gastkonten werden damit nicht als weiterer allgemeiner Anmeldeanbieter abgedeckt.

Eine optionale Verbindung professioneller Instagram-Konten für Gastgeber wäre eine separate Produktfunktion. Der Nutzer entschied ausdrücklich, bei Google und Facebook als Login-Anbietern zu bleiben. Instagram wird nicht ergänzt; Apple bleibt wie zuvor vereinbart offen. Keine Instagram-Berechtigung, Rückleitung oder Zugangsdaten angelegt; kein Instagram-Button ergänzt. Insbesondere wurden keine Veröffentlichungs-, Kommentar- oder Nachrichtenrechte erteilt.

## Anmeldevertrag

`server/social.mjs` aktiviert ausschließlich ausdrücklich konfigurierte Anbieter. `CA_SOCIAL_PROVIDERS` ist standardmäßig leer. Die öffentliche Anbieterabfrage liefert ausschließlich deren Namen; Secrets, Apple-Schlüssel und Provider-Tokens bleiben serverseitig. Flutter zeigt nur aktive Anbieter in der oben genannten Reihenfolge. E-Mail und Passwort bleiben verfügbar.

Flutter startet eine Anmeldung → Better Auth erzeugt OAuth-Zustand und PKCE → der Browser öffnet den Anbieter → dessen Rückleitung erreicht den Auth-Server → dieser prüft den Zustand und tauscht den Code aus → Flutter übernimmt eine signierte Sitzung aus dem Header. Ein URL-Marker allein meldet niemanden an. Ein HTTP-only-Cookie dient höchstens fünf Minuten lang der Sitzungsübergabe und wird dabei gelöscht. Das Sitzungstoken bleibt anschließend im Client-Arbeitsspeicher. Browser-Neuladen verlangt eine erneute Anmeldung. Abmeldung und Passwortreset entziehen serverseitige Sitzungen.

Apple verwendet einen Formular-POST. Der Server verarbeitet ihn intern, ohne eine weitere Browser-Rückleitung mit Code oder Namensdaten zu erzeugen. Das im Formular angelieferte ID-Token ist kein Identitätsnachweis. Das aus dem serverseitigen Codeaustausch erhaltene Apple-ID-Token wird gegen Signatur, RS256, Aussteller, Service ID, Ablauf und gespeicherte Nonce geprüft. Bei Folgeanmeldungen ohne E-Mail/Name ergänzen ausschließlich gespeicherte Werte einer bereits verbundenen Apple-Identität die fehlenden Angaben.

Ein Anbieterlogin erzeugt weder Gastgeberrollen noch Mitgliedschaften oder Profil-, Reihen- und Eventfreigaben. Konten werden über Anbieter und dessen stabile Account-ID zugeordnet. Gleiche E-Mail-Adressen verbinden Konten nicht automatisch. Dazu meldet sich die Person zuerst mit ihrer bisherigen Methode an, bestätigt ihre E-Mail und wählt im Konto „Google/Apple/Facebook verbinden“. Die Anmeldung darf höchstens zehn Minuten zurückliegen. Andere E-Mail-Adressen werden beim Verbinden abgelehnt; insbesondere eine Apple-Relayadresse wird nicht automatisch einem Passwortkonto zugeordnet. Bestehende Freigaben bleiben an derselben Nutzer-ID. Liefert Facebook beim ersten Login keine E-Mail, scheitert die Anmeldung kontrolliert; keine Adresse wird erfunden.

Access- und Refresh-Tokens werden mit dem stabilen Better-Auth-Schlüssel verschlüsselt gespeichert. Das ID-Token wird nach seiner Prüfung nicht im Account gespeichert. Nur grundlegende Anmeldeinformationen werden angefordert; keine Messenger-, Kalender-, Kontakt- oder Mailintegration. Der synthetische Entwicklungsmodus akzeptiert weiterhin ausschließlich `@example.invalid` und übernimmt keine externen Zugangsdaten. Echte Providerkonten gehören in den separaten privaten Mailbetrieb außerhalb des KI-Arbeitsbereichs.

## Voraussetzungen

Anbieter-Entwicklerzugänge wurden vom Nutzer bestätigt; beide HTTPS-Origins sind auf `https://communityaccess.de` festgelegt. Das ist noch kein beobachtetes Live-Deployment. Es fehlen tatsächliche OAuth-Clientkonfigurationen, private Schlüsselübernahme und die öffentliche HTTPS-Abnahme. Subdomains und zusätzliche Hostingverträge werden nicht stillschweigend festgelegt.

`CA_AUTH_API_ORIGIN` und `CA_AUTH_UI_ORIGIN` werden explizit gesetzt, jeweils ohne Pfad, Query oder abschließenden Slash. Oberfläche und Auth-Server sollten unter derselben Site laufen, damit Browser die benötigten Cookies akzeptieren. Apple verlangt HTTPS für beide. Der Backend-Prozess bindet weiterhin ausschließlich an `127.0.0.1:8000`; öffentliche HTTPS-Erreichbarkeit benötigt einen separat eingerichteten Reverse Proxy, der den konfigurierten Host erhält. Der bestehende Dashboard-Tunnel veröffentlicht diese Anmeldung nicht.

| Anbieter | Serverseitige Werte | Rückleitung im Anbieterportal |
| --- | --- | --- |
| Google | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | Auth-Origin + `/api/auth/callback/google` |
| Apple | `APPLE_CLIENT_ID` (Service ID), `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` (P-256 `.p8`) | Auth-Origin + `/api/auth/callback/apple` |
| Facebook | `FACEBOOK_CLIENT_ID` (App ID), `FACEBOOK_CLIENT_SECRET` | Auth-Origin + `/api/auth/callback/facebook` |

### 1. Google

In der [Google Cloud Console](https://console.cloud.google.com/) ein geeignetes Projekt und einen OAuth-Client vom Typ „Web application“ einrichten. Consent-Screen, Zielgruppe und Testnutzer mit tatsächlichen Betreiberangaben konfigurieren. Die exakte Rückleitungsadresse registrieren; lokal lautet sie für diesen Code `http://127.0.0.1:8000/api/auth/callback/google`. Keine Gmail-, Drive- oder Kalenderberechtigungen hinzufügen. [Providerdokumentation](https://better-auth.com/docs/authentication/google).

### 2. Apple

Ein aktiver Apple-Developer-Zugang ist erforderlich; eine Mitgliedschaft wird hier nicht gebucht. Im [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list) App ID mit „Sign in with Apple“, zugehörige Service ID für Web, Domains und die exakte HTTPS-Rückleitung einrichten. Einen passenden privaten `.p8`-Schlüssel erzeugen und außerhalb des Repositorys aufbewahren. Der Server erzeugt beim Start ein ES256-Client-Secret mit 180 Tagen Gültigkeit. Rechtzeitig neu starten und Schlüsselrotation separat pflegen; keine automatische Erneuerung im laufenden Prozess. Lokales HTTP ist kein Apple-Live-Test. [Providerdokumentation](https://better-auth.com/docs/authentication/apple).

### 3. Facebook

In [Meta for Developers](https://developers.facebook.com/apps/) eine geeignete App und Facebook Login für Web einrichten. App-ID, App-Secret und die exakte gültige OAuth-Rückleitung konfigurieren. Testpersonen, Betreiberangaben, echte Datenschutz- und Datenlöschungsangaben sowie die nötige Live-Freigabe im Portal prüfen. Vorhandene Prototypseiten sind kein Nachweis einer freigegebenen Anbieter-App. [Providerdokumentation](https://better-auth.com/docs/authentication/facebook).

## Verdeckte Einrichtung

Die Hilfe ist ausschließlich vom Besitzer in einem eigenen Terminal mit echten Daten zu bedienen. **Keine Secrets in Chat, Codex-Befehle, Shellhistory, Repository oder Flutter-Builds kopieren.** Die Hilfe legt keine Anbieter-Apps oder Deployments an.

```sh
python3 -I scripts/configure_social_auth.py
```

Sie fragt Google, Apple und Facebook nacheinander ab; Anbieter können übersprungen und später ergänzt werden. Verdeckte Eingaben werden ausschließlich unter `~/.community-access-private/social-login.json` mit Dateirechten `600` gespeichert; das Verzeichnis muss `700` haben. Übersprungene vorhandene Anbieter bleiben erhalten. Apple benötigt eine private `.p8`-Datei mit Rechten `600`. Offline-Prüfung ohne Ausgabe der Werte und Serverstart:

```sh
python3 -I scripts/configure_social_auth.py --check
python3 -I scripts/configure_social_auth.py --run
```

Der Start fragt Resend verdeckt ab. Konfiguration und Start verlangen ein privates interaktives Terminal. Die Hilfe zeigt zusätzlich den passenden Flutter-Build-Befehl: `CA_AUTH_API_ORIGIN` muss zum Backend passen, `CA_AUTH_UI_ORIGIN` legt die erlaubte Adresse für Bestätigungs-/Resetlinks fest und `CA_PRIVATE_MAIL=true` schaltet die echte Kontoform frei. Mailversand, Linkprüfung und Flutter verwenden denselben ausdrücklich konfigurierten UI-Origin. Der lokale Start veröffentlicht noch keinen HTTPS-Endpunkt. Der private Mailmodus schaltet weiterhin keine synthetische Gastgeber-/Katalogdemo für echte Konten frei.

## Prüfungen und Abnahmegrenze

```sh
python3 -I scripts/local_auth.py --test-social
python3 -I scripts/local_auth.py --test
python3 -I scripts/local_auth.py --test-directory
python3 -I scripts/social_setup_test.py
cd client
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
```

`--test-social` verwendet eine isolierte lokale PostgreSQL-Datenbank, echte Better-Auth-Account-/State-/Sessionlogik und synthetische Anbieterantworten. Externe HTTP-Anfragen sind gesperrt. Separate Tests prüfen Apple-Signaturen und Nonce, Anbieterbindung, abgelaufenen Zustand, fehlende E-Mail und Abmeldung während begonnener Verknüpfung. Die Einrichtungshilfe wird mit synthetischen Schlüsseln und isolierten temporären Dateien geprüft. Das beweist keinen Google/Apple/Meta-Live-Login und kein Deployment. Vor Aktivierung sind echte Testanmeldungen je Anbieter, explizites Verbinden, Logout und Rückleitungen im Betreiberbrowser separat zu prüfen, ohne Secrets oder personenbezogene Antworten im KI-Kontext zu lesen. Native iOS-/Android-Anbieter-SDKs sind nicht Teil dieser Web-Anbindung.

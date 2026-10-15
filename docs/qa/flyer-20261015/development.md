# Flyer: GitHub und Cloudflare Development

## Umfang

Branch `codex/flyer-development-20261015`, aufgebaut auf `ae7002f`.
Flyer-Oberfläche einschließlich ihrer zuvor lokalen Designbausteine, Iconfont,
Bewegungsregeln, Communities-/Datumsfilter und Regressionstests. Die parallelen
uncommitteten Backend-, Ticketing- und Native-Arbeiten sind nicht enthalten.

Der bisherige Cloudflare-Worker wurde am 15.10.2026 über die dokumentierte
Lese-API gesichert. Sein öffentlicher Veranstaltungskatalog mit datierten
Quellenangaben bleibt erhalten; dies ist keine erneute Inhaltsverifizierung.
Die bisherigen 14 öffentlich ausgelieferten Medien werden unverändert mit
SHA-256-Manifest bewahrt. Der ursprüngliche Kompatibilitätstag bleibt erhalten.
Der Adapter berücksichtigt jetzt auch die aktuellen `from`/`before`-Filter
und den leeren, nicht angemeldeten Community-Verzeichniszustand.

## Grenzen

`https://community-access-development.stany-nyssen.workers.dev/` ist eine
Frontend-Vorschau: keine Datenbank, Kontoanlage, Anmeldung, E-Mails, Käufe oder
echten Zahlungen. Der Worker beantwortet Schreibzugriffe und private APIs mit
`DEVELOPMENT_PREVIEW_ONLY`. Es gibt keine DNS-/Mail- oder Produktionsänderung.
Die App verbindet sich ausschließlich mit derselben Development-Adresse.
Suchmaschinenindexierung bleibt deaktiviert. Synthetisches Hero-Motiv ist
gekennzeichnet. Reale Geräte, Safari und Produktionsabnahme sind nicht belegt.

## Reproduzieren

Voraussetzung: bestehendes Flutter-SDK und die gesperrten Abhängigkeiten.
Keine neue App-Abhängigkeit ist erforderlich. Aus dem Projektstamm:

```sh
cd client
flutter pub get --offline
cd packages/ca_design/example
flutter pub get --offline
cd ../../../..
python3 scripts/build_development_web.py
node --test deploy/development/worker.test.mjs
```

Die vorhandene Wrangler-Version verwenden; keine automatische Aktualisierung.
Vor dem Veröffentlichen `wrangler deploy -c wrangler.development.jsonc --dry-run`.
Nach expliziter Deployment-Freigabe `wrangler deploy -c wrangler.development.jsonc
--var GIT_COMMIT:<vollstaendige-Commit-SHA>` ausführen. Zugangswerte gehören
nicht in Dateien, Befehlsargumente, Build oder Git. Der Health-Endpunkt
`/__development/health` nennt den deployten Commit und `backendConnected:false`.
`/development-release.json` nennt den aus Git gebauten Stand.

## Lokale Prüfung auf der isolierten Arbeitskopie

- Flutter-Analyse ohne Befund.
- 336 erweiterte UI-Regressionsprüfungen bestanden.
- 15 V1-/Flyer-Prüfungen bestanden.
- Vier Development-Worker-Prüfungen bestanden: Grenzen, Commitzuordnung,
  Datumsfilter und öffentliche Leerzustände.
- Quellenprüfung auf typische Zugangstoken-/Schlüssel-Muster ohne Treffer;
  dies ist keine umfassende Geheimnis- oder Sicherheitszertifizierung.

Build-, Deployment- und Live-Ergebnisse werden zusätzlich auf der SSD unter
`Webdesign Praktiken/Community-Access/Flutter-Flyer-2026-10-15/` protokolliert.

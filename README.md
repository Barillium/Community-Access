# Community Access

Eine kleine Zugangslösung für bestehende Kollektive: persönliche Einladung, Bewerbung und manuelle Communityaufnahme; Eventteilnahme wird separat zugesagt beziehungsweise durch bestätigte Ticketzahlung begründet. Bestehende Messenger bleiben bestehen.

## Erste Version

Stand: 10.10.2026. Lauffähiger lokaler V1-Umfang mit synthetischen Konten und Zahlungen. Öffentliche/private Einzelveranstaltungen, Konto/Wiederherstellung, Communityaufnahme, getrennte Zuständigkeiten, Standardtickets, Erstattungen und Einlass bilden den Kern. Den verbindlichen Umfang und zurückgestellte Funktionen beschreibt ausschließlich die [Produktspezifikation](docs/product-spec.md).

- [Start und Prüfungen](docs/setup.md): V1-Demo und erhaltener erweiterter Entwicklungsmodus.
- [Aktionsmatrix](docs/implementation/access-matrix.md): aktuelle Rechte je Ressource.
- [V1-Entscheidung](docs/decisions/0007-v1-scope.md): Reduktion und Umgang mit bestehenden Daten.
- [Projektanweisungen](AGENTS.md), [Git-Workflow](docs/workflow.md) und [Codex-Workflow](docs/codex-workflow.md): Arbeits- und Freigaberegeln.
- [V1-Prüfbericht](docs/qa/v1-reduction-20261010.md): tatsächlich ausgeführte Prüfungen und Grenzen.

## Architektur

`client/` enthält die aktive Flutter-App, `server/` Better Auth/Node.js und PostgreSQL, `pretix-plugin/` die lokale pretix-Erweiterung. Das Root-`package.json` und die Lockdateien halten vorhandene Abhängigkeiten fest.

`app/`, `supabase/` und `exercises/` bleiben separate Demo-/Lernbereiche. `scripts/task_runner.py` ist ein eingeschränkter Entwicklungsrunner. Sein weiterhin blockierter `product`-Scope beschreibt dessen Umfang; das aktive Produktbackend ist separat vorhanden und geprüft.

## Lokal starten

Im Projektstamm:

```sh
python3 -I scripts/local_auth.py --ticketing-demo
```

In einem zweiten Terminal:

```sh
cd client
flutter run --no-pub -d chrome --web-hostname=127.0.0.1 --web-port=8300
```

V1 ist Standard. Voraussetzungen, synthetische Demokonten, Beenden und Tests stehen im [Setup](docs/setup.md#flutter-mit-better-auth-starten). Fehlende Werkzeuge nicht ungefragt installieren. Neue Dienste, echte Anbieterzugriffe und Veröffentlichung benötigen ihren eigenen Auftrag.

## Nachweisgrenzen

Alle Produktprüfungen verwenden synthetische Daten und simulierte Zahlungen. Produktiver Zahlungsbetrieb, reale Zustellung, rechtliche/betriebliche Entscheidungen und native Geräteabnahme bleiben offen. Betreiber- und Rechtstexte sind Entwürfe. Ein lokaler Commit oder Quellcode-Upload ist keine Veröffentlichung der Anwendung.

Das vorhandene GitHub-Remote bleibt erhalten; dieser V1-Auftrag autorisiert keinen Push. Eine Lizenz für den eigenen Code ist weiterhin nicht gewählt. Keine echten Secrets, privaten Bewerbungen, Mitgliederlisten oder Einladungslinks im Repository.

# Community Access

Eine kleine Zugangslösung für bestehende Kollektive in Aachen. Einladungen führen zu Bewerbungen und manueller Aufnahme; Eventteilnahme wird separat bestätigt. Bestehende Messenger bleiben bestehen.

## Stand und Einstieg

- [Produktspezifikation](docs/product-spec.md): Rollen, Abläufe, Schutzgrenzen und offene Entscheidungen.
- [Lokales Setup](docs/setup.md): getestete Flutter-Web-Umgebung auf macOS ARM64.
- [Git-Arbeitsablauf](docs/workflow.md): Änderungen prüfen, gezielt sichern und eine Rücknahme üben.
- [Projektanweisungen](AGENTS.md) und [Codex-Arbeitsablauf](docs/codex-workflow.md): kleine Aufgaben, Freigaben und geprüfte Schutzgrenzen.

Die Werkzeuge sind eingerichtet; App und Backend sind noch nicht implementiert. Die separate Flutter-Test-App liegt außerhalb dieses Repositorys unter `~/develop/community_access_setup_check`.

## Projektstruktur

```text
Scene Access/              bestehender Projektstamm; kein Umbenennen erforderlich
  README.md
  AGENTS.md
  .gitignore
  docs/                    Produkt, Setup und Arbeitsablauf
  scripts/                 reserviert für spätere Hilfsskripte
  app/                     später: Flutter-Anwendung mit eigenen Tests
  supabase/                später: lokale Migrationen, Tests und synthetische Seeds
```

`app/` und `supabase/` werden erst beim jeweiligen Entwicklungsschritt angelegt. Ein einziges Git-Repository im Projektstamm umfasst später beide Bereiche. Kein verschachteltes Repository anlegen; die externe Setup-Demo wird nicht hierher kopiert.

## Arbeitsregeln

Lokal zuerst: Flutter/Dart, PostgreSQL und Supabase. Nur synthetische Daten für Entwicklung, Tests und KI-Kontext. Keine echten Secrets, privaten Bewerbungen, Mitgliederlisten oder Einladungslinks im Repository. Community-Rollen sind communitybezogen; Mitgliedschaft ist keine bestätigte Eventteilnahme.

Keine Messenger-Synchronisierung, Zahlungen, KI-Kompatibilitätsbewertung, Trust Scores oder globalen Szeneprofile. Backend-Zugriff muss standardmäßig verweigert und explizit erlaubt werden. Privilegierte Schlüssel gehören niemals in den App-Build. Transaktionen und Konkurrenzfälle benötigen später eigene Tests.

Vor Änderungen Status und relevante Dokumente lesen, Plan und Prüfungen nennen und bestehende Arbeit erhalten. Installation, Netzwerkfreigaben, neue Dienste, Veröffentlichung, Server-/DNS-Eingriffe und destruktive Aktionen benötigen die entsprechende Nutzerfreigabe. Commits werden aus bewusst ausgewählten, geprüften Dateien erstellt.

## Lokal bleiben und sichern

Es ist kein Remote eingerichtet und nichts veröffentlicht. Git speichert lokale Versionsstände, ersetzt aber keine separate Sicherung gegen Geräteverlust. Ein Backupziel ist noch nicht eingerichtet.

Open-Source-orientiert beschreibt die Ausrichtung. Eine Lizenz für den eigenen Projektcode wurde noch nicht gewählt; aus diesem README folgt keine Lizenzfreigabe. Die Lizenzen der installierten Werkzeuge stehen in der Setup-Dokumentation.

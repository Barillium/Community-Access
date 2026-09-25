# ADR 0003: App-Prüfungen und getrennte Kernprüfung

Status: Kontrollreview auf Nutzerauftrag „Änderungen und den neuen Kontrollstand prüfen und freigeben“. Die Freigabe betrifft den lokal geprüften Kontrollstand nach erfolgreicher Abnahme und Commit; dessen vollständige SHA wird im Abschlussbericht genannt. Keine Freigabe einer konkreten App-Aufgabe und noch kein echter App-Coding-Lauf. Ergänzt [ADR 0001](0001-single-task-runner.md), ohne dessen einmalige Freigaben, Deadline, Reparaturgrenze oder geschützte Vorgaben aufzuheben.

## Coding-Aufgaben

Neuer Scope `app-ui`: ausschließlich `app/lib/main.dart` und `app/lib/demo_status.dart` als zusätzliche mögliche Dateiziele. Höchstens fünf explizit freigegebene Dateien insgesamt; unverändert nur synthetische Aufgaben mit menschlich festgelegtem niedrigem Risiko. Tests, Abhängigkeiten, SQL, Rechte, Freigaben und Controller bleiben gesperrt. Die App-Vorlage ist keine Freigabe. Neue Funktionen außerhalb der eingefrorenen Testabdeckung benötigen zuerst einen eigenen Test-/Abnahmereview.

Vor dem Modellvorschlag und nach jedem Versuch: bestehende Dokumentations-/Dart-Prüfungen plus Offline-Auflösung anhand Lockdatei, App-Format, Analyse, mindestens fünf erfolgreich abgeschlossene nicht übersprungene App-Tests und Web-Build. Der JSON-Testbericht benötigt ein erfolgreiches Abschlussereignis; bloßer Text „All tests passed“ genügt nicht. Fehlende Tests, Pakete, Werkzeuge oder ein Fehler blockieren. App-/Backend-Anbindung und Produktmigrationen bleiben als Coding-Aufgaben gesperrt.

## Flutter-Prozessgrenze

Der Kandidat bleibt unverändert; Flutter arbeitet auf einer separaten Quellkopie. Leserechte: diese Kopie, installiertes SDK, vorhandene öffentliche Pub-Pakete/-Prüfsummen und erforderliche macOS-Systemwerkzeuge. Schreibrechte: nur temporäre Cacheverwaltung, `.dart_tool` und `build`. Die eigentlichen Quellen, eingefrorenen Tests, SDK und vorhandenen Pakete bleiben schreibgeschützt. Kopien der Quellen werden anschließend auf Integrität geprüft. Keine Zugangsdaten oder Docker-Sockets im App-Testprozess.

Das Flutter-Tool wird direkt als vorhandener Dart-Snapshot aufgerufen. `FLUTTER_ALREADY_LOCKED=true` verhindert den Schreibversuch am globalen SDK-Lockfile; dies ist keine tatsächlich erworbene globale SDK-Sperre. Während der Prüfung kein SDK-/Paketupdate durchführen. Flutter benötigt macOS-Systemdienstsuche, Signale an eigene Kinder und Loopback-Verbindungen. Externes Netzwerk bleibt gesperrt. Loopback ist nicht auf einzelne Testports begrenzt: andere lokale Dienste sind damit grundsätzlich erreichbar. Diese Grenze ist keine VM-Isolation und keine Zulassung absichtlich bösartigen Codes.

Builddateien haben ein OS-Limit von 256 MiB pro Datei, keine Gesamt-Diskquote. Das bisherige Codex-Limit bleibt 16 MiB. stdout/stderr oberhalb 1 MB werden nach Ende weiterhin abgewiesen; während eines App-Builds können sie bis zum Dateilimit wachsen. Das gemeinsame Aufgabenzeitlimit bleibt aktiv. Bei EPERM während der Prozessgruppen-Beendigung wird höchstens zwei Sekunden unabhängig geprüft, ob die Gruppe tatsächlich verschwunden ist; ohne Nachweis wird blockiert.

## Separate manuelle Kernprüfung

`check_project.py --scope current` prüft wie bisher Lernumfang und Runner; `--scope app` ergänzt die isolierte App-Prüfung. `--scope core` ergänzt darauf aufbauend echte lokale Auth-/API-Tests und SQL-Analyse. Supabase muss vorher gemäß Setup sicher lokal gestartet worden sein. Der Aufruf installiert und startet keine Infrastruktur. Der Testcontroller läuft als bewusst vertrauenswürdige Infrastruktur mit Fixture-Administratorzugang; er ist nicht der Coding-Agent und erhält keine Modellvorschläge zur Ausführung.

Backend-Prüfungen beziehen sich auf die tatsächlich laufende lokale Testdatenbank. Sie bauen keine vom Agenten vorgeschlagenen SQL-Migrationen auf und beweisen keinen Gleichstand beliebiger Kandidatenmigrationen mit dieser Datenbank. Deshalb existiert weiterhin kein Backend-Coding-Scope. Die bereits implementierten Backend-Tests sind begrenzt; `--scope product` bleibt wegen Einladungen, Kollektivaufnahme, Löschfristen, vollständigem Entzugsablauf und Flutter-Backend-Integration gesperrt.

Die Quellformate HTML, TOML und SQL wurden nur für konkrete App-/Supabase-Pfade zugelassen; Daten-Dumps, Konfigurationen mit Zugangswerten und unbekannte versteckte Pfade bleiben abgelehnt. `--include-reviewed` nimmt explizit benannte neue Dateien vor dem Commit in eine manuelle Prüfung auf, ohne sie zu stagen oder zu committen. Für echte Runner-Aufgaben gelten weiterhin ein sauberer Git-Stand und vollständige freigegebene Commit-Hashes.

# AutoGPT im Community-Access-Aufgabenrunner

Der Runner unterstützt zusätzlich `--provider autogpt`. Der Adapter holt von AutoGPT Classic genau den ersten Aktionsvorschlag und übernimmt daraus ausschließlich JSON-Dateivorschläge. Anschließend laufen dieselben geschützten Prüfungen wie bei Codex. Ergebnis bleibt ein Patch zur menschlichen Prüfung.

Implementierungsgrundlage und Grenzen stehen in [ADR 0004](decisions/0004-autogpt-proposal-adapter.md). Der neue Kontrollstand ist noch nicht freigegeben. AutoGPT wurde hier weder installiert noch gestartet, und es wurde kein Modellzugang eingerichtet.

## Vor einem echten Lauf

1. Den Diff von Controller, Tests und dieser Dokumentation prüfen, bewusst sichern und den vollständigen neuen Kontroll-Commit menschlich freigeben. Die Aufgabenbasis muss sauber sein. Vorhandene unversionierte Arbeit nicht löschen oder ignorieren, um den Runner zu starten.
2. Classic-Commit `c035ab1f91b8556f86e87be26dcaf31677f64ba5` und seine vollständigen Abhängigkeiten vor Installation separat prüfen. AutoGPT Platform ist keine austauschbare Protokollimplementierung. Keine automatische Installation durch den Runner.
3. Server technisch getrennt einrichten: ausschließlich synthetische Arbeitsablage, keine Repository-/Git-/Privatdaten- oder Docker-Socket-Mounts, keine Produktionszugänge. Der Upstream-Server bindet intern an alle Interfaces; ein nackter Hoststart ist nicht vorgesehen. Nur den konkret geprüften Port auf Host-`127.0.0.1` veröffentlichen und Erreichbarkeit sowie Isolation überprüfen. Dieser Aufbau ist noch nicht umgesetzt oder getestet.
4. Konkreten Modellanbieter, Modell, ausschließlich für Entwicklung bestimmte Zugangsmittel, Telemetrie, ausgehende Verbindungen und ein serverseitiges Kostenbudget festlegen und freigeben. Modellname im Runner ist Reviewmetadatum; er konfiguriert oder attestiert den Server nicht. Nach einem Timeout auf dem Server noch laufende Anfragen kontrollieren.
5. Serverrevision und Betriebsparameter bis zum Ende des Aufgabenlaufs festhalten. `--autogpt-runtime-reviewed` erst nach diesem Review verwenden. Für Änderungen eine neue Freigabe erstellen.

## Aufgabe und Anbieter ansehen

Folgende Befehle sind Vorlagen für den Menschen, **hier nicht ausgeführt**. Die bestehende [Aufgabenvorlage](tasks/README.md) und alle Freigabegrenzen gelten weiter. `8000` ist ein Beispielport, kein nachgewiesener laufender Dienst. Platzhalter durch bewusst geprüfte Werte ersetzen.

```sh
python3 -I scripts/task_runner.py dry-run docs/tasks/single-task.example.json \
  --base VOLLSTAENDIGE_GEPRUEFTE_BASIS_SHA \
  --control VOLLSTAENDIGE_FREIGEGEBENE_KONTROLL_SHA \
  --provider autogpt \
  --autogpt-endpoint http://127.0.0.1:8000/ap/v1 \
  --model GEPRUEFTES_SERVERMODELL \
  --autogpt-runtime-reviewed
```

`dry-run` zeigt Aufgabe, Dateiliste, Abnahme, `task_sha256`, Anbieterparameter und `provider_sha256`; er erzeugt keine Freigabe und verbindet sich nicht mit AutoGPT. Anschließend dieselben geprüften Parameter für `approve` verwenden und **beide** angezeigten Hashes bestätigen:

```sh
python3 -I scripts/task_runner.py approve docs/tasks/single-task.example.json \
  --base VOLLSTAENDIGE_GEPRUEFTE_BASIS_SHA \
  --control VOLLSTAENDIGE_FREIGEGEBENE_KONTROLL_SHA \
  --provider autogpt \
  --autogpt-endpoint http://127.0.0.1:8000/ap/v1 \
  --model GEPRUEFTES_SERVERMODELL \
  --autogpt-runtime-reviewed \
  --confirm-task-sha256 GEPRUEFTER_AUFGABENHASH \
  --confirm-provider-sha256 GEPRUEFTER_ANBIETERHASH
```

Der Coding-Agent darf diesen Freigabebefehl im Projekt nicht ausführen. Die Test-Suite prüft ihn ausschließlich in einem separaten synthetischen Wegwerf-Repository. Für einen danach ausdrücklich freigegebenen Lauf:

```sh
python3 -I scripts/task_runner.py run FREIGEGEBENE_AUFGABEN_ID \
  --provider autogpt --timeout 600
```

Endpunkt und Modell werden aus der Freigabe gelesen. `--codex-home` und ein Modelloverride beim AutoGPT-Lauf werden abgewiesen. Ein Anbieterwechsel blockiert vor dem Verbrauch der Freigabe. Ein tatsächlich gestarteter Versuch verbraucht sie auch bei Fehlern. Keine HTTP-Wiederholung nach einem Timeout: Eine serverseitige Aufgabe könnte schon angelegt worden sein.

## Ergebnis prüfen

`mode: live_autogpt` benennt den gewählten Adapterpfad, keine erfolgreiche Modellantwort. `autogpt_tools_approved: false` gilt für alle Ergebnisse. Erst `status: ready_for_review` bedeutet, dass der Dateivorschlag die bestehenden Prüfungen bestanden hat. Es bleibt ein lokaler Kandidat mit Patch und Bericht, ohne automatische Übernahme, Commit, Merge oder Veröffentlichung.

Ein anderes Werkzeug statt eines unmittelbar vorgeschlagenen `finish`, Markdown-Codeblöcke um das JSON oder ein fehlgeschlagener Protokollschritt blockieren. Der Runner erweitert dann keine Rechte und genehmigt keinen zweiten AutoGPT-Schritt. Die Funktionsfähigkeit dieses begrenzten Prompts mit einem echten Modell bleibt zu prüfen.

## Lokale Prüfungen

```sh
python3 -I -m unittest discover -s scripts/runner_tests -p test_autogpt.py -v
python3 -I scripts/check_project.py \
  --include-reviewed scripts/runner_tests/test_autogpt.py \
  docs/autogpt-runner.md docs/decisions/0004-autogpt-proposal-adapter.md
git diff --check
```

Die Adaptertests ersetzen HTTP-Antworten durch synthetische Fixtures; kein Server wird gestartet. Der OS-Test prüft verweigerte Datei- und Fremdnetz-Zugriffe. Erfolgreiche Verbindung zum erlaubten Loopback-Port, echter Classic-Server, Modellantwort, Serverisolation und serverseitiger Abbruch sind dadurch nicht nachgewiesen. Alle Pflichtprüfungen müssen vor einem echten Lauf bestehen; fehlende lokale Werkzeuge sind eine Blockade, kein Erfolg.

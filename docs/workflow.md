# Git im Community-Access-Projekt

## Die fünf Begriffe

| Begriff | Beispiel in diesem Projekt |
| --- | --- |
| Arbeitskopie | Die Dateien im Ordner `Scene Access`, die du gerade bearbeitest. |
| Staging / Index | Die bewusst ausgewählten Dateiversionen für den nächsten Commit. Spätere Änderungen derselben Datei landen nicht automatisch darin. |
| Commit | Ein lokaler Versionsstand mit Nachricht, Autor und Vorgänger. Er enthält nur die vorgemerkten Änderungen. |
| Branch | Ein benannter Entwicklungszweig, etwa `main` oder `docs/clarify-invitations`. Neue Aufgaben beginnen auf einem eigenen Branch. |
| Externe Sicherung | Eine zusätzliche Kopie außerhalb dieses Rechners. Lokale Commits schützen nicht vor Geräteverlust. |

Es gibt keinen Remote und keinen Push. Autorenmetadaten werden vor dem ersten Commit bewusst gewählt; globale Git-Einstellungen werden nicht verändert. Synthetische Projektmetadaten sind keine persönliche Identitätsbestätigung.

## Kleine Änderungen nachvollziehbar sichern

Im Projektstamm starten:

```sh
cd "/Users/stanynyssen/Scene Access"
git status --short --branch
git switch -c docs/clarify-invitations
```

`status` zeigt Branch und Änderungen. `switch -c` erzeugt einen neuen lokalen Branch; der Name ist ein Beispiel und muss für jede Aufgabe eindeutig sein. Vor einem Branchwechsel offene Arbeit prüfen und erhalten.

Nach einer kleinen Änderung, beispielsweise am README:

```sh
git diff -- README.md
git add -- README.md
git diff --cached --stat
git diff --cached -- README.md
git diff --cached --check
```

`diff` zeigt noch nicht vorgemerkte Änderungen. `add` wählt hier nur das README aus. `diff --cached` zeigt genau den nächsten Commit; `--check` prüft problematische Leerzeichen. Neue, noch unversionierte Dateien zeigt normales `git diff` nicht: deren Namen zuerst mit `git status` prüfen und nur bekannte, unkritische Inhalte lesen.

Erst wenn Inhalt, Dateiliste und Autorenangaben passen, folgt ein Commit. Beispiel mit ausdrücklich synthetischen Metadaten nur für diesen Aufruf:

```sh
git -c user.name="Community Access" -c user.email="development@example.invalid" commit -m "docs: clarify invitation workflow"
git status --short --branch
```

Ein Commit ist lokal; er veröffentlicht nichts. `??` bedeutet unversioniert, `A ` bedeutet als neue Datei vorgemerkt und ` M` bedeutet eine noch nicht vorgemerkte Änderung. Eine reine Branchzeile ohne weitere Einträge bedeutet einen sauberen Arbeitsstand. Nicht pauschal `git add .` verwenden.

## Was nicht in Git gehört

`.gitignore` hält unter anderem Umgebungsdateien, lokale Konfiguration, private Datenordner, Dumps, Backups, Schlüssel und Build-Ausgaben aus der üblichen Dateiauswahl heraus. Nur die exakten Vorlagen `.env.example` und `config.example.json` im Projektstamm sind ausgenommen; sie dürfen ausschließlich harmlose Platzhalter enthalten. Sie werden erst angelegt, wenn tatsächlich benötigt.

App-Lockdateien wie `app/pubspec.lock`, SQL-Migrationen und synthetische Seeds bleiben versionierbar. Ein echter SQL-Dump darf deshalb nicht beliebig als `.sql` neben einer Migration abgelegt werden: echte Daten bleiben ganz außerhalb des KI-Arbeitsbereichs. `.gitignore` ist weder Zugriffskontrolle noch vollständige Geheimniserkennung und wirkt nicht rückwirkend auf bereits versionierte Dateien. `git add -f` würde Ausschlüsse umgehen und ist hier kein normaler Arbeitsweg.

Eine synthetische lokale Konfiguration unter `.local/git-ignore-check/config.local.json` dient ausschließlich dem Ausschlusstest. Sie enthält keinen Zugangswert und wird nicht vorgemerkt. Ignorierte Dateien sind weiterhin auf dem Rechner vorhanden.

Zur Prüfung eines bekannten Dateinamens, ohne dessen Inhalt zu lesen:

```sh
git check-ignore -v -- .local/git-ignore-check/config.local.json
git status --short --ignored
```

Der erste Befehl nennt die passende Ausschlussregel. Der zweite zeigt ignorierte Pfade mit `!!`; er gibt keine Dateiinhalte aus.

## Sichere Rücknahmeübung

Nur auf sauberer Arbeitskopie durchführen. Die folgende Übung erzeugt eine neue Wegwerfdatei auf einem eigenen Branch; vorhandene Produktdateien werden nicht geändert. Wenn Branch oder Datei bereits existieren, anhalten und einen neuen Übungsnamen wählen.

```sh
git status --short
git switch -c learn/git-revert
mkdir -p experiments
printf '%s\n' 'Nur synthetische Git-Uebung.' > experiments/git-revert-demo.txt
git add -- experiments/git-revert-demo.txt
git diff --cached -- experiments/git-revert-demo.txt
git -c user.name="Community Access" -c user.email="development@example.invalid" commit -m "chore: add disposable git exercise"
git -c user.name="Community Access" -c user.email="development@example.invalid" revert --no-edit HEAD
git status --short
git log --oneline -3
git switch main
```

`printf` schreibt nur die neue Übungsdatei. Nach dem Übungs-Commit ist `HEAD` genau dieser Commit; nur in dieser unmittelbaren Reihenfolge ist `revert HEAD` hier richtig. `revert` erstellt einen neuen Gegen-Commit, der die gerade hinzugefügte Wegwerfdatei entfernt. Die Historie bleibt nachvollziehbar, andere Dateien bleiben unverändert. Der Übungsbranch bleibt zur Einsicht erhalten.

Bei einem Konflikt nicht mit Reset oder Überschreiben fortfahren. Status lesen und den konkreten Konflikt gemeinsam klären. Kein `reset --hard`, `clean`, Force-Push oder Löschen bestehender Arbeit für diese Übung.

## Prüfungen dieses Schritts

Die Abnahme prüft Markdown/Whitespace, die exakte vorgemerkte Dateiliste, Ausschlussregeln mit synthetischen Dateinamen und einer synthetischen lokalen Datei sowie den unveränderten Inhalt der bestehenden Produkt- und Setup-Dokumentation. Die Rücknahmeübung muss denselben Dateibaum wie vor dem Übungs-Commit ergeben. Private Konfiguration, Dumps oder echte Bewerbungen werden dafür nicht gelesen.

Eine gezielte Inhaltsprüfung der vorgesehenen Dokumentation ist keine Garantie gegen jede Art sensibler Daten. Vor einer späteren Veröffentlichung sind unter anderem lokale Pfade, organisatorische Angaben und Lizenzentscheidung erneut zu prüfen. Es werden keine Netzwerkdienste oder Sicherungsziele eingerichtet.

Flutter-Analyse und Anwendungstests werden in diesem Schritt nicht erneut ausgeführt: Es wird kein Dart-Code geändert. Deren letzter geprüfter Stand steht in [setup.md](setup.md).

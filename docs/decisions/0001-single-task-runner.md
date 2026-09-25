# ADR 0001: begrenzter Runner mit getrenntem Prüfer

Stand: 25.09.2026. Implementierungsentscheidung dieser Ausbaustufe; **noch keine Freigabe eines Kontroll-Commits für echte Modellläufe**. ADR bedeutet dokumentierte Architekturentscheidung.

## Ausgangspunkt

Vorhanden sind Dokumentation und eine abhängigkeitenfreie Dart-Lernübung. Flutter-App, Supabase und Produktrollen sind noch nicht implementiert. Flutter/Dart, PostgreSQL und Supabase bleiben der Zielstack. Die [Produktspezifikation](../product-spec.md) bleibt die einzige fachliche Grundlage.

## Entscheidung

Ein Python-Runner aus der vorhandenen Standardbibliothek steuert genau einen manuellen Lauf. Keine neue Paketinstallation, kein Dienst, Scheduler oder Cloud-Backend. Der Codex-Adapter benutzt die vorhandene CLI und liefert ausschließlich strukturierte Dateivorschläge. Nur der übergeordnete Runner wendet erlaubte Vorschläge an und startet die vorgegebenen Prüfungen.

Der Arbeitsstand ist ein Export eines expliziten lokalen Git-Commits ohne `.git`. Das ist eine getrennte Momentaufnahme, kein Git-Worktree mit gemeinsam beschreibbarer Git-Verwaltung. Das Ergebnis ist ein Patch mit Bericht und Kandidatendateien; keine automatische Übernahme, kein Commit durch den Agenten, kein Merge und kein Deployment.

Kontroll-Commit, Basis-Commit und Aufgabeninhalt werden vorab festgelegt. Der Runner vergleicht seinen eigenen Inhalt mit dem Kontroll-Commit. Tests stammen aus dem ebenfalls festgelegten Basis-Commit; für einen normalen Lauf sind sie schreibgeschützt. Der Aufgabenhash umfasst Risiko, Dateiliste und Abnahme. Freigaben liegen außerhalb der für Kinder lesbaren Bereiche. Ein nicht blockierendes Dateilock verhindert parallele Starts in diesem Repository.

macOS Seatbelt beschränkt Modell- und Testprozesse zusätzlich: nur ausdrücklich erlaubte Dateien lesen, nur eigene temporäre Ausgabe schreiben. Tests haben keinen Netzwerkzugriff; der Codex-Adapter braucht nach gesonderter Freigabe Netzwerk zum Modelldienst. Es gibt keinen ungeschützten Fallback. Der Agent darf den CLI-Befehl zur Freigabe nicht ausführen; sein Prozess darf außer der festgelegten Codex-Datei keine anderen Programme starten.

Vor jedem Lauf prüft ein synthetischer Grenztest die Lese-, Schreib- und Netzwerksperre des Testprofils. Unveränderte Ausgangstests müssen zuerst bestehen. Dann folgen ein Vorschlag und höchstens zwei Reparaturversuche. Das Laufzeitbudget umfasst Vorschlag und Prüfungen; Prozessbeendigung erhält maximal zwei zusätzliche Sekunden je aktuell beendetem Kind. Nicht bestätigtes Aufräumen sperrt weitere Starts bis zur menschlichen Klärung.

## Grenzen und verworfene Abkürzungen

- `AGENTS.md`, `.gitignore`, ein Branch oder eine Anweisung „ändere keine Tests“ sind allein keine technische Isolation. Daher getrennte Vorschläge und ein OS-Profil.
- Diese Grenze gilt gegenüber den gestarteten Kindern, nicht gegenüber dem macOS-Kontoinhaber, Administratoren oder anderen unbeschränkten Prozessen desselben Kontos. Git-Hashes authentifizieren keine menschliche Identität. Der Mensch muss den Kontrollstand prüfen und auswählen.
- Die erlaubten Systembibliotheken, Dart-SDK und Codex-Binärdatei sind Teil der vertrauenswürdigen lokalen Umgebung. Ihr Inhalt wird nicht pro Lauf kryptografisch attestiert. Globale Dateimetadaten bleiben lesbar; private Dateiinhalte sind nicht pauschal freigegeben.
- Keine Container-/VM-/separate-Benutzer-Isolation eingerichtet. Prozessgruppen beenden normale Nachkommen, sind kein Beweis gegen absichtlich abgetrennte Prozesse oder Kerneldefekte. macOS-Sandboxverhalten muss nach Betriebssystem- und Werkzeugupdates erneut geprüft werden.
- Dedizierte Entwicklungsanmeldung bleibt manuell. Keine produktiven Zugangsdaten, SSH-Agenten oder Veröffentlichungsrechte an Kinder weiterreichen. Der Adapter liest `auth.json` nicht selbst und kopiert niemals die normale Codex-Anmeldung. Der Modellprozess benötigt diese spezielle Entwicklungsanmeldung; eine technische Prüfung ihrer Kontorechte findet nicht statt.
- Codex-Netzwerk ist nicht auf einzelne Domains eingeschränkt. Ein echter Modellaufruf und sein Authentifizierungs-/Netzwerkprofil sind noch ungeprüft; die Tests simulieren den Modellvorschlag. Ein erfolgreicher Schutztest für Dart ist kein Nachweis für Codex-Netzwerkbetrieb.
- Tests sind schreibgeschützt, aber ihr Erfolg ist kein Beweis gegen beliebig bösartigen Programmcode oder eine vollständige fachliche Abnahme. Der vorhandene Neun-Fälle-Test belegt nur die Lernfunktion. Keine Behauptung vollständiger Testabdeckung neuer Funktionen.
- Eine Lizenz für den Projektcode bleibt offen. Python nutzt die bestehende Standardbibliothek; keine neue Produktionsabhängigkeit oder kostenpflichtige Funktion wird aktiviert. Modellzugang, Tarif und mögliche Nutzungskosten sind vor einem echten Lauf vom Menschen zu klären.

## Spätere Erweiterungen

App-, Datenbank- oder Berechtigungsaufgaben bleiben gesperrt, bis tatsächliche App-, Datenbank- und Rollentests samt synthetischer Umgebung vorhanden und die Prüfregeln separat freigegeben sind. Auch Wiederholung, Transaktionen, Entzug und Konkurrenz um den letzten Eventplatz gehören dann zwingend zur Abnahme. Keine dieser Produktentscheidungen wird durch den Runner vorweggenommen.

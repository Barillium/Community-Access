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

## Nachtrag: tatsächlich erzeugtes Anmeldeverzeichnis

Der Nutzer hat Kontrollstand `5c86c25` freigegeben und sich separat angemeldet. Die CLI erzeugte neben `auth.json` die Ordner `log` und `tmp`; das wurde ausschließlich anhand der Namen und Dateitypen festgestellt. Die ursprüngliche Ein-Datei-Prüfung blockierte dieses Layout.

Die Korrektur auf `fix/runner-login-layout` toleriert genau diese beiden regulären Ordner, gibt jedoch nur die Anmeldedatei zum Lesen frei. Konfigurationen, weitere Einträge und Symlinks bleiben abgelehnt. Schreibrechte oder Netzwerkrechte werden nicht erweitert. Echte Anmeldedaten und Log-Inhalte werden dafür weder gelesen noch verschoben. Der neue Kontrollstand benötigt vor einem echten Modelllauf einen eigenen menschlichen Review. Ein Modelllauf sowie mögliche weitere CLI-Laufzeitanforderungen bleiben ungeprüft.

## Nachtrag: getrennte Codex-Laufzeitablage

Der erste echte Start gegen Kontrollstand `f226551` brach vor einem Modellvorschlag beim Initialisieren des internen App-Servers ab. In einer leeren Offline-Testumgebung wurde nachgewiesen: Die CLI schreibt eine lokale SQLite-Zustandsdatenbank; deren WAL-Datei überschreitet bereits beim Start das bisherige 1-MB-Dateilimit. Die beobachtete CLI-Version war nun `0.155.0-alpha.16.4`.

Die vorbereitete Korrektur auf `fix/runner-codex-state` verwendet pro Versuch ein frisches `CODEX_HOME` innerhalb der bereits schreibbaren temporären Laufablage. Dort verweist ein vom Controller erzeugter Symlink ausschließlich auf die explizite Entwicklungs-Anmeldedatei. Das OS-Profil erlaubt deren Original weiterhin nur zum Lesen. Fremde Symlinks in Aufgaben, Kandidaten oder dem übergebenen Anmeldeverzeichnis bleiben verboten; der interne Auth-Verweis ist eine gezielte Ausnahme. Die normale Benutzeranmeldung wird nicht eingebunden und die echte Anmeldedatei wird weder gelesen noch kopiert durch den Controller.

Nur für den Codex-Prozess steigt das Dateilimit auf 16 MiB je Datei. Für Tests bleibt es bei 1.000.000 Bytes. stdout/stderr werden nach Prozessende weiterhin bei 1.000.000 Bytes abgewiesen; während des Modellprozesses können sie bis zum höheren OS-Limit wachsen. Das ist keine Gesamt-Diskquote. Deadline, Ausführungsrechte und Netzwerkprofil bleiben unverändert. Ein Token-Refresh kann gegebenenfalls eine neue Datei in der temporären Laufablage erzeugen; diese Ablage ist daher weiterhin privat und darf nicht versioniert oder ungeprüft geteilt werden. Der Runner synchronisiert solche Daten nicht zurück in die ursprüngliche Anmeldung.

31 Tests inklusive tatsächlichem Offline-CLI-Start bestanden. Ein synthetischer OS-Test belegt: Laufzeitdatei über 1 MB schreibbar, ursprüngliche Anmeldedatei durch den internen Verweis nicht überschreibbar. Namensauflösung von `chatgpt.com` gelang separat ohne Zugangsdaten mit dem bestehenden Netzwerkprofil. Dies belegt noch keine erfolgreiche authentifizierte Modellantwort. Die Korrektur benötigt einen neuen menschlich freigegebenen Kontrollstand; die verbrauchte erste Aufgabenfreigabe wird nicht wiederverwendet.

## Nachtrag: öffentliche System-Zertifikate

Kontrollstand `aff3b9a` wurde nach Nutzerfreigabe committet und für einen neuen echten Lauf verwendet. Die CLI initialisierte jetzt erfolgreich, scheiterte jedoch beim TLS-Verbindungsaufbau mit `invalid peer certificate: UnknownIssuer`. Der identifizierte eigene Codex-Prozess wurde nach wiederholtem identischem Fehler gezielt beendet; die ursprüngliche Anmeldung blieb unverändert.

Ein separater Verbindungstest ohne Zugangsdaten zeigte: Mit `SSL_CERT_FILE=/private/etc/ssl/cert.pem` gelang der TLS-Aufbau; anschließend antwortete der Dienst mit `401 Unauthorized`, wie ohne Anmeldung zu erwarten. Der zeitbegrenzte Diagnosetest belegt den TLS-Weg, keine erfolgreiche Modellantwort. Das vorhandene öffentliche CA-Bündel liegt bereits innerhalb der lesbaren Systempfade. Keine Zertifikatsinstallation, keine zusätzliche Dateifreigabe und keine deaktivierte Zertifikatsprüfung sind nötig.

Die vorbereitete Korrektur auf `fix/runner-system-certificates` setzt ausschließlich diese feste CA-Datei in der bereinigten Codex-Umgebung. Fehlt sie, blockiert der Start. Hostseitige CA-/TLS-Umgebungsvariablen werden weiterhin nicht übernommen. Die Vertrauensbasis hängt damit vom vorhandenen macOS-CA-Bündel ab; nach OS-/CLI-Updates erneut prüfen. Der geänderte Controller benötigt vor einem weiteren angemeldeten Lauf einen eigenen Review und Freigabe.

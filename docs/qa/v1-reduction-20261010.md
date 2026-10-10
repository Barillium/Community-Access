# Reduzierte lauffähige V1 · 10.10.2026

Auftrag: doppelte oder widersprüchliche Regeln beheben und eine lauffähige reduzierte V1 auf einem neuen Branch lokal committen. Branch: `codex/v1-scope-cleanup-20261010`. Ausgangscommit: `9d63c11`. Keine Veröffentlichung oder neuen Installationen.

## Ergebnis und Regelbereinigung

Die [Produktspezifikation](../product-spec.md) ist die einzige verbindliche Produktregelquelle. [ADR 0007](../decisions/0007-v1-scope.md) begründet den Umfang. Frühere Regeln bleiben ausdrücklich als [Historie](../history/product-decisions-through-20261009.md) erhalten. Die versehentlich zur zweiten Aktionsmatrix gewordene Setup-Datei enthält wieder Start- und Prüfanweisungen; ihr eigener Kontoanhang wurde in die [Aktionsmatrix](../implementation/access-matrix.md) übernommen. Arbeitsregeln, technische Rechte und Testnachweise sind getrennt.

Bereinigt wurden insbesondere überholte Aussagen zum fehlenden Backend, Veranstalterrechten gegenüber ausdrücklich zugewiesener Communitymoderation, Profilzugang gegenüber einzelner Eventfreigabe, Mitgliedschaft gegenüber Teilnahme und die pauschale Löschbehauptung gegenüber getrennt aufzubewahrenden Finanzdaten. Die Vorschau sagt jetzt „Einzelne Eventfreigabe“; ihre Regressionserwartung folgt derselben fachlichen Korrektur. Der ältere Runner-Scope `product` bleibt eine Grenze dieses Lernwerkzeugs, keine Produktstatusaussage.

V1 ist Standard für Serverprozess und Flutter. Zurückgestellte Wege fehlen in der Oberfläche und werden bei direkten HTTP-Aufrufen verweigert. Die chronologische Startseite ignoriert gespeicherte Empfehlungssignale. Auch frühere private Profilfreigaben und öffentliche Reihen öffnen die zurückgestellten Wege nicht. Der ausdrücklich gewählte erweiterte Entwicklungsmodus erhält den Ausbau ohne Datenlöschung. Alle neuen V1-Bedienbeschriftungen sind in Deutsch und Englisch hinterlegt; der Datenschutzentwurf benennt den tatsächlich aktiven Umfang.

Zahlungsabgleich, Belege, Erstattungen und Einlass verwenden unabhängig vom Katalogmodus die bisherigen vollständigen Berechtigungsregeln. Ein ausgeblendetes bestehendes Event darf dadurch weder eine bezahlte Bestellung stornieren noch einen Einlasshalt auslösen. Neue Käufe für zurückgestellte Events oder Kategorien werden verweigert. Bestehende Aufbewahrungsklassen und echte Sperrprüfungen bleiben erhalten.

## Commitumfang und erhaltene Vorarbeiten

Der Ausgangsstand enthielt bereits umfangreiche uncommittete Implementierung. Für eine aus Git wiederherstellbare App werden deshalb auch die benötigte bereits vorhandene Server-/Flutter-Basis, lokale Designpakete samt Lizenzen, native Projektvorbereitung, Lockdateien, synthetische Fixtures, Migrationen und lokale Prüfskripte übernommen. Neue V1-Änderungen sind die Prozess-/Buildabgrenzung, betroffenen Katalog-/Ticketwege, vereinfachten Bedienelemente, gezielten Tests und konsolidierten Regeln. Es wurden keine neuen Pakete aufgelöst oder installiert.

Runtimebestände, Abhängigkeiten, Builds, private Konfiguration und frühere Provider-/DNS-/Mailnachweise werden nicht aufgenommen. Die separate `app/`-/Supabase-Demo, Übungen und geschützte Runner-Kontrolllogik bleiben unverändert. Weitere nicht ausgewählte lokale Vorarbeiten bleiben im Checkout. Historische Berichte können auf weiterhin nur lokal vorhandene Nachweise verweisen; sie gehören nicht zur aktuellen V1-Abnahme.

## Tatsächlich ausgeführte Prüfungen

Alle nachfolgend aufgeführten Schlussläufe bestanden, ohne übersprungene Fälle:

| Prüfung | Ergebnis |
| --- | --- |
| V1 HTTP/PostgreSQL `--test-v1` | 10 Tests: direkte Zusatzwege, öffentliche/private Profile, Reihen, Sortierung, Kaufwiederholung, Zahlung/Location, Altbestellung, Scanner und Einmaleinlass |
| Auth `--test` | 12 Tests |
| Communityaufnahme `--test-access` | 14 Tests |
| Verzeichnis `--test-directory`, nach letzter Korrektur erneut | 57 Tests |
| Ticketing `--test-ticketing` | 15 Tests |
| Private Rechte/Moderation `--test-private-access` | 26 Tests |
| Vorhandenes natives pretix `--test-native-ticketing` | 8 Tests plus 7 native Verifikationspunkte, nur simulierte Zahlungen |
| Erhaltene Anbieteranmeldung `--test-social`, isolierte synthetische Konfiguration | 15 Tests |
| Store-/Kontoschutz `--test-store` | 4 Tests |
| HTTP/Gateways/Mail/Limits/Kompression/Modus/Store-/Social-Konfiguration | 29 Komponententests |
| Importfreie pretix-Plugin-Policy | 4 Tests |
| Flutter V1 `test/v1_scope_test.dart` | 4 Tests |
| Flutter erweitert, V1-Tags ausgeschlossen | 292 Tests |
| Dart-Formatierung, `flutter analyze --no-pub` | Bestanden, keine Analysebefunde |
| Separater V1-Web-Releasebuild, ohne Pub-/CDN-Download | Bestanden; kein nativer Gerätebuild |
| Chromium, ausschließlich `127.0.0.1` | 9 Prüfpunkte, keine Seitenfehler |

Die vorhandenen Backendregressionen laufen bewusst im erweiterten Modus. V1-Tests und Browserabnahme verwenden den Standardmodus. Zwischenläufe deckten eine irreführende Vorschau-Beschriftung auf und wurden nach Korrektur erneut ausgeführt. Ein zunächst direkt aufgerufener Social-Integrationstest benötigte seine isolierte Fixture-Konfiguration; sein korrekter Wrapper-Lauf besteht. Eine Flutter-Prüfung aus dem falschen Verzeichnis zählte nicht; die vollständig wiederholte Client-Prüfung besteht. Frühere Testannahmen über neutrale 404-Antworten und wiederholbaren Checkout wurden an den tatsächlich geschützten Vertrag angepasst, einschließlich einer Datenbankprüfung auf genau eine offene Bestellung.

Browserabnahme: persönlicher Kauf → simulierte Bestätigung → geschützte Location → eigener Beleg → Teil-/Vollerstattung durch Veranstalter → Provisionsansicht für Plattformteam. Zusätzlich V1-Navigation bei 390/1440 Pixeln und Ticketliste bei 320 Pixeln. Die drei folgenden Screenshots wurden visuell geprüft:

- [Startseite mobil](v1-reduction-20261010/v1-home-390.png)
- [Startseite Desktop](v1-reduction-20261010/v1-home-1440.png)
- [Eigene Tickets bei 320 Pixeln](v1-reduction-20261010/my-tickets-mobile.png)
- [Browserergebnis](v1-reduction-20261010/browser-result.json) und [Prüfzahlen](v1-reduction-20261010/checks.json)

Die eigens gestarteten Browser-, Web-, Auth-, Ticket- und Datenbankprozesse wurden beendet. Synthetische Diagnosebestände bleiben gemäß bestehendem Wrapper erhalten und werden nicht committed.

## Prüfung des vorgemerkten Quellstands

Die explizite Dateiliste wurde gegen den gesamten Git-Index abgeglichen und separat exportiert. Der Export enthielt alle benötigten lokalen JavaScript-/Dart-Importe und drei Flutter-Assetmanifeste. Ein dabei entdecktes fehlendes synthetisches Flyer-Testasset wurde ergänzt. Geprüft wurden 74 JavaScript-Dateien auf Syntax, 38 Python-Dateien auf Syntax, 133 Dart-Dateien auf lokale Importziele sowie JSON und die acht zentralen Dokumente auf vorhandene Linkziele. Drei Leerraum-/Zeilenendbefunde in übernommenen Lizenz-/Plugindateien wurden ohne inhaltliche Änderung bereinigt; der vollständige Staging-Whitespacecheck besteht. Bekannte Schlüssel-/Tokenformate ergaben in der expliziten Dateiauswahl keine Treffer; das ersetzt keine umfassende Geheimniserkennung.

Auch direkt aus diesem Export bestanden nochmals alle 10 V1-HTTP-/PostgreSQL-Tests und der V1-Web-Releasebuild. Dafür wurden ausschließlich die bereits installierten Abhängigkeiten wiederverwendet; keine Paketinstallation oder neue Auflösung. Die lokalen App-/Designpaketpfade zeigten auf die exportierten Quellen. Alle 45 nicht für den Commit ausgewählten bereits versionierten Dateien blieben gegenüber dem Aufgabenstart bytegleich. Unversionierte Provider-/Nachweisdateien bleiben ebenfalls außerhalb des Commits erhalten.

## Grenzen und ausgelassene Bereiche

Kein Push, Deployment, echter Mailversand, Anbieter-Login oder Stripezugriff. Nicht ausgeführt: reale Geräte/Safari, Store-Einreichung, vollständige Barrierefreiheits-, Rechts- oder Produktionsabnahme sowie erneute Tests der unveränderten Supabase-/Lerndemo. Der ältere Einzelaufgaben-Runner ist für diese App nicht geeignet und wurde nicht erweitert oder freigegeben. Betreiber-/Verkäuferdaten, gewählte Provision, Vertrags-/Aufbewahrungsfragen, echte Anbietertests und Betrieb bleiben vor echtem Verkauf offen. Dies ist eine lokal lauffähige synthetische V1.

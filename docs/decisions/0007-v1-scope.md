# ADR 0007: Reduzierte erste Version

Datum: 10.10.2026 · Nutzerauftrag: doppelte/widersprüchliche Regeln beheben, eine lauffähige reduzierte V1 auf neuem Branch lokal committen.

## Entscheidung

Die [Produktspezifikation](../product-spec.md) ist die einzige verbindliche Produktquelle. Sie ersetzt widersprechende frühere Produkttexte. Arbeitsregeln stehen in der Root-AGENTS.md, Rechte in der [Aktionsmatrix](../implementation/access-matrix.md), Ausführung im [Setup](../setup.md). Historische Berichte beschreiben ausschließlich ihren damaligen Prüfstand.

V1 ist Standard in Serverprozess und Flutter-Build. Der vorhandene erweiterte Entwicklungsumfang bleibt ausschließlich bei explizitem `CA_PRODUCT_EDITION=extended` erreichbar. Es werden keine Daten oder bestehenden Implementierungen gelöscht. Der Umfang wird in der Oberfläche sowie serverseitig begrenzt. Einzelveranstaltungen ohne Reihenbindung, Communityaufnahme, manuelle Teilnahme, Standardticketing, Moderation und Einlass bilden den Kern.

Die genaue Liste der enthaltenen und zurückgestellten Funktionen steht ausschließlich in Abschnitt 2 der Produktspezifikation. Eine zweite Scope-Tabelle wird hier nicht geführt.

## Begründung und Folgen

Die bisherigen chronologischen Ergänzungen widersprachen sich bei Zuständigkeiten und Implementierungsstand. Communitymoderation wird ausdrücklich vom Veranstalter getrennt. Bei Tickets bedeutet manuelle Freigabe Kaufberechtigung; Zahlung begründet Teilnahme. Die vorhandene Antrags-/Eventbereinigung bleibt von der Vorschau neuer Datenklassen getrennt. Setup enthält wieder Start- und Prüfanweisungen statt einer zweiten Aktionsmatrix.

Finanzielle Folgeprozesse verwenden weiterhin die vollständigen bisherigen Berechtigungsregeln. V1-Katalogfilter allein dürfen keine bestehende Zahlung stornieren, keinen Einlasshalt setzen oder Belege/Erstattungen verlieren. Neue Verkäufe für zurückgestellte Events/Kategorien werden dagegen verweigert.

Die bestehende Suite wird explizit im erweiterten Modus ausgeführt; neue V1-Tests prüfen den Standardmodus. Keine Änderung am geschützten Einzelaufgaben-Runner, seinen Freigaben oder Scope-Grenzen. Neue Abhängigkeiten, reale Dienste, Push und Veröffentlichung gehören nicht zum Auftrag.

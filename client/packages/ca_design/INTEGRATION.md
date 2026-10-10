# Lokale Integration in Community Access

Quelle: `community-access-codex-uebergabe.zip`, vom Nutzer am 05.10.2026 zur
schrittweisen Umsetzung freigegeben. Die ursprünglichen Dateihashes stehen in
`docs/qa/ca-design-integration-2026-10-05/package-original-hashes.json`, bezogen
auf den Projektstamm.

Bewusst freigegebene Abweichungen von der Paketquelle:

- `fonts/OFL.txt` ist als Asset registriert, damit die Lizenzanzeige sie laden kann.
- `tool/gen_tokens.py` liest die bestehende zentrale Quelle
  `client/design/aushang3.tokens.json`. Es gibt keine zweite Tokenquelle.
- Die untere Navigation begrenzt die Systemschrift nicht mehr auf 130 Prozent.
  Ihre Höhe wird an die vollständige, gegebenenfalls mehrzeilige Beschriftung
  angepasst. Die Plattformhöhen 50/80 bleiben Mindesthöhen; Tippflächen sind
  über die volle Höhe bedienbar.
- Die Rundungen nativer iOS-Einstellungen bleiben als ausdrücklich freigegebene
  Ausnahme erhalten.
- Zusätzliche Tests prüfen Lizenzladung, 200 Prozent Systemschrift sowie
  beschriftete iOS-/Android-Tippflächen in beiden Darstellungen.
- Lokale Fehlvergleichsbilder sind ausgeschlossen; die gelieferten Referenzen
  sind unverändert.

Tokenpflege, vom Projektstamm aus:

```sh
python3 -I client/packages/ca_design/tool/gen_tokens.py
dart format client/packages/ca_design/lib/src/tokens.dart
```

Die ursprüngliche README und Beispiel-App bleiben als Übergabereferenz erhalten.
Ihre Aussagen über frühere Freigaben, Testergebnisse oder Plattformanforderungen
sind keine zusätzlichen aktuellen Nachweise. Die Beispielaktionen ersetzen keine
Produktlogik.

Aktueller Abnahmestand: siehe `docs/qa/ca-design-integration-2026-10-05/report.md`.

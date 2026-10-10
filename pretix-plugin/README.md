# Community Access pretix plugin · lokaler synthetischer Betrieb

Auf pretix 2026.8.0 festgelegt, isoliert installiert und mit eigener PostgreSQL-Datenbank geprüft. Das Plugin ergänzt die nativen Cart-/Order-/Presale-Hooks und leitet den bestehenden Stripe-Kartenanbieter ab. Vendor-Dateien bleiben unverändert.

- Ein persönlicher Warenkorb, kontogebundene Browserübergabe und erneute Berechtigungsprüfung auch bei Ticketdownloads.
- 15-Minuten-Frist gilt für Warenkorb und unbezahlte native Bestellung.
- Geschützter Prozentsatz, Gebühr vom nativen Preis nach Ermäßigung, kein Käuferaufschlag.
- Native PDF-Ausgabe und Einlassprüfung; Entzug sperrt native Positionen.
- Lokale Zahlungen und Gebührenrückzahlungen sind simuliert. Kein Stripe-Konto, Schlüssel oder echter Geldfluss.

`python3 -m unittest discover -s pretix-plugin/tests` prüft nur die importfreie Policy. `python3 -I scripts/local_auth.py --test-native-ticketing` prüft aus dem Projektstamm zusätzlich die installierte native Laufzeit. [Setup](../docs/setup.md#lokale-ticketing-demo-05102026) und [Prüfergebnisse](../docs/qa/ticketing-20261005.md).

`constraints-2026.8.0.txt` dokumentiert die geprüfte Auflösung; `dependency-review-20261005.json` enthält Paketmetadaten, Lizenznamen und Wheel-Hashes. Eine weitere Installation erfordert die entsprechende Freigabe. Native Daten und Umgebung bleiben unter ignoriertem `.local/`.

Livebetrieb bleibt gesperrt. Echte Connect-Verbindung, Stripe-Webhooks und explizite API-Rückzahlungen der Plattformgebühr benötigen eine getrennte Sandbox-Abnahme. [Architektur und Lizenzbedingungen](../docs/ticketing.md).

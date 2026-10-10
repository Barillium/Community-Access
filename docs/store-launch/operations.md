# Lokale Betriebsübergabe und späteres Hosting

Der Nutzer hat kein Hosting gewählt. Es wurde kein neuer Dienst gebucht, kein DNS verändert und nichts veröffentlicht.

## Lokal reproduzierbar

- Bestehende isolierte PostgreSQL-Prüfung: `python3 -I scripts/local_auth.py --test-store`.
- Neue Schemaergänzung `server/migrations/0010-account-deletion.sql` wird im bestehenden lokalen Auth-Bootstrap ausgeführt. HTTP-Prozesse mit `CA_AUTH_BOOTSTRAP=false` führen weiterhin kein DDL aus. Die neue Tabelle erfordert bei bestehenden Installationen einen gesonderten Eigentümer-Bootstrap; keine automatische Remote-Migration.
- Löschvorgänge: `GET/POST /api/account/deletion`; serverseitig das aktuelle Konto. Teamwarteschlange `GET /api/account/deletion/queue` nur mit zugewiesener `ca_team`-Rolle und Produktmodul. Ein Plattformausschluss sperrt das Datenschutzanliegen nicht.
- Vorläufiger Alterswert `CA_MINIMUM_ACCOUNT_AGE=16`; `CA_ACCOUNT_AGE_REVIEWED` bleibt bis zur Prüfung ungesetzt. Mit konfiguriertem Alter und fehlender Prüfung bleibt Kontoanlage geschlossen. Der Review-Schalter ist eine Betreiberangabe und keine technische Rechtsprüfung.
- `NODE_ENV=production` mit synthetischem Produktprofil scheitert vor Datenbank- und Mailzugriff. Der vorhandene private Mailmodus bleibt erhalten, enthält aber keinen echten Produkt-/Ticketbetrieb.
- Kandidatenbuilds und Prüfberichte liegen unter `.local/store-launch`; keine echten Zahlungs- oder Mailzugänge an Compiler oder Tests weiterreichen.

## Anforderungen an das noch zu wählende Hosting

Dauerhaft betreibbarer Node-Prozess, PostgreSQL mit eingeschränkter Anwendungsrolle, getrennte Migrationseigentümerrolle, selbst betriebenes pretix 2026.8.0 mit geplantem Aktualisierungspfad, dessen Arbeitsprozesse/Redis und persistentem Dateispeicher sowie HTTPS-Gateway. Region, Betriebskosten, Auftragsverarbeitungsverträge und Sicherung müssen vor Auswahl verglichen werden. Kein konkreter Tarif oder Versionsupgrade ist gewählt.

Gesundheitsprüfung ohne Personen-/Zahlungsdaten, datensparsame technische Meldungen, Wiederherstellung in getrennte Umgebung, Umgang mit Entzügen und abgelaufenen Daten nach Wiederherstellung. Laufende Zahlungs-/Erstattungsabgleiche müssen auch bei pausierten Neukäufen weiterlaufen.

## Zahlungsadapter: noch echte Implementierung nötig

Der vorhandene `syntheticPretixClient` sowie `createTicketing` weisen echte Anbieter bewusst ab. Das bisherige Datenmodell kennzeichnet Verbindungen/Belege als synthetisch. Vor Produktion sind eigene geprüfte Anbieterzustände und Migrationen, idempotente Bestell-/Webhook-/Refundwege, Signaturprüfung, Stripe-Connect-Onboarding pro Verkäufer, unveränderliche Verkäufer-/Gebührenstände und Tests der Rückerstattung von Plattformgebühren erforderlich. Testantworten umbenennen oder `synthetic=false` setzen ist keine Umsetzung.

Bei Systembrowser-Checkout darf keine mit dem Dart-HTTP-Client erzeugte Cookie-Challenge als Browserbindung gelten. Übergabe muss im tatsächlich geöffneten Browser entstehen und serverseitig kurzlebig, kontogebunden, wiederholsicher und widerrufbar geprüft werden. Keine Tokens in URLs. Dies bleibt ein Startblocker.

## Kontolöschung: vorbereiteter Eingang, offener Abschluss

Anfragen werden dauerhaft angenommen, mit eindeutiger Referenz quittiert und auf maximal 100 Vorgänge in der teamgeschützten Warteschlange begrenzt. Passwörter werden nur an die vorhandene serverseitige Better-Auth-Prüfung übergeben, nicht gespeichert. Ein höchstens fünf Minuten alter Login kann alternativ die Identität bestätigen.

Vor realem Einsatz Bearbeitung festlegen und nachweisen: Konto-/Sitzungslöschung, Gastgeberverantwortung und Delegationen, Bewerbungen/Präferenzen/Interessen, externe Loginanbieter, pretix/Stripe und gesetzliche Restdaten, offene Erstattungen, Backups/WAL sowie Kommunikation von Fristen und Abschluss. Keine Pauschalfrist wurde erfunden; keine automatische Löschung aktiviert. Die Tabelle darf nicht durch einen Konto-Fremdschlüssel kaskadieren.

## Nur der Eigentümer im privaten Bereich

Betreiberanschrift, tatsächliche Verträge und Anbieterzugänge vervollständigen. Secrets, Karten-/Kontodaten, MFA und Entwicklerzertifikate außerhalb von Repository und KI-Kontext halten. Die Templates enthalten ausschließlich öffentliche Einstellungen. Entwicklerkonto- und Veröffentlichungsschritte gehören nicht zu diesem Auftrag.

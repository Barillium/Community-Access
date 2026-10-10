# Beta- und Geräteabnahme

Status: vorbereitet, nicht als ausgeführt markieren. Browser-QA ist separat. Nur synthetische Testpersonen und Events verwenden.

| Prüfung | Erwartung | iPhone | Android |
| --- | --- | --- | --- |
| Installation und Start | Kein Absturz; lesbare öffentliche Ansicht; keine Testkonten vorausgefüllt | offen | offen |
| Konto ab 16 | Explizite Altersbestätigung; Server lehnt fehlende/falsche Bestätigung ab | offen | offen |
| Verifikation und Reset | Links öffnen kalt und warm die richtige Appansicht; Fremddomain abgewiesen | offen | offen |
| Einladung und Eventlink | Keine automatische Freigabe; servergeprüfte Sicht und Adresse | offen | offen |
| Sitzung | Nach Neustart erneute Anmeldung; keine ungeschützte Tokendatei; Abmeldung/Entzug wirksam | offen | offen |
| Ticketkauf | Externer Checkout hat seine eigene sichere Sitzung; Rückleitung ist kein Zahlungsbeleg | offen | offen |
| Zahlungswiederholung | Kein Doppelkauf; letzte Plätze bleiben transaktional begrenzt | offen | offen |
| Erstattung/Entzug | Keine positive Einlassfreigabe nach Sperre; Finanznachweise erhalten | offen | offen |
| Bilder | JPG/PNG-Auswahl und Abbruch; große/falsche Datei; EXIF entfernt; Ausgabe begrenzt | offen | offen |
| Kontakt und Meldung | Mailprogramm/Browser öffnet; Abbruch ohne Absturz; Moderation erreichbar | offen | offen |
| Kontolöschung | Eigene Anfrage; Passwort/erneute Anmeldung; Netzfehler und Wiederholung; tatsächliche Bearbeitung | offen | offen |
| Schlechte Verbindung | Eindeutige Fehler; keine ungewollte Wiederholung einer schreibenden Aktion | offen | offen |
| Große Schrift und Tastatur | Kleine Displays und 200 Prozent Schrift bleiben bedienbar | offen | offen |
| VoiceOver/TalkBack | Fokusfolge, Namen, Status und Eingabefehler verständlich | offen | offen |
| Zurück und Lebenszyklus | OS-Zurück, Hintergrund/Vordergrund und Abbruch erhalten sinnvollen Zustand | offen | offen |
| Berechtigungen | Keine Kamera-, Mikrofon-, Standort- oder Vollspeicherabfrage ohne Produktbedarf | offen | offen |

Pro Ergebnis Geräte-/OS-/Buildversion, Datum, Tester, tatsächlichen Ablauf und Befund erfassen. Kein Gerätetest wurde durch lokale Widgettests ersetzt. Neue persönliche Google-Play-Konten benötigen derzeit 12 kontinuierlich angemeldete Tester über mindestens 14 Tage, danach Antrag auf Produktionszugang; das wird über den Kontoinhaber durchgeführt.

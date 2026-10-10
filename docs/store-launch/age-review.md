# Konto ab 16: geprüfte Grundlagen und offene Umsetzung

Stand 09.10.2026. Nutzerentscheidung: Konten ab 16, Ticketverkauf zum Start. Recherchebasis Deutschland/EU; Zielmärkte und konkrete Vertragsbedingungen sind noch nicht bestätigt. Dies ist eine vorbereitende Prüfung, keine Rechtsfreigabe.

## Datenschutz und Vertrag getrennt behandeln

Artikel 8 DSGVO betrifft die Einwilligung nach Artikel 6 Absatz 1 Buchstabe a bei direkt an Kinder gerichteten Onlineangeboten. Ab 16 kann diese Altersvoraussetzung erfüllt sein; andere Rechtsgrundlagen, verständliche Informationen und Anforderungen an wirksame Einwilligung bleiben zu prüfen. Artikel 8 Absatz 3 lässt nationales Vertragsrecht ausdrücklich unberührt. Die Zahl 16 ist daher keine allgemeine Erlaubnis für Konto- oder Kaufverträge. [Amtlicher EU-Text, Artikel 6–9](https://eur-lex.europa.eu/eli/reg/2016/679/oj?locale=de).

Für Deutschland verlangen rechtlich nicht lediglich vorteilhafte Erklärungen Minderjähriger grundsätzlich die Einwilligung der gesetzlichen Vertretung. Ohne erforderliche Einwilligung hängt die Vertragswirksamkeit von deren Genehmigung ab. Der konkrete kostenlose Nutzungsvertrag und bezahlte Ticketkauf müssen jeweils eingeordnet werden. [§ 107 BGB](https://www.gesetze-im-internet.de/bgb/__107.html), [§ 108 BGB](https://www.gesetze-im-internet.de/bgb/__108.html).

§ 110 BGB kann einen vollständig mit entsprechend überlassenen Mitteln bewirkten Vertrag wirksam machen. Daraus folgt keine pauschale Freigabe für jeden Onlinekauf; Herkunft/Verfügung über Mittel und vollständige Leistung sind Bedingungen. Ein Häkchen „Ich bin 16“ oder eine erfolgreiche Kartenzahlung weist diese Voraussetzungen nicht nach. [§ 110 BGB](https://www.gesetze-im-internet.juris.de/bgb/__110.html).

## Einlass bleibt veranstaltungsbezogen

Bei öffentlichen Tanzveranstaltungen dürfen 16- und 17-Jährige ohne entsprechende Begleitung grundsätzlich längstens bis 24 Uhr anwesend sein; gesetzliche Ausnahmen sind getrennt geregelt. Für als Nachtbar/Nachtclub geführte Gaststätten und vergleichbare Vergnügungsbetriebe gilt eine eigenständige Minderjährigengrenze. Konkreten Betriebstyp, Begleitung, Zeit und gegebenenfalls behördliche Ausnahmen muss der Verkäufer/Veranstalter klären. Konto und Zahlung ersetzen keine Einlassprüfung. [§ 5 JuSchG](https://www.gesetze-im-internet.de/juschg/__5.html), [§ 4 JuSchG](https://www.gesetze-im-internet.de/juschg/__4.html).

## Vor der Freigabe konkret entscheiden

- Zielmärkte, Betreiber und kostenlose Nutzungsbedingungen bestätigen; nötige Einwilligung der Sorgeberechtigten und deren nachvollziehbare Erfassung bestimmen.
- Für Ticketkäufe 16-/17-Jähriger einen rechtlich geprüften Kaufweg festlegen, einschließlich Verkäuferbedingungen, Erstattungen und Zahlungsanbieterregeln. Noch kein Minderjährigen-Kaufweg implementiert oder freigegeben.
- Communityzuordnungen/Bewerbungen auf mögliche besondere Kategorien personenbezogener Daten prüfen; Rechtsgrundlage und erforderliche Zusatzbedingungen bestimmen. Keine Gesundheits-/Szeneklassifikation und keine Ausweiskopien als Standard erheben.
- Veranstalter müssen Alter, Einlasszeiten, Begleitung und Ausnahmen je Event verständlich angeben und tatsächlich kontrollieren können.
- Kontoalter, Eventmindestalter und Store-Inhaltsbewertung getrennt festlegen. Die Selbstauskunft ist keine verifizierte Alterskontrolle.

## Technischer Stand

Der Store-Kandidat verlangt eine aktive Bestätigung ab 16 und übermittelt den konfigurierten Wert serverseitig. Es wird kein Geburtsdatum gesammelt. Bei `CA_MINIMUM_ACCOUNT_AGE=16` blockiert der Server Registrierung, bis `CA_ACCOUNT_AGE_REVIEWED=true` ausdrücklich gesetzt ist. Dieses Flag bestätigt eine externe Prüfung; es führt selbst keine Prüfung durch. Standard-Entwicklung ohne Alterskonfiguration bleibt synthetisch. Die Startfreigabe bleibt offen.

# Entscheidungen

> Einordnung für V1 · 10.10.2026: Die folgenden Entscheidungen dokumentieren den vorhandenen Ausbau. Zurückgestellte Profil-/Reihen- und Kategorienwege sind nur im erweiterten Modus aktiv. Verbindlicher Produktumfang und Aufbewahrungsklassen: [Produktspezifikation](../product-spec.md); Begründung: [ADR 0007](../decisions/0007-v1-scope.md).

## Bestehende Architektur übernehmen

Der Fahrplan benennt Flutter/Supabase, verlangt aber zugleich die Übernahme funktionierender Architektur. Die geltende AGENTS.md und die tatsächliche Implementierung verwenden Better Auth/Node/PostgreSQL sowie pretix. Diese bleiben bestehen; kein zweiter produktiver Datenbestand und kein neues Authsystem.

## Verbindliche lokale Defaults

- Eventgrant öffnet nur das konkrete Event. Die zusätzliche implizite Profilaufnahme wurde entfernt; die bisherige Prüfung auf widerrufenen Profilzugang bleibt bestehen.
- Die primäre Community-Mitgliedschaft bleibt kompatibel. Zusätzliche Community-Zugangswege brauchen eine vom zuständigen Community-Moderator bestätigte Eventzuordnung.
- Vorhandene freiwillig gestellte und angenommene Communityanträge gelten beim Upgrade als bewusst angenommen. Es gibt keine automatische Aufnahme durch Ticketkauf.
- Privater Kategoriengrant erweitert nie Eventzugang. Kategorien: inherit_event, community_subset, explicit_grant; Kauf: visible_authenticated oder event_approval_required.
- Ein persönliches Ticket pro Event über alle Kategorien; bestehender Unique-Index wird übernommen. Ein Event, ein Veranstalter, EUR pro Bestellung. Mengen- oder Clientpreise werden nicht angenommen.
- Kategoriebedingungen sind Kaufbedingungen. Nach bezahlter Ausstellung prüft Einlass Eventzugang und Sperren; Verkaufsende oder reiner Communityaustritt bei einem öffentlichen Event entzieht das Ticket nicht.
- Zahlungen bleiben ausschließlich synthetisch. Kategorien sind im unabhängigen Vertragsadapter und im bereits installierten nativen pretix 2026.8.0 integriert. Jeder native Artikel hat ein Kategorienkontingent und gehört zusätzlich zum gemeinsamen Eventkontingent. Keine neue Installation oder Änderung am Vendor-Code.
- Temporäre Maßnahmen brauchen ein explizites Zukunftsdatum. Dauerhafte Communitysperren brauchen zwei verschiedene zugewiesene Moderatoren. Falltexte bleiben getrennt von wirksamen Sperren.
- Scanner ist eine zeitlich begrenzte Eventrolle. Zufälliges Token wird gehasht gespeichert; Onlineprüfung vergleicht den Inhaber anhand seiner bestätigten Konto-E-Mail. Diese Zuordnung ist ein Testverfahren, keine vorgegebene rechtliche Identitätsprüfung. Kamera-/QR-Erkennung ist keine Voraussetzung für den serverseitigen Einlasstest.
- Keine neuen Löschfristen: Nutzerentscheidung 08.10.2026 ausdrücklich „zunächst nur Vorschau“. Bestehende bereits vereinbarte Bereinigung ist separat zu behandeln.

## Communityverwaltung und Verantwortlichkeit

Nutzerklärung am 08.10.2026: „Die Communities werden von Moderatoren verwaltet und nicht den Veranstaltern“. Deshalb gewährt `ca_host` als bestehende Veranstalterzulassung keine Communityverwaltung. Gültige `ca_community_staff`-Zuweisung ist für Einladung, Aufnahme, Formular, Communityregeln, Veröffentlichungsrecht und Communityfreigabe erforderlich. Sie wird ausschließlich vom Plattformteam zeitlich begrenzt zugewiesen. Eine Person kann nur durch diese getrennte Zuweisung zusätzlich Moderator werden; Veranstalterstatus erteilt die Rolle nicht automatisch.

`ca_community_publisher` begrenzt Veröffentlichung auf genau einen Auftritt und eine Community. Eine Profilzuordnung allein genügt nicht; der Entzug kann nicht durch erneutes Speichern der Zuordnung umgangen werden. Neue Eventveröffentlichungen bleiben bis zur Communityfreigabe für Gäste geschlossen. Bereits gültige synthetische Veröffentlichungsrechte werden beim Upgrade übernommen. Synthetische Regressionfixtures besitzen ausdrücklich zusätzlich zugewiesene Moderationsrollen; neu zugelassene Veranstalter erhalten diese nicht.

Der vorhandene Verantwortliche `ca_organizer.owner_id` bleibt der eindeutige Event- und Verkaufseigentümer. Ein Konto kann mehrere Auftritte führen; mehrere unabhängige Auftritte dürfen in derselben Community veröffentlichen. Es gibt keinen Eigentümerentzug oder Eigentümerwechsel-Endpunkt, also auch keine API zum Entfernen des letzten Eigentümers.

Der Nutzer hat anschließend ausdrücklich die gemeinsame Auftrittsverwaltung gewählt. `ca_organizer_member` ergänzt eine angenommene Verwalterrolle je konkretem Auftritt. Einladungen sind sieben Tage gültig und verleihen vor Annahme keine Verwaltungsrechte. Das verantwortliche Konto verwaltet diese Einladungen und ihren Entzug sowie Änderungen der Zahlungszuordnung. Gemeinsame Verwaltung überträgt weder die Verkäuferzuordnung noch Communitymoderation oder Rechte an weiteren Auftritten desselben Eigentümers. Versionsprüfungen und der bestehende gemeinsame Schreiblock schützen gleichzeitige Annahme, Entzug und Profiländerungen. Die zulässigen Communityzuordnungen richten sich weiterhin nach dem verantwortlichen Konto des bearbeiteten Auftritts. Offene Profilaufnahme-Links prüfen zusätzlich das fortgeltende Recht ihres Ausstellers. [Umsetzung und Nachweise](collaboration.md).

Communityregeln sind additive Versionen, die der freiwillige Aufnahmeantrag referenziert. Eine neue Regelversion verändert den alten Antragsbezug nicht. Annahme, Aufnahmeentscheidung und freigegebene Teilnahme bleiben eigenständige Zustände.

## Erteilte Freigaben und offene Entscheidungen

Der Nutzer bestätigte am 08.10.2026 ausdrücklich die Anpassung vorhandener Kauf-, Zahlungsabgleichs- und Mitgliedschaftsentzugspfade mit Berechtigungs-/Konkurrenztests. Zwei Werkzeugänderungen wurden zuvor automatisch abgelehnt; die erste wurde sicherer auf die Entfernung der impliziten Profilfreigabe bei erhaltener Sperrprüfung begrenzt. Private Projektnotizen wurden nach abgelehnter zusätzlicher Abfrage nicht weiter gelesen.

Native Kategorien wurden anschließend ausdrücklich lokal freigegeben und mit echten Artikel-/Kontingentmodellen geprüft.

Vor echtem Verkauf offen: verbindliche Verkäuferidentität je Veranstalter, Zahlungsempfänger, ausdrücklich gewählte Provision, Auszahlungen, Stornierungen/Erstattungsverantwortung, rechtlich geprüfte Aufbewahrungspolitik und echte Stripe-Sandbox. Dafür keine Vertragsregeln erfinden. Die lokalen synthetischen Tests sind unabhängig davon möglich.

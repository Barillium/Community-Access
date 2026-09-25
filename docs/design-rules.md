# Regeln für die spätere Oberfläche

Stand: 25.09.2026. Diese Regeln konkretisieren die Verständlichkeit der [Produktspezifikation](product-spec.md); eine synthetische Statusoberfläche ist implementiert; eine verbindliche visuelle Identität ist noch nicht festgelegt.

- Deutsch, kurze Beschriftungen und klare nächste Schritte. Fachbegriffe beim ersten Auftreten erklären.
- Einladung, Bewerbung, Mitgliedschaft, Eventanfrage und Eventbestätigung getrennt benennen. Ein genehmigter Bewerbungsstatus darf keine zugesagte Eventteilnahme suggerieren.
- Manuelle Entscheidungen als solche kennzeichnen. Keine KI-Bewertung, Vertrauensskala oder communityübergreifenden Profile.
- Community und zuständigen Kontext sichtbar machen; Sichtbarkeit ist kein Backend-Zugriffsschutz.
- Ladezustand, leerer Zustand, Fehler und Erfolg benötigen verständliche Rückmeldungen. Fehlertexte enthalten keine Tokens, privaten Adressen oder Bewerbungsantworten.
- Bedienbarkeit mit Tastatur, eindeutige Feldbeschriftungen und verständliche Fokuszustände als spätere Abnahme vorsehen. Status nicht allein durch Farbe vermitteln.
- Nur synthetische Beispiele. Formularpflichtfelder, Aufbewahrung weiterer Daten, konkrete Gestaltung, Farben, Schrift und Komponentenbibliothek bleiben offen; keine zusätzlichen personenbezogenen Felder erfinden.

Diese Dokumentationsregeln werden im Diff geprüft. Erste Widget-Tests sind im Nachtrag unten dokumentiert. Automatische Browser- und umfassende Barrierefreiheitstests stehen noch aus.

## Erste lokale Demo

`app/` verwendet vorläufig die Material-3-Komponenten des Flutter-SDK mit einem grünen Farbschema; dies ist keine festgelegte Markenidentität. Die Seite zeigt den Community-Kontext und ausschließlich erfundene Beispiele. Beschriftete Auswahlchips wechseln Demozustände, ohne fachliche Aktionen auszuführen. Status bleibt als Text sichtbar; die Statuskarte ist als Live-Region ausgezeichnet. Die lokale Anzeige hat keinen Lade-, Serverfehler- oder leeren Datenzustand, da keine Daten angefordert werden. Solche Zustände müssen mit einer späteren Datenanbindung ergänzt werden.

Widget-Tests prüfen Startzustand, alle vier Beispiele, Tastaturbedienung und schmale Darstellung mit großer Schrift. Eine vollständige Barrierefreiheitsabnahme steht noch aus.

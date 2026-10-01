# Community Access · Flutter-Gastoberfläche

Diese Oberfläche wurde am 01.10.2026 aus dem bisherigen Vergleichsprototyp erhalten. Sie enthält Gastanmeldung, Kontowiederherstellung, Einladungen, Bewerbungen, Eventansichten sowie ihre bestehenden Tests und Rubik-Schriftdateien samt Lizenz.

## Stand der Umstellung

Das bisherige Backend, die Gastgeberverwaltung und der öffentliche Webkatalog wurden aus dem aktiven Projekt entfernt. Better Auth ist noch nicht installiert oder angebunden. Die separate Statusdemo unter `../app/` bleibt bestehen.

`AccessApi` beschreibt weiterhin den bisherigen Produktvertrag. `HttpAccessApi` ist der erhaltene HTTP-Adapter mit Bearer-Token und ausschließlich lokalem Ziel `http://127.0.0.1:8000`. Dies ist **keine Better-Auth-Integration**. Ohne neues Backend funktionieren Anmeldung und Produktaktionen nicht. Die bestehenden Tests verwenden synthetische Antworten beziehungsweise Testimplementierungen.

Die Verweise auf den entfernten Webkatalog und das entfernte Testpostfach öffnen keine Fenster mehr. Sie zeigen während der Umstellung einen Verfügbarkeitshinweis.

## Lokale Prüfungen und Oberfläche

Bei bereits vorhandenen Flutter-Abhängigkeiten, aus diesem Ordner:

```sh
flutter pub get --offline
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Die erhaltene Oberfläche lässt sich anschließend aufrufen:

```sh
flutter run -d chrome --web-hostname=127.0.0.1 --web-port=8300
```

Dieser Aufruf startet nur die Flutter-Oberfläche, keinen Authentifizierungs- oder Produktserver. Neue Abhängigkeiten benötigen vor einer Installation einen eigenen Review und die Projektfreigabe.

## Nächster Integrationsschritt

Für die geplante Umstellung müssen die serverseitige Laufzeit, Better-Auth-Datenbankanbindung, sichere Sitzungsverarbeitung und der Flutter-Zugriff festgelegt werden. Communityrechte, Bewerbungen, Eventzusagen und geschützte Locations benötigen weiterhin ein eigenes Produkt-Backend mit Berechtigungs- und Konkurrenztests.

Die [offizielle Better-Auth-Installation](https://better-auth.com/docs/installation) beschreibt die serverseitige Authentifizierung. Sie ist keine Abnahme der hier erhaltenen Oberfläche oder des Produktvertrags.

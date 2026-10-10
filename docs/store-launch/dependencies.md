# Neue mobile Abhängigkeiten

Geprüft am 09.10.2026 vor Installation; keine Lizenzgebühr, kein neuer externer Dienst oder Abonnement. Versionen im Pub-Lockfile fixiert. Betrieb und Stores können unabhängig davon Kosten verursachen.

| Paket | Version | Lizenz | Zweck |
| --- | --- | --- | --- |
| app_links | 7.2.1 | Apache-2.0 | Vom Betriebssystem verifizierte App-/Universal-Links empfangen |
| url_launcher | 6.3.2 | BSD-3-Clause | Ausgewählte HTTPS-/E-Mail-Kontakte im System öffnen |
| file_selector | 1.1.0 | BSD-3-Clause | Einzelne vom Nutzer ausgewählte JPG-/PNG-Datei lesen |
| cupertino_icons | 1.0.9 | MIT | Schriftzeichen für Flutters adaptive iOS-Steuerelemente |

Die Plattformimplementierungen, `cross_file`, `plugin_platform_interface` und das Flutter-SDK-Webplugin sind transitive Abhängigkeiten. `flutter pub get` hat zunächst 23 Pakete und anschließend die benötigte iOS-Iconschrift hinzugefügt; bereits vorhandene Pakete wurden nicht pauschal aktualisiert. Es wurde kein Analytics-, Werbe-, Push-, Zahlungs- oder Crash-Reporting-SDK ergänzt. Die App soll den vorhandenen Flutter-Lizenzdialog zugänglich machen. Die maschinenlesbare Bestandsliste steht in `dependency-inventory.json`.

Quellen: [app_links](https://pub.dev/packages/app_links/versions/7.2.1), [Lizenz](https://pub.dev/packages/app_links/license), [url_launcher](https://pub.dev/packages/url_launcher/versions/6.3.2), [Lizenz](https://pub.dev/packages/url_launcher/license), [file_selector](https://pub.dev/packages/file_selector/versions/1.1.0), [Lizenz](https://pub.dev/packages/file_selector/license).

Die zusätzliche Iconschrift war bereits lokal vorhanden. [Paket](https://pub.dev/packages/cupertino_icons/versions/1.0.9), [MIT-Lizenz](https://pub.dev/packages/cupertino_icons/license); ebenfalls keine Lizenzgebühr oder Netzwerkdienste.

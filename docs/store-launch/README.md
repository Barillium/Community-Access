# Community Access: Store-Start vorbereiten

V1-Umfang: [Produktspezifikation](../product-spec.md). Diese Unterlagen bleiben unfreigegebene native Startvorbereitung; die lokale synthetische V1-Abnahme steht im [Prüfbericht](../qa/v1-reduction-20261010.md).

Stand: 09.10.2026. Nutzerauftrag: alles für den Start vorbereiten; keine Veröffentlichung über Entwicklerkonten. Entscheidung: **Community Access**, Ticketverkauf zum Start, Konten **ab 16 Jahren**, Voraussetzungen noch zu prüfen. Kein Hosting vorhanden; ausschließlich lokale Bereitstellung vorbereiten. Diese Unterlage ergänzt die [Produktspezifikation](../product-spec.md), keine zweite Spezifikation.

## Vorbereitet

- Flutter-Projekte für iOS und Android; Kennung `de.communityaccess.app`, Version `0.1.0+1`. Die Verfügbarkeit der Kennung in Entwicklerkonten ist nicht geprüft. Bestehende Weboberfläche bleibt erhalten.
- Android: Internetberechtigung, kein Gerätebackup, HTTPS im Release, Ziel-API mindestens 36, keine automatische Release-Signierung mit dem Debugschlüssel. iOS: Associated Domains, Standard-HTTPS ohne ATS-Ausnahmen; keine eigene Kryptografie. Export-Compliance-Angabe vor Einreichung anhand des endgültigen SDK-Bestands prüfen.
- App-Links über die konfigurierte HTTPS-Domain. Rückleitungen für Einladungen, Bestätigung, Passwortreset sowie Event-/Reihen-/Profilnavigation verwenden die bestehenden Parser und serverseitigen Zugriffsprüfungen. Domainzuordnung und echtes Geräteverhalten sind noch nicht nachgewiesen.
- Mobile Dateiauswahl für JPG/PNG: höchstens 10 MB Eingang, Pixelneukodierung ohne EXIF, höchstens 256 KB Ausgang. Keine pauschale Fotomediathek-/Speicherberechtigung. Externe Kontaktlinks öffnen die Systemanwendung nur auf echten Mobilgeräten.
- Web-OAuth bleibt erhalten. Mobile Builds zeigen vorerst E-Mail-Anmeldung; der browsercookiebasierte Web-OAuth wird nicht als mobile Anmeldung angeboten. Zusätzlicher mobiler Anbieterlogin erfordert verifizierte PKCE-/Sitzungsübergabe.
- Löschanfrage im Konto: Bestätigung und aktuelles Passwort oder höchstens fünf Minuten alte Anmeldung. Server ordnet ausschließlich das eigene Konto zu. Wiederholungen/Parallelität ergeben denselben Vorgang. Keine automatische Kontolöschung, keine Finanzkaskade, kein erfundenes Bearbeitungsdatum. Bearbeitung und tatsächliche Löschung sind eigene Startnachweise.
- Kontoalter im Store-Kandidaten: explizite Bestätigung ab 16; kein Geburtsdatum und keine Ausweiskopie. Backend verlangt die passende Bestätigung nur bei konfigurierter, geprüfter Altersregel. Eine ungeprüfte konfigurierte Regel blockiert Kontoanlage. Das ist keine verifizierte Altersprüfung und legt nicht die Store-Altersfreigabe fest.
- [Store-Texte DE](store-listing.de.md), [EN](store-listing.en.md), [Datenschutzinventar](privacy-inventory.csv), [Prüferhinweise](review-notes.md), [Beta-Abnahme](device-test-plan.md), [Betriebsübergabe](operations.md), [Abhängigkeiten](dependencies.md).

[Ausgeführte Prüfungen und ihre Grenzen](verification.md) · [Recherche zu Kontoalter 16, Kauf und Einlass](age-review.md)

## Ausführen, ohne etwas zu veröffentlichen

```sh
python3 -I scripts/check_store_readiness.py --output .local/store-launch/readiness.json
python3 -I scripts/local_auth.py --test-store
node --test server/store_launch.test.mjs
cd client
flutter analyze --no-pub
flutter test --no-pub
```

Die Startprüfung meldet fehlende Nachweise mit Rückgabecode 2; das ist ein erwarteter Blockerbericht, kein erfolgreich freigegebener Start.

Ein gesonderter Kandidatenbuild überschreibt keine vorhandene Vorschau:

```sh
python3 -I scripts/build_store_candidate.py --platform web
python3 -I scripts/build_store_candidate.py --platform android
python3 -I scripts/build_store_candidate.py --platform ios
```

Android/iOS benötigen die jeweils vollständige lokale Werkzeugkette. iOS wird ausdrücklich ohne Codesign gebaut. Android ohne bereitgestellten Uploadschlüssel bleibt unsigniert; Signierung und accountgebundene Domainzuordnung folgen durch den Eigentümer. Kein Skript lädt Builds hoch, aktiviert Verkauf, verschickt Nachrichten oder legt Cloudressourcen an.

## Noch vor echtem Start erforderlich

1. Altersvoraussetzungen ab 16 einschließlich Datenschutz, Verträgen, Zahlungsablauf und veranstaltungsbezogenem Jugendschutz prüfen. Kein Zugriff auf Nachtclubs allein durch Kontoalter ableiten.
2. Betreiberanschrift privat vervollständigen, Rollen mit Veranstaltern klären; Datenschutz-/Nutzungs-/Verkäufertexte prüfen. Die bestehenden Informationstexte bleiben ehrliche Entwürfe.
3. Hostingziel wählen und einen realen Produktbetrieb implementieren. Der vorhandene `private-mail`-Betrieb bietet nur Kontofunktionen. `server/ticketing.mjs` und der pretix-Adapter akzeptieren bislang ausschließlich synthetisches Ticketing. Eine reine Umgebungsumschaltung macht daraus keinen Livebetrieb.
4. Stripe-Connect-Onboarding, echte Anbieter-Testzahlungen, signierte Ereignisse, Wiederholungen, Gebühren und Teil-/Vollerstattungen prüfen. Jeder Veranstalter bleibt Verkäufer. Erst danach Livebetrieb separat einrichten.
5. Browsergebundenen pretix-Checkout für mobile Systembrowser sicher anbinden: Challenge/Cookie aus einem Dart-HTTP-Client ist keine Sitzung des externen Browsers. Kein Sessiontoken in Links oder Rückleitungen. Bis zum verifizierten Handoff kein mobiler Ticketverkauf.
6. Löschanfragen tatsächlich bearbeiten können: verantwortliches Team, angemessene mitgeteilte Bearbeitungsdauer, Rechtsgrundlagen für Restdaten, Anbieter-/Backup-Löschung und Nachweis des Abschlusses. Keine automatische Frist oder destruktive Löschung aus diesem Vorbereitungsauftrag ableiten.
7. Mail-Empfang, Sicherung/Wiederherstellung, Monitoring, Support und Moderation im gewählten Betrieb nachweisen.
8. Xcode/iOS-SDK, Android-SDK/JDK einrichten, native Builds, echte iPhone-/Android-Tests und VoiceOver/TalkBack durchführen. Browser-Screenshots sind keine Gerätescreenshots und keine Store-Abnahme.
9. Datenschutzauskünfte und Inhalts-/Altersfreigaben anhand des tatsächlichen Startumfangs ausfüllen. Kontoalter 16 ist keine automatische Store-Altersbewertung.

Entwicklerkonten, Signierung, TestFlight/Play-Testtracks, Storeformular-Eintrag und Einreichung wurden nicht bedient. Die Store-Startfreigabe bleibt **blockiert**, bis die obigen produktiven Nachweise vorliegen.

## Offizielle Grundlagen, geprüft 09.10.2026

- [Flutter iOS](https://docs.flutter.dev/deployment/ios), [Android](https://docs.flutter.dev/deployment/android)
- [Apple Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [SDK-Mindestanforderungen](https://developer.apple.com/news/?id=ueeok6yw)
- [Google Ziel-API](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en), [Testpflicht persönlicher Konten](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [Apple Datenschutz](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/), [Google Datensicherheit](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en), [Google Kontolöschung](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)

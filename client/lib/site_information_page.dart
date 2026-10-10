import 'package:flutter/material.dart';

import 'design_system.dart';
import 'legal_api.dart';
import 'product_scope.dart';
import 'legal_pages.dart';
import 'better_auth_api.dart';
import 'app_language.dart';
import 'contact_link_stub.dart'
    if (dart.library.js_interop) 'contact_link_web.dart';

Future<void> openLegalReport(BuildContext context, {LegalApi? api}) async {
  final owned = api == null;
  final target = api ?? BetterAuthAccessApi();
  try {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => LegalReportPage(api: target)),
    );
  } finally {
    if (owned && (target is BetterAuthAccessApi)) target.close();
  }
}

const ticketLegalInformation =
    'Ticketing und Veranstaltungsprüfungen: Dein Ticketvertrag besteht mit dem angegebenen Veranstalter. Er verantwortet Durchführung, erforderliche Genehmigungen, Nutzungsrechte und Sicherheit. Community Access vermittelt technisch; eine behördliche Genehmigungsprüfung findet durch die Plattform nicht statt. Veranstalter bestätigen ihre Verantwortung, nicht eine Prüfung oder Freigabe durch die Plattform. Eigene gesetzliche Pflichten der Plattform bleiben bestehen. Eingeschränkter Zugang ist keine Genehmigung oder Legalitätsprüfung. Meldungen werden vom Plattformteam geprüft. Eine begründete Verkaufspause stoppt neue und unbezahlte Käufe; bezahlte Tickets bleiben bei bloßer Unklarheit gültig. Bei Verbot, konkreter Gefahr oder Absage können Angebot und Einlass gesperrt und Erstattungen geprüft werden. Entscheidungen werden begründet; betroffene Veranstalter können erneute Prüfung verlangen. Dieser lokale Entwurf ersetzt keine geprüften Verkaufsbedingungen.';
const legalPrivacyInformation =
    'Für Ticketing werden Verkäuferangaben und der Erklärungsstand zur Bestellung gespeichert. Meldungen enthalten Inhaltsreferenz, Begründung und grundsätzlich Kontaktangaben. Diese Angaben sind nur für die zuständige Bearbeitung bestimmt; Meldendenkontakte werden nicht automatisch an Veranstalter weitergegeben. Der lokale Test erzeugt ausschließlich synthetische Empfangs- und Entscheidungshinweise. Vor echtem Betrieb müssen Rechtsgrundlagen, Zuständigkeiten, Empfänger, Aufbewahrung und tatsächliche Zustellung geklärt werden.';

const siteContactEmail = 'info@communityaccess.de';

const operatorInformation =
    '''Vorgesehener Betreiber: Stany Nyssen, vorläufig als Privatperson.
Kontakt: info@communityaccess.de
Die ladungsfähige Anschrift und gegebenenfalls weitere erforderliche Angaben fehlen noch. Dieser Bereich bleibt ein unvollständiger Entwurf.''';

const _privacyProviders = ProductScope.extended
    ? '''Zusätzliche Anbieter
Die synthetische Entwicklung verwendet erfundene Konten und versendet keine echten E-Mails. Der gesonderte private Mailbetrieb verwendet Resend für Bestätigungs- und Resetmails. Google, Apple oder Facebook werden nur nach Auswahl einer eingerichteten Anmeldeoption aufgerufen. Dabei wird der Browser zum jeweiligen Anbieter weitergeleitet. Diese optionale Anmeldung kann notwendige Cookies für den Anmeldeablauf verwenden.'''
    : '''Zusätzliche Anbieter
Die synthetische V1 verwendet erfundene Konten und versendet keine echten E-Mails. Anmeldung über externe Anbieter ist in V1 nicht aktiviert. Der gesonderte private Mailbetrieb mit Resend gehört nicht zu dieser Demo.''';

const _privacyPreferences = ProductScope.extended
    ? '''Präferenzen und Veranstaltungszugang im lokalen synthetischen Prototyp
Gäste können freiwillig Veranstaltungspräferenzen, Musikgeschmack, Lieblingsveranstaltungen und Freizeitbeschäftigungen angeben und diese im Konto ändern oder leeren. Persönliche Empfehlungen verwenden außerdem Merkliste und gefolgte Communities. Nach einer freigeschalteten Veranstaltung kann der Gast selbst einen Besuch bestätigen. Dafür bleibt ausschließlich die Zuordnung „hat eine Veranstaltung dieses Veranstalters besucht“ ohne Eventname, Datum oder Anzahl erhalten; sie kann im Konto gelöscht werden. Präferenzen, Interessen und Antworten werden nicht öffentlich als Gastprofil angezeigt.'''
    : '''Veranstaltungszugang in V1
Die V1 sortiert sichtbare kommende Einzelveranstaltungen chronologisch. Persönliche Empfehlungen, Präferenzen, Merkliste, Community-Folgen und Besuchssignale sind zurückgestellt. Ein Wechsel des Entwicklungsmodus löscht bestehende Daten nicht.''';

const _privacyRetention = ProductScope.extended
    ? '''Veranstaltungsanfragen und Löschung
Veranstalter prüfen Anfragen manuell. Zeit und Ort semi-öffentlicher Veranstaltungen werden erst nach Zusage und ab den festgelegten Freigabezeiten ausgeliefert. Eventinformationen einschließlich Flyer, Anfragen, Antworten, Eventfreigaben und Eventmerkliste sind ab exakt 168 Stunden nach dem eingetragenen tatsächlichen Veranstaltungsende nicht mehr abrufbar und werden bei der nächsten Bereinigung aus der aktiven lokalen Datenbank gelöscht. Ein unabhängiger Veranstalterprofilzugang bleibt bis zum Entzug oder zur Kontolöschung bestehen. Der lokale Server prüft die Frist bei Anfragen, beim Start und einmal pro Minute. Altbestände ohne Endzeit benötigen eine Korrektur; eine Endzeit wird nicht erfunden. Backups, Datenbankjournale, bereits übermittelte Informationen und externe Kopien sind damit nicht als gelöscht nachgewiesen. Der private Mailbetrieb bietet diese Produktfunktionen derzeit nicht an.'''
    : '''Veranstaltungsanfragen und Löschung
Veranstalter prüfen Anfragen manuell. Communitymitgliedschaft, einzelne Eventfreigabe und Teilnahme sind getrennt. Bei kostenpflichtigen Events erlaubt eine manuelle Zusage nur den Kauf; erst bestätigte Zahlung begründet Teilnahme. Geschützte genaue Locations erfordern aktuell berechtigte Teilnahme. Eventinformationen sind ab exakt 168 Stunden nach dem eingetragenen tatsächlichen Veranstaltungsende nicht mehr abrufbar. Die bestehende Bereinigung löscht nur dafür freigegebene, nicht durch neue Referenzen gebundene Events. Bestellnachweise und offene Erstattungen bleiben getrennt erhalten; neue Datenklassen haben bislang nur eine Aufbewahrungsvorschau. Backups, Journale und bereits übermittelte Informationen sind damit nicht als gelöscht nachgewiesen.''';

const privacyInformation =
    '''Stand: 10.10.2026 · Unvollständiger Entwurf

Verantwortlicher und Kontakt
Für den Plattformbetrieb vorgesehen: Stany Nyssen, vorläufig als Privatperson. Datenschutzanfragen gehen an info@communityaccess.de. Die Zuständigkeiten mit den Veranstaltern und die vollständigen Betreiberangaben bleiben zu klären.

Technischer Seitenaufruf
Schriften, Icons und Flutter-Renderer werden mit der Website ausgeliefert. Der Seitenaufruf lädt keine Analyse-, Werbe- oder Social-Media-Skripte. Suchbegriffe werden an das konfigurierte Community-Access-Backend übermittelt, um öffentliche Events und Communitynamen zu durchsuchen. Geschützte Inhalte gehören nicht zur öffentlichen Trefferliste.

Konto und Anmeldung
Die Anwendung verarbeitet für ein Konto Name, E-Mail-Adresse, Passwortnachweis und Sitzungsdaten. Das Passwort wird serverseitig über die Auth-Bibliothek verarbeitet; das Sitzungstoken der E-Mail-Anmeldung bleibt in der Oberfläche im Arbeitsspeicher. Ein HttpOnly-Sitzungscookie ermöglicht die Wiederaufnahme nach einem Neuladen; der Server prüft dabei die Sitzung erneut. Sitzungen gelten im aktuellen Code höchstens acht Stunden ab Anmeldung, ohne gleitende Verlängerung; Bestätigungs- und Resetlinks sind eine Stunde gültig. Das beschreibt die Gültigkeit, keine zugesicherte Datenlöschfrist.

$_privacyProviders

$_privacyPreferences

$_privacyRetention

Noch zu ergänzen
Für den tatsächlichen Betrieb fehlen bestätigte Angaben zu Hosting und Zugriffsprotokollen, Rechtsgrundlagen und Zwecken je Verarbeitung, Empfängern und möglichen Drittlandübermittlungen, Aufbewahrung und Löschung sowie die zuständige Aufsichtsbehörde. Der Empfang und die Bearbeitung am benannten Kontaktweg sind noch zu prüfen.

Deine Rechte
Je nach Voraussetzungen bestehen Rechte auf Auskunft, Berichtigung, Löschung, Einschränkung der Verarbeitung, Datenübertragbarkeit und Widerspruch. Eine Einwilligung kann für die Zukunft widerrufen werden. Es besteht ein Beschwerderecht bei einer Datenschutzaufsichtsbehörde. Für Anliegen zu deinen Daten nutze info@communityaccess.de.''';

const siteContactInformation = '''Für Hilfe, Fragen zu deinen Daten und Inhaltsmeldungen erreichst du Community Access unter:

info@communityaccess.de

Bitte nenne bei einer Meldung den betroffenen Inhalt und beschreibe das Problem. Sende keine Passwörter, Anmeldelinks oder unnötigen persönlichen Angaben über andere Personen.''';

class SiteContactPage extends StatelessWidget {
  const SiteContactPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: accessAppBar(context, 'Hilfe & Kontakt'),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        width: AccessPageWidth.reading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              key: const Key('site-contact-readable'),
              label: siteContactInformation,
              excludeSemantics: true,
              child: const SelectableText(
                siteContactInformation,
                style: TextStyle(height: AccessTypography.readingHeight),
              ),
            ),
            const SizedBox(height: AccessSpacing.s24),
            TextButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'Community Access',
              ),
              child: Text(
                localText(
                  context,
                  'Open-Source-Lizenzen',
                  'Open-source licenses',
                ),
              ),
            ),
            TextButton(
              onPressed: () => openLegalReport(context),
              child: const LocalText('Veranstaltung melden'),
            ),
            OutlinedButton(
              onPressed: () async {
                final opened = await openContact('mailto:$siteContactEmail');
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Kopiere die Adresse in dein E-Mail-Programm.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('E-Mail schreiben'),
            ),
          ],
        ),
      ),
    ),
  );
}

class SiteInformationPage extends StatelessWidget {
  final bool privacy;
  const SiteInformationPage({super.key, required this.privacy});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: accessAppBar(
      context,
      privacy ? 'Datenschutz' : 'Betreiber / Impressum',
    ),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        width: AccessPageWidth.reading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: privacy ? privacyInformation : operatorInformation,
              excludeSemantics: true,
              child: SelectableText(
                privacy ? privacyInformation : operatorInformation,
                style: const TextStyle(height: AccessTypography.readingHeight),
              ),
            ),
            const SizedBox(height: AccessSpacing.s24),
            LocalText(
              privacy ? legalPrivacyInformation : ticketLegalInformation,
            ),
            const LocalText(legalAccessNotice),
          ],
        ),
      ),
    ),
  );
}

class SiteInformationLinks extends StatelessWidget {
  const SiteInformationLinks({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AccessSpacing.s12,
    children: [
      TextButton(
        onPressed: () => openLegalReport(context),
        child: const LocalText('Veranstaltung melden'),
      ),
      for (final privacy in [false, true])
        TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => SiteInformationPage(privacy: privacy),
            ),
          ),
          child: LocalText(privacy ? 'Datenschutz' : 'Betreiber / Impressum'),
        ),
      TextButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const SiteContactPage()),
        ),
        child: const LocalText('Hilfe & Kontakt'),
      ),
    ],
  );
}

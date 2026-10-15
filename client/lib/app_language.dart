import 'package:flutter/material.dart';

class AppLanguage extends ValueNotifier<bool> {
  AppLanguage() : super(false);
}

class LanguageScope extends InheritedNotifier<AppLanguage> {
  const LanguageScope({
    super.key,
    required AppLanguage language,
    required super.child,
  }) : super(notifier: language);
  static AppLanguage? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>()?.notifier;
}

String localText(BuildContext context, String de, [String? en]) {
  if (LanguageScope.of(context)?.value != true) return de;
  if (en != null) return en;
  final translated = englishCopy[de];
  if (translated != null) return translated;
  final rate = RegExp(
    r'^Zu viele Anfragen\. Bitte warte (\d{1,4}) Sekunden und versuche es erneut\.$',
  ).firstMatch(de);
  if (rate != null) {
    return 'Too many requests. Please wait ${rate.group(1)} seconds and try again.';
  }
  final refund = RegExp(r'^Bitte 1 bis (\d+) Cent eingeben\.$').firstMatch(de);
  if (refund != null) {
    return 'Please enter 1 to ${refund.group(1)} cents.';
  }
  return de;
}

class LocalText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextScaler? textScaler;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final String? semanticsLabel;
  const LocalText(
    this.data, {
    super.key,
    this.style,
    this.textScaler,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.semanticsLabel,
  });
  @override
  Widget build(BuildContext context) => Text(
    localText(context, data),
    style: style,
    textScaler: textScaler,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
    softWrap: softWrap,
    semanticsLabel: semanticsLabel,
  );
}

const englishCopy = <String, String>{
  'Mein Zugang': 'My access',
  'Konto und Darstellung': 'Account and appearance',
  "Events und Einladungen": "Events and invitations",
  "Events und Einladungen verwalten": "Manage events and invitations",
  "Einlassrollen": "Admission roles",
  "Einlassrollen verwalten": "Manage admission roles",
  "Einzelne Eventfreigabe": "Individual event access",
  "Mit Konto kannst du eine Aufnahme oder Eventteilnahme anfragen.": "With an account, you can apply to join a community or request event attendance.",
  "Dein Konto begründet keine Mitgliedschaft oder Eventzusage.":
      "Your account does not establish membership or confirmed attendance.",
  "Eine persönliche Eventeinladung öffnet nur dieses Event. Bei kostenpflichtigen Events erlaubt sie den Kauf; erst bestätigte Zahlung begründet die Teilnahme.": "A personal event invitation opens only this event. For paid events it allows purchase; only confirmed payment establishes attendance.",

  'Konto löschen': 'Delete account',
  'Kontolöschung anfragen': 'Request account deletion',
  'Bitte melde dich erneut an oder bestätige dein aktuelles Passwort.':
      'Please sign in again or confirm your current password.',
  'Bitte bestätige das erforderliche Mindestalter für dein Konto.':
      'Please confirm the required minimum age for your account.',
  'Die Kontoanlage ist noch nicht verfügbar.':
      'Account registration is not available yet.',
  'Der Status konnte nicht geladen werden. Bitte erneut versuchen.':
      'The status could not be loaded. Please try again.',
  'Der Eingang ist unklar. Prüfe vor einer erneuten Anfrage den Status.': 'The result is unclear. Check the status before submitting another request.',

  "Ticketzugang": "Ticket access",
  "Ticketbezeichnung": "Ticket name",
  "Ticketpreis in Cent": "Ticket price in cents",
  "Ticketkontingent": "Ticket quota",
  "Bitte benennen.": "Please enter a name.",
  "Positiven Centbetrag eingeben.": "Enter a positive amount in cents.",
  "Positive Anzahl eingeben.": "Enter a positive quantity.",
  "Erstattungsbetrag in Cent": "Refund amount in cents",
  "Reihen, Events und Gästekreise": "Series, events and guest circles",
  "Bitte speichere zuerst dein Veranstalterprofil.":
      "Please save your organizer profile first.",
  "Veranstaltungsreihen": "Event series",
  "Nicht frei sichtbare Reihen und Events erscheinen nur im freigegebenen Gästekreis. Außenstehende sehen auch keinen Hinweis darauf. Eine Reihenfreigabe umfasst alle veröffentlichten und künftigen Events der Reihe. Profilfreigaben sind davon unabhängig.": "Restricted series and events are visible only to their approved guest circle. Other visitors see no indication of them. A series grant covers all published and future events in that series. Profile access is separate.",
  "Reihe anlegen": "Create series",
  "Reihe bearbeiten": "Edit series",
  "Eine geschützte Reihe bleibt geschützt, auch wenn du ein Event als frei sichtbar markierst. Eine einzelne Eventfreigabe öffnet nur dieses Event.": "A restricted series stays restricted when an event is marked publicly visible. Individual event access opens only that event.",
  "Event anlegen": "Create event",
  "Gästekreis freigeben": "Grant guest access",
  "Freigabe zur Sichtbarkeit für ein bestehendes Konto mit bestätigter E-Mail. Dies bestätigt keine Eventteilnahme.": "Grant visibility to an existing account with a verified email. This does not confirm event attendance.",
  "Reihe oder einzelnes Event": "Series or individual event",
  "E-Mail des Gastkontos": "Guest account email",
  "Sichtbarkeit freigeben": "Grant visibility",
  "Gästekreis erweitert.": "Guest access granted.",
  "Freigaben verwalten": "Manage access grants",
  "Noch keine Reihen- oder Eventfreigaben.":
      "No series or event access grants yet.",
  "Reihe": "Series",
  "Freigegeben": "Granted",
  "Sichtbarkeit entziehen": "Revoke visibility",
  "Sichtbarkeit entzogen.": "Visibility revoked.",
  "Erneut freigeben": "Grant again",
  "Sichtbarkeit erneut freigegeben.": "Visibility granted again.",
  "Neu laden": "Reload",
  "Veranstaltungsreihe bearbeiten": "Edit event series",
  "Name der Reihe": "Series name",
  "Beschreibung der Reihe": "Series description",
  "Reihe frei sichtbar anzeigen": "Show series publicly",
  "Öffentliche Reihen benötigen ein öffentliches Veranstalterprofil.":
      "Public series require a public organizer profile.",
  "Nur der gesondert freigegebene Gästekreis sieht diese Reihe und ihre Events. Eine einzelne Eventfreigabe öffnet ausschließlich das ausgewählte Event.": "Only the approved guest circle can see this series and its events. Individual event access opens only the selected event.",
  "Reihe speichern": "Save series",
  "Die Reihe konnte nicht gespeichert werden.":
      "The series could not be saved.",
  "Die Änderung konnte nicht gespeichert werden.":
      "The change could not be saved.",
  "Profiladresse": "Profile address",

  "Merken zählt als öffentliches Interesse. Namen bleiben verborgen.":
      "Saving counts as public interest. Names remain hidden.",
  "Merken bestätigt keine Mitgliedschaft oder Teilnahme. Deine Auswahl ist nur für dich sichtbar; bei öffentlichen Inhalten wird die Gesamtzahl als Interesse angezeigt. Namen bleiben verborgen.": "Saving does not confirm membership or attendance. Your selection is visible only to you; public content shows the total count as interest. Names remain hidden.",
  "Noch keine verfügbaren Einträge in deiner Merkliste.":
      "No available entries in your saved items yet.",
  "Entfernen fehlgeschlagen.": "Removal failed.",

  "Zurück zur Verwaltung": "Back to management",
  "Folgen konnte nicht gespeichert werden. Bitte prüfe den aktuellen Status.":
      "Following could not be saved. Please check the current status.",
  "Gewählte Community": "Selected community",
  "Merkliste konnte nicht geladen werden.": "Saved items could not be loaded.",
  "Merken konnte nicht gespeichert werden.":
      "The saved item could not be updated.",
  "Event merken": "Save event",
  "Reihe merken": "Save series",
  "Veranstalter merken": "Save organizer",
  "Aus Merkliste entfernen": "Remove from saved items",
  "Anmelden und merken": "Sign in and save",
  "Fallreferenz": "Case reference",
  "Erstellt am": "Created on",
  "Beschwerde eingereicht am": "Complaint submitted on",
  "Beschwerde bereits eingereicht.": "Complaint already submitted.",
  "Bitte Ticketcode und Konto-E-Mail eingeben.":
      "Please enter the ticket code and account email.",
  "Plattformprovision in Prozent": "Platform commission as a percentage",
  "Die Aktion konnte nicht abgeschlossen werden. Bitte prüfe den aktuellen Stand.":
      "The action could not be completed. Please check the current status.",
  "Die Präferenzen konnten nicht geladen werden.":
      "Preferences could not be loaded.",
  "Anmeldemethode verbinden": "Connect sign-in method",
  "Oder mit einem anderen Konto anmelden": "Or sign in with another account",
  "Bestätige zuerst deine E-Mail und melde dich unmittelbar vor dem Verbinden erneut an.": "Verify your email first and sign in again immediately before connecting.",
  "Diese Anmeldung ist derzeit im Browser verfügbar.":
      "This sign-in method is currently available in the browser.",
  "Die Anmeldung konnte nicht gestartet werden.":
      "Sign-in could not be started.",
  "Weitere Anmeldemethoden konnten nicht geladen werden. Die Anmeldung mit E-Mail und Passwort bleibt verfügbar.": "Other sign-in methods could not be loaded. Email and password sign-in remains available.",
  "Google verbinden": "Connect Google",
  "Mit Google anmelden": "Sign in with Google",
  "Apple verbinden": "Connect Apple",
  "Mit Apple anmelden": "Sign in with Apple",
  "Facebook verbinden": "Connect Facebook",
  "Mit Facebook anmelden": "Sign in with Facebook",

  "Der Status der Linkanfrage ist unklar. Prüfe zuerst dein Postfach und einen vorhandenen Link, bevor du einen neuen anforderst.": "The link request status is uncertain. Check your inbox and an existing link before requesting another one.",
  "Anmelden und Zugriff erneut prüfen": "Sign in and check access again",
  "Anfrage wird bearbeitet": "Processing request",
  "Bestätige zuerst deine E-Mail-Adresse.": "Verify your email address first.",
  "Bestätigung prüfen": "Check verification",
  "Bestätigungs- und Resetlinks erhältst du per E-Mail. Öffne sie auf dem Community-Access-PC.": "Verification and reset links arrive by email. Open them on the Community Access computer.",
  "Das Testpostfach ist während der Backend-Umstellung noch nicht verfügbar.":
      "The test mailbox is currently unavailable.",
  "Dein Zugang bleibt persönlich. Communityaufnahme und Eventzusage werden separat entschieden.": "Your access stays personal. Community admission and event participation are decided separately.",
  "Der Link gilt 60 Minuten und kann einmal verwendet werden.":
      "The link is valid for 60 minutes and can be used once.",
  "Der Link gilt 60 Minuten. Die Bestätigung ist keine Aufnahme oder Eventzusage.": "The link is valid for 60 minutes. Verification does not grant community admission or event participation.",
  "Der Link konnte nicht angefordert werden.":
      "The link could not be requested.",
  "Die Aktion konnte nicht abgeschlossen werden.":
      "The action could not be completed.",
  "Die beiden Passwörter stimmen nicht überein.": "The passwords do not match.",
  "Die Passwörter stimmen nicht überein.": "The passwords do not match.",
  "E-Mail bestätigen.": "Verify email.",
  "E-Mail-Adresse bestätigen": "Verify email address",
  "E-Mail-Adresse bestätigt. Melde dich an oder aktualisiere deine Gastübersicht.":
      "Email verified. Sign in or refresh your guest overview.",
  "Lokaler Prototyp · Nur erfundene Adressen mit @example.invalid. Nachrichten werden im lokalen Testpostfach abgelegt.": "Local prototype · Only fictitious addresses ending in @example.invalid. Messages go to the local test mailbox.",
  "Lokales Testpostfach öffnen": "Open local test mailbox",
  "Mindestens 12 Zeichen. Nach dem Wechsel werden bisherige Anmeldungen ungültig.": "At least 12 characters. Changing the password invalidates previous sessions.",
  "Neues Passwort": "New password",
  "Neues Passwort festlegen.": "Set a new password.",
  "Passwort geändert. Bitte melde dich erneut an. Bisherige Sitzungen sind ungültig.":
      "Password changed. Please sign in again. Previous sessions are invalid.",
  "Passwort speichern": "Save password",
  "Prüfe dein Postfach. Der neueste Link ersetzt den bisherigen.":
      "Check your inbox. The latest link replaces the previous one.",
  "Trage eine gültige E-Mail-Adresse ein.": "Enter a valid email address.",
  "Verwende 12 bis 72 Zeichen und höchstens 72 UTF-8-Bytes.":
      "Use 12 to 72 characters and no more than 72 UTF-8 bytes.",
  "Verwende eine Adresse mit @example.invalid.":
      "Use an address ending in @example.invalid.",
  "Wenn ein Konto mit dieser Adresse existiert, findest du einen Link im Postfach. Der Link gilt 60 Minuten.": "If an account exists for this address, a link will arrive in the inbox. The link is valid for 60 minutes.",
  "Wiederherstellungslink anfordern": "Request recovery link",
  "Das Konto konnte nicht angelegt werden.":
      "The account could not be created.",
  "Trage deinen Namen ein.": "Enter your name.",
  "Trage einen erfundenen Namen ein.": "Enter a fictitious name.",
  "Wenn diese Adresse für ein neues Konto verwendet werden kann, erhältst du einen Bestätigungslink. Bestätige deine E-Mail-Adresse und melde dich danach an. Bei einem bestehenden Konto kannst du dich anmelden oder dein Passwort zurücksetzen.": "If this address can be used for a new account, you will receive a verification link. Verify your email and then sign in. If you already have an account, sign in or reset your password.",
  "Bestätige deine E-Mail-Adresse und melde dich vor dem Verbinden erneut an.":
      "Verify your email and sign in again before linking an account.",
  "Bitte bestätige zuerst deine E-Mail-Adresse.":
      "Please verify your email address first.",
  "Bitte melde dich erneut an.": "Please sign in again.",
  "Bitte öffne die Einladung erneut.": "Please reopen the invitation.",
  "Das Formular wurde geändert. Lade die Seite neu und prüfe deine Angaben.":
      "The form changed. Reload the page and check your answers.",
  "Dein Konto ist für Plattformaktionen gesperrt. Eigene Bestellbelege und Beschwerden bleiben erreichbar.": "Your account is restricted from platform actions. Your own order receipts and complaints remain available.",
  "Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.":
      "Your session expired. Please sign in again.",
  "Der Eintrag wurde inzwischen geändert. Lade den aktuellen Stand und prüfe die Freigaben erneut.":
      "The entry changed. Reload the current version and check access again.",
  "Der Link ist ungültig oder abgelaufen. Fordere einen neuen Link an.":
      "The link is invalid or expired. Request a new link.",
  "Der Link konnte gerade nicht versendet werden. Ein bisher gültiger Link bleibt verwendbar. Versuche es später erneut.": "The link could not be sent. A previously valid link can still be used. Try again later.",
  "Der Zugang wurde gesperrt. Bitte nutze den angegebenen Kontaktweg.":
      "Access was restricted. Please use the stated contact channel.",
  "Der Zugangslink ist ungültig, abgelaufen oder für ein anderes Konto bestimmt.":
      "The access link is invalid, expired, or intended for another account.",
  "Der lokale Auth-Dienst ist gerade nicht erreichbar.":
      "The local authentication service is currently unavailable.",
  "Die Aktion konnte nicht abgeschlossen werden. Prüfe deine Angaben und versuche es erneut.":
      "The action could not be completed. Check your details and try again.",
  "Die Anbieteranmeldung konnte nicht abgeschlossen werden. Bitte versuche es erneut.":
      "Provider sign-in could not be completed. Please try again.",
  "Die Anbieteranmeldung konnte nicht gestartet werden.":
      "Provider sign-in could not be started.",
  "Die Anmeldemethoden sind gerade nicht verfügbar.":
      "Sign-in methods are currently unavailable.",
  "Die Anmeldung konnte nicht abgeschlossen werden.":
      "Sign-in could not be completed.",
  "Die Sitzung wurde geändert. Bitte lade den aktuellen Stand erneut.":
      "The session changed. Please reload the current state.",
  "Diese Aktion ist dem verantwortlichen Konto vorbehalten.":
      "This action is reserved for the responsible account.",
  "Diese Anfrage wurde bereits bearbeitet. Lade den aktuellen Stand.":
      "This request has already been handled. Reload the current state.",
  "Diese persönliche Einladung ist ungültig, abgelaufen oder gehört zu einem anderen Konto.": "This personal invitation is invalid, expired, or belongs to another account.",
  "Dieser Anbieter ist noch nicht eingerichtet.":
      "This provider is not configured yet.",
  "Dieser Bereich ist dem berechtigten Projektteam vorbehalten.":
      "This area is reserved for the authorized project team.",
  "Dieser Eintrag ist nicht verfügbar oder nicht für dich freigegeben.":
      "This entry is unavailable or you do not have access.",
  "Dieser Zugangsweg ist momentan nicht freigegeben.":
      "This access route is currently unavailable.",
  "E-Mail oder Passwort stimmen nicht überein.":
      "Email or password is incorrect.",
  "Eine erneute Anfrage ist gesperrt. Bitte kontaktiere den Gastgeber über euren bestehenden Kontaktweg.": "Another request is restricted. Please contact the organizer through your existing channel.",
  "Für diese Aktion fehlt die aktuelle Berechtigung.":
      "You do not currently have permission for this action.",
  "Für diesen Bereich brauchst du zugeordnete Gastgeberrechte.":
      "You need assigned organizer permissions for this area.",
  "Persönliche Einladungen gelten für ein bestehendes bestätigtes Konto. Bitte melde dich damit an.": "Personal invitations require an existing verified account. Please sign in with that account.",
  "Prüfe deine Angaben.": "Check your details.",
  "Prüfe deine Angaben. Verwende ein synthetisches Testkonto.":
      "Check your details. Use a synthetic test account.",
  "Unbekannte Anmeldemethode.": "Unknown sign-in method.",
  "Zu viele Anfragen. Bitte warte einen Moment und versuche es erneut.":
      "Too many requests. Please wait a moment and try again.",
  "Zu viele Versuche. Bitte warte kurz.":
      "Too many attempts. Please wait a moment.",
  "Meine Beschwerden": "My complaints",
  "Keine eigenen Moderationsfälle vorhanden.":
      "No moderation cases concerning your account.",
  "Erneute Prüfung verlangen": "Request another review",
  "Beschwerde eingereicht.": "Complaint submitted.",
  "Weitere Beschwerde oder Meldung einreichen":
      "Submit another complaint or report",
  "Erneut anmelden": "Sign in again",
  "Begründung": "Reason",
  "Einreichen": "Submit",
  "Bei bestehenden Bestellungen oder Zusagen ist diese Ticketkonfiguration gesperrt.": "This ticket configuration is locked because orders or confirmations already exist.",
  "Bitte Eventinhalte prüfen: Ende nach Beginn, Line-up und Genres innerhalb der Grenzen sowie ein gültiger Flyer mit Bildbeschreibung.": "Check the event content: the end must follow the start; line-up and genres must stay within the limits; the flyer must include an image description.",
  "Bitte beide Freigabezeitpunkte festlegen.": "Set both release times.",
  "Bitte bestätige das vom Veranstalter angegebene Mindestalter.":
      "Confirm the organizer's stated minimum age.",
  "Bitte die Pflichtangaben und Zahlen prüfen.":
      "Check required fields and numbers.",
  "Bitte ein Veranstalterprofil auswählen oder zuerst speichern.":
      "Select an organizer profile or save one first.",
  "Bitte ein gültiges Datum und eine Uhrzeit angeben.":
      "Enter a valid date and time.",
  "Bitte ein vorhandenes Formular auswählen oder zuerst erstellen.":
      "Select an existing form or create one first.",
  "Bitte eine öffentliche Anfragefrist unabhängig vom Eventbeginn festlegen.":
      "Set a public request deadline independently of the event start.",
  "Bitte höchstens 12 kurze Angaben pro Präferenzfeld eintragen.":
      "Enter up to 12 short items per preference field.",
  "Das Plattformteam muss zuerst einen Provisionssatz festlegen.":
      "The platform team must set a fee rate first.",
  "Der Empfänger braucht ein bestehendes Konto mit bestätigter E-Mail-Adresse.":
      "The recipient needs an existing account with a verified email address.",
  "Der Erstattungsbetrag überschreitet den noch offenen Betrag.":
      "The refund exceeds the outstanding amount.",
  "Der Provisionssatz wurde geändert. Bitte den aktuellen Stand laden.":
      "The fee rate changed. Reload the current version.",
  "Der Ticketdienst ist gerade nicht erreichbar. Bitte erneut prüfen.":
      "The ticket service is currently unavailable. Please check again.",
  "Der Veranstalter muss deinen Ticketkauf zuerst freigeben.":
      "The organizer must approve your ticket purchase first.",
  "Die Communityregeln wurden geändert. Bitte die Einladung erneut prüfen.":
      "Community rules changed. Please check the invitation again.",
  "Die Eventangaben sind zu groß. Bitte den Flyer verkleinern.":
      "The event data is too large. Please reduce the flyer size.",
  "Die Frage ist nicht geprüft oder fragt unzulässige Angaben ab. Verwende den Fragenkatalog.": "This question is unreviewed or requests prohibited data. Use the question catalog.",
  "Die Kapazität darf bestehende Zusagen nicht unterschreiten.":
      "Capacity cannot be lower than existing confirmations.",
  "Die Löschfrist dieser Veranstaltung ist bereits abgelaufen. Sie kann nicht erneut gespeichert werden.":
      "This event's retention period has ended. It cannot be saved again.",
  "Die Mitgliedschaftspflicht kann bei bestehenden Zusagen nicht geändert werden.":
      "The membership requirement cannot change while confirmations exist.",
  "Die Ticketplätze werden in der Ticketverwaltung festgelegt.":
      "Ticket inventory is set in ticket management.",
  "Die Veranstaltung hat bereits begonnen. Neue Anfragen oder Zusagen sind nicht mehr möglich.": "The event has started. New requests or confirmations are no longer possible.",
  "Die Veranstaltung hat keine freien Plätze mehr.":
      "The event has no remaining places.",
  "Die veröffentlichte Anfragefrist oder der sichtbare Beginn erlaubt diese Aktion nicht mehr.":
      "The published deadline or visible start no longer permits this action.",
  "Diese Entscheidung braucht eine andere zuständige Moderationsperson.":
      "This decision requires another authorized moderator.",
  "Diese Erstattung wurde bereits mit einem anderen Betrag verarbeitet.":
      "This refund has already been processed with another amount.",
  "Diese Veranstaltung ist bereits beendet.": "This event has ended.",
  "Dieses Ticket ist gesperrt. Eine Erstattung wird gegebenenfalls geprüft.":
      "This ticket is restricted. A refund will be reviewed where applicable.",
  "Dieses Ticket wurde bereits beim Einlass verwendet.":
      "This ticket has already been used for admission.",
  "Dieses Ticketangebot ist derzeit nicht im Verkauf.":
      "This ticket offer is currently closed for sale.",
  "Ein Besuch kann erst nach dem Ende eingetragen werden.":
      "A visit can only be recorded after the event ends.",
  "Eine Endzeit ist erforderlich, damit die Löschfrist von exakt 168 Stunden nach Veranstaltungsende berechnet werden kann.": "An end time is required to calculate the retention period of exactly 168 hours after the event ends.",
  "Eine Reihe mit Events kann nicht in eine andere verantwortliche Community verschoben werden.":
      "A series with events cannot move to another responsible community.",
  "Für dieses Event ist eine aktive Communitymitgliedschaft nötig.":
      "This event requires active community membership.",
  "Neue Communityaufnahmen und Freigaben sind vorübergehend pausiert.":
      "New community admissions and access grants are temporarily paused.",
  "Neue Ticketkäufe sind vorübergehend pausiert. Bestehende Bestellungen bleiben abrufbar.": "New ticket purchases are temporarily paused. Existing orders remain available.",
  "Semi-öffentliche Events dürfen Zeit und Ort nicht öffentlich freigeben. Entferne den Flyer und verwende die geplante Freigabe.": "Semi-public events cannot publish their time and location. Remove the flyer and use the planned release.",
  "Zuerst das Veranstalterkonto verbinden.":
      "Connect the organizer account first.",
  "Öffentliche Events und Reihen benötigen ein öffentliches Veranstalterprofil.":
      "Public events and series require a public organizer profile.",
  "Öffentliche Veranstaltungen brauchen Beschreibung, Beginn und einen öffentlich auffindbaren Ort.": "Public events require a description, start time, and publicly discoverable location.",
  "Öffentlicher Verkauf braucht ein öffentliches Event ohne Mitgliedschaftspflicht.": "Public ticket sales require a public event without a membership requirement.",

  "Eingeschränkter Zugang ist keine rechtliche Einstufung als Privatveranstaltung. Communityaufnahme und Kaufberechtigung ersetzen keine erforderliche Genehmigung.": "Restricted access does not establish that an event is legally private. Community admission and purchase eligibility do not replace required permissions.",
  "Ich bestätige, dass ich als Veranstalter und Ticketverkäufer die Verantwortung für die Durchführung dieser Veranstaltung trage. Ich bin dafür verantwortlich, erforderliche Genehmigungen und Nutzungsrechte einzuholen und die geltenden Sicherheitsvorgaben einzuhalten. Community Access vermittelt technisch und führt keine behördliche Genehmigungsprüfung durch. Eigene gesetzliche Pflichten der Plattform bleiben bestehen.": "I acknowledge my responsibility as the organizer and ticket seller for running this event. I am responsible for obtaining required permissions and usage rights and complying with applicable safety requirements. Community Access provides the technical intermediary service and does not carry out an official permission review. The platform retains its own statutory obligations.",
  "Ticketverkauf zur Klärung pausiert": "Ticket sales paused for clarification",
  "Veranstaltung gesperrt · Einlass angehalten":
      "Event blocked · admission suspended",
  "Keine Verkaufssperre durch das Plattformteam":
      "No sales restriction by the platform team",
  "Vertragspartner für dein Ticket": "Your ticket seller",
  "Verkäuferangaben fehlen. Der Verkauf bleibt geschlossen.":
      "Seller information is missing. Sales remain closed.",
  "Unternehmerangabe des Verkäufers": "Seller declares business status",
  "Privatverkäuferangabe · keine rechtliche Prüfung":
      "Seller declares private status · no legal verification",
  "Dein Vertragspartner für das Ticket ist der angegebene Veranstalter. Er verantwortet Durchführung, erforderliche Genehmigungen, Nutzungsrechte und Sicherheit. Community Access vermittelt technisch und führt keine behördliche Genehmigungsprüfung durch. Eigene gesetzliche Pflichten der Plattform bleiben bestehen.": "Your contract for the ticket is with the named organizer. They are responsible for running the event, required permissions, usage rights and safety. Community Access provides the technical intermediary service and does not carry out an official permission review. The platform retains its own statutory obligations.",
  "Bedingungenstand": "Terms version",
  "Veranstaltung melden": "Report event",
  "Verkauf pausieren": "Pause sales",
  "Angebot und Einlass sperren": "Block offer and admission",
  "Verkauf wieder öffnen": "Reopen sales",
  "Keine Maßnahme": "No action",
  "Prüfstand geladen. Bitte die Entscheidung bestätigen.":
      "Review state loaded. Please confirm the decision.",
  "Meldung offen": "Report open",
  "Meldung entschieden": "Report decided",
  "Meldung geprüft · keine Maßnahme": "Report reviewed · no action",
  "Keine ausreichende Grundlage für eine Maßnahme":
      "Insufficient grounds for action",
  "Lokaler Test: nur erfundene Angaben und E-Mail-Adressen mit @example.invalid verwenden. Es wird keine E-Mail versendet.": "Local test: use invented information and email addresses ending in @example.invalid only. No email is sent.",
  "Beschreibe den konkreten Verdacht. Eine Meldung allein sperrt die Veranstaltung nicht. Keine Passwörter, Einladungslinks, Gästelisten oder unnötigen persönlichen Angaben senden.": "Describe the specific concern. A report alone does not block an event. Do not send passwords, invitation links, guest lists or unnecessary personal information.",
  "Inhaltsreferenz": "Content reference",
  "Warum könnte das Angebot rechtswidrig sein?":
      "Why might this offer be unlawful?",
  "Hinweis auf sexuellen Missbrauch von Kindern: Kontaktangaben können entfallen.":
      "Report concerning child sexual abuse: contact details may be omitted.",
  "Dein Name": "Your name",
  "Kontakt-E-Mail": "Contact email",
  "Synthetische E-Mail mit @example.invalid erforderlich.":
      "A synthetic email ending in @example.invalid is required.",
  "Ich melde nach bestem Wissen und halte meine Angaben für richtig und vollständig.": "I report in good faith and believe my information is accurate and complete.",
  "Meldungen werden nur vom zuständigen Plattformteam bearbeitet. Kontaktangaben werden nicht automatisch an Veranstalter weitergegeben. Aufbewahrung und reale Zustellung müssen vor echtem Betrieb festgelegt werden.": "Reports are processed only by the responsible platform team. Contact details are not automatically shared with organizers. Retention and actual delivery must be defined before real operation.",
  "Meldung einreichen": "Submit report",
  "Meldung empfangen": "Report received",
  "Die Meldung konnte nicht gesendet werden.":
      "The report could not be submitted.",
  "Bitte ausfüllen.": "Please fill in this field.",
  "Bitte auswählen.": "Please select an option.",
  "Verkäuferangaben": "Seller information",
  "Vollständiger Verkäufername": "Full seller name",
  "Geschäfts- oder Kontaktanschrift": "Business or contact address",
  "Verkäuferstatus": "Seller status",
  "Privatperson": "Private individual",
  "Unternehmer": "Business",
  "Diese Angaben sind für berechtigte Ticketkäufer vor dem Kauf sichtbar. Keine geschützte Veranstaltungsadresse eintragen. Im lokalen Test ausschließlich erfundene Angaben verwenden.": "These details are visible to authorized ticket buyers before purchase. Do not enter a protected event address. Use invented information only in the local test.",
  "Der Verkäuferstatus richtet sich nach der tatsächlichen Tätigkeit. Die Auswahl ist keine rechtliche Einstufung durch die Plattform.": "Seller status depends on actual activity. This selection is not a legal classification by the platform.",
  "Verkäuferangaben speichern": "Save seller information",
  "Verkäuferangaben gespeichert. Veranstalterbestätigungen bitte erneut prüfen.":
      "Seller information saved. Please review organizer declarations again.",
  "Verkäuferangaben konnten nicht geladen werden.":
      "Seller information could not be loaded.",
  "Der Erklärungstext wurde geändert. Bitte aktualisiere die Anwendung.":
      "The declaration text has changed. Please update the application.",
  "Veranstalterbestätigung": "Organizer declaration",
  "Prüfe insbesondere die zulässige Nutzung des Veranstaltungsorts, erforderliche behördliche Erlaubnisse, Brandschutz, Kapazität, Jugendschutz und gegebenenfalls Musiklizenzen. Nicht jede Veranstaltung benötigt dieselben Erlaubnisse.": "Check permitted venue use, required official permissions, fire safety, capacity, protection of minors and any required music licenses. Different events need different permissions.",
  "Veranstalterverantwortung: bestätigt.":
      "Organizer responsibility: acknowledged.",
  "Veranstalterverantwortung: noch nicht aktuell bestätigt.":
      "Organizer responsibility: current acknowledgement missing.",
  "Bestätigung speichern": "Save declaration",
  "Verantwortung nicht bestätigen · Verkauf geschlossen halten":
      "Do not acknowledge responsibility · keep sales closed",
  "Bestätigung gespeichert.": "Declaration saved.",
  "Veranstalterverantwortung nicht bestätigt. Verkauf bleibt geschlossen.":
      "Organizer responsibility not acknowledged. Sales remain closed.",
  "Die Erklärung konnte nicht geladen werden.":
      "The declaration could not be loaded.",
  "Veranstaltungsmeldungen prüfen": "Review event reports",
  "Meine Veranstaltungsprüfungen": "My event reviews",
  "Veranstaltungsprüfung": "Event review",
  "Lokaler Test · keine rechtliche Freigabe und kein E-Mail-Versand":
      "Local test · no legal approval and no email delivery",
  "Keine Vorgänge vorhanden.": "No cases available.",
  "Prüfungen konnten nicht geladen werden.": "Reviews could not be loaded.",
  "Lokales Testpostfach": "Local test mailbox",
  "Postfach nicht verfügbar.": "Mailbox unavailable.",
  "Zuständigkeit": "Assigned reviewer",
  "Noch nicht zugewiesen": "Not yet assigned",
  "Stellungnahme": "Statement",
  "Bearbeitung übernehmen": "Take ownership of review",
  "Event-ID zur Prüfung": "Event ID for review",
  "Maßnahme": "Action",
  "Grundlage": "Basis",
  "Bestätigtes Verbot": "Confirmed prohibition",
  "Konkrete Gefahr": "Specific danger",
  "Absage": "Cancellation",
  "Klärung abgeschlossen": "Clarification completed",
  "Genehmigungslage klären": "Clarify permission status",
  "Begründung und Rechts- oder Regelgrundlage":
      "Reason and legal or policy basis",
  "Eine Verkaufspause erhält bezahlte Tickets. Eine Sperre hält den Einlass an und erzeugt Erstattungsaufgaben. Erneutes Öffnen reaktiviert gestoppte Bestellungen nicht.": "A sales pause preserves paid tickets. Blocking an event suspends admission and creates refund reviews. Reopening does not reactivate stopped orders.",
  "Begründete Entscheidung speichern": "Save reasoned decision",
  "Stellungnahme oder Bitte um erneute Prüfung":
      "Statement or request for reconsideration",
  "Erneute Prüfung anfordern": "Request reconsideration",
  "Verkäuferangaben oder aktuelle Veranstalterbestätigung fehlen.":
      "Seller information or a current organizer declaration is missing.",
  "Der Prüfstand wurde geändert. Bitte neu laden.":
      "The review state has changed. Please reload.",
  "Betroffene Veranstalter dürfen ihre eigene Teamentscheidung nicht treffen.":
      "Affected organizers cannot make their own team decision.",
  "Keine privaten Einladungslinks oder Zugangscodes eintragen.":
      "Do not enter private invitation links or access codes.",
  "Deine Stellungnahme wurde bereits eingereicht.":
      "Your statement has already been submitted.",
  "Ticketing und Veranstaltungsprüfungen: Dein Ticketvertrag besteht mit dem angegebenen Veranstalter. Er verantwortet Durchführung, erforderliche Genehmigungen, Nutzungsrechte und Sicherheit. Community Access vermittelt technisch; eine behördliche Genehmigungsprüfung findet durch die Plattform nicht statt. Veranstalter bestätigen ihre Verantwortung, nicht eine Prüfung oder Freigabe durch die Plattform. Eigene gesetzliche Pflichten der Plattform bleiben bestehen. Eingeschränkter Zugang ist keine Genehmigung oder Legalitätsprüfung. Meldungen werden vom Plattformteam geprüft. Eine begründete Verkaufspause stoppt neue und unbezahlte Käufe; bezahlte Tickets bleiben bei bloßer Unklarheit gültig. Bei Verbot, konkreter Gefahr oder Absage können Angebot und Einlass gesperrt und Erstattungen geprüft werden. Entscheidungen werden begründet; betroffene Veranstalter können erneute Prüfung verlangen. Dieser lokale Entwurf ersetzt keine geprüften Verkaufsbedingungen.": "Ticketing and event reviews: Your ticket contract is with the named organizer. They are responsible for running the event, required permissions, usage rights and safety. Community Access provides the technical intermediary service; the platform does not carry out an official permission review. Organizers acknowledge their responsibility, not a review or approval by the platform. The platform retains its own statutory obligations. Restricted access is not permission or legal verification. Reports are reviewed by the platform team. A reasoned sales pause stops new and unpaid purchases; paid tickets remain valid while uncertainty is clarified. Prohibition, specific danger or cancellation may lead to blocked offers and admission, and refund reviews. Decisions include reasons; affected organizers can request reconsideration. This local draft does not replace reviewed sales terms.",
  "Für Ticketing werden Verkäuferangaben und der Erklärungsstand zur Bestellung gespeichert. Meldungen enthalten Inhaltsreferenz, Begründung und grundsätzlich Kontaktangaben. Diese Angaben sind nur für die zuständige Bearbeitung bestimmt; Meldendenkontakte werden nicht automatisch an Veranstalter weitergegeben. Der lokale Test erzeugt ausschließlich synthetische Empfangs- und Entscheidungshinweise. Vor echtem Betrieb müssen Rechtsgrundlagen, Zuständigkeiten, Empfänger, Aufbewahrung und tatsächliche Zustellung geklärt werden.": "Ticketing stores seller information and the declaration version with the order. Reports contain a content reference, reasons and normally contact details. These details are used only for responsible handling; reporter contact details are not automatically shared with organizers. The local test creates synthetic receipt and decision notices only. Legal bases, responsibilities, recipients, retention and actual delivery must be clarified before real operation.",

  'Der Veranstalter bleibt Verkäufer der Tickets. Nur das verantwortliche Konto kann die Zahlungszuordnung ändern.': 'The organizer remains the ticket seller. Only the responsible account can change the payment account.',
  "Gemeinsam verwalten": "Manage together",
  "Auftritte und Einladungen": "Organizer profiles and invitations",
  "Gemeinsame Verwaltung gilt nur für diesen Veranstalterauftritt. Sie verleiht keine Communitymoderation. Das verantwortliche Konto verwaltet Einladungen und die Zahlungszuordnung.": "Shared management applies only to this organizer profile. It does not grant community moderation. The responsible account manages invitations and the payment account.",
  "Verantwortliches Konto": "Responsible account",
  "Zur gemeinsamen Verwaltung einladen": "Invite to shared management",
  "Keine weiteren Konten oder Einladungen.":
      "No additional accounts or invitations.",
  "Einladung zur Verwaltung annehmen": "Accept management invitation",
  "Auftritt verwalten": "Manage organizer profile",
  "Verwaltung entziehen": "Revoke management access",
  "Die gemeinsame Verwaltung ist nicht verfügbar.":
      "Shared management is unavailable.",
  "Nur das verantwortliche Konto darf die Zahlungszuordnung ändern.":
      "Only the responsible account can change the payment account.",
  "Das verantwortliche Konto kann hier nicht entfernt werden.":
      "The responsible account cannot be removed here.",
  "Die Einladung ist abgelaufen oder nicht mehr verfügbar.":
      "The invitation has expired or is no longer available.",
  "Ticketangebote konnten nicht neu geprüft werden.":
      "Ticket offers could not be checked again.",
  "Der Kauf konnte nicht freigegeben werden.":
      "The purchase could not be authorized.",
  "Weitere Ticketangebote": "More ticket offers",
  "Ich erfülle das für diese Veranstaltung angegebene Mindestalter.":
      "I meet the minimum age stated for this event.",
  "Vor dem Kauf ist eine persönliche Freigabe erforderlich.":
      "Personal approval is required before purchase.",
  "Das Ticket gilt für dein Konto. Beim Einlass werden Eventzugang und Sperren erneut geprüft.": "The ticket is bound to your account. Event access and restrictions are checked again at admission.",
  "Dieses Ticket kaufen": "Buy this ticket",
  "Ticketkategorien konnten nicht geladen werden.":
      "Ticket categories could not be loaded.",
  "Die Änderung wurde nicht übernommen.": "The change was not saved.",
  "Bitte Preis und Kontingent gültig eingeben.":
      "Enter a valid price and quota.",
  "Private Ticketangebote": "Private ticket offers",
  "Private Ticketangebote und Einlassrollen":
      "Private ticket offers and admission roles",
  "Lokaler Test · kein echter Verkauf": "Local test · no real sale",
  "Preis (€)": "Price (€)",
  "Ticketname": "Ticket name",
  "Kategorienkontingent": "Category quota",
  "Kaufberechtigung": "Purchase authorization",
  "Alle mit Eventzugang": "Everyone with event access",
  "Mitglieder der Eventcommunity": "Members of the event community",
  "Persönlich Freigeschaltete": "Personally authorized guests",
  "Teilnahmefreigabe erforderlich": "Attendance approval required",
  "Eventzugang und Konto genügen": "Event access and an account suffice",
  "Eine persönliche Kategorienfreigabe gibt keinen Eventzugang. Kategorienbedingungen gelten beim Kauf. Bei einem öffentlichen Event bleibt ein bezahlt erworbenes Ticket nach reinem Communityaustritt gültig. Event- und Veranstaltersperren greifen weiterhin.": "Personal category approval does not grant event access. Category conditions apply at purchase. For a public event, a paid ticket remains valid after leaving a community. Event and organizer restrictions still apply.",
  "Kategorie anlegen": "Create category",
  "Bestätigte Konto-E-Mail": "Verified account email",
  "Persönliche Freigabe": "Personal approval",
  "Zugang gemäß Kategorie": "Access according to category",
  "24 h freigeben": "Authorize for 24 hours",
  "Einlassrolle für 12 h vergeben": "Assign admission role for 12 hours",
  "Keine Einlassrolle verfügbar.": "No admission role available.",
  "Einlass bestätigt · synthetischer Test":
      "Admission confirmed · synthetic test",
  "Einlass nicht bestätigt. Bitte Verbindung und Berechtigung prüfen.":
      "Admission not confirmed. Check connection and authorization.",
  "Lokaler Test. Nur online prüfen. Weitergegebene Screenshots ersetzen die Zuordnung zum Konto nicht.": "Local test. Online checks only. Shared screenshots do not replace account verification.",
  "Konto-E-Mail vor Ort abgleichen": "Verify account email on site",
  "Ticketcode": "Ticket code",
  "Online-Einlass": "Online admission",
  "Einlass online prüfen": "Check admission online",
  "Online-Einlasscode anzeigen": "Show online admission code",
  "Kontogebunden. Code vor Ort nur online prüfen. Screenshots können weitergegeben werden.": "Account-bound. Verify the code online on site. Screenshots can be shared.",
  "Zuständigkeiten konnten nicht geprüft werden.":
      "Responsibilities could not be checked.",
  "Vorgang gespeichert.": "Action saved.",
  "Der Vorgang wurde nicht übernommen.": "The action was not saved.",
  "Vertraulicher Moderationsfall": "Confidential moderation case",
  "Einspruch": "Appeal",
  "Aufbewahrungsvorschau": "Retention preview",
  "Es wird nichts gelöscht. Fristen sind noch nicht beschlossen.":
      "Nothing will be deleted. Retention periods have not been decided.",
  "Mitgliedschaften, Sperren und Finanznachweise bleiben erhalten. Externe Kopien sind nicht geprüft.": "Memberships, restrictions and financial records are preserved. External copies have not been verified.",
  "Private Adressen": "Private addresses",
  "Abgeschlossene Bewerbungen": "Completed applications",
  "Abgelaufene Einladungen": "Expired invitations",
  "Teilnahmen": "Attendance records",
  "Einlassprüfungen": "Admission checks",
  "Eventmedien": "Event media",
  "Moderationsfälle": "Moderation cases",
  "Finanznachweise": "Financial records",
  "Freigaben und Moderation": "Approvals and moderation",
  "Lokaler Test. Jede Aktion wird serverseitig auf deine Zuständigkeit geprüft.":
      "Local test. Your authority for each action is checked on the server.",
  "Eigenes Event": "Own event",
  "Eventzugang für 24 h sperren": "Block event access for 24 hours",
  "Zuständige Community": "Assigned community",
  "Communityzugang für 24 h pausieren": "Pause community access for 24 hours",
  "Eine Communitypause sperrt nur diesen Zugangsweg. Eine dauerhafte Maßnahme braucht eine unabhängige zweite Prüfung.": "A community pause blocks only this access path. A permanent restriction requires an independent second review.",
  "Moderation für 24 h zuweisen": "Assign moderation for 24 hours",
  "Veranstalterauftritt für Veröffentlichungsrecht":
      "Organizer profile for publishing rights",
  "Veröffentlichungsrecht vergeben": "Grant publishing rights",
  "Veröffentlichungsrecht entziehen": "Revoke publishing rights",
  "Veröffentlichungsrechte verleihen keine Communityverwaltung oder Aufnahmebefugnis.": "Publishing rights do not grant community administration or admission authority.",
  "Community für Eventfreigabe": "Community for event approval",
  "Communityfreigabe für Event anfragen":
      "Request community approval for event",
  "Als Moderation freigeben": "Approve as moderator",
  "Unabhängig überprüfte Maßnahme": "Independently reviewed restriction",
  "Vertraulicher Falltext oder eigener Einspruch":
      "Confidential case details or own appeal",
  "Moderationsfall anlegen": "Create moderation case",
  "Text als neue Communityregeln veröffentlichen":
      "Publish text as new community rules",
  "Eigener Moderationsvorgang": "Own moderation case",
  "Zugewiesener Communityfall": "Assigned community case",
  "Vertraulichen Fall lesen": "Read confidential case",
  "Dauerhafte Maßnahme unabhängig bestätigen":
      "Independently confirm permanent restriction",
  "Eigenen Einspruch einreichen": "Submit own appeal",
  "Aufbewahrung nur ansehen": "View retention preview",
  "Communityverwaltung": "Community administration",
  "Moderatoren entscheiden manuell über deine Mitgliedschaft.":
      "Moderators decide on your membership manually.",
  "Die Moderation teilt eine Einladung über einen bestehenden Kanal. Du beantwortest die Fragen der Community.": "Moderators share an invitation through an existing channel. You answer the community questions.",
  "Die Moderation teilt eine Einladung über einen bestehenden Kanal.":
      "Moderators share an invitation through an existing channel.",
  "Moderatoren entscheiden manuell. Die Aufnahme allein ist keine Eventzusage.": "Moderators decide manually. Community admission alone does not confirm event attendance.",
  'So funktioniert’s': 'How it works',
  'Orte': 'Venues',
  'Für Gäste': 'For guests',
  'Für Veranstalter': 'For organizers',
  'Mit Konto sortieren wir das Programm nach deinem Geschmack.':
      'With an account, we sort the program to suit your taste.',
  'Ein Konto schaltet nichts frei.': 'An account does not grant access.',
  'Du bestimmst, wer kommt und wann der Ort bekannt wird.':
      'You decide who comes and when the location is released.',
  'Aufnahme und Eventteilnahme werden separat von Hand entschieden.':
      'Admission and event attendance are decided separately by a person.',
  'Als Veranstalter starten': 'Start as an organizer',
  'Einladung erhalten': 'Receive an invitation',
  'Der Gastgeber teilt eine Einladung über einen bestehenden Kanal. Du beantwortest die Fragen der Community.': 'The organizer shares an invitation through an existing channel. You answer the community’s questions.',
  'Aufnahme abwarten': 'Wait for admission',
  'Gastgeber entscheiden manuell über deine Mitgliedschaft.':
      'Organizers decide on your membership by hand.',
  'Erst eine separate Zusage bestätigt deinen Eventplatz.':
      'Only a separate approval confirms your event place.',
  'ENTDECKEN': 'DISCOVER',
  'MITMACHEN': 'TAKE PART',
  'RECHTLICHES': 'LEGAL',
  'Programm': 'Program',
  'Communityprofile': 'Community profiles',
  'Über Community Access': 'About Community Access',

  'Helle Darstellung': 'Light appearance',
  'Dunkle Darstellung': 'Dark appearance',
  'Mit Zugang': 'With access',
  'Anmelden': 'Sign in',
  'Abmelden': 'Sign out',
  'Dein Konto': 'Your account',
  'Dein Testkonto': 'Your test account',
  'Zur Hauptseite': 'Back to home',
  'Zur Anmeldung': 'Back to sign in',
  'Zurück': 'Back',
  'Abbrechen': 'Cancel',
  'Öffnen': 'Open',
  'Communities': 'Communities',
  'Veranstalter': 'Organizers',
  'Veranstaltungsorte': 'Venues',
  'Über': 'About',
  'Menü': 'Menu',
  'Menü schließen': 'Close menu',
  'Hauptnavigation': 'Main navigation',
  'Events & Communities.': 'Events & communities.',
  'Öffentlich geteilt': 'Shared publicly',
  'OHNE ANMELDUNG ENTDECKEN': 'DISCOVER',
  'DEIN ZUGANG': 'YOUR ACCESS',
  'Entdecke, was Gastgeber öffentlich teilen. Dein persönlicher Zugang beginnt mit einer Einladung.': 'Discover what organizers share publicly. Your personal access starts with an invitation.',
  'Entdecken ist\nder erste Schritt.': 'Discovery is\nthe first step.',
  'Dein persönlicher Zugang beginnt mit einer Einladung. Aufnahme und Eventteilnahme werden vom Gastgeber separat entschieden.': 'Your personal access starts with an invitation. Admission and event attendance are separate organizer decisions.',
  'So funktioniert Community Access': 'How Community Access works',
  'Event suchen': 'Search events',
  'Event oder Community': 'Event or community',
  'Suche in öffentlich geteilten Events und Communitynamen.':
      'Search publicly shared events and community names.',
  'Suchen': 'Search',
  'Suche zurücksetzen': 'Clear search',
  'Erneut versuchen': 'Try again',
  'Noch keine öffentlichen Events.': 'No public events yet.',
  'Keine passenden öffentlichen Events.': 'No matching public events.',
  'Hier erscheinen Events, sobald Gastgeber sie öffentlich teilen.':
      'Events will appear when organizers share them publicly.',
  'Versuche einen anderen Event- oder Communitynamen.':
      'Try another event or community name.',
  'Öffentliche Events sind derzeit nicht verfügbar.':
      'Public events are currently unavailable.',
  'Communities entdecken.': 'Discover communities.',
  'Entdecken.\nKennenlernen.\nDabei sein.': 'Discover.\nConnect.\nTake part.',
  'Veranstaltungen': 'Events',
  'Veranstaltung': 'Event',
  'Veranstaltungsreihe': 'Event series',
  'Event ansehen': 'View event',
  'Veranstaltung ansehen': 'View event',
  'Reihe ansehen': 'View series',
  'Abgesagt': 'Cancelled',
  'Aktualisieren': 'Refresh',
  'Weitere Veranstaltungen': 'More events',
  'Vorherige Seite': 'Previous page',
  'Betreiber / Impressum': 'Legal notice',
  'Datenschutz': 'Privacy',
  'Hilfe & Kontakt': 'Help & contact',
  'Community Access · Lokaler synthetischer Prototyp':
      'Community Access · Local synthetic prototype',
  'Konto anlegen.': 'Create an account.',
  'Testkonto anlegen.': 'Create a test account.',
  'Konto anlegen': 'Create account',
  'Testkonto anlegen': 'Create test account',
  'Testname': 'Test name',
  'Name': 'Name',
  'E-Mail': 'Email',
  'Passwort': 'Password',
  'Passwort bestätigen': 'Confirm password',
  'Mit deinem Testkonto anmelden': 'Sign in with your test account',
  'Mit deinem Konto anmelden': 'Sign in with your account',
  'Meine Merkliste': 'My saved items',
  'Gastgeberverwaltung': 'Organizer administration',
  'Deine Veranstalterprofile.': 'Your organizer profiles.',
  'Profilname': 'Profile name',
  'Profilbeschreibung': 'Introduction',
  'Profil öffentlich anzeigen': 'Show public profile',
  'Profil speichern': 'Save profile',
  'Deine Communities': 'Your communities',
  'Veranstalterprofil auswählen': 'Select organizer profile',
  'Weiteres Veranstalterprofil anlegen': 'Create another organizer profile',
  'Event- und Ortsangaben': 'Event and venue details',
  'Eventtitel': 'Event title',
  'Verantwortliche Community': 'Responsible community',
  'Einzelnes Event': 'Single event',
  'Veröffentlichungsstatus': 'Publication status',
  'Entwurf': 'Draft',
  'Veröffentlicht': 'Published',
  'Event öffentlich anzeigen': 'Show public event',
  'Beginn mit Zeitzone': 'Start with timezone',
  'Freigegebene Ortsangabe': 'Location details',
  'Zugänglichkeit und Awareness': 'Accessibility and awareness',
  'Seite vorab ansehen': 'Preview page',
  'Speichern': 'Save',
  'Event speichern': 'Save event',
  'Frage hinzufügen': 'Add question',
  'Frage entfernen': 'Remove question',
  'Formularfrage': 'Form question',
  'Pflichtfeld': 'Required field',
  'Freigeben': 'Approve',
  'Ablehnen': 'Decline',
  'Zugriff entziehen': 'Revoke access',
  'Beschreibung': 'Description',
  'Line-up': 'Line-up',
  'Musikgenres': 'Music genres',
  'Einlass': 'Admission',
  'Mindestalter': 'Minimum age',
  'Ende mit Zeitzone': 'End with timezone',
  'Veranstaltungsort': 'Venue',
  'Flyer auswählen': 'Select flyer',
  'Flyer entfernen': 'Remove flyer',
  'Bildbeschreibung': 'Image description',
  'Lieblingsveranstaltungen': 'Favourite events',
  'Musikgeschmack': 'Music taste',
  'Veranstaltungspräferenzen': 'Event preferences',
  'Freizeitbeschäftigungen': 'Leisure activities',
  'Meine Präferenzen': 'My preferences',
  'Präferenzen speichern': 'Save preferences',
  'Präferenzen gespeichert.': 'Preferences saved.',
  'Awarenesskonzept vorhanden?': 'Is there an awareness policy?',
  'Awarenessteam vorhanden?': 'Is there an awareness team?',
  'Ja': 'Yes',
  'Nein': 'No',
  'Bitte auswählen': 'Please select',
  'Öffentlich': 'Public',
  'Privat': 'Private',
  'Semi-öffentlich': 'Semi-public',
  'Sichtbarkeit': 'Visibility',
  'Gästeprüfung': 'Guest review',
  'Manuelle Anfrage': 'Manual review',
  'Formular und manuelle Prüfung': 'Form and manual review',
  'Nur persönliche Freigabe': 'Personal invitation only',
  'Zeitangaben freigeben ab': 'Release time details from',
  'Ortsangaben freigeben ab': 'Release location details from',
  'Formulare verwalten': 'Manage forms',
  'Formular erstellen': 'Create form',
  'Formulartitel': 'Form title',
  'Formular speichern': 'Save form',
  'Ohne Formular': 'No form',
  'Anfragen zu Veranstaltungen': 'Event requests',
  'Interesse bekunden': 'Express interest',
  'Interesse gesendet.': 'Interest submitted.',
  'Zugang verwalten': 'Manage access',
  'Teilnahme zusagen': 'Approve attendance',
  'Teilnahmezusage widerrufen': 'Revoke attendance approval',
  'Ich war dort': 'I attended',
  'Besuch als allgemeine Veranstalterpräferenz gespeichert.':
      'Attendance saved as a general organizer preference.',
  'pending': 'Pending',
  'approved': 'Approved',
  'rejected': 'Declined',
  'revoked': 'Revoked',
  'withdrawn': 'Withdrawn',
  "Hinter jedem Event steht eine Community.":
      "Behind every event is a community.",
  "Öffentliche Profile zeigen, was die Gastgeber über ihre Community teilen möchten.": "Public profiles show what organizers choose to share about their community.",
  "Communities entdecken": "Discover communities",
  "Bestehende Veranstalter bleiben der Mittelpunkt. Die Gastgeber bestimmen, welche Informationen sie öffentlich teilen.": "Organizers remain at the centre. They decide which information to share publicly.",
  "Community Access ergänzt bestehende Veranstalter um einen nachvollziehbaren Zugang. Bestehende Kommunikationskanäle bleiben bestehen.": "Community Access adds a clear access process for organizers. Existing communication channels stay in place.",
  "Bewerbung zurückziehen?": "Withdraw application?",
  "Die Gastgeber können diese Bewerbung danach nicht mehr annehmen. Mit einer gültigen Einladung kannst du dich erneut bewerben. Der Rückzug gibt keine Mitgliedschaft oder Eventzusage.": "Organizers can no longer approve this application after withdrawal. A valid invitation lets you reapply. Withdrawal grants neither membership nor event admission.",
  "Rückzug bestätigen": "Confirm withdrawal",
  "Nur für die lokale Demo: NurDemo-2026!":
      "For the local demo only: NurDemo-2026!",
  "Passwort vergessen?": "Forgot password?",
  "Einladung öffnen": "Open invitation",
  "EVENT": "EVENT",
  "Dieses Event ist abgesagt.": "This event is cancelled.",
  "Selbstauskunft, keine verifizierte Altersprüfung.":
      "Self-declaration; age has not been verified.",
  "Eventteilnahme anfragen": "Request event admission",
  "Deine Anfrage ist offen. Die genaue Location bleibt geschützt.":
      "Your request is pending. The exact location stays protected.",
  "Location abrufen": "View location",
  "Community": "Community",
  "Gastzugang": "Guest access",
  "Gastzugang · Lokale Demo": "Guest access · Local demo",
  "Bewerbung – Aufnahme – Eventanfrage – separate Bestätigung":
      "Application – admission – event request – separate confirmation",
  "Deine E-Mail-Adresse ist bestätigt.": "Your email address is verified.",
  "Dein Konto begründet keine Mitgliedschaft oder Eventzusage. Profilzugriff wird separat vom Gastgeber freigegeben.": "Your account grants neither membership nor event admission. The organizer approves profile access separately.",
  "Keine Bewerbungen vorhanden.": "No applications yet.",
  "Du kannst dich erneut bewerben. Öffne dafür eine gültige Einladung dieser Community.":
      "You can reapply using a valid invitation to this community.",
  "Eine erneute Bewerbung ist gesperrt.": "Reapplication is blocked.",
  "Bewerbung zurückziehen": "Withdraw application",
  "Gastgeber entscheiden manuell. Die Aufnahme allein ist keine Eventzusage.": "Organizers decide manually. Community admission does not confirm event attendance.",
  "Aktuell sind keine Events für dich zugänglich.":
      "No events are currently accessible to you.",
  "Keine Events für diese Auswahl.": "No events match this selection.",
  "Alle Konten, Veranstalter und Orte sind erfunden. Änderungen werden im lokalen Prototyp gespeichert.": "All accounts, organizers and locations are synthetic. Changes are saved in the local prototype.",
  "Ein Profilwechsel lädt den gespeicherten Stand. Jedes Profil hat eigene Zugänge und Veranstaltungen.": "Switching profiles loads the saved version. Each profile has separate access and events.",
  "Neues Profil: Erst speichern, dann Veranstaltungen anlegen.":
      "New profile: save it before adding events.",
  "Bewerbung mit manueller Freigabe": "Application with manual approval",
  "Eigenes Formular mit manueller Freigabe": "Custom form with manual approval",
  "Persönlicher Zugangslink": "Personal access link",
  "Profiladresse zum Teilen": "Profile address to share",
  "Noch keine Profilanfragen.": "No profile requests yet.",
  "Für ein bestehendes Konto mit bestätigter E-Mail. Einmal nutzbar, sieben Tage gültig.":
      "For an existing verified account. Single use, valid for seven days.",
  "Link erstellen": "Create link",
  "Link widerrufen": "Revoke link",
  "Reihen, Events und Gästekreise verwalten":
      "Manage series, events and guest access",
  "Das öffentliche Ortsverzeichnis übernimmt nur freigegebene Orte frei sichtbarer Events in öffentlichen Communities. Geschützte Reihen und Events erscheinen dort nicht.": "The public venue directory includes shared locations of public events in public communities. Protected events and series stay hidden.",
  "Eventangaben hinzufügen": "Add event details",
  "Verwaltung neu laden": "Reload administration",
  "Beginn im sichtbaren Event anzeigen": "Show start time to event viewers",
  "Diese Ortsangabe im sichtbaren Event anzeigen":
      "Show location to event viewers",
  "Diese Angaben werden allen Personen angezeigt, die das Event sehen dürfen. Keine privaten Adressen oder persönlichen Notizen eintragen. Unbekannt ist keine Aussage über vorhandene Ausstattung.": "Everyone who can view the event sees these details. Do not enter private addresses or personal notes. Unknown does not indicate whether facilities exist.",
  "Eventangaben speichern": "Save event details",
  "Ungespeicherte Vorschau der sichtbaren Eventangaben.":
      "Unsaved preview of visible event details.",
  "Vorherige Programmseite": "Previous programme page",
  "Dein Konto.": "Your account.",
  "Bestätigungslink erneut anfordern": "Resend verification link",
  "Deine Präferenzen.": "Your preferences.",
  "Verwende ausschließlich erfundene Angaben und eine E-Mail mit @example.invalid. Dein Konto ist keine Communityaufnahme oder Eventzusage.": "Use synthetic details and an @example.invalid email only. An account grants neither community nor event admission.",
  "Verwende eine erreichbare E-Mail-Adresse. Dein Konto ist keine Communityaufnahme oder Eventzusage.": "Use an email you can access. An account grants neither community nor event admission.",
  "Dein Zugang.": "Your access.",
  "E-Mail-Adresse": "Email address",
  "Mit deinem Testkonto anmelden.": "Sign in with your test account.",
  "Mit deinem Konto anmelden.": "Sign in with your account.",
  "Anmelden.": "Sign in.",
  "Zugang zu deinem privaten Profil": "Access to your private profile",
  "Deine Formularfragen": "Your form questions",
  "Offene Profilanfragen": "Pending profile requests",
  "Veranstaltungen und Orte": "Events and venues",
  "Mindestens eine Community auswählen. Private Communitynamen bleiben für andere verborgen.": "Select at least one community. Private community names stay hidden from other viewers.",
  "Diese Freigaben betreffen ausschließlich dein Profil, keine Mitgliedschaft oder Eventzusage.": "These approvals grant profile access only, not membership or event admission.",
  "Mindestens eine Community auswählen.": "Select at least one community.",
};

String attendanceStatus(
  BuildContext context,
  String status,
) => switch (status) {
  'pending' => localText(context, 'Anfrage in Bearbeitung', 'Request pending'),
  'approved' => localText(context, 'Teilnahme zugesagt', 'Attendance approved'),
  'purchase_eligible' => localText(
    context,
    'Ticketkauf freigegeben · Zahlung erforderlich',
    'Ticket purchase approved · payment required',
  ),
  'rejected' => localText(context, 'Anfrage abgelehnt', 'Request declined'),
  'revoked' => localText(
    context,
    'Teilnahmezusage widerrufen',
    'Attendance approval revoked',
  ),
  'withdrawn' => localText(
    context,
    'Teilnahme zurückgezogen',
    'Attendance withdrawn',
  ),
  _ => status,
};

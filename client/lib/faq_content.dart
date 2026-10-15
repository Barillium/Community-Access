import 'package:flutter/material.dart';

import 'app_language.dart';
import 'design_system.dart';

class FaqContent extends StatelessWidget {
  const FaqContent({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AushangPalette.of(context);
    final compact =
        MediaQuery.sizeOf(context).width < 768 ||
        AccessLayout.largeText(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AccessSpacing.s48),
        const AccessHeading('FAQ', role: AccessHeadingRole.page, level: 1),
        const SizedBox(height: AccessSpacing.s20),
        Text(
          localText(
            context,
            'Deine Fragen. Alle wichtigen Antworten zu Zugang, Events und deinem Konto.',
            'Your questions. Everything you need to know about access, events and your account.',
          ),
          style: TextStyle(
            color: palette.muted,
            height: 1.5,
            fontSize: AccessTypography.leadSize,
          ),
        ),
        const SizedBox(height: AccessSpacing.s48),
        for (final group in _groups) ...[
          _FaqGroup(group: group, compact: compact),
          const SizedBox(height: AccessSpacing.s48),
        ],
      ],
    );
  }
}

class _FaqGroup extends StatelessWidget {
  const _FaqGroup({required this.group, required this.compact});
  final _Group group;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = AushangPalette.of(context);
    final heading = AccessHeading(
      localText(context, group.de, group.en),
      role: AccessHeadingRole.section,
      level: 2,
    );
    final questions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in group.questions)
          ExpansionTile(
            key: PageStorageKey(item.questionDe),
            tilePadding: const EdgeInsets.symmetric(
              vertical: AccessSpacing.s12,
            ),
            childrenPadding: const EdgeInsets.only(
              bottom: AccessSpacing.s24,
              right: AccessSpacing.s24,
            ),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            expandedAlignment: Alignment.centerLeft,
            minTileHeight: 64,
            textColor: palette.ink,
            collapsedTextColor: palette.ink,
            iconColor: palette.ink,
            collapsedIconColor: palette.ink,
            shape: Border(bottom: BorderSide(color: palette.hair)),
            collapsedShape: Border(bottom: BorderSide(color: palette.hair)),
            title: Text(
              localText(context, item.questionDe, item.questionEn),
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: AccessTypography.leadSize,
                height: 1.4,
              ),
            ),
            children: [
              Text(
                localText(context, item.answerDe, item.answerEn),
                style: TextStyle(
                  color: palette.muted,
                  height: 1.6,
                  fontSize: AccessTypography.bodySize,
                ),
              ),
            ],
          ),
      ],
    );
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.ink)),
      ),
      padding: const EdgeInsets.only(top: AccessSpacing.s20),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: AccessSpacing.s16),
                questions,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 240,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: AccessSpacing.s16,
                      right: AccessSpacing.s24,
                    ),
                    child: heading,
                  ),
                ),
                Expanded(child: questions),
              ],
            ),
    );
  }
}

class _Question {
  const _Question(
    this.questionDe,
    this.questionEn,
    this.answerDe,
    this.answerEn,
  );
  final String questionDe, questionEn, answerDe, answerEn;
}

class _Group {
  const _Group(this.de, this.en, this.questions);
  final String de, en;
  final List<_Question> questions;
}

const _groups = [
  _Group("Grundlagen", "The basics", [
    _Question(
      "Was ist Community Access?",
      "What is Community Access?",
      "Community Access hilft bestehenden Kollektiven, Veranstaltungen zu teilen und Zugang zu organisieren. Du kannst öffentliche Events entdecken, eine Communityaufnahme beantragen und deine eigene Teilnahme verwalten. Bestehende Messenger und Kontaktwege bleiben bestehen.",
      "Community Access helps existing collectives share events and manage access. You can discover public events, apply to join a community and manage your own attendance. Existing messengers and contact channels remain in place.",
    ),
    _Question(
      "Was kann ich ohne Konto sehen?",
      "What can I see without an account?",
      "Öffentlich geteilte Events und Veranstalter kannst du ohne Anmeldung ansehen und durchsuchen. Private Veranstaltungen, Bewerbungen und geschützte genaue Locations sind nur mit der passenden aktuellen Berechtigung sichtbar. Ein Konto allein öffnet keine geschützten Inhalte.",
      "You can browse and search publicly shared events and organizers without signing in. Private events, applications and protected exact locations require the appropriate current access. An account alone does not unlock protected content.",
    ),
    _Question(
      "Wie lege ich ein Konto an?",
      "How do I create an account?",
      "Öffne „Konto“ und wähle die Registrierung. Nach dem Anlegen erhältst du einen Bestätigungslink. Bestätige deine E-Mail-Adresse und melde dich anschließend an. Die Bestätigung meldet dich nicht automatisch an und macht dich noch nicht zum Communitymitglied oder Eventteilnehmer.",
      "Open “Account” and choose registration. After registering, you receive a verification link. Verify your email address, then sign in. Verification does not sign you in automatically or make you a community member or confirmed attendee.",
    ),
  ]),
  _Group("Einladung und Teilnahme", "Invitations and attendance", [
    _Question(
      "Wie komme ich in eine Community?",
      "How do I join a community?",
      "Du brauchst ein bestätigtes Konto und eine persönliche Einladung der zuständigen Communitymoderation. Die Einladung wird über einen bestehenden Kontaktweg geteilt. Öffne sie mit dem vorgesehenen Konto, beantworte die Fragen und reiche deine Bewerbung ein. Die Moderation entscheidet manuell über die Aufnahme.",
      "You need a verified account and a personal invitation from the assigned community moderators. The invitation is shared through an existing contact channel. Open it with the intended account, answer the questions and submit your application. Moderators review admission manually.",
    ),
    _Question(
      "Wie lange gilt eine Einladung?",
      "How long is an invitation valid?",
      "Eine persönliche Communityeinladung gilt sieben Tage, ist an das vorgesehene Konto gebunden und kann widerrufen werden. Erst eine erfolgreich eingereichte Bewerbung verbraucht sie. Ist die Einladung abgelaufen oder zurückgezogen, wende dich über euren bisherigen Kontaktweg an die Communitymoderation.",
      "A personal community invitation is valid for seven days, is bound to its intended account and can be revoked. Only a successfully submitted application uses it up. If it has expired or been withdrawn, contact the community moderators through your existing channel.",
    ),
    _Question(
      "Bin ich als Mitglied automatisch bei einem Event dabei?",
      "Does membership automatically confirm event attendance?",
      "Nein. Communitymitgliedschaft und Eventteilnahme sind getrennte Entscheidungen. Bei einem Event ohne Ticket stellst du eine Teilnahmeanfrage; erst die separate Zusage bestätigt deinen Platz. Bei einem kostenpflichtigen Event ist eine manuelle Freigabe gegebenenfalls nur die Kaufberechtigung. Erst die bestätigte Zahlung begründet dann deine Teilnahme.",
      "No. Community membership and event attendance are separate decisions. For an event without tickets, you submit an attendance request; only a separate approval confirms your place. For a paid event, manual approval may only grant permission to buy. Only confirmed payment then establishes attendance.",
    ),
    _Question(
      "Was erlaubt eine persönliche Eventeinladung?",
      "What does a personal event invitation allow?",
      "Eine einzelne Eventfreigabe öffnet ausschließlich das betreffende Event. Sie gibt dir weder Zugang zum privaten Veranstalterprofil noch zu anderen Veranstaltungen und macht dich nicht zum Communitymitglied. Beachte anschließend die Teilnahme- oder Kaufbedingungen des Events.",
      "Individual event access opens only that event. It does not unlock a private organizer profile or other events, and it does not make you a community member. You still need to follow the event’s attendance or purchase requirements.",
    ),
    _Question(
      "Wann sehe ich die genaue Location?",
      "When can I see the exact location?",
      "Die öffentliche Ortsangabe und eine geschützte genaue Location sind getrennt. Die genaue Location kannst du erst mit aktuell berechtigter, bestätigter Teilnahme abrufen. Bei einem Ticketevent braucht es dafür eine bestätigte Zahlung. Wird die Berechtigung entzogen, ist ein neuer Abruf gesperrt.",
      "A public location description and a protected exact location are separate. You can retrieve the exact location only with current authorized, confirmed attendance. A ticketed event requires confirmed payment. If access is revoked, you can no longer retrieve the location.",
    ),
    _Question(
      "Welche Fristen und Altersbedingungen gelten?",
      "Which deadlines and age requirements apply?",
      "Beachte die Angaben im jeweiligen Event. Teilnahmeanfragen und Zusagen sind nur vor Beginn möglich; eine Anfragefrist kann früher enden. Ein Mindestalter kann zusätzlich gelten und wird von dir ausdrücklich bestätigt. Ein Konto oder eine Communitymitgliedschaft ersetzt keine Alters- oder Einlassbedingung.",
      "Check the details of the individual event. Attendance requests and approvals are possible only before it starts; a request deadline may be earlier. An additional minimum age may apply and requires your explicit confirmation. An account or community membership does not replace age or admission requirements.",
    ),
  ]),
  _Group("Tickets und Einlass", "Tickets and admission", [
    _Question(
      "Wann kann ich ein Ticket kaufen?",
      "When can I buy a ticket?",
      "Für einen Kauf brauchst du ein bestätigtes Konto und ein verfügbares Angebot. Bei öffentlichem Verkauf ist keine manuelle Kaufentscheidung nötig. Bei Verkauf nach Freigabe muss der Veranstalter zuerst deine Kaufberechtigung bestätigen. Eine Einladung, Anfrage oder Kaufberechtigung reserviert noch kein Ticket.",
      "To buy a ticket, you need a verified account and an available offer. Public sales do not require manual purchase approval. For approval-based sales, the organizer must first confirm your permission to buy. An invitation, request or purchase approval does not reserve a ticket.",
    ),
    _Question(
      "Wie lange bleibt mein Ticket reserviert?",
      "How long is my ticket reserved?",
      "Im Checkout wird ein verfügbares Ticket für 15 Minuten reserviert. Erst eine bestätigte Zahlung schließt den Kauf ab. Pro bestätigtem Konto und Event ist ein persönliches Ticket vorgesehen. Gruppenkäufe und die Übertragung auf andere Personen werden nicht angeboten.",
      "An available ticket is reserved for 15 minutes during checkout. Only confirmed payment completes the purchase. There is one personal ticket per verified account and event. Group purchases and transfers to other people are not offered.",
    ),
    _Question(
      "Wo finde ich mein Ticket und wie funktioniert der Einlass?",
      "Where can I find my ticket, and how does admission work?",
      "Öffne im Konto „Meine Tickets“. Dort findest du deinen Bestellstatus und den verfügbaren Ticketnachweis. Beim Einlass werden Ticket, zugeordnetes Konto, Zahlung und aktuelle Berechtigung online geprüft. Ein bereits verwendeter Code erlaubt keinen zweiten Einlass; ohne erfolgreiche Onlineprüfung gibt es keine Einlassbestätigung.",
      "Open “My tickets” in your account to see your order status and available ticket document. At admission, the ticket, linked account, payment and current access are checked online. A code that has already been used does not permit a second admission; an unsuccessful online check does not confirm admission.",
    ),
    _Question(
      "Was passiert bei einer Absage oder Erstattung?",
      "What happens if an event is cancelled or a refund is needed?",
      "Vertragspartner für dein Ticket ist der angegebene Veranstalter. Eine Absage oder ein tatsächlicher Berechtigungsentzug sperrt den betroffenen Einlass und löst eine Erstattungsprüfung aus. Der zuständige Veranstalter oder ein berechtigter Verwalter prüft und genehmigt eine Teil- oder Vollerstattung. Eine Verkaufspause allein storniert bereits bezahlte Tickets nicht.",
      "Your contractual ticket seller is the named organizer. Cancellation or actual withdrawal of access blocks the affected admission and triggers a refund review. The responsible organizer or an authorized manager reviews and approves a partial or full refund. Pausing sales alone does not cancel tickets that have already been paid for.",
    ),
    _Question(
      "Sind Zahlungen in dieser lokalen Vorschau echt?",
      "Are payments in this local preview real?",
      "Nein. Diese lokale Vorschau verwendet erfundene Konten, Veranstaltungen und simulierte Zahlungen. Es wird kein Geld bewegt. Testbelege sind keine gültigen Eintrittstickets für echte Veranstaltungen.",
      "No. This local preview uses fictional accounts and events with simulated payments. No money changes hands. Test documents are not valid admission tickets for real events.",
    ),
  ]),
  _Group("Konto, Daten und Hilfe", "Account, data and help", [
    _Question(
      "Was mache ich, wenn ich mein Passwort vergessen habe?",
      "What if I forget my password?",
      "Wähle bei der Anmeldung „Passwort vergessen“ und fordere einen neuen Link an. Bestätigungs- und Resetlinks gelten eine Stunde. Ist ein Link abgelaufen oder bereits verwendet, fordere einen neuen an. Melde dich nach dem Zurücksetzen erneut an und teile keine Passwörter oder Anmeldelinks.",
      "Choose “Forgot password” when signing in and request a new link. Verification and reset links are valid for one hour. If a link has expired or has already been used, request another one. Sign in again after resetting your password, and do not share passwords or sign-in links.",
    ),
    _Question(
      "Wer kann meine Bewerbungsantworten sehen?",
      "Who can see my application answers?",
      "Deine Bewerbungen und Antworten werden nicht als öffentliches Gastprofil angezeigt. Communitybewerbungen sind für dich und die zuständige Communitymoderation bestimmt. Veranstalter bearbeiten nur die Eventanfragen, für die sie zuständig sind. Genaue geschützte Locations gehören nicht in öffentliche Texte oder Flyer.",
      "Your applications and answers are not displayed as a public guest profile. Community applications are for you and the assigned community moderators. Organizers handle only the event requests within their responsibility. Protected exact locations do not belong in public descriptions or flyers.",
    ),
    _Question(
      "Wie kann ich mein Konto löschen lassen?",
      "How can I request account deletion?",
      "Öffne im Konto „Konto löschen“ und bestätige die Anfrage mit der erforderlichen erneuten Anmeldung oder Passwortbestätigung. Die Bestätigung speichert eine Löschanfrage; sie bedeutet nicht, dass alle Daten bereits gelöscht sind. Bestellnachweise und offene Erstattungen müssen getrennt behandelt werden.",
      "Open “Delete account” in your account and confirm the request using the required sign-in or password confirmation. Confirmation records a deletion request; it does not mean that all data has already been erased. Order records and outstanding refunds must be handled separately.",
    ),
    _Question(
      "Wie melde ich einen Inhalt oder bekomme Hilfe?",
      "How can I report content or get help?",
      "Nutze „Veranstaltung melden“ beim betreffenden Inhalt oder „Hilfe & Kontakt“ im Konto beziehungsweise Seitenfuß. Beschreibe, welcher Inhalt betroffen ist und was passiert ist. Sende keine Passwörter, privaten Einladungslinks oder unnötigen Daten anderer Personen. Für eigene Beschwerden und Einsprüche gibt es den zugehörigen Kontobereich.",
      "Use “Report event” on the relevant content or “Help & contact” in your account or the footer. Describe the content and what happened. Do not send passwords, private invitation links or unnecessary information about other people. Your account includes the relevant section for your own complaints and appeals.",
    ),
  ]),
  _Group("Für Veranstalter", "For organizers", [
    _Question(
      "Wie starte ich als Veranstalter?",
      "How do I get started as an organizer?",
      "Melde dich mit einem bestätigten Konto an und öffne die Veranstalteraufnahme unter „Zugang verwalten“. Stelle dein Kollektiv vor und beantworte die Angaben zu Veranstaltungsarten sowie Awarenesskonzept und Awarenessteam. Das Plattformteam prüft die Bewerbung manuell. Die Aufnahme erteilt keine automatische Communitymoderation.",
      "Sign in with a verified account and open organizer admission under “Manage access”. Introduce your collective and provide the requested event-type, awareness-concept and awareness-team information. The platform team reviews the application manually. Admission does not automatically grant community moderation rights.",
    ),
    _Question(
      "Wer entscheidet über Aufnahme und Eventteilnahme?",
      "Who decides on community admission and event attendance?",
      "Die ausdrücklich zugewiesene Communitymoderation entscheidet über Communityaufnahme, Regeln und Veröffentlichungsfreigaben. Veranstalter verantworten ihre eigenen Eventinhalte, Teilnahmeentscheidungen und Verkäufe. Diese Rollen sind getrennt; eine Veranstalterzulassung allein erlaubt keine Verwaltung der Community.",
      "Explicitly assigned community moderators decide on community admission, rules and publication permissions. Organizers are responsible for their own event content, attendance decisions and sales. These roles are separate; organizer admission alone does not grant community administration rights.",
    ),
    _Question(
      "Kann ich meinen Auftritt gemeinsam verwalten?",
      "Can I manage my organizer profile with other people?",
      "Ja. Das verantwortliche Konto kann ein bestätigtes Konto ausdrücklich zur gemeinsamen Verwaltung eines bestimmten Auftritts einladen. Erst die Annahme verleiht die zugewiesenen Rechte; sie können wieder entzogen werden. Die Einladung gilt sieben Tage. Verkäuferverantwortung, andere Auftritte und Communitymoderation werden dadurch nicht übertragen.",
      "Yes. The responsible account can explicitly invite a verified account to help manage a particular organizer profile. Assigned rights take effect only after acceptance and can be revoked. The invitation is valid for seven days. It does not transfer seller responsibility, access to other profiles or community moderation rights.",
    ),
  ]),
];

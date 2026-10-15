import 'package:flutter/material.dart';

import 'app_language.dart';
import 'design_system.dart';

/// Editorial topics and name ideas are distinct from registered communities.
class CommunityTopics extends StatelessWidget {
  const CommunityTopics({super.key, this.query = ''});
  final String query;

  @override
  Widget build(BuildContext context) {
    final palette = AushangPalette.of(context);
    final groups = [
      for (final group in _groups)
        (group, group.topics.where((topic) => topic.matches(query)).toList()),
    ];
    final count = groups.fold<int>(0, (sum, group) => sum + group.$2.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          headingLevel: 2,
          child: Text(
            localText(
              context,
              'Themen & Veranstaltungstypen',
              'Topics & event types',
            ),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: AccessSpacing.s16),
        Text(
          localText(
            context,
            '48 Kategorien als Inspiration. Die Namensideen sind Beispiele, keine registrierten Communities. Eine Community kann mehrere Themen und Veranstaltungsformate verbinden.',
            '48 categories for inspiration. The name ideas are examples, not registered communities. A community can bring together several topics and event formats.',
          ),
          style: TextStyle(color: palette.muted, height: 1.6),
        ),
        const SizedBox(height: AccessSpacing.s24),
        if (query.isNotEmpty) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              count == 0
                  ? localText(
                      context,
                      'Keine passenden Themen. Versuche einen anderen Suchbegriff.',
                      'No matching topics. Try another search term.',
                    )
                  : localText(
                      context,
                      count == 1
                          ? '1 passendes Thema'
                          : '$count passende Themen',
                      count == 1
                          ? '1 matching topic'
                          : '$count matching topics',
                    ),
            ),
          ),
          const SizedBox(height: AccessSpacing.s24),
        ],
        for (final (group, topics) in groups)
          if (topics.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.only(top: AccessSpacing.s20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: palette.ink)),
              ),
              child: Semantics(
                headingLevel: 3,
                child: Text(
                  localText(context, group.de, group.en).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AccessSpacing.s20),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth >= 760 &&
                        !AccessLayout.largeText(context)
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - AccessSpacing.s20 * (columns - 1)) /
                    columns;
                return Wrap(
                  spacing: AccessSpacing.s20,
                  runSpacing: AccessSpacing.s20,
                  children: [
                    for (final topic in topics)
                      SizedBox(
                        width: width,
                        child: Container(
                          padding: const EdgeInsets.all(AccessSpacing.s20),
                          decoration: BoxDecoration(
                            border: Border.all(color: palette.hair),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Semantics(
                                headingLevel: 4,
                                child: Text(
                                  localText(context, topic.de, topic.en),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AccessSpacing.s12),
                              Text(
                                localText(
                                  context,
                                  topic.eventsDe,
                                  topic.eventsEn,
                                ),
                                style: TextStyle(
                                  color: palette.muted,
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: AccessSpacing.s16),
                              Text(
                                localText(
                                  context,
                                  'Namensidee: ${topic.name}',
                                  'Name idea: ${topic.name}',
                                ),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: palette.muted,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AccessSpacing.s40),
          ],
      ],
    );
  }
}

class _Topic {
  const _Topic(this.de, this.en, this.name, this.eventsDe, this.eventsEn);
  final String de, en, name, eventsDe, eventsEn;
  bool matches(String query) => [
    de,
    en,
    name,
    eventsDe,
    eventsEn,
  ].join(' ').toLowerCase().contains(query);
}

class _TopicGroup {
  const _TopicGroup(this.de, this.en, this.topics);
  final String de, en;
  final List<_Topic> topics;
}

const _groups = [
  _TopicGroup("Musik & Nachtleben", "Music & nightlife", [
    _Topic(
      "Clubkultur & elektronische Musik",
      "Clubbing & electronic music",
      "Nachtschicht",
      "Clubnächte, DJ-Sets, Listening Sessions",
      "Club nights, DJ sets, listening sessions",
    ),
    _Topic(
      "Rave & Underground",
      "Rave & underground",
      "Freifrequenz",
      "Kollektivnächte, Warehouse-Events, Open-Air-Raves",
      "Collective nights, warehouse events, open-air raves",
    ),
    _Topic(
      "Live-Musik & Bands",
      "Live music & bands",
      "Bühnenkontakt",
      "Konzerte, Release-Shows, Bandabende",
      "Concerts, release shows, band nights",
    ),
    _Topic(
      "Jazz & Improvisation",
      "Jazz & improvisation",
      "Offbeat",
      "Jazzabende, Jam Sessions, Impro-Konzerte",
      "Jazz nights, jam sessions, improvised concerts",
    ),
    _Topic(
      "Hip-Hop & Urban Culture",
      "Hip-hop & urban culture",
      "Cypher Circle",
      "Rap-Shows, Beat Sessions, Freestyle-Battles",
      "Rap shows, beat sessions, freestyle battles",
    ),
    _Topic(
      "Punk, Metal & alternative Musik",
      "Punk, metal & alternative music",
      "Gegenstrom",
      "Underground-Konzerte, DIY-Shows, Szeneabende",
      "Underground concerts, DIY shows, scene nights",
    ),
    _Topic(
      "Klassik & zeitgenössische Musik",
      "Classical & contemporary music",
      "Klangraum",
      "Kammerkonzerte, Neue Musik, Gesprächskonzerte",
      "Chamber concerts, new music, concert talks",
    ),
    _Topic(
      "Ambient & experimentelle Musik",
      "Ambient & experimental music",
      "Zwischenfrequenz",
      "Sound Art, Klangperformances, Hörsessions",
      "Sound art, sonic performances, listening sessions",
    ),
    _Topic(
      "Festivals & Kulturwochen",
      "Festivals & cultural programmes",
      "Freifeld",
      "Kleine Festivals, Kulturwochenenden, Mehrspartenprogramme",
      "Small festivals, cultural weekends, multidisciplinary programmes",
    ),
  ]),
  _TopicGroup("Kunst & Kultur", "Arts & culture", [
    _Topic(
      "Film & unabhängiges Kino",
      "Film & independent cinema",
      "Bildwechsel",
      "Screenings, Kurzfilmabende, Filmgespräche",
      "Screenings, short-film nights, film discussions",
    ),
    _Topic(
      "Dokumentarfilm & Debatte",
      "Documentaries & debate",
      "Blickpunkt",
      "Dokumentarfilmvorführungen, Diskussionen, Themenabende",
      "Documentary screenings, discussions, themed evenings",
    ),
    _Topic(
      "Theater & Performance",
      "Theatre & performance",
      "Spielraum",
      "Theaterabende, Performancekunst, szenische Lesungen",
      "Theatre nights, performance art, staged readings",
    ),
    _Topic(
      "Comedy & Improvisation",
      "Comedy & improvisation",
      "Lachlabor",
      "Stand-up, Improtheater, Comedy Open Mics",
      "Stand-up, improv theatre, comedy open mics",
    ),
    _Topic(
      "Literatur & Poetry",
      "Literature & poetry",
      "Wortwechsel",
      "Lesungen, Poetry Slams, Schreibabende",
      "Readings, poetry slams, writing evenings",
    ),
    _Topic(
      "Bildende Kunst & Ausstellungen",
      "Visual art & exhibitions",
      "Offene Fläche",
      "Vernissagen, Ausstellungen, Atelierbesuche",
      "Exhibition openings, exhibitions, studio visits",
    ),
    _Topic(
      "Fotografie",
      "Photography",
      "Kontaktbogen",
      "Fotoausstellungen, Fotowalks, Bildbesprechungen",
      "Photo exhibitions, photo walks, image discussions",
    ),
    _Topic(
      "Design, Architektur & Mode",
      "Design, architecture & fashion",
      "Formwechsel",
      "Design Talks, Architekturführungen, Modenschauen",
      "Design talks, architecture tours, fashion shows",
    ),
    _Topic(
      "Digitale Kunst & Medienkunst",
      "Digital & media art",
      "Pixelraum",
      "AV-Performances, Installationen, Creative-Coding-Shows",
      "AV performances, installations, creative-coding shows",
    ),
  ]),
  _TopicGroup(
    "Kreativsein, Tanz & queere Kultur",
    "Making, dance & queer culture",
    [
      _Topic(
        "Kreatives Handwerk & DIY",
        "Creative crafts & DIY",
        "Werkraum",
        "Keramik, Siebdruck, Nähen, Schmuckworkshops",
        "Ceramics, screen printing, sewing, jewellery workshops",
      ),
      _Topic(
        "Tanz & Social Dance",
        "Dance & social dance",
        "Tanzverbindung",
        "Salsa, Bachata, Swing, Tango, Tanzabende",
        "Salsa, bachata, swing, tango, social dance nights",
      ),
      _Topic(
        "Zeitgenössischer Tanz & Bewegung",
        "Contemporary dance & movement",
        "Körperraum",
        "Tanzworkshops, Contact Improvisation, Bewegungsjam",
        "Dance workshops, contact improvisation, movement jams",
      ),
      _Topic(
        "Queere Kunst & Nachtkultur",
        "Queer art & nightlife",
        "Queer Frequenz",
        "Queere Clubnächte, Kulturabende, Performances",
        "Queer club nights, cultural evenings, performances",
      ),
      _Topic(
        "Drag & Cabaret",
        "Drag & cabaret",
        "Glitzerbühne",
        "Drag-Shows, Cabaret, Variety-Abende",
        "Drag shows, cabaret, variety nights",
      ),
      _Topic(
        "Ballroom & Vogue",
        "Ballroom & vogue",
        "House Lights",
        "Balls, Vogue Sessions, Workshops",
        "Balls, vogue sessions, workshops",
      ),
    ],
  ),
  _TopicGroup("Begegnung & Gesellschaft", "People & society", [
    _Topic(
      "Interkultureller Austausch",
      "Intercultural exchange",
      "Zwischenwelten",
      "Kulturabende, gemeinsame Feste, Begegnungen",
      "Cultural evenings, shared celebrations, meetups",
    ),
    _Topic(
      "Sprachen & internationale Begegnung",
      "Languages & international meetups",
      "Sprachsalon",
      "Sprachtandems, Sprachcafés, internationale Stammtische",
      "Language tandems, language cafés, international meetups",
    ),
    _Topic(
      "Nachbarschaft & Stadtteilkultur",
      "Neighbourhood & local culture",
      "Nebenan Zusammen",
      "Stadtteilfeste, Hofkonzerte, Nachbarschaftstreffen",
      "Neighbourhood festivals, courtyard concerts, local meetups",
    ),
    _Topic(
      "Familien & Generationen",
      "Families & generations",
      "Generationenplatz",
      "Familienkultur, Mitmachaktionen, generationenübergreifende Treffen",
      "Family culture, participatory activities, intergenerational meetups",
    ),
    _Topic(
      "Ehrenamt & gesellschaftliches Engagement",
      "Volunteering & civic engagement",
      "Gemeinsam Wirken",
      "Kennenlerntreffen, Aktionstage, Benefizveranstaltungen",
      "Introductory meetups, action days, benefit events",
    ),
    _Topic(
      "Nachhaltigkeit & solidarisches Leben",
      "Sustainability & solidarity",
      "Zukunftswerk",
      "Kleidertausch, Repair Cafés, Nachhaltigkeitsworkshops",
      "Clothing swaps, repair cafés, sustainability workshops",
    ),
    _Topic(
      "Politik, Demokratie & Diskussion",
      "Politics, democracy & discussion",
      "Offenes Forum",
      "Podiumsgespräche, politische Bildung, Diskussionsabende",
      "Panel talks, civic education, discussion evenings",
    ),
  ]),
  _TopicGroup("Wissen & Arbeit", "Knowledge & work", [
    _Topic(
      "Wissenschaft & Wissensaustausch",
      "Science & knowledge sharing",
      "Denkraum",
      "Science Talks, Vorträge, öffentliche Forschungsabende",
      "Science talks, lectures, public research evenings",
    ),
    _Topic(
      "Technologie & Programmierung",
      "Technology & programming",
      "Code & Kaffee",
      "Entwicklermeetups, Hackathons, Technikvorträge",
      "Developer meetups, hackathons, technology talks",
    ),
    _Topic(
      "Maker & offene Werkstätten",
      "Makers & open workshops",
      "Machbar",
      "FabLab-Abende, Elektronikworkshops, gemeinsame Bauprojekte",
      "FabLab evenings, electronics workshops, shared building projects",
    ),
    _Topic(
      "Beruflicher Austausch & Gründung",
      "Professional exchange & entrepreneurship",
      "Ideenknoten",
      "Branchentreffen, Gründerabende, Netzwerkveranstaltungen",
      "Industry meetups, startup evenings, networking events",
    ),
    _Topic(
      "Kreativwirtschaft & freie Berufe",
      "Creative industries & freelancers",
      "Freiraum Netzwerk",
      "Portfolioabende, Projekttreffen, Austausch für Selbstständige",
      "Portfolio nights, project meetups, freelancer exchanges",
    ),
  ]),
  _TopicGroup("Spielen & Genuss", "Games & food", [
    _Topic(
      "Brettspiele & Gesellschaftsspiele",
      "Board & tabletop games",
      "Spielrunde",
      "Spieleabende, Kennenlernrunden, Turniere",
      "Game nights, introductory sessions, tournaments",
    ),
    _Topic(
      "Pen & Paper, LARP & Fantasy",
      "Tabletop roleplaying, LARP & fantasy",
      "Weltenzirkel",
      "Rollenspielrunden, LARP-Treffen, Erzählworkshops",
      "Roleplaying sessions, LARP meetups, storytelling workshops",
    ),
    _Topic(
      "Gaming & E-Sport",
      "Gaming & esports",
      "Local Lobby",
      "LAN-Partys, Communityturniere, Gaming-Abende",
      "LAN parties, community tournaments, gaming nights",
    ),
    _Topic(
      "Essen & gemeinsames Kochen",
      "Food & cooking together",
      "Lange Tafel",
      "Kochabende, Supper Clubs, gemeinsame Essen",
      "Cooking evenings, supper clubs, shared meals",
    ),
    _Topic(
      "Kaffee, Tee & Genusskultur",
      "Coffee, tea & tasting culture",
      "Geschmacksrunde",
      "Verkostungen, Barista-Workshops, Teerunden",
      "Tastings, barista workshops, tea gatherings",
    ),
    _Topic(
      "Märkte, Vintage & lokale Produkte",
      "Markets, vintage & local products",
      "Fundstücke",
      "Flohmärkte, Designmärkte, Tauschbörsen, Pop-ups",
      "Flea markets, design markets, swaps, pop-ups",
    ),
  ]),
  _TopicGroup("Bewegung & Draußen", "Movement & outdoors", [
    _Topic(
      "Freizeit- & Teamsport",
      "Recreational & team sports",
      "Zusammenspiel",
      "Offene Trainings, Freizeitturniere, Sporttreffen",
      "Open training, recreational tournaments, sports meetups",
    ),
    _Topic(
      "Laufen & urbane Bewegung",
      "Running & urban movement",
      "Stadttempo",
      "Lauftreffs, gemeinsame Trainings, Community Runs",
      "Running groups, shared training, community runs",
    ),
    _Topic(
      "Radfahren & Mobilität",
      "Cycling & mobility",
      "Freilauf",
      "Gruppenausfahrten, Radwerkstätten, Mobilitätsaktionen",
      "Group rides, bicycle workshops, mobility events",
    ),
    _Topic(
      "Natur, Wandern & Outdoor",
      "Nature, hiking & outdoors",
      "Draußen Zusammen",
      "Wanderungen, Naturführungen, Outdoor-Treffen",
      "Hikes, nature tours, outdoor meetups",
    ),
    _Topic(
      "Yoga, Achtsamkeit & Entspannung",
      "Yoga, mindfulness & relaxation",
      "Ruhepol",
      "Yogastunden, Meditation, Atem- und Entspannungsworkshops",
      "Yoga sessions, meditation, breathing and relaxation workshops",
    ),
    _Topic(
      "Reisen & regionale Entdeckung",
      "Travel & local discovery",
      "Horizontkreis",
      "Reisevorträge, Stadtführungen, gemeinsame Ausflüge",
      "Travel talks, city tours, shared excursions",
    ),
  ]),
];

import 'package:ca_design/ca_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Beispiel-App mit den vier Zielen. Alle Inhalte sind synthetisch.
const _wald = AssetImage('assets/wald.png');
const _klang = AssetImage('assets/klang.png');

class DemoApp extends StatefulWidget {
  const DemoApp({super.key, this.tab = 0, this.dark = false});
  final int tab;
  final bool dark;

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  late int _tab = widget.tab;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CaTheme.light(),
      darkTheme: CaTheme.dark(),
      themeMode: widget.dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: switch (_tab) {
          0 => const ProgrammScreen(),
          1 => const MerklisteScreen(),
          2 => const ZugangScreen(),
          _ => const KontoScreen(),
        },
        bottomNavigationBar: CaNavBar(
          currentIndex: _tab,
          onSelect: (i) => setState(() => _tab = i),
          items: const [
            CaNavItem('Programm', Icons.calendar_today_outlined,
                Icons.calendar_today),
            CaNavItem('Merkliste', Icons.bookmark_border, Icons.bookmark),
            CaNavItem('Mein Zugang', Icons.door_front_door_outlined,
                Icons.door_front_door,
                badge: 1),
            CaNavItem(
                'Konto', Icons.account_circle_outlined, Icons.account_circle),
          ],
        ),
      ),
    );
  }
}

class ProgrammScreen extends StatefulWidget {
  const ProgrammScreen({super.key});

  @override
  State<ProgrammScreen> createState() => _ProgrammScreenState();
}

class _ProgrammScreenState extends State<ProgrammScreen> {
  String _view = 'events';
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    void open() => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const EventScreen()));
    return CaLargeTitlePage(
      actions: [
        IconButton(
            tooltip: 'Suchen', icon: const Icon(Icons.search), onPressed: () {})
      ],
      onRefresh: () async {},
      header: Padding(
        padding: const EdgeInsets.only(top: CaSpace.s2),
        child: CaSegments<String>(
          segments: const {
            'events': 'Events',
            'orte': 'Orte',
            'veranstalter': 'Veranstalter'
          },
          value: _view,
          onChanged: (v) => setState(() => _view = v),
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Column(children: [
            const SizedBox(height: CaSpace.s3),
            GestureDetector(
              onTap: open,
              child: const PosterCarousel(height: 380, slides: [
                PosterSlide(
                    title: 'Waldfunk',
                    date: '21.11.',
                    image: _wald,
                    imageNote: 'Synthetisches Bild'),
                PosterSlide(title: 'Offenes Zeichnen', date: '20.11.'),
              ]),
            ),
            PosterInfo(
              when: 'Samstag, ab 22 Uhr',
              host: 'Tiefschlaf Soundsystem',
              access: CaAccess.semi,
              lockText: 'Ort nach Zusage',
              action: CaButton(
                  label: 'Interesse bekunden',
                  icon: Icons.arrow_forward,
                  expand: true,
                  onPressed: open),
              save: CaSaveButton(
                  saved: _saved,
                  eventTitle: 'Waldfunk',
                  onChanged: (v) => setState(() => _saved = v)),
            ),
          ]),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              CaSpace.gutter, CaSpace.s7, CaSpace.gutter, CaSpace.s7),
          sliver: SliverList.list(children: [
            Text('NOVEMBER', style: CaType.section),
            const SizedBox(height: CaSpace.s3),
            EventRow(
                title: 'Nacht der Klanglandschaften',
                when: 'Sa 14.11. · 19:00',
                access: CaAccess.semi,
                image: _klang,
                placeLocked: true,
                saved: true,
                onSaved: (_) {},
                onTap: open),
            EventRow(
                title: 'Lesung im Treppenhaus',
                when: 'Sa 28.11. · 19:00',
                access: CaAccess.public,
                place: 'Morgenraum',
                saved: false,
                onSaved: (_) {},
                onTap: open),
          ]),
        ),
      ],
    );
  }
}

class EventScreen extends StatelessWidget {
  const EventScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = CaColors.of(context);
    return CaPageWidth(
        child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // Helle Symbole in der Statusleiste über dem Plakat.
        systemOverlayStyle: SystemUiOverlayStyle.light,
        backgroundColor: Colors.transparent,
        foregroundColor: CaPrimitive.white,
        shape: const Border(),
        actions: [
          IconButton(
              tooltip: 'Teilen',
              icon: Icon(Icons.adaptive.share),
              onPressed: () {}),
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Mehr',
              icon: Icon(Icons.adaptive.more),
              onPressed: () =>
                  showCaActions(context, title: 'Waldfunk', actions: [
                CaAction('In den Kalender',
                    icon: Icons.event_outlined, onTap: () {}),
                CaAction('Teilen', icon: Icons.adaptive.share, onTap: () {}),
                CaAction('Veranstalter ansehen',
                    icon: Icons.groups_outlined, onTap: () {}),
                CaAction('Event melden',
                    icon: Icons.flag_outlined, onTap: () {}),
              ]),
            ),
          ),
        ],
      ),
      body: ListView(padding: EdgeInsets.zero, children: [
        const PosterHero(
            height: 420,
            slide:
                PosterSlide(title: 'Waldfunk', date: '21.11.', image: _wald)),
        Padding(
          padding: const EdgeInsets.all(CaSpace.gutter),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Samstag, ab 22 Uhr',
                style: CaType.meta.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: CaSpace.s1),
            Text('Tiefschlaf Soundsystem', style: CaType.lead),
            const SizedBox(height: CaSpace.s3),
            const Wrap(spacing: CaSpace.s4, children: [
              AccessMark(CaAccess.semi),
              LockLabel('Ort nach Zusage')
            ]),
            const SizedBox(height: CaSpace.s5),
            Text(
                'Eine Nacht mit Bässen zwischen Bäumen. Wer Interesse bekundet, beantwortet zwei Fragen; '
                'das Kollektiv entscheidet von Hand.',
                style: CaType.body.copyWith(color: c.textSecondary)),
            const SizedBox(height: CaSpace.s5),
            const EmbossedLock(label: 'Genauer Ort', fill: true),
          ]),
        ),
      ]),
      bottomNavigationBar: CaBottomAction(
        child: Row(children: [
          Expanded(
              child: CaButton(
                  label: 'Interesse bekunden',
                  icon: Icons.arrow_forward,
                  expand: true,
                  onPressed: () {})),
          const SizedBox(width: CaSpace.s2),
          CaSaveButton(saved: false, eventTitle: 'Waldfunk', onChanged: (_) {}),
        ]),
      ),
    ));
  }
}

class MerklisteScreen extends StatefulWidget {
  const MerklisteScreen({super.key});

  @override
  State<MerklisteScreen> createState() => _MerklisteScreenState();
}

class _MerklisteScreenState extends State<MerklisteScreen> {
  final _items = [
    'Nacht der Klanglandschaften',
    'Lesung im Treppenhaus',
    'Druckmarkt im Hinterhof'
  ];

  @override
  Widget build(BuildContext context) {
    return CaLargeTitlePage(
      title: 'Merkliste',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CaSpace.gutter),
          sliver: SliverList.list(children: [
            for (final (i, t) in _items.indexed)
              CaSwipeToRemove(
                id: t,
                onRemove: () {
                  setState(() => _items.remove(t));
                  showCaToast(context, 'Aus der Merkliste entfernt',
                      actionLabel: 'Rückgängig',
                      onAction: () => setState(() => _items.insert(i, t)));
                },
                child: EventRow(
                  title: t,
                  when: [
                    'Sa 14.11. · 19:00',
                    'Sa 28.11. · 19:00',
                    'So 22.11. · 12:00'
                  ][i % 3],
                  access: i == 0 ? CaAccess.semi : CaAccess.public,
                  image: i == 0 ? _klang : null,
                  placeLocked: i == 0,
                  place: i == 0 ? null : 'Morgenraum',
                ),
              ),
          ]),
        ),
      ],
    );
  }
}

class ZugangScreen extends StatelessWidget {
  const ZugangScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CaLargeTitlePage(
      title: 'Mein Zugang',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(CaSpace.gutter),
          sliver: SliverList.list(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child:
                      Text('NACHT DER KLANGLANDSCHAFTEN', style: CaType.title)),
              const SizedBox(width: CaSpace.s3),
              const Stamp(label: 'Zugesagt', icon: Icons.check),
            ]),
            const SizedBox(height: CaSpace.s5),
            const DoorList(steps: [
              DoorStep('Zugesagt von Morgenraum',
                  detail: '06.10., von Hand', state: DoorState.done),
              DoorStep('Ort folgt',
                  detail: 'Sa 14.11., 19:00', state: DoorState.now),
            ]),
            const SizedBox(height: CaSpace.s4),
            const EmbossedLock(label: 'Genauer Ort', fill: true),
          ]),
        ),
      ],
    );
  }
}

class KontoScreen extends StatelessWidget {
  const KontoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CaLargeTitlePage(
      title: 'Konto',
      slivers: [
        SliverList.list(children: [
          CaSettingsSection(header: 'Für dich', items: [
            CaSettingsItem('Meine Interessen', icon: Icons.tune, onTap: () {}),
            CaSettingsItem('Benachrichtigungen',
                value: 'Zusagen und Orte',
                icon: Icons.notifications_none,
                onTap: () {}),
          ]),
          CaSettingsSection(header: 'App', items: [
            // Öffnet die Spracheinstellung der App im System (iOS 13+, Android 13+).
            CaSettingsItem('Sprache',
                value: 'Deutsch', icon: Icons.language, onTap: () {}),
            CaSettingsItem('Darstellung',
                value: 'System', icon: Icons.contrast, onTap: () {}),
          ]),
          CaSettingsSection(header: 'Hilfe und Rechtliches', items: [
            CaSettingsItem('So funktioniert’s',
                icon: Icons.help_outline, onTap: () {}),
            CaSettingsItem('Hilfe und Kontakt',
                icon: Icons.mail_outline, onTap: () {}),
            CaSettingsItem('Impressum und Datenschutz',
                icon: Icons.policy_outlined, onTap: () {}),
          ]),
          Padding(
            padding: const EdgeInsets.all(CaSpace.gutter),
            child: CaButton(
                label: 'Abmelden',
                kind: CaButtonKind.outline,
                expand: true,
                onPressed: () {}),
          ),
        ]),
      ],
    );
  }
}

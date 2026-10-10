import 'package:ca_design/ca_design.dart';
import 'package:flutter/material.dart';

// Bausteinübersicht. Alle Inhalte sind synthetisch.
void main() => runApp(const Gallery());

class Gallery extends StatefulWidget {
  const Gallery({super.key});

  @override
  State<Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> {
  ThemeMode _mode = ThemeMode.system;
  int _tab = 0;
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aushang 3',
      debugShowCheckedModeBanner: false,
      theme: CaTheme.light(),
      darkTheme: CaTheme.dark(),
      themeMode: _mode,
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const CaLogo(),
            actions: [
              IconButton(
                tooltip: 'Darstellung wechseln',
                icon: const Icon(Icons.contrast),
                onPressed: () => setState(() => _mode =
                    Theme.of(context).brightness == Brightness.dark
                        ? ThemeMode.light
                        : ThemeMode.dark),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: CaSpace.s8),
            children: [
              const PosterCarousel(slides: [
                PosterSlide(
                    title: 'Waldfunk',
                    date: '21.11.',
                    image: AssetImage('assets/wald.png'),
                    imageNote: 'Synthetisches Bild'),
                PosterSlide(title: 'Offenes Zeichnen', date: '20.11.'),
              ]),
              PosterInfo(
                when: 'Samstag, ab 22 Uhr',
                host: 'Tiefschlaf Soundsystem',
                access: CaAccess.semi,
                lockText: 'Ort nach Zusage',
                action: CaButton(
                    label: 'Interesse bekunden',
                    icon: Icons.arrow_forward,
                    expand: true,
                    onPressed: () {}),
                save: CaSaveButton(
                  saved: _saved,
                  eventTitle: 'Waldfunk',
                  onChanged: (v) {
                    setState(() => _saved = v);
                    showCaToast(context, v ? 'Gemerkt' : 'Nicht mehr gemerkt',
                        actionLabel: 'Rückgängig',
                        onAction: () => setState(() => _saved = !v));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(CaSpace.gutter),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: CaSpace.s7),
                      Text('FÜR DICH', style: CaType.section),
                      const SizedBox(height: CaSpace.s3),
                      EventRow(
                        title: 'Nacht der Klanglandschaften',
                        image: const AssetImage('assets/klang.png'),
                        when: 'Sa 14.11. · 19:00',
                        access: CaAccess.semi,
                        placeLocked: true,
                        reason: 'Du folgst Morgenraum',
                        saved: true,
                        onSaved: (_) {},
                        onTap: () {},
                      ),
                      EventRow(
                        title: 'Lesung im Treppenhaus',
                        when: 'Sa 28.11. · 19:00',
                        access: CaAccess.public,
                        place: 'Morgenraum',
                        saved: false,
                        onSaved: (_) {},
                        onTap: () {},
                      ),
                      const SizedBox(height: CaSpace.s7),
                      Text('DEIN ZUGANG', style: CaType.section),
                      const SizedBox(height: CaSpace.s4),
                      const DoorList(steps: [
                        DoorStep('Zugesagt von Morgenraum',
                            detail: '06.10., von Hand', state: DoorState.done),
                        DoorStep('Ort folgt',
                            detail: 'Sa 14.11., 19:00', state: DoorState.now),
                      ]),
                      const SizedBox(height: CaSpace.s4),
                      const EmbossedLock(label: 'Genauer Ort', fill: true),
                      const SizedBox(height: CaSpace.s5),
                      const Wrap(
                          spacing: CaSpace.s5,
                          runSpacing: CaSpace.s4,
                          children: [
                            Stamp(
                                label: 'Zugesagt',
                                icon: Icons.check,
                                animate: true),
                            Stamp(label: 'Abgesagt', yes: false),
                          ]),
                      const SizedBox(height: CaSpace.s7),
                      const CaNote(
                        kind: CaNoteKind.decision,
                        icon: Icons.schedule,
                        title: 'Zwei Anfragen warten auf deine Entscheidung.',
                      ),
                      const SizedBox(height: CaSpace.s4),
                      CaNote(
                        kind: CaNoteKind.error,
                        icon: Icons.error_outline,
                        title: 'Das Programm lädt gerade nicht.',
                        text: 'Deine Merkliste und Zusagen sind sicher.',
                        action: CaButton(
                            label: 'Erneut versuchen',
                            kind: CaButtonKind.outline,
                            small: true,
                            icon: Icons.refresh,
                            onPressed: () {}),
                      ),
                      const SizedBox(height: CaSpace.s4),
                      const CaOfflineBar(
                          text: 'Offline. Du siehst den Stand von 18:40.'),
                      const SizedBox(height: CaSpace.s4),
                      const Row(children: [
                        CaSkeleton(width: 88, height: 88),
                        SizedBox(width: CaSpace.s4),
                        Expanded(child: CaSkeleton(height: 26)),
                      ]),
                      CaEmpty(
                        icon: Icons.bookmark_border,
                        title: 'Noch nichts gemerkt.',
                        text: 'Tippe bei einem Event auf das Lesezeichen.',
                        action: CaButton(
                            label: 'Zum Programm',
                            kind: CaButtonKind.neutral,
                            icon: Icons.arrow_forward,
                            onPressed: () {}),
                      ),
                    ]),
              ),
            ],
          ),
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
      ),
    );
  }
}

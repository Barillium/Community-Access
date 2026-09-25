import 'package:flutter/material.dart';

import 'demo_status.dart';

void main() => runApp(const CommunityAccessApp());

class CommunityAccessApp extends StatelessWidget {
  const CommunityAccessApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Community Access · Demo',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF35594A),
    ),
    home: const DemoPage(),
  );
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  DemoStatus status = DemoStatus.applicationPending;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Community Access')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lokale Demo · ausschließlich erfundene Daten'),
                const SizedBox(height: 24),
                Text(
                  'Kollektiv Wolkenwinkel',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text('Von der Bewerbung zur separaten Eventbestätigung.'),
                const SizedBox(height: 24),
                const Text('Demozustand auswählen'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final value in DemoStatus.values)
                      ChoiceChip(
                        label: Text(value.label),
                        selected: status == value,
                        onSelected: (_) => setState(() => status = value),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Die Auswahl zeigt nur ein Beispiel. Sie ändert keine Mitgliedschaft und erteilt keine Zusage.',
                ),
                const SizedBox(height: 24),
                Semantics(
                  liveRegion: true,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              status.label,
                              key: const Key('current-status'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(status.description),
                            const SizedBox(height: 16),
                            Text(
                              status.hasEventConfirmation
                                  ? 'Eventzusage im Beispiel vorhanden'
                                  : 'Keine Eventzusage',
                              key: const Key('event-confirmation'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Mitgliedschaft ist keine Eventbestätigung.'),
                const SizedBox(height: 8),
                const Text(
                  'Keine Anmeldung, Speicherung oder Verbindung zu einem Backend.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

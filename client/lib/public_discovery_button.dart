import 'package:flutter/material.dart';

import 'public_discovery_stub.dart'
    if (dart.library.js_interop) 'public_discovery_web.dart';

class PublicDiscoveryButton extends StatelessWidget {
  const PublicDiscoveryButton({super.key});
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () {
      if (!openPublicDiscovery()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Der öffentliche Bereich ist während der Backend-Umstellung noch nicht verfügbar.',
            ),
          ),
        );
      }
    },
    child: const Text('Öffentliche Events entdecken'),
  );
}

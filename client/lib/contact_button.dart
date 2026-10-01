import 'package:flutter/material.dart';

import 'contact_link_stub.dart'
    if (dart.library.js_interop) 'contact_link_web.dart';

bool isSyntheticContact(String? value) {
  if (value == null) return false;
  if (RegExp(r'^mailto:[a-zA-Z0-9._+\-]+@example\.invalid$').hasMatch(value)) {
    return true;
  }
  final url = Uri.tryParse(value);
  return url != null &&
      url.scheme == 'https' &&
      url.host == 'example.invalid' &&
      url.userInfo.isEmpty &&
      !url.hasPort;
}

class ContactButton extends StatelessWidget {
  final String? contact;
  const ContactButton({super.key, required this.contact});
  @override
  Widget build(BuildContext context) {
    if (!isSyntheticContact(contact)) {
      return const Text(
        'Es ist noch kein Kontaktweg hinterlegt. Nutze deinen bestehenden Kontakt zu den Gastgebern.',
        style: TextStyle(height: 1.6),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: () async {
            final opened = await openContact(contact!);
            if (!opened && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Kopiere den unten angegebenen Kontaktweg.'),
                ),
              );
            }
          },
          child: const Text('Gastgeber kontaktieren'),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Kontaktweg: $contact',
          excludeSemantics: true,
          child: SelectableText(
            contact!,
            style: const TextStyle(
              fontSize: 12,
              height: 1.6,
              color: Color(0xFF55514F),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import 'design_system.dart';

import 'access_api.dart';
import 'product_scope.dart';
import 'directory_api.dart';
import 'directory_pages.dart';
import 'event_editorial_view.dart';
import 'bookmark_views.dart';

class VisibilityPreviewPage extends StatefulWidget {
  final DirectoryApi api;
  final String eventId;
  const VisibilityPreviewPage({
    super.key,
    required this.api,
    required this.eventId,
  });
  @override
  State<VisibilityPreviewPage> createState() => _VisibilityPreviewPageState();
}

class _VisibilityPreviewPageState extends State<VisibilityPreviewPage> {
  String _audience = 'anonymous';
  Map<String, dynamic>? _data;
  String? _notice;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _data = null;
      _notice = null;
    });
    try {
      final data = await widget.api.directory(
        'manage/preview',
        body: {'id': widget.eventId, 'audience': _audience},
      );
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) {
        setState(
          () => _notice = e is ApiFailure
              ? e.message
              : 'Die Vorschau konnte nicht geladen werden.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: accessAppBar(context, 'Wer sieht was?'),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        width: AccessPageWidth.detail,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Vorschau des gespeicherten Events. Die Auswahl simuliert Rechte und erteilt keine Freigabe.',
            ),
            const SizedBox(height: AccessSpacing.s24),
            AccessField(
              decoration: const InputDecoration(labelText: 'Ansicht als'),
              trailingWidth: AccessSpacing.s40,
              builder: (decoration) => DropdownButtonFormField<String>(
                initialValue: _audience,
                isExpanded: true,
                itemHeight: null,
                decoration: decoration,
                items: [
                  for (final entry in {
                    'anonymous': 'Ohne Anmeldung',
                    if (ProductScope.extended) 'profile': 'Nur Profilzugang',
                    if (ProductScope.extended)
                      'series': 'Profil- und Reihenfreigabe',
                    'event': 'Einzelne Eventfreigabe',
                    'member': 'Aktive Communitymitgliedschaft',
                    'confirmed': 'Eventfreigabe und bestätigte Teilnahme',
                  }.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: AccessOptionText(entry.value),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        setState(() => _audience = value!);
                        _load();
                      },
              ),
            ),
            const SizedBox(height: AccessSpacing.s24),
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_notice != null) directoryNotice(_notice!),
            if (_data != null) ...[
              if (_data!['visible'] != true)
                const Text('Dieses Event erscheint in dieser Ansicht nicht.')
              else ...[
                EventEditorialView(
                  event: _data!,
                  interestControl: InterestCount(
                    count: _data!['interest_count'] as int?,
                  ),
                ),
              ],
              const SizedBox(height: AccessSpacing.s24),
              const Text(
                'Profil-, Reihen- und Eventfreigaben geben ausschließlich Sichtbarkeit. Eine Teilnahmezusage wird separat geprüft. Geschützte genaue Adressen werden ausschließlich über den eigenen Adressabruf ausgegeben.',
              ),
              if (_audience == 'confirmed')
                Padding(
                  padding: const EdgeInsets.only(top: AccessSpacing.s12),
                  child: Text(
                    _data!['exact_location_available'] == true
                        ? 'Die geschützte genaue Adresse wäre mit diesen Rechten jetzt abrufbar. Die Vorschau zeigt die Adresse selbst nicht.'
                        : 'Die geschützte genaue Adresse ist mit diesen Rechten derzeit nicht abrufbar.',
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

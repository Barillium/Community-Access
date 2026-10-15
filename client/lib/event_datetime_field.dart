import 'package:flutter/material.dart';

import 'design_system.dart';
import 'app_language.dart';

DateTime? eventDate(String? value) =>
    value == null || value.isEmpty || value.startsWith('input:')
    ? null
    : DateTime.tryParse(value)?.toLocal();

String eventDateLabel(String? value) {
  final date = eventDate(value);
  if (date == null) return 'Noch kein Termin';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year}, ${two(date.hour)}:${two(date.minute)}';
}

/// Keeps the API timestamp separate from the human-readable local input.
class EventDateTimeField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final String? errorText;
  final String? helperText;
  const EventDateTimeField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.errorText,
    this.helperText,
  });
  @override
  State<EventDateTimeField> createState() => _EventDateTimeFieldState();
}

class _EventDateTimeFieldState extends State<EventDateTimeField> {
  final _date = TextEditingController(), _time = TextEditingController();
  bool _updating = false;
  String two(int n) => n.toString().padLeft(2, '0');
  @override
  void initState() {
    super.initState();
    _read();
    widget.controller.addListener(_read);
  }

  void _read() {
    if (_updating) return;
    final raw = widget.controller.text;
    final date = eventDate(raw);
    if (raw.startsWith('input:')) {
      final parts = raw.substring(6).split('|');
      _date.text = parts.first;
      _time.text = parts.length > 1 ? parts[1] : '';
    } else {
      _date.text = date == null
          ? ''
          : '${two(date.day)}.${two(date.month)}.${date.year}';
      _time.text = date == null ? '' : '${two(date.hour)}:${two(date.minute)}';
    }
    if (mounted) setState(() {});
  }

  DateTime? _parsed() {
    final d = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$')
        .firstMatch(_date.text.trim());
    final t = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(_time.text.trim());
    if (d == null || t == null) return null;
    final day = int.parse(d[1]!),
        month = int.parse(d[2]!),
        year = int.parse(d[3]!);
    final hour = int.parse(t[1]!), minute = int.parse(t[2]!);
    if (year < 1900 || year > 2200 || hour > 23 || minute > 59) return null;
    final value = DateTime(year, month, day, hour, minute);
    // Also reject local wall-clock times skipped by daylight saving time.
    return value.year == year &&
            value.month == month &&
            value.day == day &&
            value.hour == hour &&
            value.minute == minute
        ? value
        : null;
  }

  void _write() {
    _updating = true;
    final value = _parsed();
    widget.controller.text = _date.text.isEmpty && _time.text.isEmpty
        ? ''
        : value?.toUtc().toIso8601String() ??
              'input:${_date.text}|${_time.text}';
    _updating = false;
    setState(() {});
  }

  Future<void> _pickDate() async {
    final current = eventDate(widget.controller.text) ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: current.year >= 1900 && current.year <= 2200
          ? current
          : DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
      helpText:
          '${localText(context, widget.label)}: ${localText(context, 'Datum', 'Date')}',
      cancelText: localText(context, 'Abbrechen', 'Cancel'),
      confirmText: localText(context, 'Übernehmen', 'Apply'),
      fieldLabelText: localText(context, 'Datum eingeben', 'Enter date'),
      fieldHintText: localText(context, 'TT.MM.JJJJ', 'MM/DD/YYYY'),
      errorFormatText: localText(
        context,
        'Bitte ein gültiges Datum eingeben.',
        'Please enter a valid date.',
      ),
      errorInvalidText: localText(
        context,
        'Bitte ein Datum im erlaubten Zeitraum wählen.',
        'Please choose a date within the allowed range.',
      ),
    );
    if (!mounted || selected == null) return;
    _date.text = '${two(selected.day)}.${two(selected.month)}.${selected.year}';
    if (_time.text.isEmpty) _time.text = '20:00';
    _write();
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        eventDate(widget.controller.text) ?? DateTime.now(),
      ),
      helpText: localText(context, 'Uhrzeit auswählen', 'Choose time'),
      cancelText: localText(context, 'Abbrechen', 'Cancel'),
      confirmText: localText(context, 'OK', 'Apply'),
      hourLabelText: localText(context, 'Stunde', 'Hour'),
      minuteLabelText: localText(context, 'Minute', 'Minute'),
      errorInvalidText: localText(context, 'Zeit ungültig.', 'Invalid time.'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (!mounted || selected == null) return;
    _time.text = '${two(selected.hour)}:${two(selected.minute)}';
    _write();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_read);
    _date.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _parsed();
    final invalid = widget.controller.text.startsWith('input:');
    final offset = value?.timeZoneOffset;
    final zone = offset == null
        ? ''
        : ' · UTC${offset.isNegative ? '-' : '+'}${two(offset.inMinutes.abs() ~/ 60)}:${two(offset.inMinutes.abs() % 60)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LocalText(
          widget.label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: AccessSpacing.s8),
        AccessColumns(
          minWidth: 520,
          children: [
            AccessField(
              decoration: InputDecoration(
                labelText:
                    '${localText(context, widget.label)}: ${localText(context, 'Datum', 'Date')}',
                hintText: localText(context, 'TT.MM.JJJJ', 'DD.MM.YYYY'),
              ),
              trailingWidth: AccessSpacing.s48,
              builder: (d) => TextField(
                controller: _date,
                enabled: widget.enabled,
                keyboardType: TextInputType.datetime,
                onChanged: (_) => _write(),
                decoration: d.copyWith(
                  suffixIcon: IconButton(
                    tooltip:
                        '${localText(context, 'Datum auswählen', 'Choose date')}: ${localText(context, widget.label)}',
                    onPressed: widget.enabled ? _pickDate : null,
                    icon: const AccessIcon(Icons.calendar_today_outlined),
                  ),
                ),
              ),
            ),
            AccessField(
              decoration: InputDecoration(
                labelText:
                    '${localText(context, widget.label)}: ${localText(context, 'Uhrzeit', 'Time')}',
                hintText: localText(context, 'HH:MM', 'HH:MM'),
              ),
              trailingWidth: AccessSpacing.s48,
              builder: (d) => TextField(
                controller: _time,
                enabled: widget.enabled,
                keyboardType: TextInputType.datetime,
                onChanged: (_) => _write(),
                decoration: d.copyWith(
                  suffixIcon: IconButton(
                    tooltip:
                        '${localText(context, 'Uhrzeit auswählen', 'Choose time')}: ${localText(context, widget.label)}',
                    onPressed: widget.enabled ? _pickTime : null,
                    icon: const AccessIcon(Icons.schedule),
                  ),
                ),
              ),
            ),
          ],
        ),
        Text(
          localText(
            context,
            'Zeitzone deines Geräts$zone. Sommer- und Winterzeit werden berücksichtigt.',
            'Your device’s time zone$zone. Daylight saving time is taken into account.',
          ),
        ),
        if (widget.helperText != null) LocalText(widget.helperText!),
        if (widget.errorText != null || invalid)
          Semantics(
            liveRegion: true,
            child: Text(
              widget.errorText == null
                  ? localText(
                      context,
                      'Bitte ein gültiges Datum und eine Uhrzeit eingeben.',
                      'Please enter a valid date and time.',
                    )
                  : localText(context, widget.errorText!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}

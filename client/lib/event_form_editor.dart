import 'package:flutter/material.dart';

import 'app_language.dart';
import 'directory_api.dart';
import 'access_api.dart';
import 'design_system.dart';

const safeQuestions = [
  'Was interessiert dich an unserem Programm?',
  'Welche Musik möchtest du hören?',
  'Welche Veranstaltungsformate interessieren dich?',
  'Hast du die Veranstaltungsregeln gelesen?',
  'What interests you about our programme?',
  'Which music would you like to hear?',
  'Which event formats interest you?',
  'Have you read the event rules?',
];
String? questionProblem(String value) => safeQuestions.contains(value.trim())
    ? null
    : 'Diese freie Frage ist nicht geprüft. Verwende eine Frage aus dem Fragenkatalog. Fragen nach Gesundheit, Religion, Politik, Sexualität, Ausweisen oder privaten Kontakten sind hier gesperrt.';

class EventFormEditor extends StatefulWidget {
  final DirectoryApi api;
  final String profileId;
  final Map<String, dynamic>? form;
  const EventFormEditor({
    super.key,
    required this.api,
    required this.profileId,
    this.form,
  });
  @override
  State<EventFormEditor> createState() => _EventFormEditorState();
}

class _EventFormEditorState extends State<EventFormEditor> {
  final title = TextEditingController();
  final questions = <TextEditingController>[];
  final keys = <String>[];
  final requiredFields = <bool>[];
  bool busy = false;
  String? notice;
  @override
  void initState() {
    super.initState();
    title.text = widget.form?['title'] as String? ?? '';
    title.addListener(changed);
    for (final f in widget.form?['fields'] as List? ?? []) {
      add(
        f['label'] as String,
        key: f['key'] as String,
        required: f['required'] == true,
      );
    }
    if (questions.isEmpty) add(safeQuestions.first);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  void add(String label, {String? key, bool required = true}) {
    final c = TextEditingController(text: label)..addListener(changed);
    questions.add(c);
    var next = 0;
    while (keys.contains('question_$next')) {
      next++;
    }
    keys.add(key ?? 'question_$next');
    requiredFields.add(required);
  }

  @override
  void dispose() {
    title.dispose();
    for (final c in questions) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await widget.api.directory(
        'manage/form',
        body: {
          'profile_id': widget.profileId,
          'title': title.text.trim(),
          'fields': [
            for (int i = 0; i < questions.length; i++)
              {
                'key': keys[i],
                'label': questions[i].text.trim(),
                'required': requiredFields[i],
              },
          ],
          if (widget.form != null) 'id': widget.form!['id'],
          if (widget.form != null) 'version': widget.form!['version'],
        },
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(
          () => notice = e is ApiFailure
              ? e.message
              : 'Das Formular konnte nicht gespeichert werden.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: accessAppBar(context, 'Formulare verwalten'),
    body: SingleChildScrollView(
      child: AccessPageFrame(
        title: 'Formulare verwalten',
        width: AccessPageWidth.form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LocalText(
              localText(
                context,
                'Der Fragenkatalog begrenzt die Datenerhebung. Freie oder unzulässige Fragen müssen entfernt werden, bevor du das Formular bestätigen kannst. Keine sensiblen Angaben in Antworten verlangen.',
                'The question catalogue limits data collection. Remove unreviewed or prohibited questions before confirming the form. Do not request sensitive information in answers.',
              ),
            ),
            if (notice != null) LocalText(notice!),
            const SizedBox(height: AccessSpacing.s24),
            AccessField(
              decoration: InputDecoration(
                labelText: localText(context, 'Formulartitel'),
              ),
              builder: (d) => TextField(
                controller: title,
                enabled: !busy,
                maxLength: 120,
                decoration: d,
              ),
            ),
            for (int i = 0; i < questions.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: AccessSpacing.s24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AccessField(
                      decoration: InputDecoration(
                        labelText: localText(
                          context,
                          'Fragenkatalog',
                          'Question catalogue',
                        ),
                      ),
                      builder: (d) => DropdownButtonFormField<String>(
                        initialValue: null,
                        isExpanded: true,
                        itemHeight: null,
                        decoration: d,
                        items: [
                          for (final q in safeQuestions)
                            DropdownMenuItem(value: q, child: Text(q)),
                        ],
                        onChanged: busy ? null : (v) => questions[i].text = v!,
                      ),
                    ),
                    const SizedBox(height: AccessSpacing.s16),
                    AccessField(
                      decoration: InputDecoration(
                        labelText: localText(context, 'Formularfrage'),
                        errorText: questionProblem(questions[i].text) == null
                            ? null
                            : localText(
                                context,
                                questionProblem(questions[i].text)!,
                                'This question needs review. Use the question catalogue; sensitive questions are blocked.',
                              ),
                        errorMaxLines: 8,
                      ),
                      builder: (d) => TextField(
                        controller: questions[i],
                        enabled: !busy,
                        maxLength: 180,
                        decoration: d,
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const LocalText('Pflichtfeld'),
                      value: requiredFields[i],
                      onChanged: busy
                          ? null
                          : (v) => setState(() => requiredFields[i] = v!),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              questions.removeAt(i).dispose();
                              keys.removeAt(i);
                              requiredFields.removeAt(i);
                            }),
                      child: const LocalText('Frage entfernen'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AccessSpacing.s24),
            OutlinedButton(
              onPressed: busy || questions.length >= 12
                  ? null
                  : () => setState(() => add(safeQuestions.first)),
              child: const LocalText('Frage hinzufügen'),
            ),
            const SizedBox(height: AccessSpacing.s16),
            FilledButton(
              onPressed:
                  busy ||
                      title.text.trim().isEmpty ||
                      questions.isEmpty ||
                      questions.any((q) => questionProblem(q.text) != null)
                  ? null
                  : save,
              child: const LocalText('Formular speichern'),
            ),
          ],
        ),
      ),
    ),
  );
}

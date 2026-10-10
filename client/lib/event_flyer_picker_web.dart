import 'dart:js_interop';

import 'access_api.dart';

const flyerPickerAvailable = true;
@JS('communityAccessPickFlyer')
external JSPromise<JSString> _pick();
Future<String?> pickEventFlyer() async {
  try {
    final result = (await _pick().toDart).toDart;
    return result.isEmpty ? null : result;
  } catch (_) {
    throw const ApiFailure(
      'Bitte eine JPG- oder PNG-Datei bis 10 MB wählen. Das Bild muss sich auf höchstens 256 KB verkleinern lassen.',
    );
  }
}

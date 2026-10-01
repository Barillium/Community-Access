import 'dart:js_interop';

@JS('window.open')
external JSAny? _open(JSString url, JSString target, JSString features);
Future<bool> openContact(String value) async {
  _open(value.toJS, '_blank'.toJS, 'noopener,noreferrer'.toJS);
  return true;
}

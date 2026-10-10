import 'dart:js_interop';

import 'resource_return.dart';

@JS('window.sessionStorage.getItem')
external JSString? _get(JSString key);
@JS('window.sessionStorage.setItem')
external void _set(JSString key, JSString value);
@JS('window.sessionStorage.removeItem')
external void _remove(JSString key);
@JS('window.history.replaceState')
external void _replace(JSAny? state, JSString title, JSString url);
const _key = 'ca-resource-return-v1';
String? _stored() {
  try {
    return _get(_key.toJS)?.toDart;
  } catch (_) {
    return null;
  }
}

Map<String, String>? resourceReturnTarget() =>
    validatedResourceTarget(Uri.base.fragment) ??
    validatedResourceTarget(_stored());
void _write(String? value) {
  try {
    if (value == null) {
      _remove(_key.toJS);
    } else {
      _set(_key.toJS, value.toJS);
    }
  } catch (_) {}
  // Account/invitation secrets are never copied to storage or replaced here.
  if (Uri.base.fragment.isEmpty ||
      validatedResourceTarget(Uri.base.fragment) != null) {
    _replace(
      null,
      ''.toJS,
      Uri.base.replace(fragment: value ?? '').toString().toJS,
    );
  }
}

String? rememberResourceTarget(String kind, String id) {
  final value = '$kind=$id';
  if (validatedResourceTarget(value) == null) return null;
  final previous = _stored();
  _write(value);
  return previous == value || validatedResourceTarget(previous) == null
      ? null
      : previous;
}

void restoreResourceTarget(String? previous) =>
    _write(validatedResourceTarget(previous) == null ? null : previous);

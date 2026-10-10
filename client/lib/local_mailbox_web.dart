import 'dart:js_interop';

@JS('window.open')
external JSAny? _open(JSString url, JSString target, JSString features);

// Local synthetic test mail only; no external mail provider.
bool openLocalMailbox() {
  _open(
    'http://127.0.0.1:8000/testing/mailbox'.toJS,
    '_blank'.toJS,
    'noopener,noreferrer'.toJS,
  );
  return true;
}

import 'dart:js_interop';

@JS('window.open')
external JSAny? _open(JSString url, JSString target, JSString features);

bool openNativeTicketCheckout(Uri url) {
  _open(url.toString().toJS, '_blank'.toJS, 'noopener,noreferrer'.toJS);
  return true;
}

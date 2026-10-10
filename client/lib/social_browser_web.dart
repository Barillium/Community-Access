import 'dart:js_interop';

@JS('window.location.assign')
external void _assign(JSString url);
@JS('window.history.replaceState')
external void _replace(JSAny? state, JSString title, JSString url);

bool navigateToSocial(Uri url) {
  _assign(url.toString().toJS);
  return true;
}

void clearSocialResult() {
  if (Uri.base.fragment == 'social=success' ||
      Uri.base.fragment == 'social=error') {
    _replace(null, ''.toJS, Uri.base.replace(fragment: '').toString().toJS);
  }
}

// The caller retains an already validated link in memory before clearing it.
void clearAccountLinkFragment() {
  _replace(null, ''.toJS, Uri.base.replace(fragment: '').toString().toJS);
}

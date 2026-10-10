import 'dart:js_interop';

@JS('window')
external _Window get _window;

extension type _Window(JSObject _) implements JSObject {
  external void addEventListener(String name, JSFunction listener);
  external void removeEventListener(String name, JSFunction listener);
}

extension type _UnloadEvent(JSObject _) implements JSObject {
  external void preventDefault();
  external set returnValue(String value);
}

class EventLeaveGuard {
  bool _active = false;
  late final JSFunction _listener = ((_UnloadEvent event) {
    event.preventDefault();
    event.returnValue = '';
  }).toJS;
  void setDirty(bool dirty) {
    if (dirty == _active) return;
    _active = dirty;
    if (dirty) {
      _window.addEventListener('beforeunload', _listener);
    } else {
      _window.removeEventListener('beforeunload', _listener);
    }
  }

  void dispose() => setDirty(false);
}

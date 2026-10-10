import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Session-only drafts: never persisted to browser storage or sent automatically.
class EventDrafts extends ChangeNotifier {
  static final _sessions = Expando<EventDrafts>();
  static EventDrafts forApi(Object api) => _sessions[api] ??= EventDrafts();
  final _drafts = <String, Map<String, dynamic>>{};
  int epoch = 0;
  Map<String, dynamic> _copy(Map<String, dynamic> data) =>
      jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  Map<String, dynamic>? read(String key) =>
      _drafts[key] == null ? null : _copy(_drafts[key]!);
  void write(String key, Map<String, dynamic> data) {
    _drafts[key] = _copy(data);
  }

  void remove(String key) => _drafts.remove(key);
  void clear() {
    epoch++;
    _drafts.clear();
    notifyListeners();
  }
}

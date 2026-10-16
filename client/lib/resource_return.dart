/// A resource identifier is navigation only; the server checks every read.
Map<String, String>? validatedResourceTarget(String? value) {
  if (value == null || value.length > 100 || value.split('&').length != 1) {
    return null;
  }
  try {
    final parts = Uri.splitQueryString(value);
    if (parts.length != 1) return null;
    final kind = parts.keys.single;
    final id = parts.values.single;
    if (!['event', 'series', 'community'].contains(kind) ||
        !RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$').hasMatch(id)) {
      return null;
    }
    return {'kind': kind, 'id': id};
  } catch (_) {
    return null;
  }
}

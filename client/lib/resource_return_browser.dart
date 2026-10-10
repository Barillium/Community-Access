import 'resource_return.dart';

String? _target;
Map<String, String>? resourceReturnTarget() => validatedResourceTarget(_target);
String? rememberResourceTarget(String kind, String id) {
  final value = '$kind=$id';
  if (validatedResourceTarget(value) == null) return null;
  final previous = _target;
  _target = value;
  return previous == value ? null : previous;
}

void restoreResourceTarget(String? previous) {
  _target = validatedResourceTarget(previous) == null ? null : previous;
}

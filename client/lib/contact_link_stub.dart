import 'mobile_platform.dart';

Future<bool> openContact(String value) async {
  final uri = Uri.tryParse(value);
  return uri != null && await openExternalUri(uri);
}

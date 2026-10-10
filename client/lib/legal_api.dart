abstract interface class LegalApi {
  Future<Map<String, dynamic>> legal(String path, {Map<String, dynamic>? body});
}

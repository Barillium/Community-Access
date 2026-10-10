abstract interface class AccessFlowApi {
  Future<Map<String, dynamic>> access(
    String path, {
    Map<String, dynamic>? body,
  });
}

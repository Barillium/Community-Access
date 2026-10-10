import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_http_client.dart'
    if (dart.library.js_interop) 'auth_http_client_web.dart';
import 'ticketing_api.dart';

Future<Uri> prepareNativeTicketCheckout(
  TicketingApi api,
  Map<String, dynamic> order, {
  http.Client? client,
}) async {
  final requireCurrentSession = TicketingSessionGuard(api).check;
  requireCurrentSession();
  final entry = Uri.parse(order['native_checkout_entry'] as String);
  if (entry.scheme != 'http' ||
      entry.host != '127.0.0.1' ||
      entry.port != 8400 ||
      !entry.path.endsWith('/community-access/entry/')) {
    throw StateError('Invalid local checkout');
  }
  final ownsClient = client == null;
  final transport = client ?? createAuthClient();
  try {
    final challenge = await transport
        .get(entry)
        .timeout(const Duration(seconds: 5));
    requireCurrentSession();
    if (challenge.statusCode != 200) throw StateError('Checkout unavailable');
    final nonce = (jsonDecode(challenge.body) as Map)['browser_nonce'];
    final handoff = await api.ticketing(
      'orders/${order['id']}/handoff',
      body: {'browser_nonce': nonce},
    );
    requireCurrentSession();
    final response = await transport
        .post(
          entry,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'order_id': order['id'],
            'browser_nonce': nonce,
            'code': handoff['code'],
          }),
        )
        .timeout(const Duration(seconds: 5));
    requireCurrentSession();
    if (response.statusCode != 200) throw StateError('Checkout denied');
    final url = entry.resolve(
      (jsonDecode(response.body) as Map)['checkout_url'] as String,
    );
    if (url.origin != entry.origin || !url.path.startsWith('/demo/')) {
      throw StateError('Invalid local checkout');
    }
    return url;
  } finally {
    if (ownsClient) transport.close();
  }
}

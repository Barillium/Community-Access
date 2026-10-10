import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

// OAuth state and the short-lived handoff cookie are HTTP-only. The signed
// application session remains in memory after the handoff clears that cookie.
http.Client createAuthClient() => BrowserClient()..withCredentials = true;

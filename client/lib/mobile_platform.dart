import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'platform_kind.dart' if (dart.library.io) 'platform_kind_io.dart';

/// OS browser/mail only. Private loopback URLs remain a development feature.
bool allowedExternalUri(Uri uri) {
  if (uri.userInfo.isNotEmpty || uri.toString().length > 8192) return false;
  if (uri.scheme == 'mailto') {
    return !uri.hasQuery &&
        !uri.hasFragment &&
        RegExp(r'^[^@\s<>]+@[^@\s<>]+\.[^@\s<>]+$').hasMatch(uri.path);
  }
  if (uri.host.isEmpty) return false;
  if (uri.scheme == 'https') return !uri.hasPort || uri.port == 443;
  return !kReleaseMode &&
      uri.scheme == 'http' &&
      uri.host == '127.0.0.1' &&
      [8000, 8300, 8400].contains(uri.port);
}

Future<bool> openExternalUri(Uri uri) async {
  if (!nativeMobileRuntime || !allowedExternalUri(uri)) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

import 'package:app_links/app_links.dart';

import 'auth_mode.dart';
import 'platform_kind.dart' if (dart.library.io) 'platform_kind_io.dart';

bool get mobileLinksAvailable => nativeMobileRuntime;

bool trustedMobileLink(Uri uri) =>
    configuredAuthPageOrigin(uri) &&
    uri.path == '/' &&
    !uri.hasQuery &&
    uri.toString().length <= 8192;

Future<Uri?> initialMobileLink() async {
  if (!mobileLinksAvailable) return null;
  try {
    final uri = await AppLinks().getInitialLink();
    return uri != null && trustedMobileLink(uri) ? uri : null;
  } catch (_) {
    return null;
  }
}

Stream<Uri> mobileLinkStream() => mobileLinksAvailable
    ? AppLinks().uriLinkStream.where(trustedMobileLink)
    : const Stream<Uri>.empty();

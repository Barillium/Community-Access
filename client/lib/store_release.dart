import 'package:flutter/material.dart';

import 'auth_mode.dart';

const storeBuild = bool.fromEnvironment('CA_STORE_BUILD');
const minimumAccountAge = int.fromEnvironment('CA_MINIMUM_ACCOUNT_AGE');

List<String> storeConfigurationErrors({
  required bool realAccounts,
  required String apiOrigin,
  required String uiOrigin,
  required int minimumAge,
}) {
  bool publicHttps(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        uri.origin == value &&
        !uri.host.endsWith('.invalid') &&
        !uri.host.endsWith('.localhost') &&
        uri.host != 'localhost' &&
        !uri.host.contains(':') &&
        !uri.host.endsWith('.local') &&
        !RegExp(r'^\d+(\.\d+){3}$').hasMatch(uri.host) &&
        (!uri.hasPort || uri.port == 443);
  }

  return [
    if (!realAccounts) 'Real account profile required.',
    if (!publicHttps(apiOrigin) || !publicHttps(uiOrigin))
      'Public HTTPS origins required.',
    if (minimumAge < 1 || minimumAge > 18) 'Account age decision required.',
  ];
}

bool get storeConfigurationValid =>
    !storeBuild ||
    storeConfigurationErrors(
      realAccounts: privateMailMode,
      apiOrigin: const String.fromEnvironment('CA_AUTH_API_ORIGIN'),
      uiOrigin: authUiOrigin,
      minimumAge: minimumAccountAge,
    ).isEmpty;

class StoreUnavailablePage extends StatelessWidget {
  const StoreUnavailablePage({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Community Access ist noch nicht verfügbar.\nCommunity Access is not available yet.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
}

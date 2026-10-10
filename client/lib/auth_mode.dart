// Explicit owner-operated build; default development remains synthetic.
const privateMailMode = bool.fromEnvironment('CA_PRIVATE_MAIL');
const authUiOrigin = String.fromEnvironment(
  'CA_AUTH_UI_ORIGIN',
  defaultValue: 'http://127.0.0.1:8300',
);

bool configuredAuthPageOrigin(Uri uri) {
  final configured = Uri.tryParse(authUiOrigin);
  return configured != null &&
      configured.host.isNotEmpty &&
      configured.userInfo.isEmpty &&
      configured.path.isEmpty &&
      !configured.hasQuery &&
      !configured.hasFragment &&
      (configured.scheme == 'https' ||
          authUiOrigin == 'http://127.0.0.1:8300') &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty &&
      uri.origin == configured.origin &&
      uri.userInfo.isEmpty;
}

bool allowedAccountEmail(String value) =>
    value.length <= 255 &&
    (privateMailMode
        ? RegExp(r'^[^@\s<>]+@[^@\s<>]+\.[^@\s<>]+$').hasMatch(value) &&
              !value.endsWith('@example.invalid')
        : RegExp(r'^[^@\s]+@example\.invalid$').hasMatch(value));

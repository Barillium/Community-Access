/// The build selects scope; a route or an account cannot enable deferred features.
abstract final class ProductScope {
  static const edition = String.fromEnvironment(
    'CA_PRODUCT_EDITION',
    defaultValue: 'v1',
  );
  static const extended = edition == 'extended';
  static bool get valid => edition == 'v1' || extended;
}

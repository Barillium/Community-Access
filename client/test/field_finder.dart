import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/design_system.dart';

/// Finds the actual input regardless of whether its caption wraps above it.
Finder fieldWithLabel(Type type, String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is AccessField && widget.decoration.labelText == label,
  ),
  matching: find.byType(type),
);

import 'package:flutter/material.dart';

/// Authoritative Flyer type scale in logical pixels, before user text scaling.
/// Headings wrap; display size never disables TextScaler or hides overflow.
abstract final class AccessTypography {
  static const labelSize = 13.0;
  static const captionSize = 14.0;
  static const bodySize = 16.0;
  static const leadSize = 20.0;
  static const cardTitleSize = 24.0;
  static const sectionTitleSize = 32.0;
  static const pageMin = 38.0, pageMax = 64.0;
  static const heroMin = 52.0, heroMax = 88.0;
  static const headingHeight = 1.1, titleHeight = 1.2;
  static const bodyHeight = 1.5, readingHeight = 1.6;
  static const label = TextStyle(fontSize: labelSize, height: bodyHeight);
  static const caption = TextStyle(fontSize: captionSize, height: bodyHeight);
  static const body = TextStyle(fontSize: bodySize, height: bodyHeight);
  static const lead = TextStyle(fontSize: leadSize, height: readingHeight);
  static const cardTitle = TextStyle(
    fontSize: cardTitleSize,
    height: titleHeight,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wdth', 100)],
  );
  static const sectionTitle = TextStyle(
    fontSize: sectionTitleSize,
    height: titleHeight,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wdth', 100)],
  );

  static double _between(double width, double min, double max) =>
      min + (max - min) * ((width - 390) / (1200 - 390)).clamp(0.0, 1.0);
  static double hero(double width) => _between(width, heroMin, heroMax);
  static double page(double width) => _between(width, pageMin, pageMax);
  static double section(double width) => _between(width, 28, sectionTitleSize);
  static double card(double width) => _between(width, 22, cardTitleSize);
}

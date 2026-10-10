import 'app_language.dart';
import 'aushang_tokens.dart';
import 'phosphor_vectors.dart';
import 'aushang_forui.dart';

export 'aushang_forui.dart'
    show AccessAction, AccessActionKind, AccessForuiTheme;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forui/forui.dart'
    show FBasicTheme, FFocusedOutline, FFocusedOutlineStyle;

/// All dimensions are logical pixels. TextScaler is never disabled for content.
abstract final class AccessSpacing {
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s40 = 40.0;
  static const s48 = 48.0;
  static const s64 = 64.0;
  static const s80 = 80.0;
  static const s96 = 96.0;
}

/// Named text roles; responsive headings resolve through AccessHeading.
abstract final class AccessTypography {
  static const labelSize = AushangTokens.semanticTypeFine;
  static const captionSize = AushangTokens.semanticTypeMeta;
  static const bodySize = AushangTokens.semanticTypeBody;
  static const leadSize = AushangTokens.semanticTypeLead;
  static const cardTitleSize = AushangTokens.semanticTypeTitle;
  static const sectionTitleSize = 38.0;
  static const pageMin = 38.0;
  static const pageMax = AushangTokens.semanticTypeSection;
  static const heroMin = 52.0;
  static const heroMax = AushangTokens.semanticTypeDisplay;
  static const headingHeight = 1.0;
  static const titleHeight = 1.1;
  static const bodyHeight = 1.5;
  static const readingHeight = 1.6;
  static const label = TextStyle(fontSize: labelSize, height: bodyHeight);
  static const caption = TextStyle(fontSize: captionSize, height: bodyHeight);
  static const body = TextStyle(fontSize: bodySize, height: bodyHeight);
  static const lead = TextStyle(fontSize: leadSize, height: readingHeight);
  static const cardTitle = TextStyle(
    fontSize: cardTitleSize,
    height: titleHeight,
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wdth', 68)],
  );
  static const sectionTitle = TextStyle(
    fontSize: sectionTitleSize,
    height: titleHeight,
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wdth', 68)],
  );
}

/// Theme overrides make shared layout changes possible without page edits.
@immutable
class AccessLayoutTheme extends ThemeExtension<AccessLayoutTheme> {
  final double gutterMin, gutterMax, sectionMin, sectionMax, cardMin, cardMax;
  const AccessLayoutTheme({
    this.gutterMin = AccessSpacing.s16,
    this.gutterMax = AushangTokens.semanticLayoutGutter,
    this.sectionMin = AushangTokens.semanticLayoutSectionMobile,
    this.sectionMax = AushangTokens.semanticLayoutSection,
    this.cardMin = AccessSpacing.s16,
    this.cardMax = AccessSpacing.s24,
  });
  static AccessLayoutTheme of(BuildContext context) =>
      Theme.of(context).extension<AccessLayoutTheme>() ??
      const AccessLayoutTheme();
  @override
  AccessLayoutTheme copyWith({
    double? gutterMin,
    double? gutterMax,
    double? sectionMin,
    double? sectionMax,
    double? cardMin,
    double? cardMax,
  }) => AccessLayoutTheme(
    gutterMin: gutterMin ?? this.gutterMin,
    gutterMax: gutterMax ?? this.gutterMax,
    sectionMin: sectionMin ?? this.sectionMin,
    sectionMax: sectionMax ?? this.sectionMax,
    cardMin: cardMin ?? this.cardMin,
    cardMax: cardMax ?? this.cardMax,
  );
  @override
  AccessLayoutTheme lerp(covariant AccessLayoutTheme? other, double t) {
    if (other == null) return this;
    double mix(double a, double b) => a + (b - a) * t;
    return AccessLayoutTheme(
      gutterMin: mix(gutterMin, other.gutterMin),
      gutterMax: mix(gutterMax, other.gutterMax),
      sectionMin: mix(sectionMin, other.sectionMin),
      sectionMax: mix(sectionMax, other.sectionMax),
      cardMin: mix(cardMin, other.cardMin),
      cardMax: mix(cardMax, other.cardMax),
    );
  }
}

abstract final class AccessLayout {
  static const mobileBreakpoint = 768.0;
  static const searchMinWidth = 720.0;
  static const twoColumnMinWidth = 900.0;
  static const accountColumnsMinWidth = 1000.0;
  static const navigationRowMinWidth = 1080.0;
  static const compactSurfaceWidth = 360.0;
  static const comfortableSurfaceWidth = 600.0;
  static const compactControlsWidth = 620.0;
  static const metadataMinWidth = 300.0;
  static const maxContentWidth = 1280.0;
  static const detailWidth = 1180.0;
  static const readingWidth = 760.0;
  static const formWidth = 520.0;
  static const metadataWidth = 280.0;
  static const detailSidebarWidth = 360.0;
  static const brandLockupWidth = 112.0;
  // Large text needs room to scroll the final form controls clear of the header.
  static const largeTextScrollTail = AccessSpacing.s64;
  static const minTouchTarget = 48.0;
  static const buttonHeight = 52.0;
  // Decorative geometry, deliberately separate from the spacing scale.
  static const surfaceFrame = 0.0;
  static const surfaceRadius = 0.0;
  static const surfaceInnerRadius = 0.0;
  static const controlRadius = 0.0;
  static const inputRadius = 0.0;
  static const iconSize = 24.0;
  static const brandIconSize = 28.0;
  static const smallIconSize = 18.0;
  static const brandIllustrationSize = 64.0;
  static const headerHeight = AushangTokens.componentHeaderHeight;
  static const toolbarHeight = AushangTokens.componentHeaderHeight;

  static double fluid(
    double width,
    double min,
    double max, {
    double from = 600,
    double to = 1000,
  }) => min + (max - min) * ((width - from) / (to - from)).clamp(0.0, 1.0);
  static double gutter(BuildContext context, double width) {
    final tokens = AccessLayoutTheme.of(context);
    return width < mobileBreakpoint ? tokens.gutterMin : tokens.gutterMax;
  }

  static EdgeInsets pagePadding(BuildContext context) =>
      EdgeInsets.all(gutter(context, MediaQuery.sizeOf(context).width));
  static double sectionGap(BuildContext context, double width) {
    final tokens = AccessLayoutTheme.of(context);
    return fluid(width, tokens.sectionMin, tokens.sectionMax);
  }

  static double cardPadding(BuildContext context, double width) {
    final tokens = AccessLayoutTheme.of(context);
    return fluid(
      width,
      tokens.cardMin,
      tokens.cardMax,
      from: compactSurfaceWidth,
      to: comfortableSurfaceWidth,
    );
  }

  static bool largeText(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(AccessTypography.bodySize) >=
      AccessTypography.bodySize * 1.3;
  static bool columns(
    BuildContext context,
    double width, {
    double minWidth = twoColumnMinWidth,
  }) => width >= minWidth && !largeText(context);
}

enum AccessPageWidth { content, detail, reading, form }

/// Limits nested groups without adding a second set of page gutters.
class AccessContent extends StatelessWidget {
  final Widget child;
  final AccessPageWidth width;
  const AccessContent({
    super.key,
    required this.child,
    this.width = AccessPageWidth.reading,
  });
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: switch (width) {
          AccessPageWidth.form => AccessLayout.formWidth,
          AccessPageWidth.reading => AccessLayout.readingWidth,
          AccessPageWidth.detail => AccessLayout.detailWidth,
          AccessPageWidth.content => AccessLayout.maxContentWidth,
        },
      ),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

/// Keeps complete labels visible when the inline Material label cannot fit.
/// The same label remains attached to the editable control for assistive tools.
class AccessField extends StatelessWidget {
  final InputDecoration decoration;
  final double trailingWidth;
  final Widget Function(InputDecoration decoration) builder;
  const AccessField({
    super.key,
    required this.decoration,
    required this.builder,
    this.trailingWidth = 0,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = Theme.of(context).textTheme.bodyLarge!;
      final translatedDecoration = decoration.copyWith(
        labelText: decoration.labelText == null
            ? null
            : localText(context, decoration.labelText!),
        hintText: decoration.hintText == null
            ? null
            : localText(context, decoration.hintText!),
        helperText: decoration.helperText == null
            ? null
            : localText(context, decoration.helperText!),
      );
      final padding =
          (translatedDecoration.contentPadding ??
                  Theme.of(context).inputDecorationTheme.contentPadding ??
                  const EdgeInsets.symmetric(horizontal: AccessSpacing.s20))
              .resolve(Directionality.of(context));
      final available = math.max(
        0.0,
        constraints.maxWidth -
            padding.horizontal -
            // Material 3 adds four pixels per side inside the content padding.
            AccessSpacing.s8 -
            trailingWidth -
            (translatedDecoration.prefixIcon == null
                ? 0
                : AccessLayout.minTouchTarget) -
            (translatedDecoration.suffixIcon == null
                ? 0
                : AccessLayout.minTouchTarget),
      );
      bool tooWide(String? text, {bool label = false}) {
        if (text == null || text.isEmpty) return false;
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: label
                ? Theme.of(context).textTheme.titleMedium!
                      .merge(style)
                      .merge(translatedDecoration.labelStyle)
                : style.merge(translatedDecoration.hintStyle),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        );
        painter.layout();
        final result = painter.width > available;
        painter.dispose();
        return result;
      }

      final externalLabel = tooWide(
        translatedDecoration.labelText,
        label: true,
      );
      final externalHint = tooWide(translatedDecoration.hintText);
      var resolved = translatedDecoration;
      if (externalLabel) {
        // InputDecoration.copyWith cannot clear a label with null.
        resolved = resolved.copyWith(
          labelText: '',
          floatingLabelBehavior: FloatingLabelBehavior.never,
        );
      }
      if (externalHint) {
        resolved = resolved.copyWith(
          hintText: '',
          helperText: [
            translatedDecoration.hintText!,
            if (translatedDecoration.helperText != null)
              translatedDecoration.helperText!,
          ].join('\n'),
          helperMaxLines: 100,
        );
      }
      final field = _AccessFieldFocus(child: builder(resolved));
      if (!externalLabel) return field;
      return AccessStack(
        gap: AccessSpacing.s8,
        children: [
          ExcludeSemantics(
            child: Text(
              translatedDecoration.labelText!,
              style: AccessTypography.caption,
            ),
          ),
          Semantics(label: translatedDecoration.labelText, child: field),
        ],
      );
    },
  );
}

class _AccessFieldFocus extends StatefulWidget {
  final Widget child;
  const _AccessFieldFocus({required this.child});
  @override
  State<_AccessFieldFocus> createState() => _AccessFieldFocusState();
}

class _AccessFieldFocusState extends State<_AccessFieldFocus> {
  bool focused = false;
  @override
  Widget build(BuildContext context) => FBasicTheme(
    data: AushangForui.of(context),
    child: Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (value) => setState(() => focused = value),
      child: FFocusedOutline(
        focused: focused,
        style: FFocusedOutlineStyle(
          color: AushangPalette.of(context).ink,
          borderRadius: BorderRadius.zero,
          width: AushangTokens.semanticFocusWidth,
          spacing: AushangTokens.semanticFocusOffset,
        ),
        child: widget.child,
      ),
    ),
  );
}

/// Dropdowns inherit a one-line default; allow bounded profile names to wrap.
class AccessOptionText extends LocalText {
  const AccessOptionText(super.data, {super.key})
    : super(softWrap: true, maxLines: 20, overflow: TextOverflow.visible);
}

/// Standard page toolbars grow with wrapped titles rather than clipping them.
AppBar accessAppBar(BuildContext context, String title, {Widget? leading}) {
  final style =
      (Theme.of(context).appBarTheme.titleTextStyle ?? AccessTypography.body)
          .copyWith(height: AccessTypography.titleHeight);
  final painter = TextPainter(
    text: TextSpan(text: localText(context, title), style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  );
  painter.layout(
    maxWidth: math.max(
      1,
      MediaQuery.sizeOf(context).width -
          AccessLayout.minTouchTarget -
          AccessSpacing.s48,
    ),
  );
  final height = math.max(
    AccessLayout.toolbarHeight,
    painter.height + AccessSpacing.s32,
  );
  final lines = painter.computeLineMetrics().length;
  painter.dispose();
  return AppBar(
    leading: leading,
    toolbarHeight: height,
    title: Text(
      localText(context, title),
      maxLines: math.max(1, lines),
      softWrap: true,
      overflow: TextOverflow.visible,
      style: style,
    ),
  );
}

/// Owns page gutters once. Nested sections must not add page padding again.
class AccessPageFrame extends StatelessWidget {
  final Widget child;
  final AccessPageWidth width;
  final bool verticalPadding;
  const AccessPageFrame({
    super.key,
    required this.child,
    this.width = AccessPageWidth.content,
    this.verticalPadding = true,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final limit = switch (width) {
        AccessPageWidth.content => AccessLayout.maxContentWidth,
        AccessPageWidth.detail => AccessLayout.detailWidth,
        AccessPageWidth.reading => AccessLayout.readingWidth,
        AccessPageWidth.form => AccessLayout.formWidth,
      };
      final available = constraints.hasBoundedWidth
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width;
      final inset = AccessLayout.gutter(context, available);
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: limit),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              inset,
              verticalPadding ? inset : 0,
              inset,
              verticalPadding
                  ? (AccessLayout.largeText(context)
                        ? math.max(inset, AccessLayout.largeTextScrollTail)
                        : inset)
                  : 0,
            ),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      );
    },
  );
}

class AccessStack extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  final CrossAxisAlignment alignment;
  const AccessStack({
    super.key,
    required this.children,
    this.gap = AccessSpacing.s16,
    this.alignment = CrossAxisAlignment.stretch,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignment,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(height: gap),
        children[i],
      ],
    ],
  );
}

/// A shared mechanism with area-specific ratios and minimum widths.
class AccessColumns extends StatelessWidget {
  final List<Widget> children;
  final List<int>? flex;
  final List<Widget>? stackedChildren;
  final double? stackedGap;
  final double minWidth, gap;
  const AccessColumns({
    super.key,
    required this.children,
    this.flex,
    this.stackedChildren,
    this.stackedGap,
    this.minWidth = AccessLayout.twoColumnMinWidth,
    this.gap = AccessSpacing.s32,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      assert(flex == null || flex!.length == children.length);
      if (!AccessLayout.columns(
        context,
        constraints.maxWidth,
        minWidth: minWidth,
      )) {
        return AccessStack(
          gap: stackedGap ?? gap,
          children: stackedChildren ?? children,
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(flex: flex?[i] ?? 1, child: children[i]),
          ],
        ],
      );
    },
  );
}

enum AccessHeadingRole { hero, page, section, card, poster }

class AccessHeading extends StatelessWidget {
  final String text;
  final AccessHeadingRole role;
  final int level;
  final Color? color;
  final FontWeight weight;
  final double? referenceWidth;
  final bool uppercase;
  const AccessHeading(
    this.text, {
    super.key,
    this.role = AccessHeadingRole.section,
    this.level = 2,
    this.color,
    this.weight = FontWeight.w800,
    this.referenceWidth,
    this.uppercase = false,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width =
          referenceWidth ??
          (constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width);
      final size = switch (role) {
        AccessHeadingRole.poster =>
          MediaQuery.sizeOf(context).width < 768 ? 72.0 : 136.0,
        AccessHeadingRole.hero => AccessLayout.fluid(
          width,
          AccessTypography.heroMin,
          AccessTypography.heroMax,
          to: 1200,
        ),
        AccessHeadingRole.page => AccessLayout.fluid(
          width,
          AccessTypography.pageMin,
          AccessTypography.pageMax,
        ),
        AccessHeadingRole.section => AccessTypography.sectionTitleSize,
        AccessHeadingRole.card =>
          uppercase && MediaQuery.sizeOf(context).width < 768
              ? 22.0
              : AccessTypography.cardTitleSize,
      };
      final content = localText(context, text);
      return Semantics(
        headingLevel: level,
        child: Text(
          uppercase ? content.toUpperCase() : content,
          semanticsLabel: content,
          style: TextStyle(
            fontSize: size,
            height: uppercase
                ? (role == AccessHeadingRole.card ? .98 : .9)
                : role == AccessHeadingRole.card
                ? AccessTypography.titleHeight
                : AccessTypography.headingHeight,
            fontWeight: weight,
            fontVariations: const [FontVariation('wdth', 68)],
            color: color,
          ),
        ),
      );
    },
  );
}

class AccessSection extends StatelessWidget {
  final Widget child;
  final String? title;
  const AccessSection({super.key, required this.child, this.title});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Padding(
      padding: EdgeInsets.symmetric(
        vertical: AccessLayout.sectionGap(context, constraints.maxWidth) / 2,
      ),
      child: AccessStack(
        children: [if (title != null) AccessHeading(title!), child],
      ),
    ),
  );
}

/// Semantic colors resolve together for light and dark views.
@immutable
class AushangPalette extends ThemeExtension<AushangPalette> {
  final bool dark;
  const AushangPalette({this.dark = false});
  static AushangPalette of(BuildContext context) =>
      Theme.of(context).extension<AushangPalette>() ?? const AushangPalette();
  Color get page => dark
      ? AushangTokens.darkSemanticSurfacePage
      : AushangTokens.semanticSurfacePage;
  Color get sunken => dark
      ? AushangTokens.darkSemanticSurfaceSunken
      : AushangTokens.semanticSurfaceSunken;
  Color get ink => dark
      ? AushangTokens.darkSemanticTextPrimary
      : AushangTokens.semanticTextPrimary;
  Color get muted => dark
      ? AushangTokens.darkSemanticTextSecondary
      : AushangTokens.semanticTextSecondary;
  Color get hair => dark
      ? AushangTokens.darkSemanticBorderHair
      : AushangTokens.semanticBorderHair;
  Color get control => dark
      ? AushangTokens.darkSemanticBorderControl
      : AushangTokens.semanticBorderControl;
  Color get decision => dark
      ? AushangTokens.darkSemanticTextDecision
      : AushangTokens.semanticTextDecision;
  Color get decisionSurface => dark
      ? AushangTokens.darkSemanticSurfaceDecision
      : AushangTokens.semanticSurfaceDecision;
  @override
  AushangPalette copyWith({bool? dark}) =>
      AushangPalette(dark: dark ?? this.dark);
  @override
  AushangPalette lerp(covariant AushangPalette? other, double t) =>
      t < .5 ? this : other ?? this;
}

abstract final class AccessDesign {
  static const ink = AushangTokens.semanticTextPrimary;
  static const paper = AushangTokens.semanticSurfacePage;
  static const muted = AushangTokens.semanticTextSecondary;
  static const accentSoft = AushangTokens.semanticSurfaceDecision;
  static const accent = AushangTokens.semanticSurfaceAccent;
  static const neutral = AushangTokens.semanticSurfaceSunken;
  static const focus = AushangTokens.semanticFocusRing;
  static const curve = AushangTokens.primitiveEaseStandard;

  static ThemeData theme({bool dark = false}) {
    final palette = AushangPalette(dark: dark);
    const square = RoundedRectangleBorder();
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: palette.control),
    );
    final button = FilledButton.styleFrom(
      backgroundColor: palette.ink,
      foregroundColor: palette.page,
      disabledBackgroundColor: palette.sunken,
      disabledForegroundColor: palette.muted,
      minimumSize: const Size(48, AushangTokens.componentButtonHeight),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: square,
      textStyle: const TextStyle(
        fontFamily: 'Archivo',
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      animationDuration: AushangTokens.semanticMotionHover,
    ).copyWith(side: _focusBorder(palette.ink));
    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      fontFamily: 'Archivo',
      fontFamilyFallback: const ['Rubik'],
      extensions: [const AccessLayoutTheme(), palette],
      textTheme: const TextTheme(
        bodyMedium: AccessTypography.body,
        bodyLarge: AccessTypography.body,
        bodySmall: AccessTypography.caption,
        titleLarge: AccessTypography.cardTitle,
        titleMedium: AccessTypography.lead,
        titleSmall: AccessTypography.body,
        headlineSmall: AccessTypography.sectionTitle,
        labelLarge: AccessTypography.caption,
        labelMedium: AccessTypography.caption,
        labelSmall: AccessTypography.label,
      ).apply(bodyColor: palette.ink, displayColor: palette.ink),
      scaffoldBackgroundColor: palette.page,
      colorScheme: ColorScheme.fromSeed(
        brightness: dark ? Brightness.dark : Brightness.light,
        seedColor: ink,
        primary: palette.ink,
        onPrimary: palette.page,
        secondary: accent,
        onSecondary: ink,
        surface: palette.page,
        onSurface: palette.ink,
        onSurfaceVariant: palette.muted,
        surfaceContainerHighest: palette.sunken,
        outline: palette.control,
        outlineVariant: palette.hair,
        error: palette.decision,
      ),
      dividerTheme: DividerThemeData(
        color: palette.ink,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.page,
        foregroundColor: palette.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: palette.ink)),
        toolbarHeight: AccessLayout.toolbarHeight,
        titleTextStyle: TextStyle(
          fontFamily: 'Archivo',
          color: palette.ink,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: button),
      elevatedButtonTheme: ElevatedButtonThemeData(style: button),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: button.copyWith(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: WidgetStatePropertyAll(palette.ink),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: palette.ink,
              width: states.contains(WidgetState.focused) ? 2 : 1.5,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.ink,
          shape: square,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ).copyWith(side: _focusBorder(palette.ink)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: palette.ink,
          shape: square,
          minimumSize: const Size(48, 48),
        ).copyWith(side: _focusBorder(palette.ink)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.page,
        shape: square,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.page,
        indicatorColor: palette.sunken,
        indicatorShape: square,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        errorMaxLines: 20,
        helperMaxLines: 20,
        hintMaxLines: 20,
        filled: true,
        fillColor: palette.page,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: palette.ink, width: 2),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: palette.ink, width: 1.5),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: palette.ink, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: square,
        backgroundColor: palette.page,
        selectedColor: palette.sunken,
        side: BorderSide(color: palette.hair),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        labelStyle: TextStyle(fontFamily: 'Archivo', color: palette.ink),
      ),
      dialogTheme: DialogThemeData(
        shape: square,
        backgroundColor: palette.page,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.ink),
    );
  }

  /// Reserve orange for the principal human action in a view.
  static ButtonStyle primaryAction(BuildContext context) =>
      FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: ink,
      ).copyWith(side: _focusBorder(AushangPalette.of(context).ink));

  static WidgetStateProperty<BorderSide> _focusBorder(Color color) =>
      WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? BorderSide(color: color, width: 2)
            : BorderSide.none,
      );
}

/// Flat, square surfaces use a single rule instead of nested card frames.
class AccessSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  const AccessSurface({
    super.key,
    required this.child,
    this.padding,
    this.color,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final palette = AushangPalette.of(context);
      final background = color == null || color == AccessDesign.paper
          ? palette.page
          : color == AccessDesign.neutral
          ? palette.sunken
          : color == AccessDesign.accentSoft
          ? palette.decisionSurface
          : color;
      return Container(
        padding:
            padding ??
            EdgeInsets.all(
              AccessLayout.cardPadding(context, constraints.maxWidth),
            ),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: palette.hair),
        ),
        child: Material(type: MaterialType.transparency, child: child),
      );
    },
  );
}

class AccessReveal extends StatelessWidget {
  final Widget child;
  const AccessReveal({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AushangTokens.semanticMotionEnter,
      curve: AccessDesign.curve,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

class AccessHeader extends StatelessWidget {
  final Widget child;
  const AccessHeader({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final palette = AushangPalette.of(context);
    return Container(
      constraints: BoxConstraints(minHeight: width < 768 ? 61 : 73),
      padding: EdgeInsets.symmetric(
        horizontal: AccessLayout.gutter(context, width),
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: palette.page,
        border: Border(bottom: BorderSide(color: palette.ink)),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: palette.ink),
        child: child,
      ),
    );
  }
}

class AccessTopBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final Widget leading;
  const AccessTopBar({super.key, required this.title, required this.leading});

  @override
  Size get preferredSize => const Size.fromHeight(AccessLayout.headerHeight);

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: AccessHeader(
      child: Row(
        children: [
          leading,
          const SizedBox(width: AccessSpacing.s8),
          Expanded(
            child: DefaultTextStyle(
              style: TextStyle(
                color: AushangPalette.of(context).ink,
                fontFamily: 'Archivo',
                fontSize: AccessTypography.bodySize,
                fontWeight: FontWeight.w500,
              ),
              child: title,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Original Phosphor paths from the supplied reference; keep existing identifiers.
class AccessIcon extends Icon {
  const AccessIcon(
    super.icon, {
    super.key,
    super.size,
    super.color,
    super.semanticLabel,
  });
  @override
  Widget build(BuildContext context) {
    final path = phosphorVectors[icon];
    if (path == null) return super.build(context);
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel == null,
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: SizedBox.square(
          dimension:
              size ?? IconTheme.of(context).size ?? AccessLayout.iconSize,
          child: CustomPaint(
            painter: _AccessIconPainter(
              path,
              color ??
                  IconTheme.of(context).color ??
                  AushangPalette.of(context).ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessIconPainter extends CustomPainter {
  final Path path;
  final Color color;
  _AccessIconPainter(this.path, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 256, size.height / 256);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_AccessIconPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.color != color;
}

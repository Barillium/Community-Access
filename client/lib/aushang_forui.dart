import 'flyer_design.dart';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:forui/forui.dart';

import 'aushang_tokens.dart';

/// Forui and the remaining Material controls share the exported token source.
abstract final class AushangForui {
  static final light = _theme(false);
  static final dark = _theme(true);

  static FThemeData _theme(bool dark) {
    final ink = dark ? AushangTokens.darkSemanticTextPrimary : FlyerStyle.ink;
    final page = dark
        ? AushangTokens.darkSemanticSurfacePage
        : FlyerStyle.paper;
    final sunken = dark
        ? AushangTokens.darkSemanticSurfaceSunken
        : AushangTokens.semanticSurfaceSunken;
    final muted = dark
        ? AushangTokens.darkSemanticTextSecondary
        : AushangTokens.semanticTextSecondary;
    final colors = (dark ? FColors.neutralDark : FColors.neutralLight).copyWith(
      background: page,
      foreground: ink,
      primary: ink,
      primaryForeground: page,
      secondary: sunken,
      secondaryForeground: ink,
      muted: sunken,
      mutedForeground: muted,
      card: page,
      border: dark
          ? AushangTokens.darkSemanticBorderHair
          : AushangTokens.semanticBorderHair,
      destructive: AushangTokens.semanticSurfaceDecision,
      destructiveForeground: AushangTokens.semanticTextDecision,
      error: ink,
      errorForeground: page,
    );
    TextStyle text(double size, {double height = 1.5}) => TextStyle(
      fontFamily: AushangTokens.primitiveFontFamily,

      fontSize: size,
      height: height,
      color: ink,
    );
    final body = FTypeface(
      fontFamily: AushangTokens.primitiveFontFamily,

      xs3: text(13),
      xs2: text(13),
      xs: text(14),
      sm: text(16),
      md: text(16),
      lg: text(20),
      xl: text(28, height: 1.1),
      xl2: text(38, height: 1.1),
      xl3: text(52, height: 1),
    );
    TextStyle display(double size) => text(size, height: 1.1).copyWith(
      fontWeight: FontWeight.w600,
      fontVariations: const [FontVariation('wdth', 100)],
      letterSpacing: 0,
    );
    final typography = FTypography(
      display: FTypeface(
        fontFamily: AushangTokens.primitiveFontFamily,

        xs3: display(13),
        xs2: display(13),
        xs: display(14),
        sm: display(16),
        md: display(16),
        lg: display(20),
        xl: display(28),
        xl2: display(38),
        xl3: display(52),
      ),
      body: body,
    );
    final style =
        FStyle.inherit(
          colors: colors,
          typography: typography,
          touch: true,
        ).copyWith(
          borderRadius: const FBorderRadius().scale(0),
          shadow: const [],
          pagePadding: const EdgeInsetsDelta.value(EdgeInsets.all(16)),
          focusedOutlineStyle: FFocusedOutlineStyle(
            color: ink,
            borderRadius: BorderRadius.zero,
            width: AushangTokens.semanticFocusWidth,
            spacing: AushangTokens.semanticFocusOffset,
          ),
          tappableStyle: FTappableStyle(
            // Motion is animated by AccessAction; do not delay pressed state.
            pressedEnterDuration: Duration.zero,
            pressedExitDuration: Duration.zero,
            motion: FTappableMotion.none,
          ),
        );
    return FThemeData(
      debugLabel: dark ? 'Flyer Dark' : 'Flyer Light',
      colors: colors,
      typography: typography,
      style: style,
      touch: true,
    );
  }

  static FThemeData of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class AccessForuiTheme extends StatelessWidget {
  final Widget child;
  const AccessForuiTheme({super.key, required this.child});
  @override
  Widget build(BuildContext context) => FTheme(
    data: AushangForui.of(context),
    motion: FThemeMotion(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AushangTokens.semanticMotionHover,
      curve: AushangTokens.primitiveEaseStandard,
    ),
    child: child,
  );
}

enum AccessActionKind { primary, neutral, outline, ghost }

/// One token-based Forui action, including keyboard focus and disabled states.
class AccessAction extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Widget? prefix, suffix;
  final AccessActionKind kind;
  final bool fullWidth, iconOnly, small;
  final String? tooltip;
  const AccessAction({
    super.key,
    required this.onPressed,
    required this.child,
    this.prefix,
    this.suffix,
    this.kind = AccessActionKind.outline,
    this.fullWidth = false,
    this.iconOnly = false,
    this.small = false,
    this.tooltip,
  });
  @override
  State<AccessAction> createState() => _AccessActionState();
}

class _AccessActionState extends State<AccessAction> {
  bool _hovered = false, _pressed = false, _keyboardInteraction = false;
  PointerDeviceKind? _pointerKind;
  late final _focusNode = FocusNode(
    debugLabel: 'Aushang action',
    onKeyEvent: (_, event) {
      if (!_keyboardInteraction) setState(() => _keyboardInteraction = true);
      return KeyEventResult.ignored;
    },
  );

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AushangForui.of(context);
    final primary = widget.kind == AccessActionKind.primary;
    final neutral = widget.kind == AccessActionKind.neutral;
    final outlined = widget.kind == AccessActionKind.outline;
    final ink = theme.colors.foreground;
    final background = primary
        ? AushangTokens.semanticSurfaceAccent
        : neutral
        ? ink
        : theme.colors.background;
    final foreground = primary
        ? AushangTokens.semanticTextOnAccent
        : neutral
        ? theme.colors.background
        : ink;
    ShapeDecoration decoration(Color color) => ShapeDecoration(
      color: widget.kind == AccessActionKind.ghost ? Colors.transparent : color,
      shape: RoundedRectangleBorder(
        side: outlined ? BorderSide(color: ink, width: 1.5) : BorderSide.none,
      ),
    );
    final style =
        FButtonStyle.inherit(
          style: theme.style,
          decoration: FVariants.from(
            decoration(background),
            variants: {
              [FTappableVariant.hovered]: DecorationDelta.value(
                decoration(
                  primary
                      ? AushangTokens.semanticActionPrimary
                      : neutral
                      ? (Theme.of(context).brightness == Brightness.dark
                            ? AushangTokens.darkSemanticActionNeutral
                            : AushangTokens.semanticActionNeutral)
                      : theme.colors.background,
                ),
              ),
              [FTappableVariant.pressed]: DecorationDelta.value(
                decoration(
                  primary
                      ? AushangTokens.semanticActionPrimaryPressed
                      : neutral
                      ? (Theme.of(context).brightness == Brightness.dark
                            ? AushangTokens.darkSemanticActionNeutralPressed
                            : AushangTokens.semanticActionNeutralPressed)
                      : theme.colors.secondary,
                ),
              ),
              [FTappableVariant.disabled]: DecorationDelta.value(
                decoration(theme.colors.muted),
              ),
            },
          ),
          foregroundColor: foreground,
          disabledForegroundColor: theme.colors.mutedForeground,
          textStyle: TextStyle(
            fontFamily: AushangTokens.primitiveFontFamily,
            fontWeight: FontWeight.w600,
            fontSize: widget.small ? 14 : AushangTokens.semanticTypeBody,
            height: 1.25,
          ),
          contentConstraints: BoxConstraints(
            minWidth: 48,
            minHeight: widget.small ? 48 : 52,
          ),
          contentPadding: widget.iconOnly
              ? const EdgeInsets.all(12)
              : const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          contentSpacing: 16,
          iconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          iconSize: 24,
          iconPadding: const EdgeInsets.all(12),
        ).copyWith(
          contentStyle: FButtonContentStyleDelta.delta(
            iconStyle: FVariants.from(
              IconThemeData(color: foreground, size: 24),
              variants: {
                [FTappableVariant.disabled]: IconThemeDataDelta.delta(
                  color: theme.colors.mutedForeground,
                ),
              },
            ),
            textStyle: FVariants.from(
              TextStyle(
                color: foreground,
                fontFamily: AushangTokens.primitiveFontFamily,
                fontWeight: FontWeight.w600,
                fontSize: widget.small ? 14 : AushangTokens.semanticTypeBody,
                height: 1.25,
              ),
              variants: {
                [FTappableVariant.disabled]: TextStyleDelta.delta(
                  color: theme.colors.mutedForeground,
                ),
              },
            ),
          ),
        );
    final reduced = MediaQuery.disableAnimationsOf(context);
    final animate = !reduced && !_keyboardInteraction;
    final hovering =
        _hovered &&
        _pointerKind != PointerDeviceKind.touch &&
        widget.onPressed != null &&
        animate;
    final offset = _pressed && _pointerKind != null && animate
        ? const Offset(1, 1)
        : hovering && widget.kind != AccessActionKind.ghost
        ? const Offset(-3, -3)
        : Offset.zero;
    Widget button = FBasicTheme(
      data: theme,
      child: FButton(
        focusNode: _focusNode,
        onPress: widget.onPressed,
        style: style,
        mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
        prefix: widget.prefix,
        suffix: widget.suffix,
        onHoverChange: (value) => setState(() => _hovered = value),
        onVariantChange: (_, current) {
          final pressed = current.contains(FTappableVariant.pressed);
          if (pressed != _pressed) setState(() => _pressed = pressed);
        },
        builder: (_, style, text, icons, progress, child) =>
            Flexible(child: child!),
        child: widget.child,
      ),
    );
    if (hovering && !_pressed && widget.kind != AccessActionKind.ghost) {
      button = DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: neutral ? AushangTokens.semanticSurfaceAccent : ink,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: button,
      );
    }
    button = TweenAnimationBuilder<Offset>(
      tween: Tween(end: offset),
      duration: !animate
          ? Duration.zero
          : _pressed
          ? AushangTokens.semanticMotionPress
          : AushangTokens.semanticMotionHover,
      curve: AushangTokens.primitiveEaseStandard,
      builder: (_, offset, child) =>
          Transform.translate(offset: offset, child: child),
      child: button,
    );
    button = Listener(
      onPointerDown: (event) => setState(() {
        _pointerKind = event.kind;
        _keyboardInteraction = false;
      }),
      onPointerHover: (event) {
        if (_pointerKind != event.kind || _keyboardInteraction) {
          setState(() {
            _pointerKind = event.kind;
            _keyboardInteraction = false;
          });
        }
      },
      child: button,
    );
    return widget.tooltip == null
        ? button
        : Tooltip(message: widget.tooltip!, child: button);
  }
}

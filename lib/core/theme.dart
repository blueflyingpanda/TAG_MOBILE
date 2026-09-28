import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Brand tokens, mirroring the CSS variables in TAG/src/index.css.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.secondary,
    required this.error,
    required this.success,
    required this.card,
    required this.text,
    required this.bgStart,
    required this.bgMid,
    required this.bgEnd,
  });

  final Color primary;
  final Color secondary;
  final Color error;
  final Color success;
  final Color card;
  final Color text;
  final Color bgStart;
  final Color bgMid;
  final Color bgEnd;

  static const light = AppColors(
    primary: Color(0xFF223164),
    secondary: Color(0xFFECACAE),
    error: Color(0xFFE53D00),
    success: Color(0xFF21A0A0),
    card: Color(0xFFFCFFF7),
    text: Color(0xFF222222),
    bgStart: Color(0xFFFDECC7),
    bgMid: Color(0xFFF2DEB5),
    bgEnd: Color(0xFFE7D0A4),
  );

  static const dark = AppColors(
    primary: Color(0xFF4A6FD4),
    secondary: Color(0xFFD28C8F),
    error: Color(0xFFFF5238),
    success: Color(0xFF26B5B5),
    card: Color(0xFF212540),
    text: Color(0xFFE8E8F4),
    bgStart: Color(0xFF1D2035),
    bgMid: Color(0xFF181B2D),
    bgEnd: Color(0xFF141626),
  );

  /// `text/[0.06]`-style tint used for subtle surfaces and borders.
  Color textA(double opacity) => text.withValues(alpha: opacity);

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
      card: Color.lerp(card, other.card, t)!,
      text: Color.lerp(text, other.text, t)!,
      bgStart: Color.lerp(bgStart, other.bgStart, t)!,
      bgMid: Color.lerp(bgMid, other.bgMid, t)!,
      bgEnd: Color.lerp(bgEnd, other.bgEnd, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

const gameRadius = 15.0;
final gameBorderRadius = BorderRadius.circular(gameRadius);

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: c.success,
    brightness: brightness,
  ).copyWith(
    primary: c.success,
    onPrimary: Colors.white,
    secondary: c.primary,
    error: c.error,
    surface: c.card,
    onSurface: c.text,
    surfaceContainerHighest: c.card,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: Colors.transparent,
    splashFactory: InkSparkle.splashFactory,
    extensions: [c],
  );

  final outline = OutlineInputBorder(
    borderRadius: gameBorderRadius,
    borderSide: BorderSide(color: c.textA(0.15)),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: c.text, displayColor: c.text),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: c.text,
      ),
      systemOverlayStyle: systemBarsStyle(brightness),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: outline,
      enabledBorder: outline,
      focusedBorder: outline.copyWith(borderSide: BorderSide(color: c.success, width: 2)),
      hintStyle: TextStyle(color: c.textA(0.4)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.card.withValues(alpha: 0.92),
      indicatorColor: c.success.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.success : c.textA(0.7)),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? c.success : c.textA(0.7),
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: c.textA(0.25),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: gameBorderRadius),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: gameBorderRadius),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.success,
      thumbColor: c.success,
      inactiveTrackColor: c.textA(0.15),
      activeTickMarkColor: Colors.white.withValues(alpha: 0.6),
      inactiveTickMarkColor: c.textA(0.25),
      valueIndicatorColor: c.success,
      showValueIndicator: ShowValueIndicator.onDrag,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : c.textA(0.6),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.success : c.textA(0.12),
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.transparent : c.textA(0.2),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.success),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

SystemUiOverlayStyle systemBarsStyle(Brightness b) => SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      statusBarIconBrightness: b == Brightness.dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: b,
      systemNavigationBarIconBrightness: b == Brightness.dark ? Brightness.light : Brightness.dark,
    );

/// The app-wide radial gradient from index.css:
/// `radial-gradient(circle at 85.54% 7.65%, start 0, mid 50%, end 100%)`.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth.isFinite ? box.maxWidth : 400.0;
      final h = box.maxHeight.isFinite ? box.maxHeight : 800.0;
      // CSS `circle` defaults to farthest-corner; Flutter's radius is relative
      // to the shortest side.
      final farthest = math.sqrt(math.pow(0.8554 * w, 2) + math.pow(0.9235 * h, 2));
      return DecoratedBox(
        decoration: BoxDecoration(
          color: c.bgEnd,
          gradient: RadialGradient(
            center: const Alignment(0.7108, -0.847),
            radius: farthest / math.min(w, h),
            colors: [c.bgStart, c.bgMid, c.bgEnd],
            stops: const [0, 0.5, 1],
          ),
        ),
        child: child,
      );
    });
  }
}

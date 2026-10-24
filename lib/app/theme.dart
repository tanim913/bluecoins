import 'package:flutter/material.dart';

/// Palette from the user's reference screenshot. Everything else is a tonal step of it.
const navy = Color(0xFF2B385A);
const indigo = Color(0xFF3D4B78);
const sky = Color(0xFF73B7F1);

/// Colors that have no Material role. Read with `context.palette`.
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.good,
    required this.warn,
    required this.muted,
    required this.track,
  });

  final Color good, warn;

  /// Secondary text; always at least 4.5:1 on every surface it sits on.
  final Color muted;

  /// Empty part of a progress bar.
  final Color track;

  static const dark = Palette(
    good: Color(0xFF6FD3A8),
    warn: Color(0xFFF2C86B),
    muted: Color(0xFFC3CBE2),
    track: Color(0x59050A1C),
  );
  static const light = Palette(
    good: Color(0xFF1B7F5A),
    warn: Color(0xFF8A5A00),
    muted: Color(0xFF4F5B82),
    track: Color(0xFFD9E1F2),
  );

  @override
  Palette copyWith({Color? good, Color? warn, Color? muted, Color? track}) =>
      Palette(
        good: good ?? this.good,
        warn: warn ?? this.warn,
        muted: muted ?? this.muted,
        track: track ?? this.track,
      );

  @override
  Palette lerp(Palette? other, double t) => other == null
      ? this
      : Palette(
          good: Color.lerp(good, other.good, t)!,
          warn: Color.lerp(warn, other.warn, t)!,
          muted: Color.lerp(muted, other.muted, t)!,
          track: Color.lerp(track, other.track, t)!,
        );
}

extension PaletteX on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>()!;
}

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: sky,
  onPrimary: Color(0xFF14203F),
  primaryContainer: Color(0xFF4A5B92),
  onPrimaryContainer: Colors.white,
  secondary: Color(0xFFA9C7F5),
  onSecondary: Color(0xFF14203F),
  secondaryContainer: Color(0xFF4A5B92),
  onSecondaryContainer: Colors.white,
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF4A0F0F),
  surface: Color(0xFF0C1329),
  onSurface: Colors.white,
  onSurfaceVariant: Color(0xFFC3CBE2),
  outline: Color(0xFF8E9AC0),
  outlineVariant: Color(0x2EFFFFFF),
  surfaceContainerLowest: Color(0x14FFFFFF),
  surfaceContainerLow: Color(0xFF131C3B),
  surfaceContainer: Color(0xFF18234A),
  surfaceContainerHigh: Color(0xFF212D5A),
  surfaceContainerHighest: Color(0xFF2B3868),
);

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: indigo,
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFCFE6FB),
  onPrimaryContainer: navy,
  secondary: Color(0xFF4A6FA5),
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFCFE6FB),
  onSecondaryContainer: navy,
  error: Color(0xFFB3261E),
  onError: Colors.white,
  surface: Color(0xFFEDF2FB),
  onSurface: navy,
  onSurfaceVariant: Color(0xFF4F5B82),
  outline: Color(0xFF6F7BA0),
  outlineVariant: Color(0xFFCBD4E8),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Color(0xFFF9FBFE),
  surfaceContainer: Color(0xFFEEF2FA),
  surfaceContainerHigh: Color(0xFFE6ECF8),
  surfaceContainerHighest: Color(0xFFDCE4F4),
);

const _tabular = [FontFeature.tabularFigures()];

TextTheme _text(Color c) {
  TextStyle s(
    double size,
    FontWeight w, {
    double h = 1.3,
    double ls = 0,
    bool nums = false,
  }) => TextStyle(
    fontFamily: 'NotoSans',
    fontFamilyFallback: const ['NotoSansBengali'],
    fontSize: size,
    fontWeight: w,
    height: h,
    letterSpacing: ls,
    color: c,
    fontFeatures: nums ? _tabular : null,
  );
  return TextTheme(
    displayLarge: s(44, FontWeight.w700, h: 1.1, ls: -0.5, nums: true),
    displayMedium: s(36, FontWeight.w700, h: 1.1, ls: -0.3, nums: true),
    headlineMedium: s(24, FontWeight.w700, nums: true),
    titleLarge: s(20, FontWeight.w700),
    titleMedium: s(17, FontWeight.w500),
    titleSmall: s(15, FontWeight.w500),
    bodyLarge: s(16, FontWeight.w400, h: 1.45),
    bodyMedium: s(15, FontWeight.w400, h: 1.4, nums: true),
    bodySmall: s(13, FontWeight.w400, h: 1.35, nums: true),
    labelLarge: s(15, FontWeight.w500, h: 1.2),
    labelMedium: s(13, FontWeight.w500, h: 1.2),
    labelSmall: s(12, FontWeight.w500, h: 1.2),
  );
}

ThemeData buildTheme(Brightness b) {
  final s = b == Brightness.dark ? _darkScheme : _lightScheme;
  final text = _text(s.onSurface);
  const round = 16.0;
  OutlineInputBorder border(Color c, [double w = 0]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(round),
    borderSide: w == 0 ? BorderSide.none : BorderSide(color: c, width: w),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: s,
    scaffoldBackgroundColor: s.surface,
    textTheme: text,
    extensions: [b == Brightness.dark ? Palette.dark : Palette.light],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: s.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: s.secondaryContainer,
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: s.onSurface)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: s.primary,
      foregroundColor: s.onPrimary,
      elevation: 6,
      highlightElevation: 8,
      extendedTextStyle: text.labelLarge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(round),
        ),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        side: BorderSide(color: s.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(round),
        ),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: text.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: s.surfaceContainerLowest,
      border: border(s.outline, 1),
      enabledBorder: border(s.outline, 1),
      focusedBorder: border(s.primary, 2),
      errorBorder: border(s.error, 2),
      focusedErrorBorder: border(s.error, 2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: text.bodyMedium?.copyWith(color: s.onSurfaceVariant),
      helperStyle: text.bodySmall?.copyWith(color: s.onSurfaceVariant),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: s.surfaceContainerHighest,
      contentTextStyle: text.bodyMedium,
      actionTextColor: s.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(round)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: s.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: s.outlineVariant),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: s.surfaceContainerLowest,
      selectedColor: s.secondaryContainer,
      labelStyle: text.labelLarge,
      side: BorderSide(color: s.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(
      color: s.outlineVariant,
      space: 1,
      thickness: 1,
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: 12,
      titleTextStyle: text.titleSmall,
      subtitleTextStyle: text.bodySmall?.copyWith(color: s.onSurfaceVariant),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: text.labelLarge,
        selectedBackgroundColor: s.secondaryContainer,
        selectedForegroundColor: s.onSecondaryContainer,
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: s.primary,
      selectionHandleColor: s.primary,
    ),
  );
}

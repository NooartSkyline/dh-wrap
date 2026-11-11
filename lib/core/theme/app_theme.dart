import 'package:flutter/material.dart';

class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.seed,
    required this.ink,
    required this.leaf,
    required this.canvas,
    required this.card,
    required this.line,
    required this.mint,
    required this.muted,
    required this.onInkMuted,
    required this.working,
    required this.workingWash,
    required this.idle,
    required this.idleWash,
  });

  static const standardSeed = Color(0xFF1B7A4E);

  static const standard = AppColors(
    seed: standardSeed,
    ink: Color(0xFF0E3B2E),
    leaf: Color(0xFF1B7A4E),
    canvas: Color(0xFFF3F6F4),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFD7E3DC),
    mint: Color(0xFFE5F4EC),
    muted: Color(0xFF5C6F66),
    onInkMuted: Color(0xFFD5E7DE),
    working: Color(0xFF0E6B45),
    workingWash: Color(0xFFDDF3E7),
    idle: Color(0xFF8A5A12),
    idleWash: Color(0xFFF8EBD3),
  );

  final Color seed;
  final Color ink;
  final Color leaf;
  final Color canvas;
  final Color card;
  final Color line;
  final Color mint;
  final Color muted;
  final Color onInkMuted;
  final Color working;
  final Color workingWash;
  final Color idle;
  final Color idleWash;

  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>() ?? standard;
  }

  static AppColors fromSeed(Color seed) {
    if (seed.toARGB32() == standardSeed.toARGB32()) return standard;
    final hsl = HSLColor.fromColor(seed);
    Color tone(double lightness, double saturation) {
      return hsl
          .withLightness(lightness.clamp(0, 1))
          .withSaturation(saturation.clamp(0, 1))
          .toColor();
    }

    final saturation = hsl.saturation;
    var accentLight = hsl.lightness;
    if (accentLight > 0.55) accentLight = 0.42;
    if (accentLight < 0.24) accentLight = 0.34;
    final accentSaturation = saturation < 0.2 ? 0.45 : saturation;

    return AppColors(
      seed: seed,
      ink: tone(0.16, saturation * 0.75 < 0.12 ? 0.12 : saturation * 0.75),
      leaf: hsl
          .withLightness(accentLight)
          .withSaturation(accentSaturation.clamp(0, 1))
          .toColor(),
      canvas: tone(0.96, saturation * 0.22 < 0.04 ? 0.04 : saturation * 0.22),
      card: const Color(0xFFFFFFFF),
      line: tone(0.86, saturation * 0.28 < 0.06 ? 0.06 : saturation * 0.28),
      mint: tone(0.93, saturation * 0.4 < 0.08 ? 0.08 : saturation * 0.4),
      muted: tone(0.4, saturation * 0.18 < 0.05 ? 0.05 : saturation * 0.18),
      onInkMuted: tone(
        0.88,
        saturation * 0.28 < 0.08 ? 0.08 : saturation * 0.28,
      ),
      working: standard.working,
      workingWash: standard.workingWash,
      idle: standard.idle,
      idleWash: standard.idleWash,
    );
  }

  @override
  AppColors copyWith({
    Color? seed,
    Color? ink,
    Color? leaf,
    Color? canvas,
    Color? card,
    Color? line,
    Color? mint,
    Color? muted,
    Color? onInkMuted,
    Color? working,
    Color? workingWash,
    Color? idle,
    Color? idleWash,
  }) {
    return AppColors(
      seed: seed ?? this.seed,
      ink: ink ?? this.ink,
      leaf: leaf ?? this.leaf,
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      line: line ?? this.line,
      mint: mint ?? this.mint,
      muted: muted ?? this.muted,
      onInkMuted: onInkMuted ?? this.onInkMuted,
      working: working ?? this.working,
      workingWash: workingWash ?? this.workingWash,
      idle: idle ?? this.idle,
      idleWash: idleWash ?? this.idleWash,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      seed: mix(seed, other.seed),
      ink: mix(ink, other.ink),
      leaf: mix(leaf, other.leaf),
      canvas: mix(canvas, other.canvas),
      card: mix(card, other.card),
      line: mix(line, other.line),
      mint: mix(mint, other.mint),
      muted: mix(muted, other.muted),
      onInkMuted: mix(onInkMuted, other.onInkMuted),
      working: mix(working, other.working),
      workingWash: mix(workingWash, other.workingWash),
      idle: mix(idle, other.idle),
      idleWash: mix(idleWash, other.idleWash),
    );
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData light(Color seed) {
    final colors = AppColors.fromSeed(seed);
    final scheme = ColorScheme.fromSeed(
      seedColor: colors.leaf,
      primary: colors.leaf,
      onPrimary: Colors.white,
      surface: colors.card,
    );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: colors.canvas,
      extensions: [colors],
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: colors.ink,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: colors.ink,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: colors.ink,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.ink,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.ink,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.card,
        hintStyle: TextStyle(color: colors.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.leaf, width: 1.4),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colors.card,
        side: BorderSide(color: colors.line),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(color: colors.ink, fontWeight: FontWeight.w600),
      ),
    );
  }
}

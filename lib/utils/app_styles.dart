import 'package:flutter/material.dart';

class AppTextStyles {
  static const String _fontFamilyRegular = 'SFProRounded Regular';
  static const String _fontFamilyMedium = 'SFProRounded Medium';
  static const String _fontFamilyBold = 'SFProRounded Bold';

  // Headline styles
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: _fontFamilyBold,
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );
  static const TextStyle headlineMedium = TextStyle(
    fontFamily: _fontFamilyMedium,
    fontSize: 28,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle headlineSmall = TextStyle(
    fontFamily: _fontFamilyMedium,
    fontSize: 24,
    fontWeight: FontWeight.w600,
  );

  // Title styles
  static const TextStyle titleLarge = TextStyle(
    fontFamily: _fontFamilyMedium,
    fontSize: 22,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle titleMedium = TextStyle(
    fontFamily: _fontFamilyMedium,
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle titleSmall = TextStyle(
    fontFamily: _fontFamilyMedium,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  // Body styles
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamilyRegular,
    fontSize: 16,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamilyRegular,
    fontSize: 14,
  );
  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamilyRegular,
    fontSize: 12,
  );

  // Label styles
  static const TextStyle labelLarge = TextStyle(
    fontFamily: _fontFamilyMedium,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle labelMedium = TextStyle(
    fontFamily: _fontFamilyRegular,
    fontSize: 12,
  );
  static const TextStyle labelSmall = TextStyle(
    fontFamily: _fontFamilyRegular,
    fontSize: 10,
  );

  // Button style
  static const TextStyle button = TextStyle(
    fontFamily: _fontFamilyMedium,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum StorefrontTheme {
  modern,
  vibrant,
  elegant,
  eco;

  String get displayName {
    switch (this) {
      case StorefrontTheme.modern:
        return 'Modern/Minimalist';
      case StorefrontTheme.vibrant:
        return 'Bold/Vibrant';
      case StorefrontTheme.elegant:
        return 'Elegant/Classic';
      case StorefrontTheme.eco:
        return 'Eco/Natural';
    }
  }

  String get description {
    switch (this) {
      case StorefrontTheme.modern:
        return 'נקי, פשוט, צבעים רכים';
      case StorefrontTheme.vibrant:
        return 'צבעוני, אנרגטי, גראדיאנטים';
      case StorefrontTheme.elegant:
        return 'אלגנטי, צבעים כהים, זהב/כסף';
      case StorefrontTheme.eco:
        return 'ירוקים, חומים, טבעי';
    }
  }
}

class StorefrontCustomization {
  final StorefrontTheme theme;

  final String? customPrimaryColor;
  final String? customAccentColor;
  final String? customBackgroundColor;
  final String? customTextColor;

  final String? logoUrl;
  final String? bannerUrl;

  final String? storeDescription;
  final String? storeTagline;

  final String? instagramUrl;
  final String? facebookUrl;
  final String? whatsappNumber;
  final String? websiteUrl;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  StorefrontCustomization({
    required this.theme,
    this.customPrimaryColor,
    this.customAccentColor,
    this.customBackgroundColor,
    this.customTextColor,
    this.logoUrl,
    this.bannerUrl,
    this.storeDescription,
    this.storeTagline,
    this.instagramUrl,
    this.facebookUrl,
    this.whatsappNumber,
    this.websiteUrl,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  bool hasCustomColors() {
    return customPrimaryColor != null ||
        customAccentColor != null ||
        customBackgroundColor != null ||
        customTextColor != null;
  }

  bool hasAnySocialLinks() {
    return instagramUrl != null ||
        facebookUrl != null ||
        whatsappNumber != null ||
        websiteUrl != null;
  }

  bool hasLogo() => logoUrl != null;

  bool hasBanner() => bannerUrl != null;

  Color? getPrimaryColor() {
    if (customPrimaryColor == null) return null;
    return _colorFromHex(customPrimaryColor!);
  }

  Color? getAccentColor() {
    if (customAccentColor == null) return null;
    return _colorFromHex(customAccentColor!);
  }

  Color? getBackgroundColor() {
    if (customBackgroundColor == null) return null;
    return _colorFromHex(customBackgroundColor!);
  }

  Color? getTextColor() {
    if (customTextColor == null) return null;
    return _colorFromHex(customTextColor!);
  }

  Color _colorFromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Map<String, dynamic> toMap() {
    return {
      'theme': theme.name,
      'customPrimaryColor': customPrimaryColor,
      'customAccentColor': customAccentColor,
      'customBackgroundColor': customBackgroundColor,
      'customTextColor': customTextColor,
      'logoUrl': logoUrl,
      'bannerUrl': bannerUrl,
      'storeDescription': storeDescription,
      'storeTagline': storeTagline,
      'instagramUrl': instagramUrl,
      'facebookUrl': facebookUrl,
      'whatsappNumber': whatsappNumber,
      'websiteUrl': websiteUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  factory StorefrontCustomization.fromMap(Map<String, dynamic> map) {
    return StorefrontCustomization(
      theme: StorefrontTheme.values.firstWhere(
        (t) => t.name == map['theme'],
        orElse: () => StorefrontTheme.modern,
      ),
      customPrimaryColor: map['customPrimaryColor'] as String?,
      customAccentColor: map['customAccentColor'] as String?,
      customBackgroundColor: map['customBackgroundColor'] as String?,
      customTextColor: map['customTextColor'] as String?,
      logoUrl: map['logoUrl'] as String?,
      bannerUrl: map['bannerUrl'] as String?,
      storeDescription: map['storeDescription'] as String?,
      storeTagline: map['storeTagline'] as String?,
      instagramUrl: map['instagramUrl'] as String?,
      facebookUrl: map['facebookUrl'] as String?,
      whatsappNumber: map['whatsappNumber'] as String?,
      websiteUrl: map['websiteUrl'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  factory StorefrontCustomization.defaultTheme() {
    final now = DateTime.now();
    return StorefrontCustomization(
      theme: StorefrontTheme.modern,
      createdAt: now,
      updatedAt: now,
      isActive: true,
    );
  }

  StorefrontCustomization copyWith({
    StorefrontTheme? theme,
    Object? customPrimaryColor = _unset,
    Object? customAccentColor = _unset,
    Object? customBackgroundColor = _unset,
    Object? customTextColor = _unset,
    Object? logoUrl = _unset,
    Object? bannerUrl = _unset,
    Object? storeDescription = _unset,
    Object? storeTagline = _unset,
    Object? instagramUrl = _unset,
    Object? facebookUrl = _unset,
    Object? whatsappNumber = _unset,
    Object? websiteUrl = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return StorefrontCustomization(
      theme: theme ?? this.theme,
      customPrimaryColor: identical(customPrimaryColor, _unset)
          ? this.customPrimaryColor
          : customPrimaryColor as String?,
      customAccentColor: identical(customAccentColor, _unset)
          ? this.customAccentColor
          : customAccentColor as String?,
      customBackgroundColor: identical(customBackgroundColor, _unset)
          ? this.customBackgroundColor
          : customBackgroundColor as String?,
      customTextColor: identical(customTextColor, _unset)
          ? this.customTextColor
          : customTextColor as String?,
      logoUrl: identical(logoUrl, _unset) ? this.logoUrl : logoUrl as String?,
      bannerUrl: identical(bannerUrl, _unset)
          ? this.bannerUrl
          : bannerUrl as String?,
      storeDescription: identical(storeDescription, _unset)
          ? this.storeDescription
          : storeDescription as String?,
      storeTagline: identical(storeTagline, _unset)
          ? this.storeTagline
          : storeTagline as String?,
      instagramUrl: identical(instagramUrl, _unset)
          ? this.instagramUrl
          : instagramUrl as String?,
      facebookUrl: identical(facebookUrl, _unset)
          ? this.facebookUrl
          : facebookUrl as String?,
      whatsappNumber: identical(whatsappNumber, _unset)
          ? this.whatsappNumber
          : whatsappNumber as String?,
      websiteUrl: identical(websiteUrl, _unset)
          ? this.websiteUrl
          : websiteUrl as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

const Object _unset = Object();

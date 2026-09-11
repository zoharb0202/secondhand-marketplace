import '../../../shared/models/seller_storefront_model.dart';

class ValidationResult {
  final bool isValid;
  final List<String> errors;

  ValidationResult({required this.isValid, required this.errors});

  ValidationResult.success() : isValid = true, errors = [];

  ValidationResult.failure(List<String> errors)
    : isValid = false,
      errors = errors;
}

class StorefrontValidator {
  static const int maxDescriptionLength = 1000;
  static const int maxTaglineLength = 50;

  static ValidationResult validateCustomization(
    StorefrontCustomization customization,
  ) {
    final errors = <String>[];

    if ((customization.storeDescription?.length ?? 0) > maxDescriptionLength) {
      errors.add('תיאור החנות מוגבל ל-$maxDescriptionLength תווים');
    }

    if ((customization.storeTagline?.length ?? 0) > maxTaglineLength) {
      errors.add('הסלוגן מוגבל ל-$maxTaglineLength תווים');
    }

    if (customization.instagramUrl != null) {
      if (!_isValidUrl(customization.instagramUrl!)) {
        errors.add('קישור Instagram לא תקין');
      }
    }

    if (customization.facebookUrl != null) {
      if (!_isValidUrl(customization.facebookUrl!)) {
        errors.add('קישור Facebook לא תקין');
      }
    }

    if (customization.websiteUrl != null) {
      if (!_isValidUrl(customization.websiteUrl!)) {
        errors.add('קישור אתר לא תקין');
      }
    }

    if (customization.whatsappNumber != null) {
      if (!_isValidPhoneNumber(customization.whatsappNumber!)) {
        errors.add('מספר WhatsApp לא תקין (דוגמה: +972501234567)');
      }
    }

    if (customization.customPrimaryColor != null) {
      if (!_isValidHexColor(customization.customPrimaryColor!)) {
        errors.add('צבע ראשי לא תקין (נדרש פורמט HEX)');
      }
    }

    if (customization.customAccentColor != null) {
      if (!_isValidHexColor(customization.customAccentColor!)) {
        errors.add('צבע משני לא תקין (נדרש פורמט HEX)');
      }
    }

    if (customization.customBackgroundColor != null) {
      if (!_isValidHexColor(customization.customBackgroundColor!)) {
        errors.add('צבע רקע לא תקין (נדרש פורמט HEX)');
      }
    }

    if (customization.customTextColor != null) {
      if (!_isValidHexColor(customization.customTextColor!)) {
        errors.add('צבע טקסט לא תקין (נדרש פורמט HEX)');
      }
    }

    return errors.isEmpty
        ? ValidationResult.success()
        : ValidationResult.failure(errors);
  }

  static bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  static bool _isValidPhoneNumber(String phone) {
    final phoneRegex = RegExp(r'^\+[1-9]\d{9,14}$');
    return phoneRegex.hasMatch(phone);
  }

  static bool _isValidHexColor(String color) {
    final hexRegex = RegExp(r'^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$');
    return hexRegex.hasMatch(color);
  }
}

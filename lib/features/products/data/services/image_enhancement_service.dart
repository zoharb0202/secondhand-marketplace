import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageEnhancementService {
  Future<String> enhanceImage(String originalPath) async {
    try {
      if (kDebugMode) {
        print('🎨 Starting image enhancement for: $originalPath');
      }

      final bytes = await File(originalPath).readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      if (kDebugMode) {
        print('📐 Original size: ${image.width}x${image.height}');
      }

      image = _autoLevels(image);
      image = _enhanceContrast(image, factor: 1.15);
      image = _enhanceBrightness(image);
      image = _enhanceSaturation(image, factor: 1.1);
      image = _sharpen(image, amount: 1.2);

      if (kDebugMode) {
        print('✅ Enhancements applied');
      }

      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final enhancedPath = '${dir.path}/enhanced_$timestamp.jpg';

      final enhancedBytes = img.encodeJpg(image, quality: 95);
      await File(enhancedPath).writeAsBytes(enhancedBytes);

      if (kDebugMode) {
        print('💾 Enhanced image saved: $enhancedPath');
      }

      return enhancedPath;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error enhancing image: $e');
      }
      rethrow;
    }
  }

  img.Image _autoLevels(img.Image image) {
    final histogram = List.generate(256, (_) => 0);

    for (final pixel in image) {
      final luminance = _getLuminance(
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
      );
      histogram[luminance]++;
    }

    final totalPixels = image.width * image.height;
    final threshold = (totalPixels * 0.01).toInt();

    int minLevel = 0;
    int maxLevel = 255;
    int count = 0;

    for (int i = 0; i < 256; i++) {
      count += histogram[i];
      if (count > threshold) {
        minLevel = i;
        break;
      }
    }

    count = 0;
    for (int i = 255; i >= 0; i--) {
      count += histogram[i];
      if (count > threshold) {
        maxLevel = i;
        break;
      }
    }

    if (maxLevel > minLevel) {
      final scale = 255.0 / (maxLevel - minLevel);

      for (final pixel in image) {
        final r = ((pixel.r - minLevel) * scale).clamp(0, 255).toInt();
        final g = ((pixel.g - minLevel) * scale).clamp(0, 255).toInt();
        final b = ((pixel.b - minLevel) * scale).clamp(0, 255).toInt();

        pixel.setRgb(r, g, b);
      }
    }

    return image;
  }

  img.Image _enhanceContrast(img.Image image, {double factor = 1.2}) {
    final contrastLUT = List.generate(256, (i) {
      final normalized = i / 255.0;
      final adjusted = 1 / (1 + math.exp(-(normalized - 0.5) * factor * 10));
      return (adjusted * 255).clamp(0, 255).toInt();
    });

    for (final pixel in image) {
      pixel.setRgb(
        contrastLUT[pixel.r.toInt()],
        contrastLUT[pixel.g.toInt()],
        contrastLUT[pixel.b.toInt()],
      );
    }

    return image;
  }

  img.Image _enhanceBrightness(img.Image image) {
    int totalBrightness = 0;
    final totalPixels = image.width * image.height;

    for (final pixel in image) {
      totalBrightness += _getLuminance(
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
      );
    }

    final avgBrightness = totalBrightness / totalPixels;

    if (avgBrightness < 128) {
      final adjustment = ((128 - avgBrightness) * 0.3).toInt();

      for (final pixel in image) {
        pixel.setRgb(
          (pixel.r + adjustment).clamp(0, 255).toInt(),
          (pixel.g + adjustment).clamp(0, 255).toInt(),
          (pixel.b + adjustment).clamp(0, 255).toInt(),
        );
      }
    }

    return image;
  }

  img.Image _enhanceSaturation(img.Image image, {double factor = 1.2}) {
    for (final pixel in image) {
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();

      final hsl = _rgbToHsl(r, g, b);

      hsl[1] = (hsl[1] * factor).clamp(0.0, 1.0);

      final rgb = _hslToRgb(hsl[0], hsl[1], hsl[2]);

      pixel.setRgb(rgb[0], rgb[1], rgb[2]);
    }

    return image;
  }

  img.Image _sharpen(img.Image image, {double amount = 1.5}) {
    final blurred = img.gaussianBlur(image, radius: 1);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final original = image.getPixel(x, y);
        final blur = blurred.getPixel(x, y);

        final r = (original.r + amount * (original.r - blur.r))
            .clamp(0, 255)
            .toInt();
        final g = (original.g + amount * (original.g - blur.g))
            .clamp(0, 255)
            .toInt();
        final b = (original.b + amount * (original.b - blur.b))
            .clamp(0, 255)
            .toInt();

        image.getPixel(x, y).setRgb(r, g, b);
      }
    }

    return image;
  }

  int _getLuminance(int r, int g, int b) {
    return (0.299 * r + 0.587 * g + 0.114 * b).toInt();
  }

  List<double> _rgbToHsl(int r, int g, int b) {
    final rNorm = r / 255.0;
    final gNorm = g / 255.0;
    final bNorm = b / 255.0;

    final max = math.max(rNorm, math.max(gNorm, bNorm));
    final min = math.min(rNorm, math.min(gNorm, bNorm));
    final delta = max - min;

    double h = 0;
    double s = 0;
    final l = (max + min) / 2;

    if (delta != 0) {
      s = l > 0.5 ? delta / (2 - max - min) : delta / (max + min);

      if (max == rNorm) {
        h = ((gNorm - bNorm) / delta + (gNorm < bNorm ? 6 : 0)) / 6;
      } else if (max == gNorm) {
        h = ((bNorm - rNorm) / delta + 2) / 6;
      } else {
        h = ((rNorm - gNorm) / delta + 4) / 6;
      }
    }

    return [h, s, l];
  }

  List<int> _hslToRgb(double h, double s, double l) {
    double r, g, b;

    if (s == 0) {
      r = g = b = l;
    } else {
      final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      final p = 2 * l - q;

      r = _hueToRgb(p, q, h + 1 / 3);
      g = _hueToRgb(p, q, h);
      b = _hueToRgb(p, q, h - 1 / 3);
    }

    return [
      (r * 255).round().clamp(0, 255),
      (g * 255).round().clamp(0, 255),
      (b * 255).round().clamp(0, 255),
    ];
  }

  double _hueToRgb(double p, double q, double t) {
    double tNorm = t;
    if (tNorm < 0) tNorm += 1;
    if (tNorm > 1) tNorm -= 1;
    if (tNorm < 1 / 6) return p + (q - p) * 6 * tNorm;
    if (tNorm < 1 / 2) return q;
    if (tNorm < 2 / 3) return p + (q - p) * (2 / 3 - tNorm) * 6;
    return p;
  }
}

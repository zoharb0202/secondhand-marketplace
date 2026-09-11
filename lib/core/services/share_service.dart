import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/models/product_model.dart';
import '../theme/app_colors.dart';
import '../constants/app_constants.dart';

class ShareService {
  static const String _baseUrl = AppConstants.webBaseUrl;

  static String productLink(String productId) => '$_baseUrl/product/$productId';

  static String buildProductMessage(ProductModel product) {
    final desc = product.description.length > 100
        ? '${product.description.substring(0, 100)}...'
        : product.description;
    return '''
🛒 ${product.title}

💰 מחיר: ₪${product.price.toStringAsFixed(0)}
📦 מצב: ${product.condition.displayName}
📍 מיקום: ${product.city}

$desc

👀 לצפייה ולרכישה:
${productLink(product.id)}''';
  }

  static Future<bool> shareToWhatsApp(ProductModel product) async {
    final text = Uri.encodeComponent(buildProductMessage(product));
    final uri = Uri.parse('https://wa.me/?text=$text');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }

  static Future<void> shareGeneric(ProductModel product) {
    return Share.share(buildProductMessage(product), subject: product.title);
  }

  static void showShareSheet(BuildContext context, ProductModel product) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'שיתוף המוצר',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF25D366),
                child: Icon(Icons.chat, color: Colors.white),
              ),
              title: const Text('שתף בוואטסאפ'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final ok = await shareToWhatsApp(product);
                if (!ok) await shareGeneric(product);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.ios_share, color: Colors.white),
              ),
              title: const Text('אפשרויות נוספות'),
              onTap: () {
                Navigator.pop(sheetContext);
                shareGeneric(product);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

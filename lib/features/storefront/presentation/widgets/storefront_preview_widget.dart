import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/storefront_themes.dart';
import '../../../../shared/models/seller_storefront_model.dart';

class StorefrontPreviewWidget extends StatelessWidget {
  final StorefrontCustomization customization;
  final String? sellerName;

  const StorefrontPreviewWidget({
    super.key,
    required this.customization,
    this.sellerName,
  });

  @override
  Widget build(BuildContext context) {
    final preset = StorefrontThemePreset.applyCustomization(
      customization.theme,
      customization,
    );

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: preset.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: customization.hasBanner()
                  ? null
                  : (preset.headerGradient ??
                        LinearGradient(
                          colors: [preset.primaryColor, preset.primaryColor],
                        )),
              image: customization.bannerUrl != null
                  ? DecorationImage(
                      image: NetworkImage(customization.bannerUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: customization.hasLogo()
                              ? Colors.white
                              : preset.primaryColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          image: customization.logoUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(customization.logoUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: customization.logoUrl == null
                            ? Icon(
                                Icons.store,
                                color: preset.primaryColor,
                                size: 24,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sellerName ?? 'שם החנות',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: preset.textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (customization.storeTagline != null)
                              Text(
                                customization.storeTagline!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: preset.textColor.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (customization.storeDescription != null)
                    Text(
                      customization.storeDescription!,
                      style: TextStyle(
                        fontSize: 11,
                        color: preset.textColor.withValues(alpha: 0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),

                  const Spacer(),

                  if (customization.hasAnySocialLinks())
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (customization.instagramUrl != null)
                          _buildSocialIcon(
                            Icons.camera_alt,
                            preset.accentColor,
                          ),
                        if (customization.facebookUrl != null)
                          _buildSocialIcon(Icons.facebook, preset.accentColor),
                        if (customization.whatsappNumber != null)
                          _buildSocialIcon(Icons.chat, preset.accentColor),
                        if (customization.websiteUrl != null)
                          _buildSocialIcon(Icons.language, preset.accentColor),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

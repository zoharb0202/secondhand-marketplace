import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/storefront_themes.dart';
import '../../../../shared/models/seller_storefront_model.dart';
import '../../../../shared/models/user_model.dart';

class CustomStorefrontHeader extends StatelessWidget {
  final StorefrontCustomization customization;
  final UserModel seller;

  final bool showStatsRow;

  final bool showVerifiedBadge;

  final bool showBottomDivider;

  const CustomStorefrontHeader({
    super.key,
    required this.customization,
    required this.seller,
    this.showStatsRow = true,
    this.showVerifiedBadge = true,
    this.showBottomDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final preset = StorefrontThemePreset.applyCustomization(
      customization.theme,
      customization,
    );

    return Container(
      color: preset.backgroundColor,
      child: Column(
        children: [
          if (customization.hasBanner())
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(customization.bannerUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: customization.hasCustomColors()
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          preset.primaryColor,
                          preset.primaryColor.withValues(alpha: 0.8),
                        ],
                      )
                    : (preset.headerGradient ??
                          LinearGradient(
                            colors: [preset.primaryColor, preset.primaryColor],
                          )),
              ),
            ),

          Transform.translate(
            offset: customization.hasBanner()
                ? const Offset(0, -50)
                : const Offset(0, 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  if (customization.hasLogo())
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        image: DecorationImage(
                          image: NetworkImage(customization.logoUrl!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: preset.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: seller.photoUrl != null
                          ? ClipOval(
                              child: Image.network(
                                seller.photoUrl!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Center(
                              child: Text(
                                seller.displayName
                                        ?.substring(0, 1)
                                        .toUpperCase() ??
                                    'S',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),

                  const SizedBox(height: 16),

                  Text(
                    seller.displayName ?? 'חנות',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: preset.textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  if (showVerifiedBadge && seller.isSellerVerified) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified,
                          color: preset.accentColor,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'מוכר מאומת',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: preset.accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ],

                  if (customization.storeTagline != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      customization.storeTagline!,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: preset.textColor.withValues(alpha: 0.8),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  if (showStatsRow) ...[
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem(
                          context,
                          label: 'מכירות',
                          value: seller.totalSales.toString(),
                          icon: Icons.shopping_bag_outlined,
                          color: preset.primaryColor,
                        ),
                        _buildStatItem(
                          context,
                          label: 'דירוג',
                          value: seller.sellerRating?.toStringAsFixed(1) ?? '-',
                          icon: Icons.star_outlined,
                          color: preset.accentColor,
                        ),
                        _buildStatItem(
                          context,
                          label: 'ביקורות',
                          value: '0',
                          icon: Icons.rate_review_outlined,
                          color: preset.primaryColor,
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),

                  if (customization.storeDescription != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: preset.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: preset.dividerColor),
                      ),
                      child: Text(
                        customization.storeDescription!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: preset.textColor,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (customization.hasAnySocialLinks()) ...[
                    Text(
                      'עקבו אחרינו',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: preset.textColor.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        if (customization.instagramUrl != null)
                          _buildSocialButton(
                            icon: Icons.camera_alt,
                            color: const Color(0xFFE4405F),
                            onTap: () =>
                                _launchUrl(customization.instagramUrl!),
                          ),
                        if (customization.facebookUrl != null)
                          _buildSocialButton(
                            icon: Icons.facebook,
                            color: const Color(0xFF1877F2),
                            onTap: () => _launchUrl(customization.facebookUrl!),
                          ),
                        if (customization.whatsappNumber != null)
                          _buildSocialButton(
                            icon: Icons.chat,
                            color: const Color(0xFF25D366),
                            onTap: () =>
                                _launchWhatsApp(customization.whatsappNumber!),
                          ),
                        if (customization.websiteUrl != null)
                          _buildSocialButton(
                            icon: Icons.language,
                            color: preset.accentColor,
                            onTap: () => _launchUrl(customization.websiteUrl!),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (showBottomDivider)
                    Divider(color: preset.dividerColor, thickness: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchWhatsApp(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    final uri = Uri.parse('https://wa.me/$cleanNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

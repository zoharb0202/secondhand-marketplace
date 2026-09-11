import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/storefront_themes.dart';
import '../../../../shared/models/seller_storefront_model.dart';

class ThemeSelectorWidget extends ConsumerWidget {
  final StorefrontTheme selectedTheme;
  final Function(StorefrontTheme) onThemeSelected;

  const ThemeSelectorWidget({
    super.key,
    required this.selectedTheme,
    required this.onThemeSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'בחר ערכת נושא',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'בחר עיצוב שמתאים למותג שלך',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.85,
          children: [
            _buildThemeCard(
              context,
              StorefrontTheme.modern,
              StorefrontThemePreset.modern,
            ),
            _buildThemeCard(
              context,
              StorefrontTheme.vibrant,
              StorefrontThemePreset.vibrant,
            ),
            _buildThemeCard(
              context,
              StorefrontTheme.elegant,
              StorefrontThemePreset.elegant,
            ),
            _buildThemeCard(
              context,
              StorefrontTheme.eco,
              StorefrontThemePreset.eco,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThemeCard(
    BuildContext context,
    StorefrontTheme theme,
    StorefrontThemePreset preset,
  ) {
    final isSelected = theme == selectedTheme;
    return GestureDetector(
      onTap: () => onThemeSelected(theme),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient:
                        preset.headerGradient ??
                        LinearGradient(
                          colors: [preset.primaryColor, preset.primaryColor],
                        ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _getThemeIcon(theme),
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preset.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          _buildColorDot(preset.primaryColor),
                          const SizedBox(width: 4),
                          _buildColorDot(preset.accentColor),
                          const SizedBox(width: 4),
                          _buildColorDot(preset.backgroundColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorDot(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 1),
      ),
    );
  }

  IconData _getThemeIcon(StorefrontTheme theme) {
    switch (theme) {
      case StorefrontTheme.modern:
        return Icons.auto_awesome_outlined;
      case StorefrontTheme.vibrant:
        return Icons.color_lens_outlined;
      case StorefrontTheme.elegant:
        return Icons.diamond_outlined;
      case StorefrontTheme.eco:
        return Icons.eco_outlined;
    }
  }
}

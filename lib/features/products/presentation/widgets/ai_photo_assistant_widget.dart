import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/photo_quality_result.dart';

class AiPhotoAssistantWidget extends StatelessWidget {
  final PhotoQualityResult result;
  final VoidCallback? onRetake;
  final VoidCallback? onUseAnyway;

  const AiPhotoAssistantWidget({
    super.key,
    required this.result,
    this.onRetake,
    this.onUseAnyway,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),

          const Divider(height: 1),

          _buildScoresSection(context),

          const Divider(height: 1),

          _buildSuggestionsSection(context),

          if (onRetake != null || onUseAnyway != null)
            _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final color = _getColorForLevel(result.qualityLevel);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getIconForLevel(result.qualityLevel),
                color: color,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                result.qualityText,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('ציון כללי:', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${result.overallScore.toStringAsFixed(1)}/10',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          if (!result.isGoodEnough) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Colors.orange[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'התמונה לא מספיק טובה למודעה מקצועית',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoresSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ניתוח מפורט',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...result.scores.toList().map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ScoreItem(
                icon: item.icon,
                label: item.label,
                score: item.score,
                feedback: result.feedback.getForAspect(
                  _getAspectKey(item.label),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSuggestionsSection(BuildContext context) {
    if (result.suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'טיפים לשיפור',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...result.suggestions.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20).copyWith(top: 0),
      child: Row(
        children: [
          if (onRetake != null)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onRetake,
                icon: const Icon(Icons.camera_alt),
                label: const Text('צלם שוב'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          if (onRetake != null && onUseAnyway != null)
            const SizedBox(width: 12),
          if (onUseAnyway != null)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onUseAnyway,
                icon: const Icon(Icons.check),
                label: Text(
                  result.isGoodEnough ? 'השתמש בתמונה' : 'השתמש בכל זאת',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: result.isGoodEnough
                      ? AppColors.primary
                      : Colors.orange,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getColorForLevel(QualityLevel level) {
    switch (level) {
      case QualityLevel.excellent:
        return Colors.green;
      case QualityLevel.good:
        return Colors.orange;
      case QualityLevel.needsImprovement:
        return Colors.red;
    }
  }

  IconData _getIconForLevel(QualityLevel level) {
    switch (level) {
      case QualityLevel.excellent:
        return Icons.check_circle;
      case QualityLevel.good:
        return Icons.thumbs_up_down;
      case QualityLevel.needsImprovement:
        return Icons.warning;
    }
  }

  String _getAspectKey(String label) {
    switch (label) {
      case 'תאורה':
        return 'lighting';
      case 'חדות':
        return 'sharpness';
      case 'זווית':
        return 'angle';
      case 'רקע':
        return 'background';
      case 'הצגה':
        return 'presentation';
      default:
        return '';
    }
  }
}

class _ScoreItem extends StatelessWidget {
  final String icon;
  final String label;
  final int score;
  final String feedback;

  const _ScoreItem({
    required this.icon,
    required this.label,
    required this.score,
    required this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getColorForScore(score);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                '$score/10',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 10,
            minHeight: 6,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        if (feedback.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            feedback,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Color _getColorForScore(int score) {
    if (score >= 8) return Colors.green;
    if (score >= 6) return Colors.orange;
    return Colors.red;
  }
}

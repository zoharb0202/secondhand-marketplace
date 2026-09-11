import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/theme_colors.dart';

class StreamErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  final Object? error;

  final String? title;

  final String? message;

  final String retryLabel;
  final bool compact;

  const StreamErrorView({
    super.key,
    required this.onRetry,
    this.error,
    this.title,
    this.message,
    this.retryLabel = 'נסו שוב',
  }) : compact = false;

  const StreamErrorView.compact({
    super.key,
    required this.onRetry,
    this.error,
    this.title,
    this.message,
    this.retryLabel = 'נסו שוב',
  }) : compact = true;

  @override
  Widget build(BuildContext context) {
    final isDenied = isPermissionDeniedError(error);

    final body =
        message ??
        (isDenied
            ? 'החיבור לשרת נותק. נסו שוב.'
            : 'בדקו את החיבור לאינטרנט ונסו שוב.');
    final icon = isDenied
        ? Icons.error_outline_rounded
        : Icons.cloud_off_outlined;

    final column = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: compact ? 28 : 48,
          color: isDenied ? AppColors.error : context.textTertiary,
        ),
        SizedBox(height: compact ? 8 : 16),
        Text(
          title ?? 'לא הצלחנו לטעון את הנתונים',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 14 : 17,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        SizedBox(height: compact ? 4 : 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            color: context.textSecondary,
          ),
        ),
        SizedBox(height: compact ? 8 : 20),
        if (compact)
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(retryLabel),
          )
        else
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(retryLabel),
          ),
        if (kDebugMode && error != null) ...[
          const SizedBox(height: 12),
          Text(
            '$error',
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: context.textTertiary),
          ),
        ],
      ],
    );

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 32,
          vertical: compact ? 12 : 24,
        ),
        child: column,
      ),
    );
  }
}

bool isPermissionDeniedError(Object? error) =>
    error != null && error.toString().contains('permission-denied');

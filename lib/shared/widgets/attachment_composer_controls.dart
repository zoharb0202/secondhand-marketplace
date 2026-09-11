library;

import 'package:flutter/material.dart';

import '../../core/services/attachment_upload_service.dart';
import '../../core/theme/app_colors.dart';

enum AttachmentSource { camera, gallery, file }

Future<AttachmentSource?> showAttachmentSourceSheet(BuildContext context) {
  return showModalBottomSheet<AttachmentSource>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
    ),
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'צירוף קובץ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const _SourceTile(
              icon: Icons.photo_camera_rounded,
              label: 'מצלמה',
              subtitle: 'צילום תמונה עכשיו',
              source: AttachmentSource.camera,
            ),
            const _SourceTile(
              icon: Icons.photo_library_rounded,
              label: 'גלריה',
              subtitle: 'בחירת תמונה מהמכשיר',
              source: AttachmentSource.gallery,
            ),
            const _SourceTile(
              icon: Icons.attach_file_rounded,
              label: 'קובץ',
              subtitle: 'PDF, מסמך או גיליון',
              source: AttachmentSource.file,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Text(
                'תמונות עד 10MB · מסמכים עד 20MB',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final AttachmentSource source;

  const _SourceTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: AppRadius.chipR,
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
      ),
      onTap: () => Navigator.of(context).pop(source),
    );
  }
}

class AttachmentButton extends StatelessWidget {
  final VoidCallback? onTap;

  const AttachmentButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'צירוף קובץ',
      child: IconButton(
        onPressed: onTap,
        iconSize: 22,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        icon: Icon(
          Icons.attach_file_rounded,
          color: enabled ? AppColors.primary : AppColors.textTertiary,
        ),
      ),
    );
  }
}

class AttachmentUploadStrip extends StatelessWidget {
  final AttachmentUpload upload;
  final VoidCallback onCancel;

  const AttachmentUploadStrip({
    super.key,
    required this.upload,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              upload.isImage
                  ? Icons.image_outlined
                  : Icons.insert_drive_file_outlined,
              size: 18,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: StreamBuilder<double>(
                stream: upload.progress,
                builder: (context, snapshot) {
                  final value = snapshot.data;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              upload.fileName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            value == null
                                ? 'מתחבר...'
                                : '${(value * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 4,
                          backgroundColor: AppColors.surfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Semantics(
              button: true,
              label: 'ביטול העלאה',
              child: InkResponse(
                onTap: onCancel,
                radius: 20,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.error,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

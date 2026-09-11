import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../models/message_attachment.dart';

class MessageAttachmentView extends StatelessWidget {
  final List<MessageAttachment> attachments;

  final bool isMe;

  final double maxWidth;

  const MessageAttachmentView({
    super.key,
    required this.attachments,
    required this.isMe,
    this.maxWidth = 240,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < attachments.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          attachments[i].isImage
              ? _AttachmentImage(attachment: attachments[i], maxWidth: maxWidth)
              : _AttachmentDocumentCard(
                  attachment: attachments[i],
                  isMe: isMe,
                  maxWidth: maxWidth,
                ),
        ],
      ],
    );
  }
}

class _AttachmentImage extends StatelessWidget {
  final MessageAttachment attachment;
  final double maxWidth;

  const _AttachmentImage({required this.attachment, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final ratio = attachment.aspectRatio ?? 4 / 3;
    final safeRatio = ratio.clamp(0.6, 2.0).toDouble();
    final width = maxWidth;
    final height = width / safeRatio;

    return Semantics(
      button: true,
      label: 'תמונה מצורפת, הקש/י לפתיחה במסך מלא',
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AttachmentImageViewerPage(attachment: attachment),
          ),
        ),
        child: Hero(
          tag: 'attachment_${attachment.storagePath}',
          child: ClipRRect(
            borderRadius: AppRadius.cardR,
            child: CachedNetworkImage(
              imageUrl: attachment.thumbnailUrl ?? attachment.url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              memCacheWidth: (width * MediaQuery.of(context).devicePixelRatio)
                  .round(),
              placeholder: (context, url) => Container(
                width: width,
                height: height,
                color: AppColors.surfaceVariant,
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: width,
                height: height,
                color: AppColors.surfaceVariant,
                child: const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentDocumentCard extends StatelessWidget {
  final MessageAttachment attachment;
  final bool isMe;
  final double maxWidth;

  const _AttachmentDocumentCard({
    required this.attachment,
    required this.isMe,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = isMe ? Colors.white : AppColors.textPrimary;
    final subdued = isMe
        ? Colors.white.withValues(alpha: 0.75)
        : AppColors.textTertiary;

    return Semantics(
      button: true,
      label: 'קובץ מצורף ${attachment.fileName}, הקש/י לפתיחה',
      child: InkWell(
        onTap: () => _openAttachment(context, attachment),
        borderRadius: AppRadius.cardR,
        child: Container(
          width: maxWidth,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: isMe
                ? Colors.white.withValues(alpha: 0.15)
                : AppColors.surfaceVariant,
            borderRadius: AppRadius.cardR,
            border: Border.all(
              color: isMe
                  ? Colors.white.withValues(alpha: 0.25)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: AppRadius.chipR,
                ),
                child: Icon(
                  _iconFor(attachment),
                  size: 20,
                  color: isMe ? Colors.white : AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      attachment.fileName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        attachment.typeLabel,
                        attachment.readableSize,
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: TextStyle(fontSize: 11, color: subdued),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.download_rounded, size: 18, color: subdued),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(MessageAttachment attachment) {
    final mime = attachment.mimeType.toLowerCase();
    if (mime == 'application/pdf') return Icons.picture_as_pdf_rounded;
    if (mime.contains('word') || mime.contains('msword')) {
      return Icons.description_rounded;
    }
    if (mime.contains('excel') || mime.contains('spreadsheet')) {
      return Icons.table_chart_rounded;
    }
    if (mime.startsWith('text/')) return Icons.article_outlined;
    return Icons.insert_drive_file_rounded;
  }
}

Future<void> _openAttachment(
  BuildContext context,
  MessageAttachment attachment,
) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!AttachmentPolicy.isTrustedAttachmentUrl(attachment.url)) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('לא ניתן לפתוח את הקובץ'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  try {
    final uri = Uri.parse(attachment.url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('לא ניתן לפתוח את הקובץ'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('שגיאה בפתיחת הקובץ: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class AttachmentImageViewerPage extends StatefulWidget {
  final MessageAttachment attachment;

  const AttachmentImageViewerPage({super.key, required this.attachment});

  @override
  State<AttachmentImageViewerPage> createState() =>
      _AttachmentImageViewerPageState();
}

class _AttachmentImageViewerPageState extends State<AttachmentImageViewerPage>
    with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _zoomAnimation;

  @override
  void dispose() {
    _controller.dispose();
    _animation.dispose();
    super.dispose();
  }

  void _handleDoubleTap(TapDownDetails details) {
    final current = _controller.value;
    final isZoomed = current.getMaxScaleOnAxis() > 1.01;
    final target = isZoomed
        ? Matrix4.identity()
        : (Matrix4.identity()
            ..translateByDouble(
              -details.localPosition.dx * 1.5,
              -details.localPosition.dy * 1.5,
              0,
              1,
            )
            ..scaleByDouble(2.5, 2.5, 2.5, 1));

    _zoomAnimation = Matrix4Tween(begin: current, end: target).animate(
      CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic),
    )..addListener(() => _controller.value = _zoomAnimation!.value);
    _animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.attachment.fileName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'פתיחה / הורדה',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => _openAttachment(context, widget.attachment),
          ),
        ],
      ),
      body: Center(
        child: GestureDetector(
          onDoubleTapDown: _handleDoubleTap,
          onDoubleTap: () {},
          child: InteractiveViewer(
            transformationController: _controller,
            minScale: 1,
            maxScale: 5,
            child: Hero(
              tag: 'attachment_${widget.attachment.storagePath}',
              child: CachedNetworkImage(
                imageUrl: widget.attachment.url,
                fit: BoxFit.contain,
                placeholder: (context, url) => const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                errorWidget: (context, url, error) => const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'לא ניתן לטעון את התמונה',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

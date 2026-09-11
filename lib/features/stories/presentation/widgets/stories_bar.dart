import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/story_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/story_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../pages/story_viewer_page.dart';

final activeStoriesProvider = StreamProvider<List<SellerStories>>((ref) {
  return StoryService().activeStoriesStream();
});

class StoriesBar extends ConsumerWidget {
  final bool onDark;

  const StoriesBar({super.key, this.onDark = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(activeStoriesProvider);
    final user = ref.watch(currentUserProvider).value;

    final sellerStories = storiesAsync.maybeWhen(
      data: (list) => list,
      orElse: () => const <SellerStories>[],
    );

    if (sellerStories.isEmpty && user == null) {
      return const SizedBox.shrink();
    }

    final labelColor = onDark ? Colors.white : null;

    return SizedBox(
      height: 104,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          if (user != null)
            _CreateStoryBubble(user: user, labelColor: labelColor),
          for (final ss in sellerStories)
            _StoryAvatar(
              sellerStories: ss,
              labelColor: labelColor,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoryViewerPage(sellerStories: ss),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  final SellerStories sellerStories;
  final VoidCallback onTap;
  final Color? labelColor;

  const _StoryAvatar({
    required this.sellerStories,
    required this.onTap,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final cover = sellerStories.stories.first.imageUrl;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(left: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.coral, AppColors.sun],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.surface,
                backgroundImage: NetworkImage(
                  sellerStories.sellerPhoto?.isNotEmpty == true
                      ? sellerStories.sellerPhoto!
                      : cover,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sellerStories.sellerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: labelColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateStoryBubble extends StatefulWidget {
  final dynamic user;
  final Color? labelColor;
  const _CreateStoryBubble({required this.user, this.labelColor});

  @override
  State<_CreateStoryBubble> createState() => _CreateStoryBubbleState();
}

class _CreateStoryBubbleState extends State<_CreateStoryBubble> {
  bool _busy = false;

  Future<void> _createStory() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;
      setState(() => _busy = true);

      final user = widget.user;
      final service = StoryService();
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await service.createStory(
          sellerId: user.id,
          sellerName: user.displayName ?? 'מוכר',
          sellerPhoto: user.photoUrl,
          imageBytes: bytes,
        );
      } else {
        await service.createStory(
          sellerId: user.id,
          sellerName: user.displayName ?? 'מוכר',
          sellerPhoto: user.photoUrl,
          imageFile: File(picked.path),
        );
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('הסטורי פורסם! (יעלם תוך 24 שעות)')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('שגיאה: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _busy ? null : _createStory,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceVariant,
                border: Border.all(color: AppColors.border),
              ),
              child: _busy
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.add, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 4),
            Text(
              'הסטורי שלי',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: widget.labelColor),
            ),
          ],
        ),
      ),
    );
  }
}

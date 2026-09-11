import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';

class ImageUploadWidget extends ConsumerStatefulWidget {
  final String? currentImageUrl;
  final String label;
  final String description;
  final Function(XFile) onImageSelected;
  final VoidCallback? onImageRemoved;
  final double aspectRatio;
  final double maxHeight;

  const ImageUploadWidget({
    super.key,
    this.currentImageUrl,
    required this.label,
    required this.description,
    required this.onImageSelected,
    this.onImageRemoved,
    this.aspectRatio = 1.0,
    this.maxHeight = 200,
  });

  @override
  ConsumerState<ImageUploadWidget> createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends ConsumerState<ImageUploadWidget> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  final bool _isUploading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.currentImageUrl != null || _selectedImage != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),

        Text(
          widget.description,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),

        GestureDetector(
          onTap: _isUploading ? null : _pickImage,
          child: Container(
            height: widget.maxHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _errorMessage != null
                    ? AppColors.error
                    : AppColors.border,
                width: 2,
              ),
              image: hasImage
                  ? DecorationImage(
                      image: _getImageProvider(),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Stack(
              children: [
                if (!hasImage)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 48,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'לחץ להעלאת תמונה',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'מקסימום ${AppConstants.maxImageSizeMB}MB',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),

                if (_isUploading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),

                if (hasImage && !_isUploading)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _removeImage,
                        tooltip: 'הסר תמונה',
                      ),
                    ),
                  ),

                if (hasImage && !_isUploading)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _pickImage,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'שנה',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  ImageProvider _getImageProvider() {
    if (_selectedImage != null) {
      return FileImage(File(_selectedImage!.path));
    } else if (widget.currentImageUrl != null) {
      return NetworkImage(widget.currentImageUrl!);
    }
    throw Exception('No image available');
  }

  Future<void> _pickImage() async {
    try {
      setState(() {
        _errorMessage = null;
      });

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      final sizeInMB = bytes.length / (1024 * 1024);

      if (sizeInMB > AppConstants.maxImageSizeMB) {
        setState(() {
          _errorMessage =
              'גודל התמונה גדול מדי. מקסימום ${AppConstants.maxImageSizeMB}MB';
        });
        return;
      }

      final fileName = image.name.toLowerCase();
      if (!fileName.endsWith('.jpg') &&
          !fileName.endsWith('.jpeg') &&
          !fileName.endsWith('.png')) {
        setState(() {
          _errorMessage = 'סוג קובץ לא נתמך. אנא בחר JPG או PNG';
        });
        return;
      }

      setState(() {
        _selectedImage = image;
      });

      widget.onImageSelected(image);
    } catch (e) {
      setState(() {
        _errorMessage = 'שגיאה בבחירת תמונה: ${e.toString()}';
      });
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _errorMessage = null;
    });

    if (widget.onImageRemoved != null) {
      widget.onImageRemoved!();
    }
  }
}

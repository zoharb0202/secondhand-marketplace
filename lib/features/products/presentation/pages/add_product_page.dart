import 'dart:async' show unawaited;
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'image_crop_frame_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/stream_error_view.dart';
import '../../../../core/constants/categories.dart';
import '../../../../core/constants/manufacturers.dart';
import '../../../../core/services/location_service.dart';
import '../../../../shared/models/product_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/pages/addresses_page.dart';
import '../../../search/data/services/ai_search_service.dart';
import '../../data/services/ai_photo_assistant_service.dart';
import '../../data/services/image_enhancement_service.dart';
import '../widgets/ai_photo_assistant_widget.dart';
import '../widgets/category_selector.dart';
import '../providers/product_provider.dart';

const Map<String, String> _kAiCategoryAliases = {
  'homeGarden': 'home_garden',
  'babyKids': 'kids',
  'animalsSupplies': 'pets',
  'realEstate': 'real_estate',
  'fashionBeauty': 'fashion_beauty',
};

const Map<String, String> _kAiSubCategoryAliases = {
  'mobilePhones': 'smartphones',
  'tvs': 'tv_audio',
  'consoles': 'gaming',
  'gamingAccessories': 'gaming',
  'sneakers': 'shoes',
  'menShoes': 'shoes',
  'womenShoes': 'shoes',
  'menClothing': 'men_clothing',
  'womenClothing': 'women_clothing',
  'kidsClothing': 'kids_clothing',
};

const Map<String, String> _kCatalogToLegacySubCategory = {
  'smartphones': 'mobilePhones',
  'tv_audio': 'tvs',
  'gaming': 'consoles',
  'shoes': 'sneakers',
  'men_clothing': 'menClothing',
  'women_clothing': 'womenClothing',
  'kids_clothing': 'kidsClothing',
};

String? _legacySubCategoryFor(String? catalogSubCategoryId) {
  if (catalogSubCategoryId == null) return null;
  return _kCatalogToLegacySubCategory[catalogSubCategoryId] ??
      catalogSubCategoryId;
}

String? _resolveCatalogCategoryId(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  if (Categories.findById(value) != null) return value;
  final alias = _kAiCategoryAliases[value];
  if (alias != null && Categories.findById(alias) != null) return alias;
  return null;
}

String? _resolveCatalogSubCategoryId(String categoryId, String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  if (Categories.findSubCategory(categoryId, value) != null) return value;
  final alias = _kAiSubCategoryAliases[value];
  if (alias != null && Categories.findSubCategory(categoryId, alias) != null) {
    return alias;
  }
  return null;
}

String _categoryDisplay(ProductAnalysis analysis) {
  final id = _resolveCatalogCategoryId(analysis.category);
  if (id == null) return analysis.category!;
  return Categories.findById(id)?.name ?? analysis.category!;
}

String _subCategoryDisplay(ProductAnalysis analysis) {
  final categoryId = _resolveCatalogCategoryId(analysis.category);
  if (categoryId == null) return analysis.subcategory!;
  final subId = _resolveCatalogSubCategoryId(categoryId, analysis.subcategory);
  if (subId == null) return analysis.subcategory!;
  return Categories.findSubCategory(categoryId, subId)?.name ??
      analysis.subcategory!;
}

class AddProductPage extends ConsumerStatefulWidget {
  const AddProductPage({super.key});

  @override
  ConsumerState<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends ConsumerState<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  final List<XFile> _selectedImages = [];
  final List<Uint8List> _imageBytes = [];
  final List<File> _selectedVideos = [];
  final List<String> _selectedVideosPaths = [];
  ProductCategory _selectedCategory = ProductCategory.other;
  String? _selectedSubcategory;

  String? _selectedManufacturer;
  final _manufacturerOtherController = TextEditingController();

  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  ProductCondition _selectedCondition = ProductCondition.good;
  bool _isLoading = false;
  bool _isAnalyzingImage = false;

  String? _aiAnalysisId;

  static const int _kMinStockQuantity = 2;
  static const int _kMaxStockQuantity = 99;
  bool _hasMultipleUnits = false;
  final _stockController = TextEditingController(text: '2');

  SavedAddress? _selectedPickupAddress;

  String? _selectedCategoryId;
  String? _selectedSubCategoryId;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLearnedManufacturers());
  }

  Future<void> _loadLearnedManufacturers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('brand_catalog')
          .doc('index')
          .get()
          .timeout(const Duration(seconds: 5));
      if (!snapshot.exists) return;
      final changed = applyLearnedManufacturers(snapshot.data());
      if (changed && mounted) setState(() {});
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ brand_catalog/index unavailable — bundled baseline only: $e');
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _manufacturerOtherController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  List<String> get _manufacturerOptions => manufacturersFor(
    categoryId: _selectedCategoryId,
    subCategoryId: _selectedSubCategoryId,
  );

  String? get _manufacturerValue {
    final selected = _selectedManufacturer;
    if (selected == null) return null;
    if (selected != kOtherManufacturer) return selected;
    final typed = _manufacturerOtherController.text.trim();
    return typed.isEmpty ? null : typed;
  }

  String? get _brandForStorage {
    final value = _manufacturerValue;
    if (value == null) return null;
    final canonical = matchManufacturer(value, _manufacturerOptions) ?? value;
    return canonical.toLowerCase();
  }

  String? _unknownTypedBrand() {
    if (_selectedManufacturer != kOtherManufacturer) return null;
    final typed = _manufacturerOtherController.text.trim();
    if (typed.isEmpty) return null;
    if (matchManufacturer(typed, _manufacturerOptions) != null) return null;
    if (normalizeManufacturerName(typed).length < 2) return null;
    return typed;
  }

  Future<void> _reportUnknownBrand({
    required String brandName,
    required String categoryId,
    String? subCategoryId,
    String? productId,
  }) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('suggestBrand')
          .call<dynamic>({
            'brandName': brandName,
            'categoryId': categoryId,
            'subCategoryId': subCategoryId,
            'productId': productId,
          })
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      if (kDebugMode) print('ℹ️ suggestBrand failed (non-fatal): $e');
    }
  }

  void _syncManufacturerToCategory() {
    final current = _selectedManufacturer;
    if (current == null || current == kOtherManufacturer) return;
    if (_manufacturerOptions.contains(current)) return;
    _manufacturerOtherController.text = current;
    _selectedManufacturer = kOtherManufacturer;
  }

  Widget _buildSmartPricingHint() {
    return Consumer(
      builder: (context, ref, _) {
        final statsAsync = ref.watch(
          categoryPriceStatsProvider((
            category: _selectedCategory.name,
            subcategory: _selectedSubcategory,
          )),
        );
        return statsAsync.maybeWhen(
          data: (stats) {
            if (stats == null) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cobalt.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.cobalt.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.insights,
                        size: 18,
                        color: AppColors.cobalt,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'תמחור חכם · ${stats.count} מוצרים דומים',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cobalt,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'טווח מקובל: ₪${stats.p25.toStringAsFixed(0)}–₪${stats.p75.toStringAsFixed(0)} · חציון ₪${stats.median.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _priceController.text = stats.median.toStringAsFixed(
                            0,
                          );
                        });
                      },
                      icon: const Icon(Icons.auto_fix_high, size: 16),
                      label: const Text('השתמש בחציון'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.cobalt,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
      },
    );
  }

  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();

      if (images.length + _selectedImages.length + _selectedVideos.length >
          AppConstants.maxProductImages) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'ניתן להעלות עד ${AppConstants.maxProductImages} תמונות/וידאו',
              ),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      for (final image in images) {
        await _cropAndAddImage(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('שגיאה בבחירת תמונות'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _cropAndAddImage(XFile imageFile) async {
    try {
      final originalBytes = await imageFile.readAsBytes();

      Uint8List finalBytes = originalBytes;
      XFile finalFile = imageFile;
      if (mounted) {
        final cropped = await Navigator.push<Uint8List?>(
          context,
          MaterialPageRoute(
            builder: (_) => ImageCropFramePage(imageBytes: originalBytes),
          ),
        );
        if (cropped != null && cropped.isNotEmpty) {
          finalBytes = cropped;
          finalFile = XFile.fromData(
            cropped,
            mimeType: 'image/png',
            name: 'cropped_${DateTime.now().millisecondsSinceEpoch}.png',
          );
        }
      }

      if (!mounted) return;
      final addedIndex = _selectedImages.length;
      setState(() {
        _selectedImages.add(finalFile);
        _imageBytes.add(finalBytes);
      });

      if (_selectedImages.length == 1 && !_isAnalyzingImage) {
        _analyzeImageWithAI(finalFile);
      } else {
        _moderateExtraImage(finalFile, addedIndex);
      }
    } catch (e, stackTrace) {
      if (kDebugMode) print('❌ ERROR in _cropAndAddImage: $e');
      if (kDebugMode) print('❌ Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בחיתוך תמונה: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      if (_selectedImages.length + _selectedVideos.length >=
          AppConstants.maxProductImages) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'ניתן להעלות עד ${AppConstants.maxProductImages} קבצים',
              ),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bool isFirstMedia =
            _selectedImages.isEmpty && _selectedVideos.isEmpty;

        if (kIsWeb) {
          setState(() {
            _selectedVideosPaths.add(file.name);
          });
        } else {
          if (file.path != null) {
            setState(() {
              _selectedVideos.add(File(file.path!));
            });

            if (isFirstMedia && !_isAnalyzingImage) {
              if (kDebugMode) {
                print(
                  '🎬 First video detected - extracting thumbnail for AI analysis',
                );
              }
              _analyzeVideoWithAI(file.path!);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בבחירת וידאו: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _imageBytes.removeAt(index);
    });
  }

  void _removeVideo(int index) {
    setState(() {
      if (kIsWeb) {
        _selectedVideosPaths.removeAt(index);
      } else {
        _selectedVideos.removeAt(index);
      }
    });
  }

  Future<void> _analyzeImageWithAI(XFile imageFile) async {
    setState(() {
      _isAnalyzingImage = true;
    });

    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) return;

      final rawBytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(rawBytes, targetWidth: 900);
      final frame = await codec.getNextFrame();
      final pngData = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final small = pngData!.buffer.asUint8List();
      final dataUri = 'data:image/png;base64,${base64Encode(small)}';

      final aiService = AISearchService();
      final analysis = await aiService.analyzeProductImage(dataUri);

      if (!mounted) return;

      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _AIAnalysisDialog(analysis: analysis),
      );

      if (accepted == true && mounted) {
        _applySuggestions(analysis);
      }
    } catch (e) {
      if (kDebugMode) print('Error analyzing image: $e');

      final errorMessage = e.toString();
      if (errorMessage.contains('תוכן אסור') ||
          errorMessage.contains('failed-precondition')) {
        if (mounted) {
          setState(() {
            if (_selectedImages.isNotEmpty) {
              _selectedImages.removeAt(0);
            }
            if (_imageBytes.isNotEmpty) {
              _imageBytes.removeAt(0);
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMessage.contains('תוכן אסור')
                    ? 'התמונה נחסמה: מכילה תוכן אסור (סמים/נשקים/תוכן מיני)'
                    : 'התמונה מכילה תוכן לא הולם ולא ניתן להעלות אותה',
              ),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        if (mounted) {
          String userMessage;
          Color backgroundColor;

          if (errorMessage.contains('timed out')) {
            userMessage = 'ניתוח AI לוקח זמן רב. המשך למלא את הפרטים ידנית';
            backgroundColor = AppColors.warning;
          } else if (errorMessage.contains('INTERNAL') ||
              errorMessage.contains('internal')) {
            userMessage =
                'ניתוח AI לא זמין כרגע. ניתן להמשיך למלא את הפרטים ידנית';
            backgroundColor = AppColors.warning;
          } else {
            userMessage = 'שגיאה בניתוח התמונה. המשך למלא ידנית';
            backgroundColor = AppColors.error;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userMessage),
              backgroundColor: backgroundColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzingImage = false;
        });
      }
    }
  }

  Future<void> _moderateExtraImage(XFile imageFile, int index) async {
    setState(() {
      _isAnalyzingImage = true;
    });

    try {
      final rawBytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(rawBytes, targetWidth: 900);
      final frame = await codec.getNextFrame();
      final pngData = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final small = pngData!.buffer.asUint8List();
      final dataUri = 'data:image/png;base64,${base64Encode(small)}';

      final aiService = AISearchService();
      final result = await aiService.moderateImage(dataUri);

      if (!result.isAppropriate && mounted) {
        setState(() {
          int removeAt = _selectedImages.indexOf(imageFile);
          if (removeAt == -1 &&
              index < _selectedImages.length &&
              _selectedImages[index] == imageFile) {
            removeAt = index;
          }
          if (removeAt != -1) {
            _selectedImages.removeAt(removeAt);
            if (removeAt < _imageBytes.length) {
              _imageBytes.removeAt(removeAt);
            }
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                (result.reason != null && result.reason!.isNotEmpty)
                    ? 'התמונה הוסרה: ${result.reason}'
                    : 'התמונה הוסרה: מכילה תוכן לא הולם ולא ניתן להעלות אותה',
              ),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ ERROR moderating image at index $index: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzingImage = false;
        });
      }
    }
  }

  Future<void> _analyzeVideoWithAI(String videoPath) async {
    setState(() {
      _isAnalyzingImage = true;
    });

    try {
      if (kDebugMode) print('🎬 Extracting thumbnail from video...');

      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 1024,
        quality: 85,
      );

      if (thumbnailPath == null) {
        throw Exception('Failed to extract thumbnail from video');
      }

      if (kDebugMode) print('✅ Thumbnail extracted: $thumbnailPath');

      final user = ref.read(currentUserProvider).value;
      if (user == null) return;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('temp_analysis')
          .child('${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final thumbnailFile = File(thumbnailPath);
      final bytes = await thumbnailFile.readAsBytes();
      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final imageUrl = await storageRef.getDownloadURL();

      final aiService = AISearchService();
      final analysis = await aiService.analyzeProductImage(imageUrl);

      if (!mounted) return;

      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _AIAnalysisDialog(analysis: analysis),
      );

      if (accepted == true && mounted) {
        _applySuggestions(analysis);
      }

      await storageRef.delete();
      await thumbnailFile.delete();
    } catch (e) {
      if (kDebugMode) print('Error analyzing video: $e');

      final errorMessage = e.toString();
      if (errorMessage.contains('תוכן אסור') ||
          errorMessage.contains('failed-precondition')) {
        if (mounted) {
          setState(() {
            if (_selectedVideos.isNotEmpty) {
              _selectedVideos.removeAt(0);
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMessage.contains('תוכן אסור')
                    ? 'הוידאו נחסם: מכיל תוכן אסור (סמים/נשקים/תוכן מיני)'
                    : 'הוידאו מכיל תוכן לא הולם ולא ניתן להעלות אותו',
              ),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('שגיאה בניתוח הוידאו: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzingImage = false;
        });
      }
    }
  }

  Future<void> _analyzePhotoQuality() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('נא להעלות תמונות תחילה'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('מנתח איכות תמונות...'),
                ],
              ),
            ),
          ),
        ),
      );

      final photoAssistant = AiPhotoAssistantService();
      final result = await photoAssistant.analyzePhotoQuality(
        _selectedImages[0].path,
      );

      if (!mounted) return;
      Navigator.pop(context);

      await showDialog(
        context: context,
        builder: (context) => Dialog(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppColors.primary),
                      const SizedBox(width: 12),
                      const Text(
                        'ניתוח איכות תמונה',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                AiPhotoAssistantWidget(
                  result: result,
                  onRetake: () {
                    Navigator.pop(context);
                    setState(() {
                      if (_selectedImages.isNotEmpty) {
                        _selectedImages.removeAt(0);
                      }
                      if (_imageBytes.isNotEmpty) {
                        _imageBytes.removeAt(0);
                      }
                    });
                    _pickImages();
                  },
                  onUseAnyway: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בניתוח איכות התמונה: $e'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  Future<void> _enhanceImage(int imageIndex) async {
    if (imageIndex >= _selectedImages.length) {
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('משפר את התמונה...'),
                ],
              ),
            ),
          ),
        ),
      );

      final enhancementService = ImageEnhancementService();
      final enhancedPath = await enhancementService.enhanceImage(
        _selectedImages[imageIndex].path,
      );

      if (!mounted) return;
      Navigator.pop(context);

      await _showBeforeAfterDialog(
        originalPath: _selectedImages[imageIndex].path,
        enhancedPath: enhancedPath,
        imageIndex: imageIndex,
      );
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשיפור התמונה: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showBeforeAfterDialog({
    required String originalPath,
    required String enhancedPath,
    required int imageIndex,
  }) async {
    bool useEnhanced = false;

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_fix_high, color: AppColors.primary),
                    const SizedBox(width: 12),
                    const Text(
                      'תמונה משופרת',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'לפני:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(originalPath),
                            fit: BoxFit.contain,
                            width: double.infinity,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'אחרי:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(enhancedPath),
                            fit: BoxFit.contain,
                            width: double.infinity,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.info,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'התמונה שופרה באופן אוטומטי: בהירות, ניגודיות, חדות וצבעים',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              useEnhanced = false;
                              Navigator.pop(context);
                            },
                            child: const Text('השתמש במקור'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              useEnhanced = true;
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('השתמש בשיפור'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (useEnhanced) {
      setState(() {
        _selectedImages[imageIndex] = XFile(enhancedPath);
        if (imageIndex < _imageBytes.length) {
          File(enhancedPath).readAsBytes().then((bytes) {
            if (mounted && imageIndex < _imageBytes.length) {
              setState(() {
                _imageBytes[imageIndex] = bytes;
              });
            }
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('התמונה המשופרת נבחרה בהצלחה'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  void _applySuggestions(ProductAnalysis analysis) {
    setState(() {
      _aiAnalysisId = analysis.analysisId;

      if (analysis.title.isNotEmpty) {
        _titleController.text = analysis.title;
      }

      if (analysis.description != null && analysis.description!.isNotEmpty) {
        _descriptionController.text = analysis.description!;
      }

      final aiCategoryId = _resolveCatalogCategoryId(analysis.category);
      if (aiCategoryId != null) {
        final aiSubCategoryId = _resolveCatalogSubCategoryId(
          aiCategoryId,
          analysis.subcategory,
        );

        _selectedCategoryId = aiCategoryId;
        _selectedSubCategoryId = aiSubCategoryId;
        _selectedCategory = _legacyCategoryFor(aiCategoryId);
        _selectedSubcategory = _legacySubCategoryFor(aiSubCategoryId);
        _syncManufacturerToCategory();
      } else {
        if (kDebugMode) {
          print(
            'AI category not in catalog, left unselected: ${analysis.category}',
          );
        }
      }

      final aiBrand = analysis.brand?.trim();
      if (aiBrand != null && aiBrand.isNotEmpty) {
        final matched = matchManufacturer(aiBrand, _manufacturerOptions);
        if (matched != null) {
          _selectedManufacturer = matched;
          _manufacturerOtherController.clear();
        } else {
          if (kDebugMode) {
            print('AI brand not in category list, kept as free text: $aiBrand');
          }
          _selectedManufacturer = kOtherManufacturer;
          _manufacturerOtherController.text = aiBrand;
        }
      }

      if (analysis.model != null && analysis.model!.trim().isNotEmpty) {
        _modelController.text = analysis.model!.trim();
      }
      if (analysis.color != null && analysis.color!.trim().isNotEmpty) {
        _colorController.text = analysis.color!.trim();
      }

      if (analysis.condition != null) {
        try {
          _selectedCondition = ProductCondition.values.firstWhere(
            (cond) => cond.name == analysis.condition,
            orElse: () => ProductCondition.good,
          );
        } catch (e) {
          if (kDebugMode) {
            print('Could not parse condition: ${analysis.condition}');
          }
        }
      }

      if (analysis.priceEstimate != null) {
        final avgPrice =
            (analysis.priceEstimate!.min + analysis.priceEstimate!.max) / 2;
        _priceController.text = avgPrice.toStringAsFixed(0);
      }
    });
  }

  ProductCategory _legacyCategoryFor(String categoryId) {
    switch (categoryId) {
      case 'fashion':
      case 'fashion_beauty':
      case 'fashionBeauty':
        return ProductCategory.fashion;
      case 'electronics':
        return ProductCategory.electronics;
      case 'vehicles':
        return ProductCategory.vehicles;
      case 'real_estate':
      case 'realEstate':
        return ProductCategory.realEstate;
      case 'furniture':
      case 'home_garden':
      case 'homeGarden':
        return ProductCategory.homeGarden;
      case 'sports':
        return ProductCategory.sports;
      case 'toys':
      case 'kids':
      case 'babyKids':
        return ProductCategory.babyKids;
      case 'pets':
      case 'animalsSupplies':
        return ProductCategory.animalsSupplies;
      case 'services':
        return ProductCategory.services;
      case 'jobs':
        return ProductCategory.jobs;
      default:
        return ProductCategory.other;
    }
  }

  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('נא לבחור קטגוריה מהרשימה המפורטת למטה'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedPickupAddress == null) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('נדרשת כתובת איסוף'),
            content: const Text(
              'כדי לפרסם מוצר יש להוסיף לפחות כתובת אחת שממנה ניתן לאסוף את המוצר.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ביטול'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddressesPage()),
                  );
                },
                child: const Text('הוסף כתובת'),
              ),
            ],
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('User not found');

      final int? initialStockQty = _hasMultipleUnits
          ? int.tryParse(_stockController.text.trim())
          : null;

      final specificFields = <String, dynamic>{};
      final modelText = _modelController.text.trim();
      if (modelText.isNotEmpty) specificFields['model'] = modelText;
      final colorText = _colorController.text.trim();
      if (colorText.isNotEmpty) specificFields['color'] = colorText;

      final unknownBrand = _unknownTypedBrand();
      final unknownBrandCategoryId = _selectedCategoryId;
      final unknownBrandSubCategoryId = _selectedSubCategoryId;

      final aiAnalysisId = _aiAnalysisId;

      final product = ProductModel(
        id: '',
        sellerId: user.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text),
        category: _selectedCategory,
        subcategory: _selectedSubcategory,
        brand: _brandForStorage,
        condition: _selectedCondition,
        imageUrls: [],
        createdAt: DateTime.now(),
        location: _selectedPickupAddress!.location,
        city: _selectedPickupAddress!.city,
        pickupAddressId: _selectedPickupAddress!.id,
        categoryId: _selectedCategoryId,
        subCategoryId: _selectedSubCategoryId,
        specificFields: specificFields.isEmpty ? null : specificFields,
        stockTotal: initialStockQty,
        stockRemaining: initialStockQty,
      );

      if (kDebugMode) {
        print(
          '📸 Preparing images: ${_selectedImages.length} images, ${_imageBytes.length} bytes',
        );
      }
      final List<Map<String, dynamic>> imageData = [];
      for (int i = 0; i < _selectedImages.length; i++) {
        if (i < _imageBytes.length) {
          if (kDebugMode) {
            print(
              '📸 Adding image $i: ${_selectedImages[i].name}, bytes: ${_imageBytes[i].length}',
            );
          }
          imageData.add({'file': _selectedImages[i], 'bytes': _imageBytes[i]});
        } else {
          if (kDebugMode) {
            print('⚠️ WARNING: No bytes for image $i, reading now...');
          }
          try {
            final bytes = await _selectedImages[i].readAsBytes();
            imageData.add({'file': _selectedImages[i], 'bytes': bytes});
          } catch (e) {
            if (kDebugMode) print('❌ Error reading bytes for image $i: $e');
          }
        }
      }
      if (kDebugMode) print('✅ Prepared ${imageData.length} images for upload');

      List<dynamic>? videoFiles;
      if (_selectedVideos.isNotEmpty) {
        videoFiles = _selectedVideos;
      } else if (_selectedVideosPaths.isNotEmpty) {
        videoFiles = _selectedVideosPaths;
      }

      final createdProduct = await ref
          .read(productControllerProvider.notifier)
          .createProduct(
            product: product,
            imageFiles: imageData,
            videoFiles: videoFiles,
          )
          .timeout(
            const Duration(seconds: 90),
            onTimeout: () {
              throw Exception('Product upload timed out');
            },
          );

      if (createdProduct != null &&
          unknownBrand != null &&
          unknownBrandCategoryId != null) {
        unawaited(
          _reportUnknownBrand(
            brandName: unknownBrand,
            categoryId: unknownBrandCategoryId,
            subCategoryId: unknownBrandSubCategoryId,
            productId: createdProduct.id,
          ),
        );
      }

      if (createdProduct != null && aiAnalysisId != null) {
        unawaited(
          AISearchService().logListingOutcome(
            analysisId: aiAnalysisId,
            productId: createdProduct.id,
          ),
        );
      }

      if (createdProduct != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('המוצר פורסם בהצלחה!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e, stackTrace) {
      if (kDebugMode) print('❌ ERROR in _submitProduct: $e');
      if (kDebugMode) print('📋 Stack trace: $stackTrace');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('שגיאה בהעלאת המוצר'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.toString().contains('timed out')
                        ? 'הפרסום לוקח זמן רב. נסה שוב או בדוק את החיבור לאינטרנט.'
                        : 'שגיאה: ${e.toString()}',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'פרטים טכניים:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stackTrace.toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('סגור'),
              ),
            ],
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('מוצר חדש'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _submitProduct,
              child: const Text(
                'פרסם',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildImagesSection(),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'כותרת *',
                        hintText: 'לדוגמה: אייפון 13 Pro Max',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'נא להזין כותרת';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'מחיר *',
                        hintText: '0',
                        suffixText: '₪',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'נא להזין מחיר';
                        }
                        if (double.tryParse(value) == null) {
                          return 'נא להזין מחיר תקין';
                        }
                        return null;
                      },
                    ),
                    if (_selectedCategory != ProductCategory.other)
                      _buildSmartPricingHint(),
                    const SizedBox(height: 16),

                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('יש לי יותר מפריט אחד מהמוצר הזה'),
                      subtitle: const Text(
                        'נעדכן את הכמות שנותרה אוטומטית אחרי כל מכירה',
                      ),
                      value: _hasMultipleUnits,
                      onChanged: (value) {
                        setState(() {
                          _hasMultipleUnits = value ?? false;
                        });
                      },
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      alignment: Alignment.topCenter,
                      child: _hasMultipleUnits
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: TextFormField(
                                controller: _stockController,
                                decoration: const InputDecoration(
                                  labelText: 'כמות במלאי *',
                                  hintText: '2',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (!_hasMultipleUnits) return null;
                                  final qty = int.tryParse(
                                    (value ?? '').trim(),
                                  );
                                  if (qty == null ||
                                      qty < _kMinStockQuantity ||
                                      qty > _kMaxStockQuantity) {
                                    return 'נא להזין כמות בין 2 ל-99';
                                  }
                                  return null;
                                },
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'קטגוריה *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: CategorySelector(
                        initialCategoryId: _selectedCategoryId,
                        initialSubCategoryId: _selectedSubCategoryId,
                        onSelected: (category, subCategory) {
                          setState(() {
                            _selectedCategoryId = category.id;
                            _selectedSubCategoryId = subCategory?.id;
                            _selectedCategory = _legacyCategoryFor(category.id);
                            _selectedSubcategory = _legacySubCategoryFor(
                              subCategory?.id,
                            );
                            _syncManufacturerToCategory();
                          });
                        },
                      ),
                    ),
                    if (_selectedCategoryId == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'נא לבחור קטגוריה מהרשימה',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        'manufacturer_${_selectedCategoryId}_$_selectedSubCategoryId',
                      ),
                      initialValue: _selectedManufacturer,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'יצרן/מותג',
                        hintText: 'בחר יצרן',
                      ),
                      items: _manufacturerOptions.map((manufacturer) {
                        return DropdownMenuItem(
                          value: manufacturer,
                          child: Text(
                            manufacturer,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedManufacturer = value;
                          if (value != kOtherManufacturer) {
                            _manufacturerOtherController.clear();
                          }
                        });
                      },
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      alignment: Alignment.topCenter,
                      child: _selectedManufacturer == kOtherManufacturer
                          ? Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: TextFormField(
                                controller: _manufacturerOtherController,
                                decoration: const InputDecoration(
                                  labelText: 'שם היצרן/מותג',
                                  hintText: 'לדוגמה: Gillette',
                                  helperText:
                                      'המותג נשמר במודעה שלך מיד. אם הוא מותג אמיתי, '
                                      'הוא עשוי להתווסף לרשימה לכל המוכרים לאחר בדיקה.',
                                  helperMaxLines: 2,
                                ),
                                textCapitalization: TextCapitalization.words,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'דגם/גרסה',
                        hintText: 'לדוגמה: iPhone 13 Pro Max, Air Jordan 1',
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _colorController,
                      decoration: const InputDecoration(
                        labelText: 'צבע',
                        hintText: 'לדוגמה: שחור, כחול',
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<ProductCondition>(
                      initialValue: _selectedCondition,
                      decoration: const InputDecoration(
                        labelText: 'מצב המוצר *',
                      ),
                      items: ProductCondition.values.map((condition) {
                        return DropdownMenuItem(
                          value: condition,
                          child: Text(condition.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedCondition = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'תיאור *',
                        hintText: 'תאר את המוצר בפירוט...',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'נא להזין תיאור';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'כתובת איסוף *',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _buildPickupAddressSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

          if (_isAnalyzingImage)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'מנתח את התמונה עם AI...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'זה עשוי לקחת מספר שניות',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPickupAddressSection() {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) return const SizedBox.shrink();

    final addressesAsync = ref.watch(savedAddressesProvider(user.id));

    return addressesAsync.when(
      data: (addresses) {
        if (addresses.isEmpty) {
          _selectedPickupAddress = null;
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: AppRadius.cardR,
              border: Border.all(color: AppColors.error),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_off_outlined, color: AppColors.error),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'לא ניתן לפרסם מוצר ללא כתובת איסוף. הוסף כתובת כדי להמשיך.',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddressesPage()),
                    );
                  },
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('הוסף כתובת איסוף'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        if (_selectedPickupAddress != null &&
            !addresses.any((a) => a.id == _selectedPickupAddress!.id)) {
          _selectedPickupAddress = null;
        }
        _selectedPickupAddress ??= addresses.firstWhere(
          (a) => a.isDefault,
          orElse: () => addresses.first,
        );

        return DropdownButtonFormField<String>(
          initialValue: _selectedPickupAddress!.id,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          items: addresses
              .map(
                (a) => DropdownMenuItem(
                  value: a.id,
                  child: Text(
                    '${a.label} — ${a.fullAddress}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedPickupAddress = addresses.firstWhere(
                (a) => a.id == value,
              );
            });
          },
          validator: (_) =>
              _selectedPickupAddress == null ? 'נא לבחור כתובת איסוף' : null,
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => StreamErrorView.compact(
        error: error,
        title: 'לא הצלחנו לטעון את כתובות האיסוף',
        onRetry: () => ref.invalidate(savedAddressesProvider(user.id)),
      ),
    );
  }

  Widget _buildImagesSection() {
    final totalMedia =
        _selectedImages.length +
        _selectedVideos.length +
        _selectedVideosPaths.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'מדיה ($totalMedia/${AppConstants.maxProductImages})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: totalMedia < AppConstants.maxProductImages
                      ? _pickVideo
                      : null,
                  icon: const Icon(Icons.videocam),
                  label: const Text('וידאו'),
                ),
                TextButton.icon(
                  onPressed: totalMedia < AppConstants.maxProductImages
                      ? _pickImages
                      : null,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('תמונות'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedImages.isNotEmpty && !kIsWeb)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _analyzePhotoQuality,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('בדוק איכות'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _enhanceImage(0),
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: const Text('שפר תמונה'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (totalMedia == 0)
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.perm_media_outlined,
                    size: 64,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'לחץ להוספת תמונות או וידאו',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'עד ${AppConstants.maxProductImages} קבצים',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._selectedVideos.asMap().entries.map((entry) {
                  final index = entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 120,
                            height: 120,
                            color: Colors.black,
                            child: const Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeVideo(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'וידאו',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                ..._selectedVideosPaths.asMap().entries.map((entry) {
                  final index = entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 120,
                            height: 120,
                            color: Colors.black,
                            child: const Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeVideo(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                ..._selectedImages.asMap().entries.map((entry) {
                  final index = entry.key;
                  final isFirst =
                      _selectedVideos.isEmpty &&
                      _selectedVideosPaths.isEmpty &&
                      index == 0;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: index < _imageBytes.length
                              ? Image.memory(
                                  _imageBytes[index],
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 120,
                                  height: 120,
                                  color: AppColors.surfaceVariant,
                                  child: const Icon(Icons.image_outlined),
                                ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        if (isFirst)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ראשית',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }
}

class _AIAnalysisDialog extends StatelessWidget {
  final ProductAnalysis analysis;

  const _AIAnalysisDialog({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.auto_awesome, color: AppColors.primary),
          SizedBox(width: 8),
          Text('ניתוח AI של המוצר'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'זיהינו את המוצר שלך! בדוק את הפרטים:',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),

            _InfoRow(label: 'שם', value: analysis.title),

            if (analysis.brand != null)
              _InfoRow(label: 'מותג', value: analysis.brand!),

            if (analysis.model != null)
              _InfoRow(label: 'דגם', value: analysis.model!),

            if (analysis.color != null)
              _InfoRow(label: 'צבע', value: analysis.color!),

            if (analysis.category != null)
              _InfoRow(label: 'קטגוריה', value: _categoryDisplay(analysis)),

            if (analysis.subcategory != null)
              _InfoRow(
                label: 'תת-קטגוריה',
                value: _subCategoryDisplay(analysis),
              ),

            if (analysis.condition != null)
              _InfoRow(label: 'מצב', value: analysis.condition!),

            if (analysis.priceEstimate != null)
              _InfoRow(
                label: 'מחיר משוער',
                value: analysis.priceEstimate!.toDisplayString(),
              ),

            if (analysis.description != null &&
                analysis.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'תיאור:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      analysis.description!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),

            if (analysis.features.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'מאפיינים:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...analysis.features.map(
                      (feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                feature,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (analysis.missingInfo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppColors.warning,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'נא להשלים:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ...analysis.missingInfo.map(
                        (info) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              const Text('• ', style: TextStyle(fontSize: 16)),
                              Expanded(
                                child: Text(
                                  info,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('ביטול'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('אישור והשלמה'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

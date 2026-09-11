import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/stream_error_view.dart';
import '../../../../shared/models/seller_storefront_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../domain/storefront_validator.dart';
import '../providers/storefront_provider.dart';
import '../widgets/theme_selector_widget.dart';
import '../widgets/storefront_preview_widget.dart';
import '../widgets/color_picker_widget.dart';
import '../widgets/image_upload_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/pages/seller_profile_page.dart';

class StorefrontEditorPage extends ConsumerStatefulWidget {
  const StorefrontEditorPage({super.key});

  @override
  ConsumerState<StorefrontEditorPage> createState() =>
      _StorefrontEditorPageState();
}

class _StorefrontEditorPageState extends ConsumerState<StorefrontEditorPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSaving = false;
  String? _errorMessage;

  bool _isTogglingStoreOpen = false;

  StorefrontCustomization? _customization;
  bool _hasChanges = false;

  XFile? _pendingLogo;
  XFile? _pendingBanner;

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _taglineController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _facebookController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descriptionController.dispose();
    _taglineController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _whatsappController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final storefrontAsync = ref.watch(myStorefrontProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('עיצוב החנות שלי'),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined),
            tooltip: 'תצוגה מקדימה',
            onPressed: () {
              if (user != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SellerProfilePage(
                      sellerId: user.id,
                      sellerName: user.displayName,
                    ),
                  ),
                );
              }
            },
          ),
          if (_hasChanges)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveCustomization,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'שומר...' : 'שמור'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'ערכת נושא'),
            Tab(text: 'צבעים'),
            Tab(text: 'תמונות'),
            Tab(text: 'טקסטים'),
            Tab(text: 'קישורים'),
          ],
        ),
      ),
      body: storefrontAsync.when(
        data: (customization) {
          if (_customization == null && customization != null) {
            _customization = customization;
            _initializeControllers(customization);
          } else if (_customization == null) {
            _customization = StorefrontCustomization(
              theme: StorefrontTheme.modern,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              isActive: true,
            );
          }

          return Column(
            children: [
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'תצוגה מקדימה',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    StorefrontPreviewWidget(
                      customization: _customization!,
                      sellerName: user?.displayName,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              _buildStoreOpenSwitch(user),

              const Divider(height: 1),

              if (_errorMessage != null)
                Container(
                  color: AppColors.error.withValues(alpha: 0.1),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildThemeTab(),

                    _buildColorsTab(),

                    _buildImagesTab(),

                    _buildTextsTab(),

                    _buildSocialLinksTab(),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StreamErrorView(
          error: error,
          title: 'לא הצלחנו לטעון את עיצוב החנות',
          onRetry: () => ref.invalidate(myStorefrontProvider),
        ),
      ),
    );
  }

  Widget _buildStoreOpenSwitch(UserModel? user) {
    if (user == null) return const SizedBox.shrink();

    final isOpen = user.isStoreOpen;
    return Container(
      color: AppColors.surface,
      child: SwitchListTile(
        secondary: Icon(
          isOpen ? Icons.storefront : Icons.storefront_outlined,
          color: isOpen ? AppColors.success : AppColors.textSecondary,
        ),
        title: const Text(
          'חנות פתוחה',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          isOpen ? 'החנות מוצגת לקונים כפעילה' : 'החנות מוצגת לקונים כסגורה',
          style: const TextStyle(fontSize: 12),
        ),
        value: isOpen,
        onChanged: _isTogglingStoreOpen
            ? null
            : (value) => _setStoreOpen(user.id, value),
      ),
    );
  }

  Future<void> _setStoreOpen(String userId, bool open) async {
    setState(() {
      _isTogglingStoreOpen = true;
    });

    try {
      await ref.read(authRepositoryProvider).updateUserData(userId, {
        'isStoreOpen': open,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(open ? 'החנות סומנה כפתוחה' : 'החנות סומנה כסגורה'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בעדכון סטטוס החנות: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingStoreOpen = false;
        });
      }
    }
  }

  Widget _buildThemeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ThemeSelectorWidget(
        selectedTheme: _customization?.theme ?? StorefrontTheme.modern,
        onThemeSelected: (theme) {
          setState(() {
            _customization = _customization!.copyWith(theme: theme);
            _hasChanges = true;
          });
        },
      ),
    );
  }

  Widget _buildColorsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ColorPickerWidget(
            label: 'צבע ראשי',
            description: 'הצבע העיקרי של החנות (כותרות, כפתורים)',
            currentColor:
                _customization?.getPrimaryColor() ?? const Color(0xFF6366F1),
            onColorChanged: (color) {
              setState(() {
                _customization = _customization!.copyWith(
                  customPrimaryColor: _colorToHex(color),
                );
                _hasChanges = true;
              });
            },
          ),

          const SizedBox(height: 24),

          ColorPickerWidget(
            label: 'צבע משני',
            description: 'צבע להדגשות וכפתורי פעולה',
            currentColor:
                _customization?.getAccentColor() ?? const Color(0xFFA5B4FC),
            onColorChanged: (color) {
              setState(() {
                _customization = _customization!.copyWith(
                  customAccentColor: _colorToHex(color),
                );
                _hasChanges = true;
              });
            },
          ),

          const SizedBox(height: 24),

          ColorPickerWidget(
            label: 'צבע רקע',
            description: 'צבע הרקע של החנות',
            currentColor:
                _customization?.getBackgroundColor() ?? const Color(0xFFF8FAFC),
            onColorChanged: (color) {
              setState(() {
                _customization = _customization!.copyWith(
                  customBackgroundColor: _colorToHex(color),
                );
                _hasChanges = true;
              });
            },
          ),

          const SizedBox(height: 24),

          ColorPickerWidget(
            label: 'צבע טקסט',
            description: 'צבע הטקסט בחנות',
            currentColor:
                _customization?.getTextColor() ?? const Color(0xFF1E293B),
            onColorChanged: (color) {
              setState(() {
                _customization = _customization!.copyWith(
                  customTextColor: _colorToHex(color),
                );
                _hasChanges = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImagesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ImageUploadWidget(
            currentImageUrl: _customization?.logoUrl,
            label: 'לוגו החנות',
            description: 'תמונה עגולה שתוצג בראש עמוד החנות',
            onImageSelected: (image) {
              setState(() {
                _pendingLogo = image;
                _hasChanges = true;
              });
            },
            onImageRemoved: () {
              setState(() {
                _pendingLogo = null;
                _customization = _customization!.copyWith(logoUrl: null);
                _hasChanges = true;
              });
            },
            aspectRatio: 1.0,
            maxHeight: 200,
          ),

          const SizedBox(height: 32),

          ImageUploadWidget(
            currentImageUrl: _customization?.bannerUrl,
            label: 'באנר החנות',
            description: 'תמונה רחבה שתוצג בחלק העליון של עמוד החנות',
            onImageSelected: (image) {
              setState(() {
                _pendingBanner = image;
                _hasChanges = true;
              });
            },
            onImageRemoved: () {
              setState(() {
                _pendingBanner = null;
                _customization = _customization!.copyWith(bannerUrl: null);
                _hasChanges = true;
              });
            },
            aspectRatio: 16 / 9,
            maxHeight: 200,
          ),
        ],
      ),
    );
  }

  Widget _buildTextsTab() {
    const maxDescLength = StorefrontValidator.maxDescriptionLength;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'סלוגן החנות',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'משפט קצר ותמציתי שמתאר את החנות שלך (עד 50 תווים)',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _taglineController,
            maxLength: 50,
            decoration: const InputDecoration(
              hintText: 'לדוגמה: נרות בעבודת יד מחומרים טבעיים',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _customization = _customization!.copyWith(storeTagline: value);
                _hasChanges = true;
              });
            },
          ),

          const SizedBox(height: 24),

          Text(
            'תיאור החנות',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'תיאור מפורט של החנות שלך (עד $maxDescLength תווים)',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLength: maxDescLength,
            maxLines: 5,
            decoration: InputDecoration(
              hintText:
                  'ספר לקונים על החנות שלך, הערכים שלך, ומה הופך את המוצרים שלך למיוחדים...',
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _customization = _customization!.copyWith(
                  storeDescription: value,
                );
                _hasChanges = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLinksTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSocialLinkField(
            label: 'Instagram',
            icon: Icons.camera_alt,
            controller: _instagramController,
            hintText: 'https://instagram.com/your_shop',
            onChanged: (value) {
              setState(() {
                _customization = _customization!.copyWith(instagramUrl: value);
                _hasChanges = true;
              });
            },
          ),

          const SizedBox(height: 20),

          _buildSocialLinkField(
            label: 'Facebook',
            icon: Icons.facebook,
            controller: _facebookController,
            hintText: 'https://facebook.com/your_shop',
            onChanged: (value) {
              setState(() {
                _customization = _customization!.copyWith(facebookUrl: value);
                _hasChanges = true;
              });
            },
          ),

          const SizedBox(height: 20),

          _buildSocialLinkField(
            label: 'WhatsApp',
            icon: Icons.chat,
            controller: _whatsappController,
            hintText: '972501234567',
            onChanged: (value) {
              setState(() {
                _customization = _customization!.copyWith(
                  whatsappNumber: value,
                );
                _hasChanges = true;
              });
            },
          ),

          const SizedBox(height: 20),

          _buildSocialLinkField(
            label: 'אתר אינטרנט',
            icon: Icons.language,
            controller: _websiteController,
            hintText: 'https://your-website.com',
            onChanged: (value) {
              setState(() {
                _customization = _customization!.copyWith(websiteUrl: value);
                _hasChanges = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLinkField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hintText,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: true,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _initializeControllers(StorefrontCustomization customization) {
    _descriptionController.text = customization.storeDescription ?? '';
    _taglineController.text = customization.storeTagline ?? '';
    _instagramController.text = customization.instagramUrl ?? '';
    _facebookController.text = customization.facebookUrl ?? '';
    _whatsappController.text = customization.whatsappNumber ?? '';
    _websiteController.text = customization.websiteUrl ?? '';
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  Future<void> _saveCustomization() async {
    if (_customization == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('User not found');

      final repository = ref.read(storefrontRepositoryProvider);

      String? logoUrl = _customization!.logoUrl;
      String? bannerUrl = _customization!.bannerUrl;

      if (_pendingLogo != null) {
        logoUrl = await repository.uploadLogo(user.id, _pendingLogo!);
      }

      if (_pendingBanner != null) {
        bannerUrl = await repository.uploadBanner(user.id, _pendingBanner!);
      }

      final finalCustomization = _customization!.copyWith(
        logoUrl: logoUrl,
        bannerUrl: bannerUrl,
        updatedAt: DateTime.now(),
      );

      final validation = ref.read(
        validateCustomizationProvider(finalCustomization),
      );

      if (!validation.isValid) {
        setState(() {
          _errorMessage = validation.errors.join('\n');
          _isSaving = false;
        });
        return;
      }

      await repository.updateStorefrontCustomization(
        user.id,
        finalCustomization,
      );

      setState(() {
        _pendingLogo = null;
        _pendingBanner = null;
        _hasChanges = false;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ העיצוב נשמר בהצלחה!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'שגיאה בשמירה: ${e.toString()}';
        _isSaving = false;
      });
    }
  }
}

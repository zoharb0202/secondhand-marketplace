import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../../../shared/widgets/address_form_fields.dart';
import '../providers/auth_provider.dart';

class AddFirstAddressPage extends ConsumerStatefulWidget {
  const AddFirstAddressPage({super.key});

  @override
  ConsumerState<AddFirstAddressPage> createState() =>
      _AddFirstAddressPageState();
}

class _AddFirstAddressPageState extends ConsumerState<AddFirstAddressPage> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = AddressFormControllers();

  GeoPoint? _prefillLocation;
  bool _isSaving = false;
  bool _isLocating = false;

  @override
  void dispose() {
    _controllers.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    final locationService = ref.read(locationServiceProvider);

    try {
      final position = await locationService.getCurrentPosition();
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('לא ניתן לגשת למיקום. אנא בדוק הרשאות'),
            ),
          );
        }
        return;
      }

      final parts = await locationService.getAddressComponentsFromCoordinates(
        position.latitude,
        position.longitude,
      );
      String? fallbackStreet;
      if (parts == null) {
        fallbackStreet = await locationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
      }

      if (!mounted) return;
      setState(() {
        _prefillLocation = GeoPoint(position.latitude, position.longitude);
        if (parts != null) {
          if (parts.street.isNotEmpty) _controllers.street.text = parts.street;
          if (parts.city.isNotEmpty) _controllers.city.text = parts.city;
        } else if (fallbackStreet != null && fallbackStreet.isNotEmpty) {
          _controllers.street.text = fallbackStreet;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      GeoPoint? location = await ref
          .read(locationServiceProvider)
          .getCoordinatesFromAddress(
            '${_controllers.street.text}, ${_controllers.city.text}',
          );
      location ??= _prefillLocation;

      if (location == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'לא ניתן למצוא את הכתובת. אנא בדוק את הכתובת ונסה שוב.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      await FirebaseFirestore.instance.collection('addresses').add({
        'userId': user.uid,
        'label': _controllers.label.text.trim().isEmpty
            ? 'בית'
            : _controllers.label.text.trim(),
        'fullAddress': '${_controllers.street.text}, ${_controllers.city.text}',
        'city': _controllers.city.text,
        'street': _controllers.street.text,
        'apartmentNumber': _controllers.apartment.text.isEmpty
            ? null
            : _controllers.apartment.text,
        'floor': _controllers.floor.text.isEmpty
            ? null
            : _controllers.floor.text,
        'instructions': _controllers.instructions.text.isEmpty
            ? null
            : _controllers.instructions.text,
        'location': location,
        'isDefault': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשמירת הכתובת: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('הוסף כתובת'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 56,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'לפני שממשיכים, נצטרך כתובת',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'הכתובת משמשת לאיסוף מוצרים ולהצגת מוצרים קרובים. ניתן להוסיף כתובות נוספות בהמשך מהפרופיל.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                OutlinedButton.icon(
                  onPressed: _isLocating ? null : _useCurrentLocation,
                  icon: _isLocating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: const Text('השתמש במיקום הנוכחי'),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.cardR,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: AddressFormFields(controllers: _controllers),
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'שמור והמשך',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

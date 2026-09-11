import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AddressesPage extends ConsumerStatefulWidget {
  const AddressesPage({super.key});

  @override
  ConsumerState<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends ConsumerState<AddressesPage> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('הכתובות שלי')),
        body: Center(
          child: authState.isLoading
              ? const CircularProgressIndicator()
              : const Text('יש להתחבר'),
        ),
      );
    }

    final addressesAsync = ref.watch(savedAddressesProvider(user.uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('הכתובות שלי'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddAddressDialog(user.uid),
          ),
        ],
      ),
      body: addressesAsync.when(
        data: (addresses) {
          if (addresses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    size: 64,
                    color: context.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'אין כתובות שמורות',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'הוסף כתובת לאיסוף מוצרים',
                    style: TextStyle(color: context.textTertiary),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddAddressDialog(user.uid),
                    icon: const Icon(Icons.add),
                    label: const Text('הוסף כתובת'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _addCurrentLocation(user.uid),
                    icon: const Icon(Icons.my_location),
                    label: const Text('השתמש במיקום הנוכחי'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: addresses.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final address = addresses[index];
              return _AddressCard(
                address: address,
                onEdit: () => _showEditAddressDialog(address),
                onDelete: () => _deleteAddress(address.id),
                onSetDefault: () => _setDefaultAddress(user.uid, address.id),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _AddressesError(
          error: error,
          onRetry: () => ref.invalidate(savedAddressesProvider(user.uid)),
        ),
      ),
    );
  }

  Future<void> _addCurrentLocation(String userId) async {
    final locationService = ref.read(locationServiceProvider);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final position = await locationService.getCurrentPosition();
      if (position == null) {
        if (mounted) Navigator.pop(context);
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
      String prefillStreet;
      String prefillCity;
      if (parts != null) {
        prefillStreet = parts.street;
        prefillCity = parts.city;
      } else {
        final address = await locationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        prefillStreet = address ?? '';
        prefillCity = '';
      }

      if (mounted) Navigator.pop(context);

      if (mounted) {
        _showAddAddressDialog(
          userId,
          prefillStreet: prefillStreet,
          prefillCity: prefillCity,
          prefillLocation: GeoPoint(position.latitude, position.longitude),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
      }
    }
  }

  void _showAddAddressDialog(
    String userId, {
    String? prefillStreet,
    String? prefillCity,
    GeoPoint? prefillLocation,
  }) {
    final labelController = TextEditingController();
    final streetController = TextEditingController(text: prefillStreet);
    final cityController = TextEditingController(text: prefillCity);
    final apartmentController = TextEditingController();
    final floorController = TextEditingController();
    final instructionsController = TextEditingController();
    GeoPoint? location = prefillLocation;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('הוסף כתובת'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'שם הכתובת *',
                  hintText: 'לדוגמה: בית, עבודה',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: streetController,
                decoration: const InputDecoration(
                  labelText: 'רחוב ומספר *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cityController,
                decoration: const InputDecoration(
                  labelText: 'עיר *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: apartmentController,
                      decoration: const InputDecoration(
                        labelText: 'דירה',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: floorController,
                      decoration: const InputDecoration(
                        labelText: 'קומה',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: instructionsController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'הערות לכתובת',
                  hintText: 'קוד כניסה, קומה, הערות לאיסוף...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (labelController.text.isEmpty ||
                  streetController.text.isEmpty ||
                  cityController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('יש למלא שדות חובה')),
                );
                return;
              }

              final streetError = AddressValidation.validateStreet(
                streetController.text,
              );
              if (streetError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(streetError),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              {
                final locationService = ref.read(locationServiceProvider);
                final geocoded = await locationService
                    .getCoordinatesFromAddress(
                      '${streetController.text}, ${cityController.text}',
                    );
                location = geocoded ?? location;
              }

              if (location == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'לא ניתן למצוא את הכתובת. אנא בדוק את הכתובת ונסה שוב.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              final existingAddresses = await FirebaseFirestore.instance
                  .collection('addresses')
                  .where('userId', isEqualTo: userId)
                  .get();

              await FirebaseFirestore.instance.collection('addresses').add({
                'userId': userId,
                'label': labelController.text,
                'fullAddress':
                    '${streetController.text}, ${cityController.text}',
                'city': cityController.text,
                'street': streetController.text,
                'apartmentNumber': apartmentController.text.isEmpty
                    ? null
                    : apartmentController.text,
                'floor': floorController.text.isEmpty
                    ? null
                    : floorController.text,
                'instructions': instructionsController.text.isEmpty
                    ? null
                    : instructionsController.text,
                'location': location,
                'isDefault': existingAddresses.docs.isEmpty,
                'createdAt': FieldValue.serverTimestamp(),
              });

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('הכתובת נוספה בהצלחה')),
                );
              }
            },
            child: const Text('הוסף'),
          ),
        ],
      ),
    );
  }

  void _showEditAddressDialog(SavedAddress address) {
    final labelController = TextEditingController(text: address.label);
    final streetController = TextEditingController(text: address.street);
    final cityController = TextEditingController(text: address.city);
    final apartmentController = TextEditingController(
      text: address.apartmentNumber,
    );
    final floorController = TextEditingController(text: address.floor);
    final instructionsController = TextEditingController(
      text: address.instructions,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ערוך כתובת'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'שם הכתובת',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: streetController,
                decoration: const InputDecoration(
                  labelText: 'רחוב ומספר',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cityController,
                decoration: const InputDecoration(
                  labelText: 'עיר',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: apartmentController,
                      decoration: const InputDecoration(
                        labelText: 'דירה',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: floorController,
                      decoration: const InputDecoration(
                        labelText: 'קומה',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: instructionsController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'הערות לכתובת',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (labelController.text.isEmpty ||
                  streetController.text.isEmpty ||
                  cityController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('יש למלא שדות חובה')),
                );
                return;
              }

              final streetError = AddressValidation.validateStreet(
                streetController.text,
              );
              if (streetError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(streetError),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final addressChanged =
                  streetController.text != address.street ||
                  cityController.text != address.city;

              final locationService = ref.read(locationServiceProvider);
              final newLocation = await locationService
                  .getCoordinatesFromAddress(
                    '${streetController.text}, ${cityController.text}',
                  );

              if (addressChanged && newLocation == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'לא ניתן למצוא את הכתובת. אנא בדוק את הכתובת ונסה שוב.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              await FirebaseFirestore.instance
                  .collection('addresses')
                  .doc(address.id)
                  .update({
                    'label': labelController.text,
                    'fullAddress':
                        '${streetController.text}, ${cityController.text}',
                    'city': cityController.text,
                    'street': streetController.text,
                    'apartmentNumber': apartmentController.text.isEmpty
                        ? null
                        : apartmentController.text,
                    'floor': floorController.text.isEmpty
                        ? null
                        : floorController.text,
                    'instructions': instructionsController.text.isEmpty
                        ? null
                        : instructionsController.text,
                    'location': newLocation ?? address.location,
                  });

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('הכתובת עודכנה')));
              }
            },
            child: const Text('שמור'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAddress(String addressId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('מחק כתובת'),
        content: const Text('האם אתה בטוח שברצונך למחוק כתובת זו?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('מחק'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('addresses')
          .doc(addressId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('הכתובת נמחקה')));
      }
    }
  }

  Future<void> _setDefaultAddress(String userId, String addressId) async {
    final batch = FirebaseFirestore.instance.batch();
    final addresses = await FirebaseFirestore.instance
        .collection('addresses')
        .where('userId', isEqualTo: userId)
        .get();

    for (final doc in addresses.docs) {
      batch.update(doc.reference, {'isDefault': doc.id == addressId});
    }

    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('כתובת ברירת מחדל עודכנה')));
    }
  }
}

class _AddressesError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _AddressesError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: context.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'לא הצלחנו לטעון את הכתובות שלך',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'בדוק את החיבור לאינטרנט ונסה שוב.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textTertiary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('נסה שוב'),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 16),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: context.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final SavedAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getIconForLabel(address.label),
                  color: context.accentCobalt,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    address.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                ),
                if (address.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.accentCobalt.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ברירת מחדל',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.accentCobalt,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              address.fullAddress,
              style: TextStyle(color: context.textSecondary),
            ),
            if (address.apartmentNumber != null || address.floor != null) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (address.apartmentNumber != null)
                    'דירה ${address.apartmentNumber}',
                  if (address.floor != null) 'קומה ${address.floor}',
                ].join(', '),
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
            ],
            if (address.instructions != null &&
                address.instructions!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.altSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: context.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        address.instructions!,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (!address.isDefault)
                  TextButton(
                    onPressed: onSetDefault,
                    child: const Text('קבע כברירת מחדל'),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                  color: context.textSecondary,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                  color: AppColors.error,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('בית') || lower.contains('home')) {
      return Icons.home;
    } else if (lower.contains('עבודה') ||
        lower.contains('work') ||
        lower.contains('משרד')) {
      return Icons.work;
    } else {
      return Icons.location_on;
    }
  }
}

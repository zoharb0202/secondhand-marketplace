import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/notification_preferences_model.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  NotificationPreferencesModel? _preferences;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    try {
      final doc = await _firestore
          .collection('notification_preferences')
          .doc(user.id)
          .get();

      if (doc.exists) {
        setState(() {
          _preferences = NotificationPreferencesModel.fromFirestore(doc);
          _isLoading = false;
        });
      } else {
        final defaultPrefs = NotificationPreferencesModel(
          userId: user.id,
          lastUpdated: DateTime.now(),
        );
        await _savePreferences(defaultPrefs);
        setState(() {
          _preferences = defaultPrefs;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('שגיאה בטעינת הגדרות: $e')));
      }
    }
  }

  Future<void> _savePreferences(NotificationPreferencesModel prefs) async {
    setState(() => _isSaving = true);

    try {
      await _firestore
          .collection('notification_preferences')
          .doc(prefs.userId)
          .set(prefs.toFirestore());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ההגדרות נשמרו בהצלחה ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('שגיאה בשמירת הגדרות: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _updatePreference<T>(
    T Function(NotificationPreferencesModel) getter,
    NotificationPreferencesModel Function(T) updater,
  ) {
    if (_preferences == null) return;
    final newPrefs = updater(getter(_preferences!));
    setState(() => _preferences = newPrefs);
    _savePreferences(newPrefs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('הגדרות התראות'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _preferences == null
          ? const Center(child: Text('לא נמצאו הגדרות'))
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSection(
                      title: 'הגדרות כלליות',
                      icon: Icons.settings,
                      children: [
                        _buildSwitchTile(
                          title: 'אפשר התראות',
                          subtitle: 'הפעל/השבת את כל ההתראות',
                          value: _preferences!.enableNotifications,
                          onChanged: (value) => _updatePreference(
                            (p) => p.enableNotifications,
                            (v) => _preferences!.copyWith(
                              enableNotifications: value,
                            ),
                          ),
                          icon: Icons.notifications_active,
                        ),
                        if (_preferences!.enableNotifications) ...[
                          _buildSwitchTile(
                            title: 'צלילים',
                            value: _preferences!.enableSounds,
                            onChanged: (value) => _updatePreference(
                              (p) => p.enableSounds,
                              (v) =>
                                  _preferences!.copyWith(enableSounds: value),
                            ),
                            icon: Icons.volume_up,
                          ),
                          _buildSwitchTile(
                            title: 'רטט',
                            value: _preferences!.enableVibration,
                            onChanged: (value) => _updatePreference(
                              (p) => p.enableVibration,
                              (v) => _preferences!.copyWith(
                                enableVibration: value,
                              ),
                            ),
                            icon: Icons.vibration,
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 24),

                    if (_preferences!.enableNotifications)
                      _buildSection(
                        title: 'שעות שקט',
                        icon: Icons.bedtime,
                        children: [_buildQuietHoursPicker()],
                      ),

                    const SizedBox(height: 24),

                    if (_preferences!.enableNotifications)
                      _buildSection(
                        title: 'מוצרים',
                        icon: Icons.shopping_bag,
                        children: [
                          _buildSwitchTile(
                            title: 'הודעות חדשות',
                            subtitle: 'התראות על הודעות חדשות ממוכרים',
                            value: _preferences!.notifyNewMessages,
                            onChanged: (value) => _updatePreference(
                              (p) => p.notifyNewMessages,
                              (v) => _preferences!.copyWith(
                                notifyNewMessages: value,
                              ),
                            ),
                            icon: Icons.message,
                          ),
                          _buildSwitchTile(
                            title: 'הנחות במחיר',
                            subtitle: 'התראה כשמוצר במחיר מוזל',
                            value: _preferences!.notifyPriceReductions,
                            onChanged: (value) => _updatePreference(
                              (p) => p.notifyPriceReductions,
                              (v) => _preferences!.copyWith(
                                notifyPriceReductions: value,
                              ),
                            ),
                            icon: Icons.trending_down,
                          ),
                          _buildSwitchTile(
                            title: 'התראות מחיר',
                            subtitle: 'התראה כשמוצר מגיע למחיר המבוקש',
                            value: _preferences!.notifyPriceAlerts,
                            onChanged: (value) => _updatePreference(
                              (p) => p.notifyPriceAlerts,
                              (v) => _preferences!.copyWith(
                                notifyPriceAlerts: value,
                              ),
                            ),
                            icon: Icons.notifications_active,
                          ),
                          _buildSwitchTile(
                            title: 'חזרה למלאי',
                            subtitle: 'התראה כשמוצר חוזר למלאי',
                            value: _preferences!.notifyBackInStock,
                            onChanged: (value) => _updatePreference(
                              (p) => p.notifyBackInStock,
                              (v) => _preferences!.copyWith(
                                notifyBackInStock: value,
                              ),
                            ),
                            icon: Icons.inventory,
                          ),
                          _buildSwitchTile(
                            title: 'מוצרים דומים',
                            subtitle: 'התראה על מוצרים דומים למה שאהבת',
                            value: _preferences!.notifySimilarProducts,
                            onChanged: (value) => _updatePreference(
                              (p) => p.notifySimilarProducts,
                              (v) => _preferences!.copyWith(
                                notifySimilarProducts: value,
                              ),
                            ),
                            icon: Icons.content_copy,
                          ),
                          _buildSwitchTile(
                            title: 'מוצרים חדשים',
                            subtitle: 'התראה על מוצרים חדשים בקטגוריות שאהבת',
                            value: _preferences!.notifyNewProducts,
                            onChanged: (value) => _updatePreference(
                              (p) => p.notifyNewProducts,
                              (v) => _preferences!.copyWith(
                                notifyNewProducts: value,
                              ),
                            ),
                            icon: Icons.new_releases,
                          ),
                        ],
                      ),

                    const SizedBox(height: 24),

                    if (_preferences!.enableNotifications)
                      _buildSection(
                        title: 'רכישות',
                        icon: Icons.shopping_cart,
                        children: [
                          _buildSwitchTile(
                            title: 'סטטוס הזמנה',
                            value: _preferences!.notifyOrderStatus,
                            onChanged: (value) => _updatePreference(
                              (p) => p.notifyOrderStatus,
                              (v) => _preferences!.copyWith(
                                notifyOrderStatus: value,
                              ),
                            ),
                            icon: Icons.receipt_long,
                          ),
                          _buildSwitchTile(
                            title: 'סטטוס תשלום',
                            value: _preferences!.notifyPaymentStatus,
                            onChanged: (value) => _updatePreference(
                              (p) => p.notifyPaymentStatus,
                              (v) => _preferences!.copyWith(
                                notifyPaymentStatus: value,
                              ),
                            ),
                            icon: Icons.payment,
                          ),
                        ],
                      ),

                    const SizedBox(height: 24),

                    if (_preferences!.enableNotifications)
                      _buildSection(
                        title: 'צ\'אט',
                        icon: Icons.chat,
                        children: [
                          _buildSwitchTile(
                            title: 'הודעות צ\'אט',
                            value: _preferences!.notifyChatMessages,
                            onChanged: (value) => _updatePreference(
                              (p) => p.notifyChatMessages,
                              (v) => _preferences!.copyWith(
                                notifyChatMessages: value,
                              ),
                            ),
                            icon: Icons.message,
                          ),
                          _buildSwitchTile(
                            title: 'הצעת מחיר התקבלה',
                            value: _preferences!.notifyOfferReceived,
                            onChanged: (value) => _updatePreference(
                              (p) => p.notifyOfferReceived,
                              (v) => _preferences!.copyWith(
                                notifyOfferReceived: value,
                              ),
                            ),
                            icon: Icons.local_offer,
                          ),
                          _buildSwitchTile(
                            title: 'הצעה התקבלה',
                            value: _preferences!.notifyOfferAccepted,
                            onChanged: (value) => _updatePreference(
                              (p) => p.notifyOfferAccepted,
                              (v) => _preferences!.copyWith(
                                notifyOfferAccepted: value,
                              ),
                            ),
                            icon: Icons.check_circle,
                          ),
                        ],
                      ),

                    const SizedBox(height: 24),

                    if (_preferences!.enableNotifications)
                      _buildSection(
                        title: 'ביקורות',
                        icon: Icons.star,
                        children: [
                          _buildSwitchTile(
                            title: 'ביקורות חדשות',
                            subtitle: 'התראה כשמישהו מדרג אותך',
                            value: _preferences!.notifyNewReviews,
                            onChanged: (value) => _updatePreference(
                              (p) => p.notifyNewReviews,
                              (v) => _preferences!.copyWith(
                                notifyNewReviews: value,
                              ),
                            ),
                            icon: Icons.rate_review,
                          ),
                          _buildSwitchTile(
                            title: 'תגובות לביקורות',
                            value: _preferences!.notifyReviewResponses,
                            onChanged: (value) => _updatePreference(
                              (p) => p.notifyReviewResponses,
                              (v) => _preferences!.copyWith(
                                notifyReviewResponses: value,
                              ),
                            ),
                            icon: Icons.reply,
                          ),
                        ],
                      ),

                    const SizedBox(height: 24),

                    if (_preferences!.enableNotifications)
                      _buildSection(
                        title: 'מערכת',
                        icon: Icons.settings_applications,
                        children: [
                          _buildSwitchTile(
                            title: 'המלצות מותאמות אישית',
                            subtitle: 'התראות על מוצרים מומלצים בשבילך',
                            value: _preferences!.notifyRecommendations,
                            onChanged: (value) => _updatePreference(
                              (p) => p.notifyRecommendations,
                              (v) => _preferences!.copyWith(
                                notifyRecommendations: value,
                              ),
                            ),
                            icon: Icons.auto_awesome,
                          ),
                          _buildSwitchTile(
                            title: 'מבצעים',
                            subtitle: 'קבל התראות על מבצעים והנחות',
                            value: _preferences!.notifyPromotions,
                            onChanged: (value) => _updatePreference(
                              (p) => p.notifyPromotions,
                              (v) => _preferences!.copyWith(
                                notifyPromotions: value,
                              ),
                            ),
                            icon: Icons.local_offer,
                          ),
                          _buildSwitchTile(
                            title: 'עדכוני מערכת',
                            value: _preferences!.notifySystemUpdates,
                            onChanged: (value) => _updatePreference(
                              (p) => p.notifySystemUpdates,
                              (v) => _preferences!.copyWith(
                                notifySystemUpdates: value,
                              ),
                            ),
                            icon: Icons.system_update,
                          ),
                        ],
                      ),

                    const SizedBox(height: 80),
                  ],
                ),

                if (_isSaving)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'שומר...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary,
      ),
    );
  }

  Widget _buildQuietHoursPicker() {
    return ListTile(
      leading: const Icon(Icons.bedtime, color: AppColors.primary),
      title: const Text('הגדר שעות שקט'),
      subtitle: Text(
        _preferences!.quietHoursStart != null &&
                _preferences!.quietHoursEnd != null
            ? 'מ-${_formatHour(_preferences!.quietHoursStart!)} עד ${_formatHour(_preferences!.quietHoursEnd!)}'
            : 'לא מוגדר',
      ),
      trailing: const Icon(Icons.chevron_left),
      onTap: () => _showQuietHoursDialog(),
    );
  }

  String _formatHour(int hour) {
    return '${hour.toString().padLeft(2, '0')}:00';
  }

  Future<void> _showQuietHoursDialog() async {
    int? startHour = _preferences!.quietHoursStart ?? 22;
    int? endHour = _preferences!.quietHoursEnd ?? 8;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('שעות שקט'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('בחר טווח שעות בו לא תקבל התראות:'),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      const Text('התחלה'),
                      const SizedBox(height: 8),
                      DropdownButton<int>(
                        value: startHour,
                        items: List.generate(24, (i) => i).map((hour) {
                          return DropdownMenuItem(
                            value: hour,
                            child: Text(_formatHour(hour)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => startHour = value);
                        },
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_back),
                  Column(
                    children: [
                      const Text('סיום'),
                      const SizedBox(height: 8),
                      DropdownButton<int>(
                        value: endHour,
                        items: List.generate(24, (i) => i).map((hour) {
                          return DropdownMenuItem(
                            value: hour,
                            child: Text(_formatHour(hour)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => endHour = value);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _updatePreference(
                  (p) => p.quietHoursStart,
                  (v) => _preferences!.copyWith(
                    quietHoursStart: null,
                    quietHoursEnd: null,
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text('נקה'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ביטול'),
            ),
            ElevatedButton(
              onPressed: () {
                _updatePreference(
                  (p) => p.quietHoursStart,
                  (v) => _preferences!.copyWith(
                    quietHoursStart: startHour,
                    quietHoursEnd: endHour,
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text('שמור'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../shared/models/availability_window.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/services/opening_hours_service.dart';

class AvailabilitySettingsPage extends ConsumerStatefulWidget {
  const AvailabilitySettingsPage({super.key});

  @override
  ConsumerState<AvailabilitySettingsPage> createState() =>
      _AvailabilitySettingsPageState();
}

class _AvailabilitySettingsPageState
    extends ConsumerState<AvailabilitySettingsPage> {
  List<AvailabilityWindow> _windows = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final userAsync = ref.read(authStateProvider);
    userAsync.whenData((user) async {
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null && data['availabilityWindows'] != null) {
            setState(() {
              _windows = AvailabilityWindow.parseList(
                data['availabilityWindows'],
              );
              _isLoading = false;
            });
            return;
          }
        }
      }
      setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('זמני זמינות לאיסוף'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addWindow,
              tooltip: 'הוסף חלון זמן',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      bottomNavigationBar: _isSaving
          ? const LinearProgressIndicator()
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _saveAvailability,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('שמור'),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_windows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: context.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'לא הוגדרו זמני זמינות',
              style: TextStyle(fontSize: 18, color: context.textSecondary),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'הוסיפו חלונות זמן שבהם קונים יכולים לאסוף מוצרים',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addWindow,
              icon: const Icon(Icons.add),
              label: const Text('הוסף חלון זמן'),
            ),
          ],
        ),
      );
    }

    final Map<int, List<AvailabilityWindow>> groupedWindows = {};
    for (final window in _windows) {
      if (!groupedWindows.containsKey(window.dayOfWeek)) {
        groupedWindows[window.dayOfWeek] = [];
      }
      groupedWindows[window.dayOfWeek]!.add(window);
    }

    final sortedDays = groupedWindows.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDays.length,
      itemBuilder: (context, index) {
        final day = sortedDays[index];
        final dayWindows = groupedWindows[day]!;
        final dayName = dayWindows.first.getDayName();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(
              dayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              dayWindows.length == 1
                  ? 'חלון זמן אחד'
                  : '${dayWindows.length} חלונות זמן',
              style: TextStyle(color: context.textSecondary),
            ),
            children: dayWindows.map((window) {
              return ListTile(
                leading: const Icon(
                  Icons.access_time,
                  color: AppColors.primary,
                ),
                title: Text(window.timeRange.getFormattedRange()),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  onPressed: () => _removeWindow(window),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _addWindow() {
    showDialog(
      context: context,
      builder: (context) => _AddWindowDialog(
        onAdd: (window) {
          setState(() {
            _windows.add(window);
          });
        },
      ),
    );
  }

  void _removeWindow(AvailabilityWindow window) {
    setState(() {
      _windows.remove(window);
    });
  }

  Future<void> _saveAvailability() async {
    setState(() => _isSaving = true);

    try {
      final userAsync = ref.read(authStateProvider);
      final user = userAsync.valueOrNull;

      if (user != null) {
        await OpeningHoursService().saveMine(_windows);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('זמני הזמינות נשמרו בהצלחה'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } on SellerHoursMirrorException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'זמני הזמינות נשמרו. תגית "זמין מיידי" במודעות תתעדכן בשמירה הבאה',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשמירה: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _AddWindowDialog extends StatefulWidget {
  final Function(AvailabilityWindow) onAdd;

  const _AddWindowDialog({required this.onAdd});

  @override
  State<_AddWindowDialog> createState() => _AddWindowDialogState();
}

class _AddWindowDialogState extends State<_AddWindowDialog> {
  int _selectedDay = 1;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  final List<String> _dayNames = [
    'ראשון',
    'שני',
    'שלישי',
    'רביעי',
    'חמישי',
    'שישי',
    'שבת',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('הוסף חלון זמן'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('יום:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _selectedDay,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: List.generate(7, (index) {
                return DropdownMenuItem(
                  value: index + 1,
                  child: Text(_dayNames[index]),
                );
              }),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedDay = value);
                }
              },
            ),
            const SizedBox(height: 16),
            const Text('שעות:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                      );
                      if (time != null) {
                        setState(() => _startTime = time);
                      }
                    },
                    icon: const Icon(Icons.access_time),
                    label: Text(_startTime.format(context)),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('-'),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
                      );
                      if (time != null) {
                        setState(() => _endTime = time);
                      }
                    },
                    icon: const Icon(Icons.access_time),
                    label: Text(_endTime.format(context)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ביטול'),
        ),
        ElevatedButton(onPressed: _addWindow, child: const Text('הוסף')),
      ],
    );
  }

  void _addWindow() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;

    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('שעת הסיום חייבת להיות אחרי שעת ההתחלה'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final window = AvailabilityWindow(
      dayOfWeek: _selectedDay,
      timeRange: TimeRange(
        startHour: _startTime.hour,
        startMinute: _startTime.minute,
        endHour: _endTime.hour,
        endMinute: _endTime.minute,
      ),
    );

    widget.onAdd(window);
    Navigator.pop(context);
  }
}

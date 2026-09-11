import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SavedSearchesPage extends ConsumerWidget {
  const SavedSearchesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('יש להתחבר')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('חיפושים שמורים'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showSaveSearchDialog(context, user.uid),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('saved_searches')
            .where('userId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('שגיאה: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final searches = snapshot.data!.docs;

          if (searches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'אין חיפושים שמורים',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'שמור חיפושים כדי לקבל התראות על מוצרים חדשים',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showSaveSearchDialog(context, user.uid),
                    icon: const Icon(Icons.add),
                    label: const Text('שמור חיפוש חדש'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: searches.length,
            itemBuilder: (context, index) {
              final search = searches[index].data() as Map<String, dynamic>;
              return _SavedSearchCard(
                searchId: searches[index].id,
                search: search,
                onTap: () {
                  Navigator.pop(context, search['query']);
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showSaveSearchDialog(BuildContext context, String userId) {
    final queryController = TextEditingController();
    String? selectedCategory;
    double? maxPrice;
    bool notifyOnNew = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('שמור חיפוש'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: queryController,
                  decoration: const InputDecoration(
                    labelText: 'מילות חיפוש',
                    hintText: 'לדוגמא: אייפון 14',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'קטגוריה (אופציונלי)',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'electronics',
                      child: Text('אלקטרוניקה'),
                    ),
                    DropdownMenuItem(value: 'fashion', child: Text('אופנה')),
                    DropdownMenuItem(
                      value: 'homeGarden',
                      child: Text('בית וגן'),
                    ),
                    DropdownMenuItem(value: 'vehicles', child: Text('רכב')),
                    DropdownMenuItem(
                      value: 'sports',
                      child: Text('ספורט ותחביבים'),
                    ),
                    DropdownMenuItem(
                      value: 'babyKids',
                      child: Text('תינוקות וילדים'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('אחר')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedCategory = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'מחיר מקסימלי (אופציונלי)',
                    border: OutlineInputBorder(),
                    prefixText: '₪ ',
                  ),
                  onChanged: (value) {
                    maxPrice = double.tryParse(value);
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('התראה על מוצרים חדשים'),
                  subtitle: const Text('קבל התראה כשמוצר תואם נוסף'),
                  value: notifyOnNew,
                  onChanged: (value) {
                    setState(() {
                      notifyOnNew = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
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
                if (queryController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('יש להזין מילות חיפוש')),
                  );
                  return;
                }

                await FirebaseFirestore.instance
                    .collection('saved_searches')
                    .add({
                      'userId': userId,
                      'query': queryController.text.trim(),
                      'category': selectedCategory,
                      'maxPrice': maxPrice,
                      'notifyOnNew': notifyOnNew,
                      'createdAt': FieldValue.serverTimestamp(),
                      'lastNotified': null,
                    });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('החיפוש נשמר!')));
                }
              },
              child: const Text('שמור'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedSearchCard extends StatelessWidget {
  final String searchId;
  final Map<String, dynamic> search;
  final VoidCallback onTap;

  const _SavedSearchCard({
    required this.searchId,
    required this.search,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final query = search['query'] ?? '';
    final category = search['category'];
    final maxPrice = search['maxPrice'];
    final notifyOnNew = search['notifyOnNew'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      query,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (notifyOnNew)
                    const Icon(
                      Icons.notifications_active,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'delete') {
                        await FirebaseFirestore.instance
                            .collection('saved_searches')
                            .doc(searchId)
                            .delete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('מחק'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (category != null)
                    _FilterChip(icon: Icons.category, label: category),
                  if (maxPrice != null)
                    _FilterChip(
                      icon: Icons.attach_money,
                      label: 'עד ₪${maxPrice.toStringAsFixed(0)}',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FilterChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/user_roles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  String _searchQuery = '';
  UserRole? _filterRole;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    if (currentUser == null ||
        (currentUser.role != UserRole.admin && !currentUser.isAdmin)) {
      return Scaffold(
        appBar: AppBar(title: const Text('ניהול משתמשים')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text(
                'אין הרשאה',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'רק מנהלים יכולים לגשת לדף זה',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ניהול משתמשים'),
        actions: [
          PopupMenuButton<UserRole?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (role) => setState(() => _filterRole = role),
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('הכל')),
              for (final role in UserRole.values)
                PopupMenuItem(value: role, child: Text(role.displayName)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'חיפוש לפי שם או אימייל...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(AppConstants.usersCollection)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('שגיאה: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['displayName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final matchesSearch =
                      _searchQuery.isEmpty ||
                      name.contains(_searchQuery) ||
                      email.contains(_searchQuery);

                  if (!matchesSearch) return false;

                  if (_filterRole != null) {
                    return UserRoleHelper.fromString(data['role'] as String?) ==
                        _filterRole;
                  }

                  return true;
                }).toList();

                if (users.isEmpty) {
                  return const Center(child: Text('לא נמצאו משתמשים'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final doc = users[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _UserCard(
                      userId: doc.id,
                      data: data,
                      onTap: () => _showUserDetails(doc.id, data),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(String userId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: data['photoUrl'] != null
                      ? NetworkImage(data['photoUrl'])
                      : null,
                  child: data['photoUrl'] == null
                      ? const Icon(Icons.person, size: 50)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  data['displayName'] ?? 'ללא שם',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 24),
              _DetailRow(icon: Icons.badge, label: 'מזהה משתמש', value: userId),
              _DetailRow(
                icon: Icons.email,
                label: 'אימייל',
                value: data['email'] ?? 'לא זמין',
              ),
              _DetailRow(
                icon: Icons.phone,
                label: 'טלפון',
                value: data['phoneNumber'] ?? 'לא זמין',
              ),
              _DetailRow(
                icon: Icons.person_outline,
                label: 'תפקיד',
                value: UserRoleHelper.fromString(
                  data['role'] as String?,
                ).displayName,
              ),
              _DetailRow(
                icon: Icons.location_city,
                label: 'עיר',
                value: data['city'] ?? 'לא זמין',
              ),
              _DetailRow(
                icon: Icons.calendar_today,
                label: 'תאריך הרשמה',
                value: _formatDate(data['createdAt']),
              ),
              _DetailRow(
                icon: Icons.access_time,
                label: 'התחברות אחרונה',
                value: _formatDate(data['lastLoginAt']),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditUserDialog(userId, data);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('עריכה'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _toggleUserStatus(userId, data);
                      },
                      icon: Icon(
                        data['isActive'] == false
                            ? Icons.check_circle
                            : Icons.block,
                      ),
                      label: Text(data['isActive'] == false ? 'הפעל' : 'השעה'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: data['isActive'] == false
                            ? Colors.green
                            : Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditUserDialog(String userId, Map<String, dynamic> data) {
    final nameController = TextEditingController(text: data['displayName']);
    final phoneController = TextEditingController(text: data['phoneNumber']);
    final cityController = TextEditingController(text: data['city']);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('עריכת משתמש'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'שם',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'טלפון',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(
                    labelText: 'עיר',
                    prefixIcon: Icon(Icons.location_city),
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
                await FirebaseFirestore.instance
                    .collection(AppConstants.usersCollection)
                    .doc(userId)
                    .update({
                      'displayName': nameController.text,
                      'phoneNumber': phoneController.text,
                      'city': cityController.text,
                    });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('המשתמש עודכן בהצלחה')),
                  );
                }
              },
              child: const Text('שמור'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleUserStatus(
    String userId,
    Map<String, dynamic> data,
  ) async {
    final isActive = data['isActive'] != false;
    await FirebaseFirestore.instance
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({'isActive': !isActive});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isActive ? 'המשתמש הושעה' : 'המשתמש הופעל')),
      );
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'לא זמין';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'לא זמין';
  }
}

class _UserCard extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _UserCard({
    required this.userId,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = data['isActive'] != false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundImage: data['photoUrl'] != null
                  ? NetworkImage(data['photoUrl'])
                  : null,
              child: data['photoUrl'] == null ? const Icon(Icons.person) : null,
            ),
            if (!isActive)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
        title: Text(
          data['displayName'] ?? 'ללא שם',
          style: TextStyle(
            decoration: isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(data['email'] ?? ''),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildRoleBadge(UserRoleHelper.fromString(data['role'] as String?)),
            const SizedBox(height: 4),
            Text(
              data['city'] ?? '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(UserRole role) {
    final color = switch (role) {
      UserRole.admin => Colors.purple,
      UserRole.supportAgent => Colors.blue,
      UserRole.customer => Colors.green,
    };
    final label = role.displayName;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

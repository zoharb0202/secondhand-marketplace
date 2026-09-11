import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/categories.dart';
import '../../../../core/constants/user_roles.dart';
import '../../../../core/widgets/nav_bar_clearance.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/models/user_model.dart';
import '../../models/support_ticket_model.dart';
import 'admin_support_panel.dart';
import 'debug_user_info.dart';
import '../widgets/ai_usage_card.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminTab {
  final String title;
  final String label;
  final IconData icon;
  final Widget page;

  const _AdminTab({
    required this.title,
    required this.label,
    required this.icon,
    required this.page,
  });
}

class _AdminDashboardState extends ConsumerState<AdminDashboard>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late final TabController _tabController;

  static const List<_AdminTab> _tabs = [
    _AdminTab(
      title: 'אנליטיקה',
      label: 'אנליטיקה',
      icon: Icons.analytics_outlined,
      page: _AnalyticsPage(),
    ),
    _AdminTab(
      title: 'ניהול משתמשים',
      label: 'משתמשים',
      icon: Icons.people_outline,
      page: _UserManagementPage(),
    ),
    _AdminTab(
      title: 'פניות לקוחות',
      label: 'פניות',
      icon: Icons.support_agent,
      page: AdminSupportPanel(embedded: true),
    ),
    _AdminTab(
      title: 'קטלוג מותגים',
      label: 'מותגים',
      icon: Icons.sell_outlined,
      page: _BrandCatalogPage(),
    ),
    _AdminTab(
      title: 'שימוש ב-AI',
      label: 'AI',
      icon: Icons.psychology_outlined,
      page: AiUsagePage(),
    ),
  ];

  late final List<Widget> _pages = [for (final tab in _tabs) tab.page];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _selectedIndex && mounted) {
        setState(() => _selectedIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (user.role != UserRole.admin) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: AppColors.error),
              const SizedBox(height: 16),
              const Text(
                'אין לך הרשאת גישה',
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('👑'),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _tabs[_selectedIndex.clamp(0, _tabs.length - 1)].title,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug Info',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const DebugUserInfo()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          onTap: (index) => setState(() => _selectedIndex = index),
          tabs: [
            for (final tab in _tabs)
              Tab(icon: Icon(tab.icon, size: 20), text: tab.label),
          ],
        ),
      ),
      body: NavBarClearanceInset(
        child: TabBarView(controller: _tabController, children: _pages),
      ),
    );
  }
}

class _AnalyticsPage extends ConsumerWidget {
  const _AnalyticsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, productsSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, usersSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('support_tickets')
                  .snapshots(),
              builder: (context, ticketsSnapshot) {
                if (!productsSnapshot.hasData ||
                    !usersSnapshot.hasData ||
                    !ticketsSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final totalProducts = productsSnapshot.data!.docs.length;
                final totalUsers = usersSnapshot.data!.docs.length;
                final totalTickets = ticketsSnapshot.data!.docs.length;

                final users = usersSnapshot.data!.docs
                    .map((doc) => UserModel.fromFirestore(doc))
                    .toList();

                final supportAgents = users
                    .where((u) => u.role == UserRole.supportAgent)
                    .length;
                final customers = users
                    .where((u) => u.role == UserRole.customer)
                    .length;

                final tickets = ticketsSnapshot.data!.docs
                    .map((doc) => SupportTicket.fromFirestore(doc))
                    .toList();

                final openTickets = tickets
                    .where((t) => t.status == TicketStatus.open)
                    .length;
                final inProgressTickets = tickets
                    .where((t) => t.status == TicketStatus.inProgress)
                    .length;
                final resolvedTickets = tickets
                    .where((t) => t.status == TicketStatus.resolved)
                    .length;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'סקירה כללית',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          _StatCard(
                            title: 'סה"כ משתמשים',
                            value: totalUsers.toString(),
                            icon: Icons.people,
                            color: Colors.blue,
                          ),
                          _StatCard(
                            title: 'סה"כ מוצרים',
                            value: totalProducts.toString(),
                            icon: Icons.inventory_2,
                            color: Colors.green,
                          ),
                          _StatCard(
                            title: 'פניות פתוחות',
                            value: openTickets.toString(),
                            icon: Icons.support_agent,
                            color: Colors.orange,
                          ),
                          _StatCard(
                            title: 'נציגי תמיכה',
                            value: supportAgents.toString(),
                            icon: Icons.headset_mic,
                            color: Colors.purple,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'פילוח משתמשים',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _ProgressRow(
                                label: 'לקוחות',
                                value: customers,
                                total: totalUsers,
                                color: Colors.blue,
                              ),
                              const SizedBox(height: 12),
                              _ProgressRow(
                                label: 'נציגי תמיכה',
                                value: supportAgents,
                                total: totalUsers,
                                color: Colors.purple,
                              ),
                              const SizedBox(height: 12),
                              _ProgressRow(
                                label: 'מנהלים',
                                value: 1,
                                total: totalUsers,
                                color: Colors.orange,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'פניות לקוחות',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _ProgressRow(
                                label: 'פתוחות',
                                value: openTickets,
                                total: totalTickets,
                                color: Colors.orange,
                              ),
                              const SizedBox(height: 12),
                              _ProgressRow(
                                label: 'בטיפול',
                                value: inProgressTickets,
                                total: totalTickets,
                                color: Colors.blue,
                              ),
                              const SizedBox(height: 12),
                              _ProgressRow(
                                label: 'נפתרו',
                                value: resolvedTickets,
                                total: totalTickets,
                                color: Colors.green,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _UserManagementPage extends ConsumerStatefulWidget {
  const _UserManagementPage();

  @override
  ConsumerState<_UserManagementPage> createState() =>
      _UserManagementPageState();
}

class _UserManagementPageState extends ConsumerState<_UserManagementPage> {
  UserRole? _filterRole;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('הכל'),
                  selected: _filterRole == null,
                  onSelected: (selected) {
                    setState(() => _filterRole = null);
                  },
                ),
                const SizedBox(width: 8),
                ...UserRole.values.map((role) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilterChip(
                      label: Text(
                        '${UserRoleHelper.getRoleIcon(role)} ${role.displayName}',
                      ),
                      selected: _filterRole == role,
                      onSelected: (selected) {
                        setState(() => _filterRole = selected ? role : null);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('שגיאה: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var users = snapshot.data!.docs
                  .map((doc) => UserModel.fromFirestore(doc))
                  .toList();

              if (_filterRole != null) {
                users = users.where((u) => u.role == _filterRole).toList();
              }

              if (users.isEmpty) {
                return const Center(child: Text('אין משתמשים'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return _UserCard(user: user);
                },
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showAddSupportAgentDialog(),
            icon: const Icon(Icons.add),
            label: const Text('הוסף נציג תמיכה'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddSupportAgentDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('הוסף נציג תמיכה חדש'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('צור משתמש חדש לנציג שירות לקוחות:'),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'שם מלא',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'אימייל',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'סיסמה',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
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
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final password = passwordController.text.trim();

              if (name.isEmpty || email.isEmpty || password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('נא למלא את כל השדות'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }

              try {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser == null) {
                  throw Exception('Admin not authenticated');
                }

                FirebaseApp? secondaryApp;
                try {
                  secondaryApp = await Firebase.initializeApp(
                    name: 'secondaryApp',
                    options: Firebase.app().options,
                  );
                } catch (e) {
                  secondaryApp = Firebase.app('secondaryApp');
                }

                final secondaryAuth = FirebaseAuth.instanceFor(
                  app: secondaryApp,
                );
                final userCredential = await secondaryAuth
                    .createUserWithEmailAndPassword(
                      email: email,
                      password: password,
                    );

                await userCredential.user?.updateDisplayName(name);

                final newUser = UserModel(
                  id: userCredential.user!.uid,
                  email: email,
                  displayName: name,
                  role: UserRole.supportAgent,
                  createdAt: DateTime.now(),
                );

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userCredential.user!.uid)
                    .set(newUser.toFirestore());

                await secondaryAuth.signOut();

                await secondaryApp.delete();

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('נציג תמיכה נוצר בהצלחה ✓'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } on FirebaseAuthException catch (e) {
                if (context.mounted) {
                  String message = 'שגיאה ביצירת משתמש';
                  if (e.code == 'weak-password') {
                    message = 'הסיסמה חלשה מדי';
                  } else if (e.code == 'email-already-in-use') {
                    message = 'האימייל כבר בשימוש';
                  } else if (e.code == 'invalid-email') {
                    message = 'כתובת אימייל לא תקינה';
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('שגיאה: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('צור משתמש'),
          ),
        ],
      ),
    );
  }
}

const String _kBrandPendingAi = 'pending_ai';
const String _kBrandPendingReview = 'pending_review';
const String _kBrandAiRejected = 'ai_rejected';
const String _kBrandApproved = 'approved';
const String _kBrandRejected = 'rejected';

const Map<String, String> _kBrandStatusLabels = {
  _kBrandPendingAi: 'בבדיקת AI',
  _kBrandPendingReview: 'ממתין לאישור',
  _kBrandAiRejected: 'נדחה ע״י AI',
  _kBrandApproved: 'אושר',
  _kBrandRejected: 'נדחה',
};

const List<String> _kBrandFilterOrder = [
  _kBrandPendingReview,
  _kBrandAiRejected,
  _kBrandPendingAi,
  _kBrandApproved,
  _kBrandRejected,
];

Color _brandStatusColor(String status) {
  switch (status) {
    case _kBrandApproved:
      return Colors.green;
    case _kBrandRejected:
    case _kBrandAiRejected:
      return AppColors.error;
    case _kBrandPendingAi:
      return Colors.blueGrey;
    default:
      return Colors.orange;
  }
}

String _formatBrandDate(Object? value) {
  if (value is! Timestamp) return '';
  final d = value.toDate();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

class _BrandCatalogPage extends ConsumerStatefulWidget {
  const _BrandCatalogPage();

  @override
  ConsumerState<_BrandCatalogPage> createState() => _BrandCatalogPageState();
}

class _BrandCatalogPageState extends ConsumerState<_BrandCatalogPage> {
  String? _filterStatus = _kBrandPendingReview;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('brand_suggestions')
          .orderBy('submittedAt', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'שגיאה בטעינת תור המותגים: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        final counts = <String, int>{};
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] as String?) ?? _kBrandPendingAi;
          counts[status] = (counts[status] ?? 0) + 1;
        }

        final visible = _filterStatus == null
            ? docs
            : docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return ((data['status'] as String?) ?? _kBrandPendingAi) ==
                    _filterStatus;
              }).toList();

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: Text('הכל (${docs.length})'),
                      selected: _filterStatus == null,
                      onSelected: (_) => setState(() => _filterStatus = null),
                    ),
                    const SizedBox(width: 8),
                    ..._kBrandFilterOrder.map((status) {
                      final count = counts[status] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: FilterChip(
                          label: Text(
                            '${_kBrandStatusLabels[status]} ($count)',
                          ),
                          selected: _filterStatus == status,
                          onSelected: (selected) => setState(
                            () => _filterStatus = selected ? status : null,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('אין מותגים בקטגוריה זו'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: visible.length,
                      itemBuilder: (context, index) => _BrandSuggestionCard(
                        key: ValueKey(visible[index].id),
                        doc: visible[index],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _BrandSuggestionCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;

  const _BrandSuggestionCard({super.key, required this.doc});

  @override
  State<_BrandSuggestionCard> createState() => _BrandSuggestionCardState();
}

class _BrandSuggestionCardState extends State<_BrandSuggestionCard> {
  bool _busy = false;

  Map<String, dynamic> get _data =>
      widget.doc.data() as Map<String, dynamic>? ?? const {};

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final status = (data['status'] as String?) ?? _kBrandPendingAi;
    final displayName =
        (data['displayName'] as String?) ??
        (data['rawName'] as String?) ??
        '(ללא שם)';
    final rawName = (data['rawName'] as String?) ?? displayName;
    final categoryId = (data['categoryId'] as String?) ?? '';
    final subCategoryId = data['subCategoryId'] as String?;
    final categoryName = Categories.findById(categoryId)?.name ?? categoryId;
    final subCategoryName = subCategoryId == null
        ? null
        : Categories.findSubCategory(categoryId, subCategoryId)?.name ??
              subCategoryId;
    final occurrences = (data['occurrences'] as num?)?.toInt() ?? 1;
    final ai = data['ai'] as Map<String, dynamic>?;
    final statusColor = _brandStatusColor(status);
    final isDecided = status == _kBrandApproved || status == _kBrandRejected;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _kBrandStatusLabels[status] ?? status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'נכתב כך: "$rawName"',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subCategoryName == null
                  ? 'קטגוריה: $categoryName'
                  : 'קטגוריה: $categoryName › $subCategoryName',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'מוכר: ${data['submittedByName'] ?? data['submittedBy'] ?? 'לא ידוע'}'
              ' • ${_formatBrandDate(data['submittedAt'])}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            if (occurrences > 1) ...[
              const SizedBox(height: 4),
              Text(
                'הוזן $occurrences פעמים',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _BrandAiVerdict(ai: ai),
            if (isDecided) ...[
              const SizedBox(height: 12),
              Text(
                '${status == _kBrandApproved ? 'אושר' : 'נדחה'} ע״י '
                '${data['reviewedByName'] ?? data['reviewedBy'] ?? 'לא ידוע'}'
                ' • ${_formatBrandDate(data['reviewedAt'])}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _review('reject'),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('דחה'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _showApproveDialog,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: const Text('אשר'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showApproveDialog() async {
    final controller = TextEditingController(
      text:
          (_data['displayName'] as String?) ??
          (_data['rawName'] as String?) ??
          '',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('אישור מותג לקטלוג'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'המותג יופיע ברשימת היצרנים של כל המוכרים בקטגוריה זו.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'שם לתצוגה',
                  helperText: 'ניתן לתקן אותיות גדולות/רווחים בלבד',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('אשר'),
          ),
        ],
      ),
    );
    final correctedName = controller.text.trim();
    controller.dispose();
    if (confirmed != true) return;
    await _review('approve', displayName: correctedName);
  }

  Future<void> _review(String action, {String? displayName}) async {
    setState(() => _busy = true);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('reviewBrandSuggestion')
          .call<dynamic>({
            'suggestionId': widget.doc.id,
            'action': action,
            if (displayName != null && displayName.isNotEmpty)
              'displayName': displayName,
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'approve' ? 'המותג אושר ✓' : 'המותג נדחה'),
            backgroundColor: action == 'approve'
                ? Colors.green
                : AppColors.textSecondary,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'הפעולה נכשלה'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _BrandAiVerdict extends StatelessWidget {
  final Map<String, dynamic>? ai;

  const _BrandAiVerdict({required this.ai});

  @override
  Widget build(BuildContext context) {
    final verdict = ai == null ? null : ai!['verdict'] as String?;
    final reasoning = ai == null ? null : ai!['reasoning'] as String?;
    final confidence = ai == null ? null : (ai!['confidence'] as num?);

    late final String title;
    late final Color color;
    late final IconData icon;
    switch (verdict) {
      case 'plausible':
        title = 'ה-AI: מותג אמיתי וסביר';
        color = Colors.green;
        icon = Icons.verified_outlined;
        break;
      case 'rejected':
        title = 'ה-AI: לא נראה מותג אמיתי בקטגוריה זו';
        color = AppColors.error;
        icon = Icons.block_outlined;
        break;
      case 'unavailable':
        title = 'בדיקת ה-AI לא רצה — נדרשת בדיקה ידנית';
        color = Colors.orange;
        icon = Icons.help_outline;
        break;
      case 'uncertain':
        title = 'ה-AI לא הכריע — נדרשת בדיקה ידנית';
        color = Colors.orange;
        icon = Icons.help_outline;
        break;
      default:
        title = 'ממתין לבדיקת AI…';
        color = Colors.blueGrey;
        icon = Icons.hourglass_empty;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              if (confidence != null)
                Text(
                  '${(confidence * 100).round()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
            ],
          ),
          if (reasoning != null && reasoning.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(reasoning, style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _ProgressRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0
        ? (value / total * 100).toStringAsFixed(1)
        : '0.0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              '$value ($percentage%)',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: total > 0 ? value / total : 0,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

class _UserCard extends ConsumerWidget {
  final UserModel user;

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          backgroundImage: user.photoUrl != null
              ? NetworkImage(user.photoUrl!)
              : null,
          child: user.photoUrl == null
              ? Text(
                  user.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(color: Colors.white),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.displayName ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              UserRoleHelper.getRoleIcon(user.role),
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: user.role == UserRole.admin
                    ? Colors.orange.withValues(alpha: 0.15)
                    : user.role == UserRole.supportAgent
                    ? Colors.purple.withValues(alpha: 0.15)
                    : Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                user.role.displayName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: user.role == UserRole.admin
                      ? Colors.orange
                      : user.role == UserRole.supportAgent
                      ? Colors.purple
                      : Colors.blue,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(user.email),
            if (user.phoneNumber != null) ...[
              const SizedBox(height: 2),
              Text(user.phoneNumber!),
            ],
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

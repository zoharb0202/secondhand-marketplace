import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class DebugUserInfo extends ConsumerWidget {
  const DebugUserInfo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('🐛 Debug User Info')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Firebase Auth User:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FutureBuilder<User?>(
              future: Future.value(FirebaseAuth.instance.currentUser),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data == null) {
                  return const Text('No Firebase Auth user');
                }

                final user = snapshot.data!;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('UID: ${user.uid}'),
                        Text('Email: ${user.email}'),
                        Text('Display Name: ${user.displayName}'),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Firestore User Document:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FutureBuilder<DocumentSnapshot?>(
              future: FirebaseAuth.instance.currentUser != null
                  ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .get()
                  : null,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data == null) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No Firestore user document'),
                    ),
                  );
                }

                final doc = snapshot.data!;
                if (!doc.exists) {
                  return const Card(
                    color: Colors.red,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        '⚠️ User document does not exist in Firestore!',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                }

                final data = doc.data() as Map<String, dynamic>?;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Role: ${data?['role'] ?? 'NOT SET'}'),
                        Text('Email: ${data?['email'] ?? 'NOT SET'}'),
                        Text(
                          'Display Name: ${data?['displayName'] ?? 'NOT SET'}',
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Full Document Data:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          data.toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Current User Provider:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            currentUser.when(
              data: (user) {
                if (user == null) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('currentUserProvider returns null'),
                    ),
                  );
                }

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID: ${user.id}'),
                        Text('Role: ${user.role.toString()}'),
                        Text('Role Display: ${user.role.displayName}'),
                        Text('Email: ${user.email}'),
                        Text('Display Name: ${user.displayName ?? "null"}'),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Loading...'),
                ),
              ),
              error: (error, stack) => Card(
                color: Colors.red,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Error: $error',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Test Firestore Queries:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                try {
                  final productsSnapshot = await FirebaseFirestore.instance
                      .collection('products')
                      .limit(1)
                      .get();
                  if (kDebugMode) {
                    print(
                      '✅ Can read products: ${productsSnapshot.docs.length} docs',
                    );
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '✅ Can read products: ${productsSnapshot.docs.length} docs',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (kDebugMode) print('❌ Cannot read products: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Cannot read products: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Test Read Products'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                try {
                  final usersSnapshot = await FirebaseFirestore.instance
                      .collection('users')
                      .limit(1)
                      .get();
                  if (kDebugMode) {
                    print(
                      '✅ Can read users: ${usersSnapshot.docs.length} docs',
                    );
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '✅ Can read users: ${usersSnapshot.docs.length} docs',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (kDebugMode) print('❌ Cannot read users: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Cannot read users: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Test Read Users'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                try {
                  final ticketsSnapshot = await FirebaseFirestore.instance
                      .collection('support_tickets')
                      .limit(1)
                      .get();
                  if (kDebugMode) {
                    print(
                      '✅ Can read support_tickets: ${ticketsSnapshot.docs.length} docs',
                    );
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '✅ Can read support_tickets: ${ticketsSnapshot.docs.length} docs',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (kDebugMode) print('❌ Cannot read support_tickets: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Cannot read support_tickets: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Test Read Support Tickets'),
            ),
          ],
        ),
      ),
    );
  }
}

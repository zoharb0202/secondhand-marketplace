import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../shared/models/product_model.dart';
import '../../../orders/presentation/pages/checkout_page.dart';

const Duration kPriceOfferAcceptanceWindow = Duration(hours: 24);

final Set<String> _expirySweepInFlight = {};

Future<void> _sweepIfExpired(String offerId, Map<String, dynamic> offer) async {
  if (offer['status'] != 'accepted') return;
  final expiresAtRaw = offer['offerExpiresAt'];
  if (expiresAtRaw is! Timestamp) return;
  if (DateTime.now().isBefore(expiresAtRaw.toDate())) return;
  if (_expirySweepInFlight.contains(offerId)) return;
  _expirySweepInFlight.add(offerId);

  final firestore = FirebaseFirestore.instance;
  try {
    await firestore.collection('price_offers').doc(offerId).update({
      'status': 'expired',
    });
  } catch (e) {
    _expirySweepInFlight.remove(offerId);
    return;
  }

  final productId = offer['productId'] as String?;
  if (productId == null || productId.isEmpty) return;
  try {
    final productRef = firestore.collection('products').doc(productId);
    final productSnap = await productRef.get();
    if (!productSnap.exists) return;
    final data = productSnap.data() as Map<String, dynamic>;
    if (data['reservedForOfferId'] == offerId) {
      await productRef.update({
        'isReserved': false,
        'reservedForOfferId': null,
        'reservedUntil': null,
      });
    }
  } catch (_) {}
}

class MyOffersPage extends ConsumerWidget {
  const MyOffersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('יש להתחבר')));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('הצעות מחיר'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'הצעות שקיבלתי'),
              Tab(text: 'הצעות ששלחתי'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ReceivedOffersTab(userId: user.uid),
            _SentOffersTab(userId: user.uid),
          ],
        ),
      ),
    );
  }
}

class _ReceivedOffersTab extends StatelessWidget {
  final String userId;

  const _ReceivedOffersTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('price_offers')
          .where('sellerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('שגיאה: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final offers = snapshot.data!.docs;

        if (offers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_offer, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'אין הצעות מחיר',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            final offer = offers[index].data() as Map<String, dynamic>;
            return _OfferCard(
              offerId: offers[index].id,
              offer: offer,
              isReceived: true,
            );
          },
        );
      },
    );
  }
}

class _SentOffersTab extends StatelessWidget {
  final String userId;

  const _SentOffersTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('price_offers')
          .where('buyerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('שגיאה: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final offers = snapshot.data!.docs;

        if (offers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.send, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'לא שלחת הצעות',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            final offer = offers[index].data() as Map<String, dynamic>;
            return _OfferCard(
              offerId: offers[index].id,
              offer: offer,
              isReceived: false,
            );
          },
        );
      },
    );
  }
}

class _OfferCard extends StatelessWidget {
  final String offerId;
  final Map<String, dynamic> offer;
  final bool isReceived;

  const _OfferCard({
    required this.offerId,
    required this.offer,
    required this.isReceived,
  });

  @override
  Widget build(BuildContext context) {
    final status = offer['status'] ?? 'pending';
    final originalPrice = (offer['originalPrice'] ?? 0).toDouble();
    final offeredPrice = (offer['offeredPrice'] ?? 0).toDouble();
    final discount = ((originalPrice - offeredPrice) / originalPrice * 100)
        .round();

    final offerExpiresAtRaw = offer['offerExpiresAt'];
    final offerExpiresAt = offerExpiresAtRaw is Timestamp
        ? offerExpiresAtRaw.toDate()
        : null;
    final isExpired =
        status == 'accepted' &&
        offerExpiresAt != null &&
        DateTime.now().isAfter(offerExpiresAt);
    final effectiveStatus = isExpired ? 'expired' : status;

    if (isExpired) {
      _sweepIfExpired(offerId, offer);
    }

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
                    offer['productTitle'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                _buildStatusBadge(effectiveStatus),
              ],
            ),
            const SizedBox(height: 12),
            if (isReceived)
              Text(
                'מאת: ${offer['buyerName'] ?? 'משתמש'}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '₪${offeredPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '₪${originalPrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '-$discount%',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ],
            ),
            if (offer['message']?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  offer['message'],
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
            ],
            if (isReceived && status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _rejectOffer(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('דחה'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _counterOffer(context),
                      child: const Text('הצע נגדית'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _acceptOffer(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('קבל'),
                    ),
                  ),
                ],
              ),
            ],
            if (effectiveStatus == 'accepted') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isReceived
                          ? 'המוצר שמור לקונה — עסקה מחייבת'
                          : 'ההצעה שלך אושרה — עסקה מחייבת',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    if (offerExpiresAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        isReceived
                            ? 'המוצר יישמר עד ${_formatDateTime(offerExpiresAt)}. אם התשלום לא יושלם עד אז, המוצר יחזור להיות זמין לכולם.'
                            : 'יש להשלים תשלום עד ${_formatDateTime(offerExpiresAt)} כדי לסגור את העסקה במחיר שסוכם. לאחר מכן השמירה על המוצר תפוג.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                    if (!isReceived) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _payNow(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: Text(
                            'שלם עכשיו · ₪${offeredPrice.toStringAsFixed(0)} למוצר',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else if (!isReceived && effectiveStatus == 'countered') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'המוכר שלח הצעה נגדית',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'המחיר שהוצע: ₪${((offer['counterPrice'] ?? 0).toDouble()).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _rejectOffer(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('דחה'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () => _acceptCounterOffer(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text('קבל הצעה נגדית'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (effectiveStatus == 'expired') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'תוקף השמירה פג — המוצר זמין שוב לרכישה',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _formatDate(offer['createdAt']),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'accepted':
        color = Colors.green;
        label = 'התקבלה';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'נדחתה';
        break;
      case 'countered':
        color = Colors.orange;
        label = 'הצעה נגדית';
        break;
      case 'expired':
        color = Colors.grey;
        label = 'פג תוקף';
        break;
      case 'completed':
        color = Colors.blue;
        label = 'העסקה הושלמה';
        break;
      default:
        color = Colors.blue;
        label = 'ממתין';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _acceptOffer(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('אישור מכירה'),
        content: const Text(
          'קבלת ההצעה תהפוך אותה למכירה מחייבת — המוצר יישמר לקונה '
          'למשך 24 שעות כדי להשלים את התשלום במחיר שסוכם, ולא יהיה '
          'זמין לקונים אחרים במהלך הזמן הזה.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('כן, אשר מכירה'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final productId = offer['productId'] as String?;
    final buyerId = offer['buyerId'] as String?;
    final offeredPrice = (offer['offeredPrice'] ?? 0).toDouble();

    if (productId == null || productId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('לא נמצא מוצר משויך להצעה זו')),
        );
      }
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final offerRef = firestore.collection('price_offers').doc(offerId);
    final productRef = firestore.collection('products').doc(productId);
    final expiresAt = DateTime.now().add(kPriceOfferAcceptanceWindow);

    try {
      await firestore.runTransaction((transaction) async {
        final productSnap = await transaction.get(productRef);
        if (!productSnap.exists) {
          throw Exception('המוצר לא נמצא');
        }

        final productData = productSnap.data() as Map<String, dynamic>;
        if (productData['isSold'] == true) {
          throw Exception('המוצר כבר נמכר');
        }

        final currentReservedFor = productData['reservedForOfferId'];
        final reservedUntilRaw = productData['reservedUntil'];
        final reservedUntil = reservedUntilRaw is Timestamp
            ? reservedUntilRaw.toDate()
            : null;
        final stillReservedForOther =
            productData['isReserved'] == true &&
            currentReservedFor != null &&
            currentReservedFor != offerId &&
            reservedUntil != null &&
            DateTime.now().isBefore(reservedUntil);
        if (stillReservedForOther) {
          throw Exception('המוצר כבר משוריין לקונה אחר');
        }

        transaction.update(offerRef, {
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
          'offerExpiresAt': Timestamp.fromDate(expiresAt),
        });

        transaction.update(productRef, {
          'isReserved': true,
          'reservedForOfferId': offerId,
          'reservedUntil': Timestamp.fromDate(expiresAt),
        });
      });

      if (buyerId != null && buyerId.isNotEmpty) {
        await NotificationService().sendNotification(
          userId: buyerId,
          type: NotificationType.priceOffer,
          title: 'המוכר אישר את ההצעה שלך!',
          body:
              'יש לך 24 שעות להשלים תשלום של ₪${offeredPrice.toStringAsFixed(0)} '
              'כדי לסגור את העסקה. לאחר מכן השמירה על המוצר תפוג.',
          data: {
            'productId': productId,
            'offerId': offerId,
            'offeredPrice': offeredPrice,
            'offerExpiresAt': expiresAt.toIso8601String(),
          },
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ההצעה התקבלה! המוצר שמור לקונה למשך 24 שעות'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('שגיאה באישור ההצעה: $e')));
      }
    }
  }

  Future<void> _payNow(BuildContext context) async {
    final productId = offer['productId'] as String?;
    final offeredPrice = (offer['offeredPrice'] ?? 0).toDouble();
    if (productId == null || productId.isEmpty) return;

    try {
      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();

      if (!productDoc.exists) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('המוצר לא נמצא')));
        }
        return;
      }

      final product = ProductModel.fromFirestore(productDoc);

      final reservedForOther =
          product.isReserved &&
          product.reservedForOfferId != null &&
          product.reservedForOfferId != offerId &&
          !product.isReservationExpired;
      if (product.isSold || reservedForOther) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('תוקף השמירה על המוצר פג או שהמוצר כבר נמכר'),
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CheckoutPage(
              product: product,
              overridePrice: offeredPrice,
              offerId: offerId,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
      }
    }
  }

  Future<void> _rejectOffer(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('price_offers')
          .doc(offerId)
          .update({
            'status': 'rejected',
            'rejectedAt': FieldValue.serverTimestamp(),
          });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ההצעה נדחתה')));
      }
    } on FirebaseException catch (e) {
      final message = e.code == 'permission-denied'
          ? 'לא ניתן לדחות את ההצעה במצבה הנוכחי — ייתכן שהיא כבר עודכנה'
          : 'שגיאה בדחיית ההצעה. נסה שוב';
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('שגיאה בדחיית ההצעה. נסה שוב')),
        );
      }
    }
  }

  void _counterOffer(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('הצעה נגדית'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'המחיר שלך',
            prefixText: '₪ ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () async {
              final price = double.tryParse(controller.text);
              if (price == null || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('יש להזין מחיר תקין')),
                );
                return;
              }
              try {
                await FirebaseFirestore.instance
                    .collection('price_offers')
                    .doc(offerId)
                    .update({'status': 'countered', 'counterPrice': price});
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ההצעה הנגדית נשלחה')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('שגיאה בשליחת ההצעה הנגדית. נסה שוב'),
                    ),
                  );
                }
              }
            },
            child: const Text('שלח'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptCounterOffer(BuildContext context) async {
    final counterPrice = (offer['counterPrice'] ?? 0).toDouble();
    if (counterPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('מחיר ההצעה הנגדית אינו תקין')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('קבלת הצעה נגדית'),
        content: Text(
          'קבלת ההצעה הנגדית תהפוך אותה למכירה מחייבת במחיר '
          '₪${counterPrice.toStringAsFixed(0)}. יש להשלים תשלום תוך 24 שעות '
          'כדי לסגור את העסקה.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('כן, קבל'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'acceptCounterOffer',
      );
      await callable.call<dynamic>({'offerId': offerId});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ההצעה הנגדית התקבלה! ניתן להשלים תשלום'),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      String message;
      switch (e.code) {
        case 'failed-precondition':
          message =
              'לא ניתן לקבל את ההצעה — ייתכן שהמוצר נמכר או שמור לקונה אחר';
          break;
        case 'not-found':
          message = 'ההצעה או המוצר לא נמצאו';
          break;
        case 'permission-denied':
          message = 'אין הרשאה לקבל הצעה זו';
          break;
        default:
          message = 'שגיאה בקבלת ההצעה הנגדית. נסה שוב';
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('שגיאה בקבלת ההצעה הנגדית. נסה שוב')),
        );
      }
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return '';
  }

  String _formatDateTime(DateTime dateTime) {
    final h = dateTime.hour.toString().padLeft(2, '0');
    final m = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.day}/${dateTime.month} $h:$m';
  }
}

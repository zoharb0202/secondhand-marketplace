import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/notification_service_enhanced.dart';
import '../../../../core/services/interaction_tracker.dart';
import '../../../../shared/models/product_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class PriceOfferDialog extends ConsumerStatefulWidget {
  final String productId;
  final String productTitle;
  final String sellerId;
  final double originalPrice;

  final ProductModel? product;

  const PriceOfferDialog({
    super.key,
    required this.productId,
    required this.productTitle,
    required this.sellerId,
    required this.originalPrice,
    this.product,
  });

  @override
  ConsumerState<PriceOfferDialog> createState() => _PriceOfferDialogState();
}

class _PriceOfferDialogState extends ConsumerState<PriceOfferDialog> {
  final _priceController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _priceController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('הצע מחיר'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.productTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'מחיר מקורי: ₪${widget.originalPrice.toStringAsFixed(0)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'הצעת המחיר שלך',
                prefixText: '₪ ',
                border: const OutlineInputBorder(),
                helperText: _getPriceHelper(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'הודעה למוכר (אופציונלי)',
                hintText: 'למה כדאי לקבל את ההצעה שלי...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _buildQuickOffers(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'שימו לב: אם המוכר יאשר את ההצעה, היא תהפוך למכירה '
                      'מחייבת — המוצר יישמר לכם למשך 24 שעות להשלמת התשלום '
                      'במחיר שסוכם.',
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ),
                ],
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
          onPressed: _isLoading ? null : _submitOffer,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('שלח הצעה'),
        ),
      ],
    );
  }

  String _getPriceHelper() {
    final offerText = _priceController.text;
    if (offerText.isEmpty) return '';

    final offer = double.tryParse(offerText);
    if (offer == null) return '';

    final discount =
        ((widget.originalPrice - offer) / widget.originalPrice * 100).round();
    if (discount > 0) {
      return 'הנחה של $discount%';
    } else if (discount < 0) {
      return 'יותר מהמחיר המקורי';
    }
    return 'כמו המחיר המקורי';
  }

  Widget _buildQuickOffers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'הצעות מהירות:',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _QuickOfferChip(
              label: '-10%',
              price: widget.originalPrice * 0.9,
              onTap: (price) {
                _priceController.text = price.toStringAsFixed(0);
                setState(() {});
              },
            ),
            const SizedBox(width: 8),
            _QuickOfferChip(
              label: '-20%',
              price: widget.originalPrice * 0.8,
              onTap: (price) {
                _priceController.text = price.toStringAsFixed(0);
                setState(() {});
              },
            ),
            const SizedBox(width: 8),
            _QuickOfferChip(
              label: '-30%',
              price: widget.originalPrice * 0.7,
              onTap: (price) {
                _priceController.text = price.toStringAsFixed(0);
                setState(() {});
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _submitOffer() async {
    final priceText = _priceController.text.trim();
    if (priceText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('יש להזין מחיר')));
      return;
    }

    final offeredPrice = double.tryParse(priceText);
    if (offeredPrice == null || offeredPrice <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('יש להזין מחיר תקין')));
      return;
    }

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('price_offers').add({
        'productId': widget.productId,
        'productTitle': widget.productTitle,
        'sellerId': widget.sellerId,
        'buyerId': user.uid,
        'buyerName': user.displayName ?? 'משתמש',
        'originalPrice': widget.originalPrice,
        'offeredPrice': offeredPrice,
        'message': _messageController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      try {
        await NotificationServiceEnhanced().notifyPriceOffer(
          sellerId: widget.sellerId,
          productId: widget.productId,
          buyerName: user.displayName ?? 'משתמש',
          offeredPrice: offeredPrice,
        );
      } catch (_) {}

      InteractionTracker().track(
        InteractionType.offerMade,
        product: widget.product,
        productId: widget.productId,
        price: widget.originalPrice,
        sellerId: widget.sellerId,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ההצעה נשלחה בהצלחה!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('שגיאה: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _QuickOfferChip extends StatelessWidget {
  final String label;
  final double price;
  final Function(double) onTap;

  const _QuickOfferChip({
    required this.label,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(price),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '$label (₪${price.toStringAsFixed(0)})',
          style: const TextStyle(fontSize: 12, color: Colors.blue),
        ),
      ),
    );
  }
}

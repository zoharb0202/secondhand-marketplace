import 'package:flutter_test/flutter_test.dart';
import 'package:secondhand_marketplace/core/constants/enums.dart';
import 'package:secondhand_marketplace/shared/models/order_model.dart';
import 'package:secondhand_marketplace/shared/models/seller_revenue.dart';

OrderModel _order({double itemPrice = 100, required OrderStatus status}) =>
    OrderModel(
      id: 'o',
      productId: 'p',
      sellerId: 's',
      buyerId: 'b',
      productTitle: 't',
      productImageUrl: '',
      productPrice: itemPrice,
      itemPrice: itemPrice,
      totalAmount: itemPrice,
      status: status,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  test('only completed orders count as revenue', () {
    final summary = SellerRevenue.summarize([
      _order(itemPrice: 500, status: OrderStatus.completed),
      _order(itemPrice: 200, status: OrderStatus.completed),
      _order(itemPrice: 999, status: OrderStatus.cancelled),
      _order(itemPrice: 300, status: OrderStatus.paid),
    ]);
    expect(summary.total, 700);
    expect(summary.realizedCount, 2);
  });

  test('pending, paid and ready orders are in progress', () {
    final summary = SellerRevenue.summarize([
      _order(status: OrderStatus.pending),
      _order(status: OrderStatus.paid),
      _order(status: OrderStatus.readyForPickup),
      _order(status: OrderStatus.disputed),
    ]);
    expect(summary.inProgressCount, 3);
    expect(summary.total, 0);
  });

  test('an empty order list is all zeros', () {
    final summary = SellerRevenue.summarize(const []);
    expect(summary.total, 0);
    expect(summary.realizedCount, 0);
    expect(summary.inProgressCount, 0);
  });
}

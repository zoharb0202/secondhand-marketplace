import '../../core/constants/enums.dart';
import 'order_model.dart';

class SellerRevenue {
  SellerRevenue._();

  static const Set<OrderStatus> realizedStatuses = {OrderStatus.completed};

  static const Set<OrderStatus> inProgressStatuses = {
    OrderStatus.pending,
    OrderStatus.paid,
    OrderStatus.readyForPickup,
  };

  static bool countsAsRealized(OrderModel order) =>
      realizedStatuses.contains(order.status);

  static bool isInProgress(OrderModel order) =>
      inProgressStatuses.contains(order.status);

  static SellerRevenueSummary summarize(Iterable<OrderModel> orders) {
    var realizedCount = 0;
    var inProgressCount = 0;
    var total = 0.0;

    for (final order in orders) {
      if (isInProgress(order)) inProgressCount++;
      if (!countsAsRealized(order)) continue;
      realizedCount++;
      total += order.itemPrice;
    }

    return SellerRevenueSummary(
      realizedCount: realizedCount,
      inProgressCount: inProgressCount,
      total: total,
    );
  }
}

class SellerRevenueSummary {
  final int realizedCount;

  final int inProgressCount;

  final double total;

  const SellerRevenueSummary({
    required this.realizedCount,
    required this.inProgressCount,
    required this.total,
  });
}

class SupplierOrder {
  final String id;
  final String supplierName;
  final List<OrderItem> items;
  final double totalCost;
  final DateTime orderDate;
  final DateTime? expectedDelivery;
  final String status; // pending, delivered, cancelled
  final bool isSynced;

  const SupplierOrder({
    required this.id,
    required this.supplierName,
    required this.items,
    required this.totalCost,
    required this.orderDate,
    this.expectedDelivery,
    this.status = 'pending',
    this.isSynced = false,
  });
}

class OrderItem {
  final String productName;
  final int quantity;
  final double costPrice;

  const OrderItem({
    required this.productName,
    required this.quantity,
    required this.costPrice,
  });

  double get subtotal => costPrice * quantity;
}

/// A record of products received from a supplier/company.
class ReceiveOrderItem {
  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;

  const ReceiveOrderItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
  });

  double get subtotal => unitPrice * quantity;

  ReceiveOrderItem copyWith({
    String? productId,
    String? productName,
    double? unitPrice,
    int? quantity,
  }) {
    return ReceiveOrderItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
    );
  }
}

class ReceiveOrder {
  final String id;
  final String supplierName;
  final List<ReceiveOrderItem> items;
  final double totalAmount;
  final DateTime receivedDate;
  final String? note;
  final bool isSynced;

  const ReceiveOrder({
    required this.id,
    required this.supplierName,
    required this.items,
    required this.totalAmount,
    required this.receivedDate,
    this.note,
    this.isSynced = false,
  });

  ReceiveOrder copyWith({
    String? id,
    String? supplierName,
    List<ReceiveOrderItem>? items,
    double? totalAmount,
    DateTime? receivedDate,
    String? note,
    bool? isSynced,
  }) {
    return ReceiveOrder(
      id: id ?? this.id,
      supplierName: supplierName ?? this.supplierName,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      receivedDate: receivedDate ?? this.receivedDate,
      note: note ?? this.note,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

class SaleItem {
  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;

  const SaleItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
  });

  double get subtotal => unitPrice * quantity;

  SaleItem copyWith({
    String? productId,
    String? productName,
    double? unitPrice,
    int? quantity,
  }) {
    return SaleItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
    );
  }
}

class Sale {
  final String id;
  final List<SaleItem> items;
  final double totalAmount;
  final String? customerId;
  final String? customerName;
  final DateTime saleDate;
  final String paymentMethod;
  final bool isSynced;

  const Sale({
    required this.id,
    required this.items,
    required this.totalAmount,
    this.customerId,
    this.customerName,
    required this.saleDate,
    this.paymentMethod = 'cash',
    this.isSynced = false,
  });

  Sale copyWith({
    String? id,
    List<SaleItem>? items,
    double? totalAmount,
    String? customerId,
    String? customerName,
    DateTime? saleDate,
    String? paymentMethod,
    bool? isSynced,
  }) {
    return Sale(
      id: id ?? this.id,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      saleDate: saleDate ?? this.saleDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

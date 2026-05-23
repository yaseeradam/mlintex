import '../../domain/entities/receive_order.dart';

/// Simple model stored as Map<String, dynamic> in a plain Hive Box.
class ReceiveOrderItemModel {
  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;

  ReceiveOrderItemModel({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
  });

  factory ReceiveOrderItemModel.fromEntity(ReceiveOrderItem item) =>
      ReceiveOrderItemModel(
        productId: item.productId,
        productName: item.productName,
        unitPrice: item.unitPrice,
        quantity: item.quantity,
      );

  ReceiveOrderItem toEntity() => ReceiveOrderItem(
        productId: productId,
        productName: productName,
        unitPrice: unitPrice,
        quantity: quantity,
      );

  factory ReceiveOrderItemModel.fromMap(Map<dynamic, dynamic> map) =>
      ReceiveOrderItemModel(
        productId: map['productId'] as String,
        productName: map['productName'] as String,
        unitPrice: (map['unitPrice'] as num).toDouble(),
        quantity: map['quantity'] as int,
      );

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'unitPrice': unitPrice,
        'quantity': quantity,
      };
}

class ReceiveOrderModel {
  final String id;
  final String supplierName;
  final List<ReceiveOrderItemModel> items;
  final double totalAmount;
  final DateTime receivedDate;
  final String? note;
  final bool isSynced;

  ReceiveOrderModel({
    required this.id,
    required this.supplierName,
    required this.items,
    required this.totalAmount,
    required this.receivedDate,
    this.note,
    this.isSynced = false,
  });

  factory ReceiveOrderModel.fromEntity(ReceiveOrder order) => ReceiveOrderModel(
        id: order.id,
        supplierName: order.supplierName,
        items: order.items.map(ReceiveOrderItemModel.fromEntity).toList(),
        totalAmount: order.totalAmount,
        receivedDate: order.receivedDate,
        note: order.note,
        isSynced: order.isSynced,
      );

  ReceiveOrder toEntity() => ReceiveOrder(
        id: id,
        supplierName: supplierName,
        items: items.map((e) => e.toEntity()).toList(),
        totalAmount: totalAmount,
        receivedDate: receivedDate,
        note: note,
        isSynced: isSynced,
      );

  factory ReceiveOrderModel.fromMap(Map<dynamic, dynamic> map) =>
      ReceiveOrderModel(
        id: map['id'] as String,
        supplierName: map['supplierName'] as String,
        items: (map['items'] as List)
            .map((e) => ReceiveOrderItemModel.fromMap(e as Map))
            .toList(),
        totalAmount: (map['totalAmount'] as num).toDouble(),
        receivedDate: DateTime.parse(map['receivedDate'] as String),
        note: map['note'] as String?,
        isSynced: map['isSynced'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'supplierName': supplierName,
        'items': items.map((e) => e.toMap()).toList(),
        'totalAmount': totalAmount,
        'receivedDate': receivedDate.toIso8601String(),
        'note': note,
        'isSynced': isSynced,
      };
}

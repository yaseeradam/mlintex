import 'package:hive/hive.dart';
import '../../domain/entities/sale.dart';

part 'sale_model.g.dart';

@HiveType(typeId: 2)
class SaleItemModel {
  @HiveField(0)
  final String productId;

  @HiveField(1)
  final String productName;

  @HiveField(2)
  final double unitPrice;

  @HiveField(3)
  final int quantity;

  SaleItemModel({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
  });

  factory SaleItemModel.fromEntity(SaleItem item) => SaleItemModel(
        productId: item.productId,
        productName: item.productName,
        unitPrice: item.unitPrice,
        quantity: item.quantity,
      );

  SaleItem toEntity() => SaleItem(
        productId: productId,
        productName: productName,
        unitPrice: unitPrice,
        quantity: quantity,
      );

  factory SaleItemModel.fromMap(Map<String, dynamic> map) => SaleItemModel(
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

@HiveType(typeId: 3)
class SaleModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final List<SaleItemModel> items;

  @HiveField(2)
  final double totalAmount;

  @HiveField(3)
  final String? customerId;

  @HiveField(4)
  final String? customerName;

  @HiveField(5)
  final DateTime saleDate;

  @HiveField(6)
  final String paymentMethod;

  @HiveField(7)
  final bool isSynced;

  SaleModel({
    required this.id,
    required this.items,
    required this.totalAmount,
    this.customerId,
    this.customerName,
    required this.saleDate,
    this.paymentMethod = 'cash',
    this.isSynced = false,
  });

  factory SaleModel.fromEntity(Sale sale) => SaleModel(
        id: sale.id,
        items: sale.items.map(SaleItemModel.fromEntity).toList(),
        totalAmount: sale.totalAmount,
        customerId: sale.customerId,
        customerName: sale.customerName,
        saleDate: sale.saleDate,
        paymentMethod: sale.paymentMethod,
        isSynced: sale.isSynced,
      );

  Sale toEntity() => Sale(
        id: id,
        items: items.map((e) => e.toEntity()).toList(),
        totalAmount: totalAmount,
        customerId: customerId,
        customerName: customerName,
        saleDate: saleDate,
        paymentMethod: paymentMethod,
        isSynced: isSynced,
      );

  factory SaleModel.fromMap(Map<String, dynamic> map) => SaleModel(
        id: map['id'] as String,
        items: (map['items'] as List)
            .map((e) => SaleItemModel.fromMap(e as Map<String, dynamic>))
            .toList(),
        totalAmount: (map['totalAmount'] as num).toDouble(),
        customerId: map['customerId'] as String?,
        customerName: map['customerName'] as String?,
        saleDate: DateTime.parse(map['saleDate'] as String),
        paymentMethod: map['paymentMethod'] as String? ?? 'cash',
        isSynced: true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'items': items.map((e) => e.toMap()).toList(),
        'totalAmount': totalAmount,
        'customerId': customerId,
        'customerName': customerName,
        'saleDate': saleDate.toIso8601String(),
        'paymentMethod': paymentMethod,
      };
}

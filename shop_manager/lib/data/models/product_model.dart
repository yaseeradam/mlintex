import 'package:hive/hive.dart';
import '../../domain/entities/product.dart';

part 'product_model.g.dart';

@HiveType(typeId: 0)
class ProductModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double price;

  @HiveField(3)
  final int quantity;

  @HiveField(4)
  final String? category;

  @HiveField(5)
  final String? barcode;

  @HiveField(6)
  final DateTime updatedAt;

  @HiveField(7)
  final bool isSynced;

  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.category,
    this.barcode,
    required this.updatedAt,
    this.isSynced = false,
  });

  factory ProductModel.fromEntity(Product product) => ProductModel(
        id: product.id,
        name: product.name,
        price: product.price,
        quantity: product.quantity,
        category: product.category,
        barcode: product.barcode,
        updatedAt: product.updatedAt,
        isSynced: product.isSynced,
      );

  Product toEntity() => Product(
        id: id,
        name: name,
        price: price,
        quantity: quantity,
        category: category,
        barcode: barcode,
        updatedAt: updatedAt,
        isSynced: isSynced,
      );

  factory ProductModel.fromMap(Map<String, dynamic> map) => ProductModel(
        id: map['id'] as String,
        name: map['name'] as String,
        price: (map['price'] as num).toDouble(),
        quantity: map['quantity'] as int,
        category: map['category'] as String?,
        barcode: map['barcode'] as String?,
        updatedAt: DateTime.parse(map['updatedAt'] as String),
        isSynced: true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'price': price,
        'quantity': quantity,
        'category': category,
        'barcode': barcode,
        'updatedAt': updatedAt.toIso8601String(),
      };
}

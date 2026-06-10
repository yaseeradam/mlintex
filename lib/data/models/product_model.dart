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

  @HiveField(8)
  final String? imagePath;

  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.category,
    this.barcode,
    required this.updatedAt,
    this.isSynced = false,
    this.imagePath,
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
        imagePath: product.imagePath,
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
        imagePath: imagePath,
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
        imagePath: map['imagePath'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'price': price,
        'quantity': quantity,
        'category': category,
        'barcode': barcode,
        'updatedAt': updatedAt.toIso8601String(),
        'imagePath': imagePath,
      };
}

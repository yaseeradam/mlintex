class Product {
  final String id;
  final String name;
  final double price;
  final double costPrice;
  final int quantity;
  final String? category;
  final String? barcode;
  final DateTime updatedAt;
  final bool isSynced;
  final String? imagePath;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.costPrice = 0.0,
    required this.quantity,
    this.category,
    this.barcode,
    required this.updatedAt,
    this.isSynced = false,
    this.imagePath,
  });

  Product copyWith({
    String? id,
    String? name,
    double? price,
    double? costPrice,
    int? quantity,
    String? category,
    String? barcode,
    DateTime? updatedAt,
    bool? isSynced,
    String? imagePath,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      barcode: barcode ?? this.barcode,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}

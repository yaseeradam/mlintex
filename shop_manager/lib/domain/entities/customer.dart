class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final DateTime updatedAt;
  final bool isSynced;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    required this.updatedAt,
    this.isSynced = false,
  });

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

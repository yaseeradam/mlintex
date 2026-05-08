import 'package:hive/hive.dart';
import '../../domain/entities/customer.dart';

part 'customer_model.g.dart';

@HiveType(typeId: 1)
class CustomerModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? phone;

  @HiveField(3)
  final String? address;

  @HiveField(4)
  final DateTime updatedAt;

  @HiveField(5)
  final bool isSynced;

  @HiveField(6)
  final String? avatarPath;

  @HiveField(7)
  final String? shopNumber;

  CustomerModel({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    required this.updatedAt,
    this.isSynced = false,
    this.avatarPath,
    this.shopNumber,
  });

  factory CustomerModel.fromEntity(Customer customer) => CustomerModel(
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        address: customer.address,
        updatedAt: customer.updatedAt,
        isSynced: customer.isSynced,
        avatarPath: customer.avatarPath,
        shopNumber: customer.shopNumber,
      );

  Customer toEntity() => Customer(
        id: id,
        name: name,
        phone: phone,
        address: address,
        updatedAt: updatedAt,
        isSynced: isSynced,
        avatarPath: avatarPath,
        shopNumber: shopNumber,
      );

  factory CustomerModel.fromMap(Map<String, dynamic> map) => CustomerModel(
        id: map['id'] as String,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        address: map['address'] as String?,
        updatedAt: DateTime.parse(map['updatedAt'] as String),
        isSynced: true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'updatedAt': updatedAt.toIso8601String(),
      };
}

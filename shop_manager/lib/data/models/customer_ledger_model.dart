import '../../domain/entities/customer_ledger_entry.dart';

/// Simple model stored as Map<String, dynamic> in a plain Hive Box.
class CustomerLedgerEntryModel {
  final String id;
  final String customerId;
  final DateTime date;
  final String? inDescription;
  final String? outDescription;
  final String? price;
  final int? quantity;
  final double totalAmount;
  final double totalBalance;
  final DateTime updatedAt;
  final bool isSynced;

  CustomerLedgerEntryModel({
    required this.id,
    required this.customerId,
    required this.date,
    this.inDescription,
    this.outDescription,
    this.price,
    this.quantity,
    required this.totalAmount,
    required this.totalBalance,
    required this.updatedAt,
    this.isSynced = false,
  });

  factory CustomerLedgerEntryModel.fromEntity(CustomerLedgerEntry e) =>
      CustomerLedgerEntryModel(
        id: e.id,
        customerId: e.customerId,
        date: e.date,
        inDescription: e.inDescription,
        outDescription: e.outDescription,
        price: e.price,
        quantity: e.quantity,
        totalAmount: e.totalAmount,
        totalBalance: e.totalBalance,
        updatedAt: e.updatedAt,
        isSynced: e.isSynced,
      );

  CustomerLedgerEntry toEntity() => CustomerLedgerEntry(
        id: id,
        customerId: customerId,
        date: date,
        inDescription: inDescription,
        outDescription: outDescription,
        price: price,
        quantity: quantity,
        totalAmount: totalAmount,
        totalBalance: totalBalance,
        updatedAt: updatedAt,
        isSynced: isSynced,
      );

  factory CustomerLedgerEntryModel.fromMap(Map<dynamic, dynamic> map) =>
      CustomerLedgerEntryModel(
        id: map['id'] as String,
        customerId: map['customerId'] as String,
        date: DateTime.parse(map['date'] as String),
        inDescription: map['inDescription'] as String?,
        outDescription: map['outDescription'] as String?,
        price: map['price'] as String?,
        quantity: map['quantity'] as int?,
        totalAmount: (map['totalAmount'] as num).toDouble(),
        totalBalance: (map['totalBalance'] as num).toDouble(),
        updatedAt: DateTime.parse(map['updatedAt'] as String),
        isSynced: map['isSynced'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'customerId': customerId,
        'date': date.toIso8601String(),
        'inDescription': inDescription,
        'outDescription': outDescription,
        'price': price,
        'quantity': quantity,
        'totalAmount': totalAmount,
        'totalBalance': totalBalance,
        'updatedAt': updatedAt.toIso8601String(),
        'isSynced': isSynced,
      };
}

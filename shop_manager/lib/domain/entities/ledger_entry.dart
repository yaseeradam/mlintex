import 'package:hive/hive.dart';

part 'ledger_entry.g.dart';

enum LedgerEntryType { payment, sale }

@HiveType(typeId: 5)
class LedgerEntry {
  @HiveField(0) final String id;
  @HiveField(1) final String customerId;
  @HiveField(2) final DateTime date;
  @HiveField(3) final String? inItem;
  @HiveField(4) final String? outItem;
  @HiveField(5) final double? price;
  @HiveField(6) final int? quantity;
  @HiveField(7) final double totalAmount;
  @HiveField(8) double runningBalance;
  @HiveField(9) final int typeIndex;

  LedgerEntry({
    required this.id,
    required this.customerId,
    required this.date,
    this.inItem,
    this.outItem,
    this.price,
    this.quantity,
    required this.totalAmount,
    this.runningBalance = 0,
    required this.typeIndex,
  });

  LedgerEntryType get type => LedgerEntryType.values[typeIndex];
}

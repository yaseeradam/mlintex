import 'package:hive/hive.dart';
import '../../domain/entities/debt.dart';

part 'debt_model.g.dart';

@HiveType(typeId: 4)
class DebtModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String customerId;

  @HiveField(2)
  final String customerName;

  @HiveField(3)
  final double amount;

  @HiveField(4)
  final double paidAmount;

  @HiveField(5)
  final DateTime dueDate;

  @HiveField(6)
  final String? note;

  @HiveField(7)
  final bool isPaid;

  @HiveField(8)
  final DateTime updatedAt;

  @HiveField(9)
  final bool isSynced;

  DebtModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.amount,
    this.paidAmount = 0.0,
    required this.dueDate,
    this.note,
    this.isPaid = false,
    required this.updatedAt,
    this.isSynced = false,
  });

  factory DebtModel.fromEntity(Debt debt) => DebtModel(
        id: debt.id,
        customerId: debt.customerId,
        customerName: debt.customerName,
        amount: debt.amount,
        paidAmount: debt.paidAmount,
        dueDate: debt.dueDate,
        note: debt.note,
        isPaid: debt.isPaid,
        updatedAt: debt.updatedAt,
        isSynced: debt.isSynced,
      );

  Debt toEntity() => Debt(
        id: id,
        customerId: customerId,
        customerName: customerName,
        amount: amount,
        paidAmount: paidAmount,
        dueDate: dueDate,
        note: note,
        isPaid: isPaid,
        updatedAt: updatedAt,
        isSynced: isSynced,
      );

  factory DebtModel.fromMap(Map<String, dynamic> map) => DebtModel(
        id: map['id'] as String,
        customerId: map['customerId'] as String,
        customerName: map['customerName'] as String,
        amount: (map['amount'] as num).toDouble(),
        paidAmount: (map['paidAmount'] as num? ?? 0).toDouble(),
        dueDate: DateTime.parse(map['dueDate'] as String),
        note: map['note'] as String?,
        isPaid: map['isPaid'] as bool? ?? false,
        updatedAt: DateTime.parse(map['updatedAt'] as String),
        isSynced: true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'customerId': customerId,
        'customerName': customerName,
        'amount': amount,
        'paidAmount': paidAmount,
        'dueDate': dueDate.toIso8601String(),
        'note': note,
        'isPaid': isPaid,
        'updatedAt': updatedAt.toIso8601String(),
      };
}

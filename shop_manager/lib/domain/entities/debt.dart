class Debt {
  final String id;
  final String customerId;
  final String customerName;
  final double amount;
  final double paidAmount;
  final DateTime dueDate;
  final String? note;
  final bool isPaid;
  final DateTime updatedAt;
  final bool isSynced;

  const Debt({
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

  double get remainingAmount => amount - paidAmount;
  bool get isOverdue => !isPaid && dueDate.isBefore(DateTime.now());

  Debt copyWith({
    String? id,
    String? customerId,
    String? customerName,
    double? amount,
    double? paidAmount,
    DateTime? dueDate,
    String? note,
    bool? isPaid,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return Debt(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      amount: amount ?? this.amount,
      paidAmount: paidAmount ?? this.paidAmount,
      dueDate: dueDate ?? this.dueDate,
      note: note ?? this.note,
      isPaid: isPaid ?? this.isPaid,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

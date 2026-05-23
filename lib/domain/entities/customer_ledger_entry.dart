/// A single row in a customer's ledger (the table shown in the UI).
/// Each entry can be either an IN (payment received) or OUT (goods given on credit),
/// or a product sale with price & quantity.
class CustomerLedgerEntry {
  final String id;
  final String customerId;
  final DateTime date;

  /// Description of what came IN (e.g. bank name, cash)
  final String? inDescription;

  /// Description of what went OUT (e.g. bank name, cash)
  final String? outDescription;

  /// Product name / price label
  final String? price;

  /// Quantity of product
  final int? quantity;

  /// Computed total for this row (price * quantity, or in/out amount)
  final double totalAmount;

  /// Running balance after this entry
  final double totalBalance;

  final DateTime updatedAt;
  final bool isSynced;

  const CustomerLedgerEntry({
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

  CustomerLedgerEntry copyWith({
    String? id,
    String? customerId,
    DateTime? date,
    String? inDescription,
    String? outDescription,
    String? price,
    int? quantity,
    double? totalAmount,
    double? totalBalance,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return CustomerLedgerEntry(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      date: date ?? this.date,
      inDescription: inDescription ?? this.inDescription,
      outDescription: outDescription ?? this.outDescription,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      totalAmount: totalAmount ?? this.totalAmount,
      totalBalance: totalBalance ?? this.totalBalance,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

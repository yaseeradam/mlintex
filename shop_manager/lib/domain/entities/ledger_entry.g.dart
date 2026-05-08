// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ledger_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LedgerEntryAdapter extends TypeAdapter<LedgerEntry> {
  @override
  final int typeId = 5;

  @override
  LedgerEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LedgerEntry(
      id: fields[0] as String,
      customerId: fields[1] as String,
      date: fields[2] as DateTime,
      inItem: fields[3] as String?,
      outItem: fields[4] as String?,
      price: fields[5] as double?,
      quantity: fields[6] as int?,
      totalAmount: fields[7] as double,
      runningBalance: fields[8] as double,
      typeIndex: fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, LedgerEntry obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.customerId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.inItem)
      ..writeByte(4)
      ..write(obj.outItem)
      ..writeByte(5)
      ..write(obj.price)
      ..writeByte(6)
      ..write(obj.quantity)
      ..writeByte(7)
      ..write(obj.totalAmount)
      ..writeByte(8)
      ..write(obj.runningBalance)
      ..writeByte(9)
      ..write(obj.typeIndex);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LedgerEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}

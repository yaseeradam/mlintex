// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'debt_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DebtModelAdapter extends TypeAdapter<DebtModel> {
  @override
  final int typeId = 4;

  @override
  DebtModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DebtModel(
      id: fields[0] as String,
      customerId: fields[1] as String,
      customerName: fields[2] as String,
      amount: fields[3] as double,
      paidAmount: fields[4] as double,
      dueDate: fields[5] as DateTime,
      note: fields[6] as String?,
      isPaid: fields[7] as bool,
      updatedAt: fields[8] as DateTime,
      isSynced: fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, DebtModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.customerId)
      ..writeByte(2)
      ..write(obj.customerName)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.paidAmount)
      ..writeByte(5)
      ..write(obj.dueDate)
      ..writeByte(6)
      ..write(obj.note)
      ..writeByte(7)
      ..write(obj.isPaid)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.isSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebtModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

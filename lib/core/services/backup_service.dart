import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/product_model.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/sale_model.dart';
import '../../data/models/debt_model.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../presentation/receive/receive_screen.dart';
import '../../presentation/sales_ledger/sales_ledger_screen.dart';

class BackupService {
  /// Exports all shop data from Hive into a single JSON backup file and opens Share dialog.
  static Future<void> exportBackup(BuildContext context) async {
    try {
      final authBox = Hive.box('auth');
      final activeShopId = authBox.get('active_shop_id', defaultValue: '1') as String;

      final productsBox = Hive.box<ProductModel>('products_$activeShopId');
      final customersBox = Hive.box<CustomerModel>('customers_$activeShopId');
      final debtsBox = Hive.box<DebtModel>('debts_$activeShopId');
      final salesBox = Hive.box<SaleModel>('sales_$activeShopId');
      final ledgerBox = Hive.box<LedgerEntry>('ledger_entries_$activeShopId');
      final shopLedgerBox = Hive.box<LedgerEntry>('shop_ledger_entries_$activeShopId');
      final receiveBox = Hive.box<ReceiveEntry>('receive_entries_$activeShopId');
      final salesLedgerBox = Hive.box<SalesLedgerEntry>('sales_ledger_$activeShopId');

      final backupData = {
        'version': 1,
        'app': 'Mlintex Shop Manager',
        'exportDate': DateTime.now().toIso8601String(),
        'shopId': activeShopId,
        'authData': authBox.toMap().map((k, v) => MapEntry(k.toString(), v?.toString())),
        'products': productsBox.values.map((p) => p.toMap()).toList(),
        'customers': customersBox.values.map((c) => c.toMap()).toList(),
        'debts': debtsBox.values.map((d) => d.toMap()).toList(),
        'sales': salesBox.values.map((s) => s.toMap()).toList(),
        'ledger_entries': ledgerBox.values.map((l) => {
          'id': l.id,
          'customerId': l.customerId,
          'date': l.date.toIso8601String(),
          'inItem': l.inItem,
          'outItem': l.outItem,
          'price': l.price,
          'quantity': l.quantity,
          'totalAmount': l.totalAmount,
          'runningBalance': l.runningBalance,
          'typeIndex': l.typeIndex,
        }).toList(),
        'shop_ledger_entries': shopLedgerBox.values.map((l) => {
          'id': l.id,
          'customerId': l.customerId,
          'date': l.date.toIso8601String(),
          'inItem': l.inItem,
          'outItem': l.outItem,
          'price': l.price,
          'quantity': l.quantity,
          'totalAmount': l.totalAmount,
          'runningBalance': l.runningBalance,
          'typeIndex': l.typeIndex,
        }).toList(),
        'receive_entries': receiveBox.values.map((r) => {
          'id': r.id,
          'date': r.date.toIso8601String(),
          'productName': r.productName,
          'companyName': r.companyName,
          'price': r.price,
          'quantity': r.quantity,
          'totalAmount': r.totalAmount,
          'payment': r.payment,
          'paymentDate': r.paymentDate?.toIso8601String(),
          'description': r.description,
        }).toList(),
        'sales_ledger_entries': salesLedgerBox.values.map((sl) => {
          'id': sl.id,
          'date': sl.date.toIso8601String(),
          'inItem': sl.inItem,
          'outItem': sl.outItem,
          'price': sl.price,
          'quantity': sl.quantity,
          'totalAmount': sl.totalAmount,
          'runningBalance': sl.runningBalance,
          'typeIndex': sl.typeIndex,
          'personName': sl.personName,
        }).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'mlintex_backup_$dateStr.json';

      final tempDir = await getTemporaryDirectory();
      final backupFile = File('${tempDir.path}/$fileName');
      await backupFile.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(backupFile.path)],
        text: 'Mlintex Shop Backup Data ($dateStr)',
        subject: 'Mlintex Backup',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup exported: $fileName'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export backup: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Restores shop data from raw JSON string into Hive boxes.
  static Future<bool> importBackupFromRawJson(BuildContext context, String rawJson) async {
    try {
      final Map<String, dynamic> data = jsonDecode(rawJson);
      if (!data.containsKey('products') && !data.containsKey('customers')) {
        throw Exception('Invalid backup format');
      }

      final authBox = Hive.box('auth');
      final activeShopId = authBox.get('active_shop_id', defaultValue: '1') as String;

      final productsBox = Hive.box<ProductModel>('products_$activeShopId');
      final customersBox = Hive.box<CustomerModel>('customers_$activeShopId');
      final debtsBox = Hive.box<DebtModel>('debts_$activeShopId');
      final salesBox = Hive.box<SaleModel>('sales_$activeShopId');
      final ledgerBox = Hive.box<LedgerEntry>('ledger_entries_$activeShopId');
      final shopLedgerBox = Hive.box<LedgerEntry>('shop_ledger_entries_$activeShopId');
      final receiveBox = Hive.box<ReceiveEntry>('receive_entries_$activeShopId');
      final salesLedgerBox = Hive.box<SalesLedgerEntry>('sales_ledger_$activeShopId');

      if (data['products'] != null) {
        for (final item in (data['products'] as List)) {
          final model = ProductModel.fromMap(Map<String, dynamic>.from(item));
          await productsBox.put(model.id, model);
        }
      }

      if (data['customers'] != null) {
        for (final item in (data['customers'] as List)) {
          final model = CustomerModel.fromMap(Map<String, dynamic>.from(item));
          await customersBox.put(model.id, model);
        }
      }

      if (data['debts'] != null) {
        for (final item in (data['debts'] as List)) {
          final model = DebtModel.fromMap(Map<String, dynamic>.from(item));
          await debtsBox.put(model.id, model);
        }
      }

      if (data['sales'] != null) {
        for (final item in (data['sales'] as List)) {
          final model = SaleModel.fromMap(Map<String, dynamic>.from(item));
          await salesBox.put(model.id, model);
        }
      }

      if (data['ledger_entries'] != null) {
        for (final item in (data['ledger_entries'] as List)) {
          final m = Map<String, dynamic>.from(item);
          final entry = LedgerEntry(
            id: m['id'] as String,
            customerId: m['customerId'] as String,
            date: DateTime.parse(m['date'] as String),
            inItem: m['inItem'] as String?,
            outItem: m['outItem'] as String?,
            price: (m['price'] as num?)?.toDouble(),
            quantity: m['quantity'] as int?,
            totalAmount: (m['totalAmount'] as num).toDouble(),
            runningBalance: (m['runningBalance'] as num? ?? 0).toDouble(),
            typeIndex: m['typeIndex'] as int,
          );
          await ledgerBox.put(entry.id, entry);
        }
      }

      if (data['shop_ledger_entries'] != null) {
        for (final item in (data['shop_ledger_entries'] as List)) {
          final m = Map<String, dynamic>.from(item);
          final entry = LedgerEntry(
            id: m['id'] as String,
            customerId: m['customerId'] as String,
            date: DateTime.parse(m['date'] as String),
            inItem: m['inItem'] as String?,
            outItem: m['outItem'] as String?,
            price: (m['price'] as num?)?.toDouble(),
            quantity: m['quantity'] as int?,
            totalAmount: (m['totalAmount'] as num).toDouble(),
            runningBalance: (m['runningBalance'] as num? ?? 0).toDouble(),
            typeIndex: m['typeIndex'] as int,
          );
          await shopLedgerBox.put(entry.id, entry);
        }
      }

      if (data['receive_entries'] != null) {
        for (final item in (data['receive_entries'] as List)) {
          final m = Map<String, dynamic>.from(item);
          final entry = ReceiveEntry(
            id: m['id'] as String,
            date: DateTime.parse(m['date'] as String),
            productName: m['productName'] as String,
            companyName: m['companyName'] as String,
            price: (m['price'] as num).toDouble(),
            quantity: m['quantity'] as int,
            totalAmount: (m['totalAmount'] as num).toDouble(),
            payment: (m['payment'] as num?)?.toDouble(),
            paymentDate: m['paymentDate'] != null ? DateTime.parse(m['paymentDate'] as String) : null,
            description: m['description'] as String?,
          );
          await receiveBox.put(entry.id, entry);
        }
      }

      if (data['sales_ledger_entries'] != null) {
        for (final item in (data['sales_ledger_entries'] as List)) {
          final m = Map<String, dynamic>.from(item);
          final entry = SalesLedgerEntry(
            id: m['id'] as String,
            date: DateTime.parse(m['date'] as String),
            inItem: m['inItem'] as String?,
            outItem: m['outItem'] as String?,
            price: (m['price'] as num?)?.toDouble(),
            quantity: m['quantity'] as int?,
            totalAmount: (m['totalAmount'] as num).toDouble(),
            runningBalance: (m['runningBalance'] as num? ?? 0).toDouble(),
            typeIndex: m['typeIndex'] as int,
            personName: m['personName'] as String?,
          );
          await salesLedgerBox.put(entry.id, entry);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup restored successfully!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore backup: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }
}

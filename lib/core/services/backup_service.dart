import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../utils/file_saver.dart';
import 'pending_sync_tracker.dart';

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
          'payment': sl.payment,
          'paymentDate': sl.paymentDate?.toIso8601String(),
          'costPrice': sl.costPrice,
        }).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'mlintex_backup_$dateStr.json';

      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      await FileSaver.saveJson(
        context,
        fileName,
        bytes,
        shareText: 'Mlintex Shop Backup Data ($dateStr)',
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
  ///
  /// Each data type is wrapped in its own try/catch so a failure in one type
  /// never prevents the remaining types from being restored.
  ///
  /// All restored records are marked as [PendingSyncTracker.markPending] so
  /// that the Firebase sync service will PUSH them up instead of overwriting
  /// the local restore with stale cloud data.
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

      final errors = <String>[];
      int restoredProducts = 0;
      int restoredCustomers = 0;
      int restoredDebts = 0;
      int restoredSales = 0;
      int restoredLedger = 0;
      int restoredShopLedger = 0;
      int restoredReceive = 0;
      int restoredSalesLedger = 0;

      // ── Products ───────────────────────────────────────────────────────
      if (data['products'] != null) {
        try {
          for (final item in (data['products'] as List)) {
            try {
              final model = ProductModel.fromMap(Map<String, dynamic>.from(item as Map));
              await productsBox.put(model.id, model);
              PendingSyncTracker.markPending('products', model.id);
              restoredProducts++;
            } catch (e) {
              debugPrint('[RESTORE PRODUCT ITEM ERROR] $e');
            }
          }
        } catch (e) {
          errors.add('products');
          debugPrint('[RESTORE PRODUCTS ERROR] $e');
        }
      }

      // ── Customers ─────────────────────────────────────────────────────
      if (data['customers'] != null) {
        try {
          for (final item in (data['customers'] as List)) {
            try {
              final model = CustomerModel.fromMap(Map<String, dynamic>.from(item as Map));
              await customersBox.put(model.id, model);
              PendingSyncTracker.markPending('customers', model.id);
              restoredCustomers++;
            } catch (e) {
              debugPrint('[RESTORE CUSTOMER ITEM ERROR] $e');
            }
          }
        } catch (e) {
          errors.add('customers');
          debugPrint('[RESTORE CUSTOMERS ERROR] $e');
        }
      }

      // ── Debts ─────────────────────────────────────────────────────────
      if (data['debts'] != null) {
        try {
          for (final item in (data['debts'] as List)) {
            try {
              final model = DebtModel.fromMap(Map<String, dynamic>.from(item as Map));
              await debtsBox.put(model.id, model);
              PendingSyncTracker.markPending('debts', model.id);
              restoredDebts++;
            } catch (e) {
              debugPrint('[RESTORE DEBT ITEM ERROR] $e');
            }
          }
        } catch (e) {
          errors.add('debts');
          debugPrint('[RESTORE DEBTS ERROR] $e');
        }
      }

      // ── Sales ─────────────────────────────────────────────────────────
      if (data['sales'] != null) {
        try {
          for (final item in (data['sales'] as List)) {
            try {
              final model = SaleModel.fromMap(Map<String, dynamic>.from(item as Map));
              await salesBox.put(model.id, model);
              PendingSyncTracker.markPending('sales', model.id);
              restoredSales++;
            } catch (e) {
              debugPrint('[RESTORE SALE ITEM ERROR] $e');
            }
          }
        } catch (e) {
          errors.add('sales');
          debugPrint('[RESTORE SALES ERROR] $e');
        }
      }

      // ── Ledger Entries ────────────────────────────────────────────────
      if (data['ledger_entries'] != null) {
        try {
          for (final item in (data['ledger_entries'] as List)) {
            try {
              final m = Map<String, dynamic>.from(item as Map);
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
              PendingSyncTracker.markPending('ledger_entries', entry.id);
              restoredLedger++;
            } catch (e) {
              debugPrint('[RESTORE LEDGER ITEM ERROR] $e');
            }
          }
        } catch (e) {
          errors.add('ledger_entries');
          debugPrint('[RESTORE LEDGER ERROR] $e');
        }
      }

      // ── Shop Ledger Entries ───────────────────────────────────────────
      if (data['shop_ledger_entries'] != null) {
        try {
          for (final item in (data['shop_ledger_entries'] as List)) {
            try {
              final m = Map<String, dynamic>.from(item as Map);
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
              PendingSyncTracker.markPending('shop_ledger_entries', entry.id);
              restoredShopLedger++;
            } catch (e) {
              debugPrint('[RESTORE SHOP LEDGER ITEM ERROR] $e');
            }
          }
        } catch (e) {
          errors.add('shop_ledger_entries');
          debugPrint('[RESTORE SHOP LEDGER ERROR] $e');
        }
      }

      // ── Receive Entries ───────────────────────────────────────────────
      if (data['receive_entries'] != null) {
        try {
          for (final item in (data['receive_entries'] as List)) {
            try {
              final m = Map<String, dynamic>.from(item as Map);
              final entry = ReceiveEntry(
                id: m['id'] as String,
                date: DateTime.parse(m['date'] as String),
                productName: m['productName'] as String,
                companyName: m['companyName'] as String,
                price: (m['price'] as num).toDouble(),
                quantity: m['quantity'] as int,
                totalAmount: (m['totalAmount'] as num).toDouble(),
                payment: (m['payment'] as num?)?.toDouble(),
                paymentDate: m['paymentDate'] != null
                    ? DateTime.parse(m['paymentDate'] as String)
                    : null,
                description: m['description'] as String?,
              );
              await receiveBox.put(entry.id, entry);
              PendingSyncTracker.markPending('receive_entries', entry.id);
              restoredReceive++;
            } catch (e) {
              debugPrint('[RESTORE RECEIVE ITEM ERROR] $e');
            }
          }
        } catch (e) {
          errors.add('receive_entries');
          debugPrint('[RESTORE RECEIVE ERROR] $e');
        }
      }

      // ── Sales Ledger Entries ──────────────────────────────────────────
      if (data['sales_ledger_entries'] != null) {
        try {
          for (final item in (data['sales_ledger_entries'] as List)) {
            try {
              final m = Map<String, dynamic>.from(item as Map);
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
                payment: (m['payment'] as num?)?.toDouble(),
                paymentDate: m['paymentDate'] != null
                    ? DateTime.parse(m['paymentDate'] as String)
                    : null,
                costPrice: (m['costPrice'] as num?)?.toDouble(),
              );
              await salesLedgerBox.put(entry.id, entry);
              PendingSyncTracker.markPending('sales_ledger', entry.id);
              restoredSalesLedger++;
            } catch (e) {
              debugPrint('[RESTORE SALES LEDGER ITEM ERROR] $e');
            }
          }
        } catch (e) {
          errors.add('sales_ledger_entries');
          debugPrint('[RESTORE SALES LEDGER ERROR] $e');
        }
      }

      // ── Summary snackbar ──────────────────────────────────────────────
      if (context.mounted) {
        final total = restoredProducts + restoredCustomers + restoredDebts +
            restoredSales + restoredLedger + restoredShopLedger +
            restoredReceive + restoredSalesLedger;

        final parts = <String>[
          if (restoredProducts > 0) '$restoredProducts products',
          if (restoredCustomers > 0) '$restoredCustomers customers',
          if (restoredDebts > 0) '$restoredDebts debts',
          if (restoredSales > 0) '$restoredSales sales',
          if (restoredLedger > 0) '$restoredLedger ledger entries',
          if (restoredShopLedger > 0) '$restoredShopLedger shop ledger entries',
          if (restoredReceive > 0) '$restoredReceive receive entries',
          if (restoredSalesLedger > 0) '$restoredSalesLedger sales ledger entries',
        ];

        final summary = parts.isEmpty ? 'No records found in backup.' : parts.join(', ');
        final hasErrors = errors.isNotEmpty;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasErrors
                  ? 'Restored $total records (errors in: ${errors.join(', ')}). $summary'
                  : 'Backup restored: $summary',
            ),
            backgroundColor:
                hasErrors ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
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

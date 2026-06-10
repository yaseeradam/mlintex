import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/product_model.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/sale_model.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../presentation/receive/receive_screen.dart';
import '../../presentation/sales_ledger/sales_ledger_screen.dart';

/// Simple local auth state (no Firebase yet).
/// In production, swap this with FirebaseAuth.
class AuthNotifier extends Notifier<AuthState> {
  static const _boxName = 'auth';
  static const _keyLoggedIn = 'logged_in';
  static const _keyEmail = 'email';
  static const _keyName = 'shop_name';
  static const _keyPhone = 'shop_phone';
  static const _keyShopNumber = 'shop_number';
  static const _keyAddress = 'shop_address';
  static const _keyLogoPath = 'shop_logo_path';
  static const _keyShops = 'shops_list';
  static const _keyActiveShopId = 'active_shop_id';

  @override
  AuthState build() {
    final box = Hive.box(_boxName);
    final loggedIn = box.get(_keyLoggedIn, defaultValue: false) as bool;
    if (loggedIn) {
      final rawShops = box.get(_keyShops, defaultValue: <dynamic>[]) as List<dynamic>;
      final activeShopId = box.get(_keyActiveShopId, defaultValue: '1') as String;

      if (rawShops.isEmpty) {
        // Migration/First-time path: Create a default shop from existing fields
        final existingName = box.get(_keyName, defaultValue: 'My Shop') as String;
        final defaultShop = {
          'id': '1',
          'name': existingName,
          'phone': box.get(_keyPhone, defaultValue: '') as String,
          'shopNumber': box.get(_keyShopNumber, defaultValue: '') as String,
          'address': box.get(_keyAddress, defaultValue: '') as String,
          'logoPath': box.get(_keyLogoPath) as String?,
        };
        box.put(_keyShops, [defaultShop]);
        box.put(_keyActiveShopId, '1');

        return AuthState.authenticated(
          email: box.get(_keyEmail, defaultValue: 'shop@example.com') as String,
          shopName: existingName,
          phone: defaultShop['phone'] as String,
          shopNumber: defaultShop['shopNumber'] as String,
          address: defaultShop['address'] as String,
          logoPath: defaultShop['logoPath'],
          shops: [defaultShop],
          activeShopId: '1',
        );
      }

      final shops = List<Map<dynamic, dynamic>>.from(
        rawShops.map((s) => Map<dynamic, dynamic>.from(s as Map)),
      );

      final activeShop = shops.firstWhere(
        (s) => s['id'] == activeShopId,
        orElse: () => shops.first,
      );

      return AuthState.authenticated(
        email: box.get(_keyEmail, defaultValue: 'shop@example.com') as String,
        shopName: activeShop['name'] as String? ?? 'My Shop',
        phone: activeShop['phone'] as String? ?? '',
        shopNumber: activeShop['shopNumber'] as String? ?? '',
        address: activeShop['address'] as String? ?? '',
        logoPath: activeShop['logoPath'] as String?,
        shops: shops,
        activeShopId: activeShopId,
      );
    }
    return const AuthState.unauthenticated();
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Simple demo: accept any non-empty email/password
    if (email.trim().isEmpty || password.isEmpty) return false;

    final box = Hive.box(_boxName);
    await box.put(_keyLoggedIn, true);
    await box.put(_keyEmail, email.trim());

    // Derive shop name from email for demo — default to M Lin Tex
    final name = email.contains('@')
        ? email.split('@').first
            .split('.')
            .map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s)
            .join(' ')
        : 'M Lin Tex';

    // If derived name looks generic (admin, user, test), use app name
    final shopName = ['admin', 'user', 'test', 'shop'].contains(name.toLowerCase())
        ? 'M Lin Tex'
        : name;

    final defaultShop = {
      'id': '1',
      'name': shopName,
      'phone': '',
      'shopNumber': '',
      'address': '',
      'logoPath': null,
    };

    await box.put(_keyName, shopName);
    await box.put(_keyPhone, '');
    await box.put(_keyShopNumber, '');
    await box.put(_keyAddress, '');
    await box.delete(_keyLogoPath);
    await box.put(_keyShops, [defaultShop]);
    await box.put(_keyActiveShopId, '1');

    state = AuthState.authenticated(
      email: email.trim(),
      shopName: shopName,
      phone: '',
      shopNumber: '',
      address: '',
      logoPath: null,
      shops: [defaultShop],
      activeShopId: '1',
    );
    return true;
  }

  Future<void> logout() async {
    final box = Hive.box(_boxName);
    await box.put(_keyLoggedIn, false);
    state = const AuthState.unauthenticated();
  }

  Future<void> addShop(String name) async {
    if (!state.isAuthenticated) return;

    final box = Hive.box(_boxName);
    final shops = List<Map<dynamic, dynamic>>.from(state.shops);

    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newShop = {
      'id': newId,
      'name': name,
      'phone': '',
      'shopNumber': '',
      'address': '',
      'logoPath': null,
    };

    shops.add(newShop);
    box.put(_keyShops, shops);

    await switchShop(newId);
  }

  Future<void> switchShop(String id) async {
    if (!state.isAuthenticated) return;

    final box = Hive.box(_boxName);
    final rawShops = box.get(_keyShops, defaultValue: <dynamic>[]) as List<dynamic>;
    final shops = List<Map<dynamic, dynamic>>.from(
      rawShops.map((s) => Map<dynamic, dynamic>.from(s as Map)),
    );

    final shop = shops.firstWhere(
      (s) => s['id'].toString() == id.toString(),
      orElse: () => shops.first,
    );

    final actualId = shop['id'].toString();

    // Dynamically open all shop-specific boxes
    await Hive.openBox<ProductModel>('products_$actualId');
    await Hive.openBox<CustomerModel>('customers_$actualId');
    await Hive.openBox<DebtModel>('debts_$actualId');
    await Hive.openBox<SaleModel>('sales_$actualId');
    await Hive.openBox('customer_ledger_$actualId');
    await Hive.openBox('receive_orders_$actualId');
    await Hive.openBox<LedgerEntry>('ledger_entries_$actualId');
    await Hive.openBox<ReceiveEntry>('receive_entries_$actualId');
    await Hive.openBox<SalesLedgerEntry>('sales_ledger_$actualId');

    box.put(_keyActiveShopId, actualId);
    box.put(_keyName, shop['name'] as String? ?? '');
    box.put(_keyPhone, shop['phone'] as String? ?? '');
    box.put(_keyShopNumber, shop['shopNumber'] as String? ?? '');
    box.put(_keyAddress, shop['address'] as String? ?? '');
    if (shop['logoPath'] != null) {
      box.put(_keyLogoPath, shop['logoPath']);
    } else {
      box.delete(_keyLogoPath);
    }

    state = state.copyWith(
      shopName: shop['name'] as String? ?? 'My Shop',
      phone: shop['phone'] as String? ?? '',
      shopNumber: shop['shopNumber'] as String? ?? '',
      address: shop['address'] as String? ?? '',
      logoPath: shop['logoPath'] as String?,
      shops: shops,
      activeShopId: actualId,
    );
  }

  void updateActiveShop({
    required String name,
    required String phone,
    required String shopNumber,
    required String address,
    String? logoPath,
  }) {
    if (!state.isAuthenticated) return;

    final box = Hive.box(_boxName);
    final shops = List<Map<dynamic, dynamic>>.from(state.shops);
    final activeId = state.activeShopId;

    final index = shops.indexWhere((s) => s['id'].toString() == activeId.toString());
    if (index != -1) {
      shops[index] = {
        'id': activeId,
        'name': name,
        'phone': phone,
        'shopNumber': shopNumber,
        'address': address,
        'logoPath': logoPath,
      };
    }

    box.put(_keyShops, shops);
    box.put(_keyName, name);
    box.put(_keyPhone, phone);
    box.put(_keyShopNumber, shopNumber);
    box.put(_keyAddress, address);
    if (logoPath != null) {
      box.put(_keyLogoPath, logoPath);
    } else {
      box.delete(_keyLogoPath);
    }

    state = state.copyWith(
      shopName: name,
      phone: phone,
      shopNumber: shopNumber,
      address: address,
      logoPath: logoPath,
      shops: shops,
    );
  }

  Future<void> deleteShop(String id) async {
    if (!state.isAuthenticated) return;
    if (state.shops.length <= 1) return; // Cannot delete the last shop

    final box = Hive.box(_boxName);
    final shops = List<Map<dynamic, dynamic>>.from(state.shops);

    shops.removeWhere((s) => s['id'].toString() == id.toString());
    box.put(_keyShops, shops);

    if (state.activeShopId.toString() == id.toString()) {
      await switchShop(shops.first['id'].toString());
    } else {
      state = state.copyWith(shops: shops);
    }
  }

  void updateShopName(String name) {
    updateActiveShop(
      name: name,
      phone: state.phone,
      shopNumber: state.shopNumber,
      address: state.address,
      logoPath: state.logoPath,
    );
  }
}

class AuthState {
  final bool isAuthenticated;
  final String email;
  final String shopName;
  final String phone;
  final String shopNumber;
  final String address;
  final String? logoPath;
  final List<Map<dynamic, dynamic>> shops;
  final String activeShopId;

  const AuthState._({
    required this.isAuthenticated,
    required this.email,
    required this.shopName,
    required this.phone,
    required this.shopNumber,
    required this.address,
    this.logoPath,
    required this.shops,
    required this.activeShopId,
  });

  const AuthState.unauthenticated()
      : this._(
          isAuthenticated: false,
          email: '',
          shopName: '',
          phone: '',
          shopNumber: '',
          address: '',
          logoPath: null,
          shops: const [],
          activeShopId: '',
        );

  const AuthState.authenticated({
    required String email,
    required String shopName,
    String phone = '',
    String shopNumber = '',
    String address = '',
    String? logoPath,
    List<Map<dynamic, dynamic>> shops = const [],
    String activeShopId = '',
  }) : this._(
          isAuthenticated: true,
          email: email,
          shopName: shopName,
          phone: phone,
          shopNumber: shopNumber,
          address: address,
          logoPath: logoPath,
          shops: shops,
          activeShopId: activeShopId,
        );

  AuthState copyWith({
    bool? isAuthenticated,
    String? email,
    String? shopName,
    String? phone,
    String? shopNumber,
    String? address,
    String? logoPath,
    List<Map<dynamic, dynamic>>? shops,
    String? activeShopId,
  }) {
    return AuthState._(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      email: email ?? this.email,
      shopName: shopName ?? this.shopName,
      phone: phone ?? this.phone,
      shopNumber: shopNumber ?? this.shopNumber,
      address: address ?? this.address,
      logoPath: logoPath ?? this.logoPath,
      shops: shops ?? this.shops,
      activeShopId: activeShopId ?? this.activeShopId,
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final activeShopIdProvider = Provider<String>((ref) {
  final authState = ref.watch(authProvider);
  return authState.activeShopId;
});

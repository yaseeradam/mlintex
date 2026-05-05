import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Simple local auth state (no Firebase yet).
/// In production, swap this with FirebaseAuth.
class AuthNotifier extends Notifier<AuthState> {
  static const _boxName = 'auth';
  static const _keyLoggedIn = 'logged_in';
  static const _keyEmail = 'email';
  static const _keyName = 'shop_name';

  @override
  AuthState build() {
    final box = Hive.box(_boxName);
    final loggedIn = box.get(_keyLoggedIn, defaultValue: false) as bool;
    if (loggedIn) {
      return AuthState.authenticated(
        email: box.get(_keyEmail, defaultValue: 'shop@example.com') as String,
        shopName: box.get(_keyName, defaultValue: 'My Shop') as String,
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
    // Derive shop name from email for demo
    final name = email.contains('@')
        ? email.split('@').first
            .split('.')
            .map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s)
            .join(' ')
        : 'My Shop';
    await box.put(_keyName, name);

    state = AuthState.authenticated(email: email.trim(), shopName: name);
    return true;
  }

  Future<void> logout() async {
    final box = Hive.box(_boxName);
    await box.put(_keyLoggedIn, false);
    state = const AuthState.unauthenticated();
  }

  void updateShopName(String name) {
    final box = Hive.box(_boxName);
    box.put(_keyName, name);
    state = state.copyWith(shopName: name);
  }
}

class AuthState {
  final bool isAuthenticated;
  final String email;
  final String shopName;

  const AuthState._({
    required this.isAuthenticated,
    required this.email,
    required this.shopName,
  });

  const AuthState.unauthenticated()
      : this._(isAuthenticated: false, email: '', shopName: '');

  const AuthState.authenticated({required String email, required String shopName})
      : this._(isAuthenticated: true, email: email, shopName: shopName);

  AuthState copyWith({bool? isAuthenticated, String? email, String? shopName}) {
    return AuthState._(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      email: email ?? this.email,
      shopName: shopName ?? this.shopName,
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

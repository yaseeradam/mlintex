import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dashboard/dashboard_screen.dart';
import '../sales/sales_screen.dart';
import '../products/products_screen.dart';
import '../customers/customers_screen.dart';
import '../settings/settings_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/sync_provider.dart';
import '../../data/datasources/sync_service.dart';

class _TabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int i) => state = i;
}

final _currentTabProvider = NotifierProvider<_TabNotifier, int>(_TabNotifier.new);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _screens = [
    DashboardScreen(),
    SalesScreen(),
    ProductsScreen(),
    CustomersScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(_currentTabProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentTab,
        children: _screens,
      ),
      bottomNavigationBar: _GlassBottomNav(
        currentIndex: currentTab,
        onTap: (i) => ref.read(_currentTabProvider.notifier).setTab(i),
      ),
    );
  }
}

class _GlassBottomNav extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _GlassBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    final isOnline = syncStatus.value == SyncStatus.synced;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      height: 68,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.dashboard_rounded, label: 'Home', index: 0, currentIndex: currentIndex, onTap: onTap),
                _NavItem(icon: Icons.point_of_sale_rounded, label: 'Sales', index: 1, currentIndex: currentIndex, onTap: onTap),
                _NavItem(icon: Icons.inventory_2_rounded, label: 'Products', index: 2, currentIndex: currentIndex, onTap: onTap),
                _NavItem(icon: Icons.people_rounded, label: 'Customers', index: 3, currentIndex: currentIndex, onTap: onTap),
                _NavItem(icon: Icons.more_horiz_rounded, label: 'More', index: 4, currentIndex: currentIndex, onTap: onTap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dashboard/dashboard_screen.dart';
import '../sales_ledger/sales_ledger_screen.dart';
import '../customers/customers_screen.dart';
import '../receive/receive_screen.dart';
import '../products/products_screen.dart';
import '../settings/settings_screen.dart';
import '../shop/shop_screen.dart';
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
    SalesLedgerScreen(),
    ReceiveScreen(),
    CustomersScreen(),
    ShopScreen(),
    ProductsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(_currentTabProvider);

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: IndexedStack(
          key: ValueKey(currentTab),
          index: currentTab,
          children: _screens,
        ),
      ),
      bottomNavigationBar: _ModernBottomNav(
        currentIndex: currentTab,
        onTap: (i) => ref.read(_currentTabProvider.notifier).setTab(i),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class _ModernBottomNav extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _ModernBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    final hasPending = syncStatus.value == SyncStatus.pending ||
        syncStatus.value == SyncStatus.syncing;

    final items = [
      _NavItemData(icon: Icons.home_rounded, activeIcon: Icons.home_rounded, label: 'Home'),
      _NavItemData(icon: Icons.receipt_long_rounded, activeIcon: Icons.receipt_long_rounded, label: 'Sales'),
      _NavItemData(icon: Icons.download_rounded, activeIcon: Icons.download_rounded, label: 'Receive'),
      _NavItemData(icon: Icons.people_rounded, activeIcon: Icons.people_rounded, label: 'Customers'),
      _NavItemData(icon: Icons.shopping_bag_rounded, activeIcon: Icons.shopping_bag_rounded, label: 'Shop'),
      _NavItemData(icon: Icons.storefront_rounded, activeIcon: Icons.storefront_rounded, label: 'Store'),
      _NavItemData(icon: Icons.settings_rounded, activeIcon: Icons.settings_rounded, label: 'Settings'),
    ];

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding + 12),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final item = items[i];
            final isSelected = i == currentIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Active indicator background
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: isSelected ? 40 : 0,
                            height: isSelected ? 28 : 0,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          // Icon with sync badge
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  isSelected ? item.activeIcon : item.icon,
                                  key: ValueKey(isSelected),
                                  size: 22,
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                              // Sync status dot on home tab
                              if (i == 0 && hasPending)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppTheme.warningColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppTheme.surfaceColor,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : const Color(0xFF94A3B8),
                          letterSpacing: -0.2,
                        ),
                        child: Text(item.label),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

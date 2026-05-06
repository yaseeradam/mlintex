import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../data/datasources/sync_service.dart';
import '../widgets/glass_container.dart';
import '../dashboard/debt_provider.dart';
import '../sales/sale_provider.dart';
import '../products/product_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedTab = 0; // 0 = Settings, 1 = Reports

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.backgroundStart : const Color(0xFFF1F5F9);
    final surfaceLight = isDark ? AppTheme.surfaceLight.withOpacity(0.3) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);

    return Container(
      color: bgColor,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Text(
                    'More',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: titleColor,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
            ),

            // Segmented Control
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: surfaceLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SegmentButton(
                        title: 'Settings',
                        icon: PhosphorIconsRegular.gear,
                        isSelected: _selectedTab == 0,
                        onTap: () => setState(() => _selectedTab = 0),
                      ),
                    ),
                    Expanded(
                      child: _SegmentButton(
                        title: 'Reports',
                        icon: PhosphorIconsRegular.chartBar,
                        isSelected: _selectedTab == 1,
                        onTap: () => setState(() => _selectedTab = 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Content
            Expanded(
              child: _selectedTab == 0
                  ? const _SettingsContent()
                  : const _ReportsContent(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark ? AppTheme.surfaceColor : Colors.white;
    final activeColor = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;
    final inactiveColor = isDark ? AppTheme.textMuted : const Color(0xFF94A3B8);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsContent extends ConsumerStatefulWidget {
  const _SettingsContent();

  @override
  ConsumerState<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends ConsumerState<_SettingsContent> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(syncStatusProvider);
    final isSyncing = syncStatus.value == SyncStatus.syncing;
    final authState = ref.watch(authProvider);
    final initial = authState.shopName.isNotEmpty
        ? authState.shopName[0].toUpperCase()
        : 'S';

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        // Profile Card
        GestureDetector(
          onTap: () => context.push('/profile'),
          child: ModernCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor.withOpacity(0.2),
                        AppTheme.accentColor.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: AppTheme.primaryLight,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authState.shopName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        authState.email,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  PhosphorIconsRegular.caretRight,
                  color: AppTheme.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        _SectionHeader('Appearance'),
        _SettingsGroup(
          children: [
            _ActionTile(
              icon: ref.watch(themeProvider) == ThemeMode.dark
                  ? PhosphorIconsRegular.moon
                  : PhosphorIconsRegular.sun,
              iconColor: ref.watch(themeProvider) == ThemeMode.dark
                  ? const Color(0xFF8B5CF6)
                  : AppTheme.warningColor,
              title: ref.watch(themeProvider) == ThemeMode.dark ? 'Dark Mode' : 'Light Mode',
              trailing: Switch.adaptive(
                value: ref.watch(themeProvider) == ThemeMode.dark,
                onChanged: (val) => ref
                    .read(themeProvider.notifier)
                    .setMode(val ? ThemeMode.dark : ThemeMode.light),
                activeColor: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _SectionHeader('Preferences'),
        _SettingsGroup(
          children: [
            _ToggleTile(
              icon: PhosphorIconsRegular.bell,
              iconColor: AppTheme.warningColor,
              title: 'Notifications',
              value: _notificationsEnabled,
              onChanged: (v) => setState(() => _notificationsEnabled = v),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _SectionHeader('Data & Sync'),
        _SettingsGroup(
          children: [
            _ActionTile(
              icon: PhosphorIconsRegular.cloudArrowUp,
              iconColor: AppTheme.successColor,
              title: 'Manual Sync',
              trailing: isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(PhosphorIconsRegular.caretRight,
                      color: AppTheme.textMuted, size: 20),
              onTap: isSyncing ? null : () => ref.read(syncServiceProvider).syncAll(),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _SectionHeader('Account'),
        _SettingsGroup(
          children: [
            _ActionTile(
              icon: PhosphorIconsRegular.signOut,
              iconColor: AppTheme.errorColor,
              title: 'Sign Out',
              titleColor: AppTheme.errorColor,
              onTap: () => _showLogoutDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Sign Out'),
        content: const Text(
            'Are you sure you want to sign out? Your offline data will be kept safe.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _ReportsContent extends ConsumerWidget {
  const _ReportsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
    final salesAsync = ref.watch(salesProvider);
    final debtsAsync = ref.watch(debtsProvider);
    final productsAsync = ref.watch(productsProvider);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        _SectionHeader('Revenue Overview'),
        salesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
          data: (sales) {
            final now = DateTime.now();
            final todaySales = sales
                .where((s) =>
                    s.saleDate.day == now.day &&
                    s.saleDate.month == now.month &&
                    s.saleDate.year == now.year)
                .toList();
            final monthSales = sales
                .where((s) =>
                    s.saleDate.month == now.month &&
                    s.saleDate.year == now.year)
                .toList();

            final todayTotal =
                todaySales.fold<double>(0, (sum, s) => sum + s.totalAmount);
            final monthTotal =
                monthSales.fold<double>(0, (sum, s) => sum + s.totalAmount);

            return Row(
              children: [
                Expanded(
                  child: _StatCardPremium(
                    title: 'Today',
                    amount: currency.format(todayTotal),
                    subtitle: '${todaySales.length} transactions',
                    colors: const [
                      Color(0xFF6366F1),
                      Color(0xFF4F46E5),
                    ],
                    icon: PhosphorIconsFill.calendar,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCardPremium(
                    title: 'This Month',
                    amount: currency.format(monthTotal),
                    subtitle: '${monthSales.length} transactions',
                    colors: const [
                      Color(0xFF10B981),
                      Color(0xFF059669),
                    ],
                    icon: PhosphorIconsFill.chartBar,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        _SectionHeader('Inventory & Debts'),
        debtsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const SizedBox(),
          data: (debts) {
            final unpaid = debts.where((d) => !d.isPaid).toList();
            final totalOwed = unpaid.fold<double>(
                0, (sum, d) => sum + d.remainingAmount);

            return Row(
              children: [
                Expanded(
                  child: _StatCardPremium(
                    title: 'Unpaid Debts',
                    amount: currency.format(totalOwed),
                    subtitle: '${unpaid.length} customers',
                    colors: const [
                      Color(0xFFF43F5E),
                      Color(0xFFE11D48),
                    ],
                    icon: PhosphorIconsFill.receipt,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: productsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => const SizedBox(),
                    data: (products) {
                      final lowStock =
                          products.where((p) => p.quantity < 5).length;
                      return _StatCardPremium(
                        title: 'Low Stock',
                        amount: lowStock.toString(),
                        subtitle: 'Items to restock',
                        colors: const [
                          Color(0xFFF59E0B),
                          Color(0xFFD97706),
                        ],
                        icon: PhosphorIconsFill.warning,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        _SectionHeader('Top Selling Items'),
        salesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const SizedBox(),
          data: (sales) {
            if (sales.isEmpty) {
              return ModernCard(
                padding: const EdgeInsets.all(20),
                child: const Center(
                  child: Text(
                    'No sales yet.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              );
            }

            // Calculate top selling
            final Map<String, int> productSales = {};
            final Map<String, String> productNames = {};

            for (final sale in sales) {
              for (final item in sale.items) {
                productSales[item.productId] =
                    (productSales[item.productId] ?? 0) + item.quantity;
                productNames[item.productId] = item.productName;
              }
            }

            final sortedKeys = productSales.keys.toList()
              ..sort(
                  (a, b) => productSales[b]!.compareTo(productSales[a]!));

            final top3 = sortedKeys.take(3).toList();

            return Column(
              children: top3.asMap().entries.map((entry) {
                final index = entry.key;
                final id = entry.value;
                final medals = [
                  PhosphorIconsFill.trophy,
                  PhosphorIconsFill.medal,
                  PhosphorIconsFill.star,
                ];
                final medalColors = [
                  const Color(0xFFFBBF24),
                  const Color(0xFF94A3B8),
                  const Color(0xFFCD7F32),
                ];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ModernCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: medalColors[index].withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            medals[index],
                            color: medalColors[index],
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            productNames[id]!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${productSales[id]} sold',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.primaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.cardBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: isDark ? AppTheme.textPrimary : const Color(0xFF0F172A),
        ),
      ),
    );
  }
}

class _ThemeToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _ThemeToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: textColor,
                ),
              ),
            ),
            if (isActive)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIconsFill.check,
                  color: AppTheme.primaryLight,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final mutedColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: iconColor,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultTextColor = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final mutedColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: titleColor ?? defaultTextColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ?? const SizedBox(),
          ],
        ),
      ),
    );
  }
}

class _StatCardPremium extends StatelessWidget {
  final String title;
  final String amount;
  final String subtitle;
  final List<Color> colors;
  final IconData icon;

  const _StatCardPremium({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.colors,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

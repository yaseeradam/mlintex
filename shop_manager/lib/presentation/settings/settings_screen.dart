import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_theme.dart';
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
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  const Text(
                    'More',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
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
                  color: AppTheme.textSecondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SegmentButton(
                        title: 'Settings',
                        icon: Icons.settings_rounded,
                        isSelected: _selectedTab == 0,
                        onTap: () => setState(() => _selectedTab = 0),
                      ),
                    ),
                    Expanded(
                      child: _SegmentButton(
                        title: 'Reports',
                        icon: Icons.bar_chart_rounded,
                        isSelected: _selectedTab == 1,
                        onTap: () => setState(() => _selectedTab = 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _selectedTab == 0 ? const _SettingsContent() : const _ReportsContent(),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
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
              size: 18,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
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
  bool _biometricEnabled = false;
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(syncStatusProvider);
    final isSyncing = syncStatus.value == SyncStatus.syncing;
    final authState = ref.watch(authProvider);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        // Profile Card
        GestureDetector(
          onTap: () => context.push('/profile'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    authState.shopName.isNotEmpty ? authState.shopName[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
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
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        authState.email,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        _SectionHeader('Preferences'),
        _SettingsGroup(
          children: [
            _ToggleTile(
              icon: PhosphorIconsRegular.fingerprint,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Biometric Login',
              value: _biometricEnabled,
              onChanged: (v) => setState(() => _biometricEnabled = v),
            ),
            const Divider(height: 1, indent: 56, color: Color(0xFFF3F4F6)),
            _ToggleTile(
              icon: PhosphorIconsRegular.bell,
              iconColor: const Color(0xFFF59E0B),
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
              iconColor: const Color(0xFF10B981),
              title: 'Manual Sync',
              trailing: isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(PhosphorIconsRegular.caretRight, color: AppTheme.textSecondary, size: 20),
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
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to sign out? Your offline data will be kept safe.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        const _SectionHeader('Revenue Overview'),
        salesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
          data: (sales) {
            final now = DateTime.now();
            final todaySales = sales.where((s) => s.saleDate.day == now.day && s.saleDate.month == now.month && s.saleDate.year == now.year).toList();
            final monthSales = sales.where((s) => s.saleDate.month == now.month && s.saleDate.year == now.year).toList();

            final todayTotal = todaySales.fold<double>(0, (sum, s) => sum + s.totalAmount);
            final monthTotal = monthSales.fold<double>(0, (sum, s) => sum + s.totalAmount);

            return Row(
              children: [
                Expanded(
                  child: _StatCardPremium(
                    title: 'Today',
                    amount: currency.format(todayTotal),
                    subtitle: '${todaySales.length} transactions',
                    colors: const [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    icon: Icons.today_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCardPremium(
                    title: 'This Month',
                    amount: currency.format(monthTotal),
                    subtitle: '${monthSales.length} transactions',
                    colors: const [Color(0xFF10B981), Color(0xFF059669)],
                    icon: Icons.calendar_month_rounded,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        const _SectionHeader('Inventory & Debts'),
        debtsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const SizedBox(),
          data: (debts) {
            final unpaid = debts.where((d) => !d.isPaid).toList();
            final totalOwed = unpaid.fold<double>(0, (sum, d) => sum + d.remainingAmount);

            return Row(
              children: [
                Expanded(
                  child: _StatCardPremium(
                    title: 'Unpaid Debts',
                    amount: currency.format(totalOwed),
                    subtitle: '${unpaid.length} customers',
                    colors: const [Color(0xFFF43F5E), Color(0xFFE11D48)],
                    icon: Icons.money_off_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: productsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => const SizedBox(),
                    data: (products) {
                      final lowStock = products.where((p) => p.quantity < 5).length;
                      return _StatCardPremium(
                        title: 'Low Stock',
                        amount: lowStock.toString(),
                        subtitle: 'Items to restock',
                        colors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                        icon: Icons.warning_rounded,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        
        const _SectionHeader('Top Selling Items'),
        salesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const SizedBox(),
          data: (sales) {
            if (sales.isEmpty) {
              return const GlassContainer(
                padding: EdgeInsets.all(16),
                child: Text('No sales yet.', style: TextStyle(color: AppTheme.textSecondary)),
              );
            }
            
            // Calculate top selling
            final Map<String, int> productSales = {};
            final Map<String, String> productNames = {};
            
            for (final sale in sales) {
              for (final item in sale.items) {
                productSales[item.productId] = (productSales[item.productId] ?? 0) + item.quantity;
                productNames[item.productId] = item.productName;
              }
            }
            
            final sortedKeys = productSales.keys.toList()
              ..sort((a, b) => productSales[b]!.compareTo(productSales[a]!));
              
            final top3 = sortedKeys.take(3).toList();
            
            return Column(
              children: top3.map((id) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDE68A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            productNames[id]!,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimary),
                          ),
                        ),
                        Text(
                          '${productSales[id]} sold',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.primaryColor),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

// ─── Reusable Components ───────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppTheme.textPrimary,
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

  const _ToggleTile({required this.icon, required this.iconColor, required this.title, this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppTheme.textPrimary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged, activeColor: iconColor),
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

  const _ActionTile({required this.icon, required this.iconColor, required this.title, this.subtitle, this.titleColor, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: titleColor ?? AppTheme.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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

  const _StatCardPremium({required this.title, required this.amount, required this.subtitle, required this.colors, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: colors.first.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(amount, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/quick_add_shop_customer_sheet.dart';
import '../dashboard/debt_provider.dart';
import '../ledger/customer_ledger_screen.dart';
import 'shop_customer_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  bool _isGridView = false;
  late AnimationController _fabAnim;

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fabAnim.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabAnim.dispose();
    super.dispose();
  }

  static const List<Color> _avatarColors = [
    AppTheme.primaryColor,
    AppTheme.accentColor,
    AppTheme.successColor,
    AppTheme.warningColor,
    AppTheme.errorColor,
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  @override
  Widget build(BuildContext context) {
    final shopsAsync = ref.watch(shopCustomersProvider);
    final debtsAsync = ref.watch(debtsProvider);
    const bg = Color(0xFFF1F5F9);
    const textPrimary = Color(0xFF0F172A);
    const textMuted = Color(0xFF64748B);
    const cardBg = Colors.white;
    const borderColor = Color(0xFFE2E8F0);

    return Container(
      color: bg,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Shop Customers',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: textPrimary, letterSpacing: -1)),
                        shopsAsync.when(
                          data: (s) => Text('${s.length} total',
                              style: const TextStyle(fontSize: 13, color: textMuted, fontWeight: FontWeight.w500)),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                  // Grid/List toggle
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _ViewToggleBtn(
                        icon: PhosphorIconsRegular.list,
                        active: !_isGridView,
                        onTap: () => setState(() => _isGridView = false),
                      ),
                      _ViewToggleBtn(
                        icon: PhosphorIconsRegular.squaresFour,
                        active: _isGridView,
                        onTap: () => setState(() => _isGridView = true),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  // Add button
                  GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const QuickAddShopCustomerSheet(),
                    ),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.warningColor, Color(0xFFD97706)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: AppTheme.warningColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(PhosphorIconsFill.userPlus, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // ── Owed Header Card ─────────────────────────────────────
            shopsAsync.when(
              data: (shops) {
                final shopIds = shops.map((s) => s.id).toSet();
                final unpaid = (debtsAsync.value ?? []).where((d) => !d.isPaid && shopIds.contains(d.customerId)).toList();
                final totalDebts = unpaid.length;
                final fmt = NumberFormat('#,##0', 'en_US');
                final totalOwed = unpaid.fold<double>(0, (s, d) => s + d.remainingAmount);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _OwedHeaderCard(
                    totalOwed: totalOwed,
                    totalDebts: totalDebts,
                    fmt: fmt,
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // ── Search ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => ref.read(shopCustomerSearchProvider.notifier).update(val),
                decoration: InputDecoration(
                  hintText: 'Search by name, phone or customer details…',
                  prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, color: AppTheme.textMuted, size: 18),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(PhosphorIconsRegular.x, color: AppTheme.textMuted, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(shopCustomerSearchProvider.notifier).update('');
                          },
                        )
                      : null,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── List / Grid ──────────────────────────────────────────
            Expanded(
              child: shopsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (shops) {
                  final query = ref.watch(shopCustomerSearchProvider).toLowerCase();
                  final filtered = query.isEmpty
                      ? shops
                      : shops.where((c) =>
                          c.name.toLowerCase().contains(query) ||
                          (c.phone?.contains(query) ?? false) ||
                          (c.shopNumber?.toLowerCase().contains(query) ?? false)).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(PhosphorIconsRegular.users, size: 64, color: AppTheme.textMuted.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(query.isEmpty ? 'No customers yet' : 'No results for "$query"',
                            style: TextStyle(color: textMuted, fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        if (query.isEmpty)
                          Text('Tap + to add your first customer',
                              style: TextStyle(color: textMuted.withOpacity(0.7), fontSize: 13)),
                      ]),
                    );
                  }

                  if (_isGridView) {
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.92,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _ShopGridCard(
                        customer: filtered[i],
                        avatarColor: _avatarColors[filtered[i].name.hashCode % _avatarColors.length],
                        debts: debtsAsync.value ?? [],
                        onTap: () => _openLedger(context, filtered[i]),
                        onEdit: () => _openEdit(context, filtered[i]),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ShopListCard(
                      customer: filtered[i],
                      avatarColor: _avatarColors[filtered[i].name.hashCode % _avatarColors.length],
                      debts: debtsAsync.value ?? [],
                      onTap: () => _openLedger(context, filtered[i]),
                      onEdit: () => _openEdit(context, filtered[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openLedger(BuildContext context, dynamic customer) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CustomerLedgerScreen(
        customerId: customer.id,
        customerName: customer.name,
        customerPhone: customer.phone,
        customerAddress: customer.address,
        customerShopNumber: customer.shopNumber,
        customerAvatarPath: customer.avatarPath,
      ),
    ));
  }

  void _openEdit(BuildContext context, dynamic customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickAddShopCustomerSheet(existing: customer),
    );
  }
}

// ── View Toggle Button ───────────────────────────────────────────────────────

class _ViewToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ViewToggleBtn({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: active ? Colors.white : AppTheme.textMuted),
      ),
    );
  }
}

// ── Stat Pill ────────────────────────────────────────────────────────────────

// ── Owed Header Card ─────────────────────────────────────────────────────────

class _OwedHeaderCard extends StatelessWidget {
  final double totalOwed;
  final int totalDebts;
  final NumberFormat fmt;

  const _OwedHeaderCard({
    required this.totalOwed,
    required this.totalDebts,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL AMOUNT OWED',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalDebts active debts',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₦${fmt.format(totalOwed)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Accumulated pending balance from customers with active debt entries.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── List Card ────────────────────────────────────────────────────────────────

class _ShopListCard extends StatelessWidget {
  final dynamic customer;
  final Color avatarColor;
  final List<dynamic> debts;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _ShopListCard({
    required this.customer,
    required this.avatarColor,
    required this.debts,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final initial = customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?';
    final unpaidDebts = debts.where((d) => d.customerId == customer.id && !d.isPaid).toList();
    final totalOwed = unpaidDebts.fold<double>(0, (s, d) => s + d.remainingAmount);
    final fmt = NumberFormat('#,##0', 'en_US');

    return GestureDetector(
      onTap: onTap,
      child: ModernCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // Avatar
          _Avatar(avatarPath: customer.avatarPath, initial: initial, color: avatarColor, size: 52),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(customer.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
              const SizedBox(height: 3),
              if (customer.shopNumber != null)
                Row(children: [
                  Icon(Icons.store_rounded, size: 12, color: AppTheme.primaryColor),
                  const SizedBox(width: 4),
                  Expanded(child: Text(customer.shopNumber!, style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                ]),
              if (customer.phone != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(PhosphorIconsRegular.phone, size: 12, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(customer.phone!, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ]),
              ],
              if (unpaidDebts.isNotEmpty) ...[
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('₦${fmt.format(totalOwed)}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.errorColor, fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
          ),
          // Actions
          Column(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: onEdit,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_rounded, size: 15, color: AppTheme.primaryColor),
              ),
            ),
            const SizedBox(height: 6),
            const Icon(PhosphorIconsRegular.caretRight, size: 16, color: Color(0xFF64748B)),
          ]),
        ]),
      ),
    );
  }
}

// ── Grid Card ────────────────────────────────────────────────────────────────

class _ShopGridCard extends StatelessWidget {
  final dynamic customer;
  final Color avatarColor;
  final List<dynamic> debts;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _ShopGridCard({
    required this.customer,
    required this.avatarColor,
    required this.debts,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final initial = customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?';
    final unpaidDebts = debts.where((d) => d.customerId == customer.id && !d.isPaid).toList();
    final totalOwed = unpaidDebts.fold<double>(0, (s, d) => s + d.remainingAmount);
    final fmt = NumberFormat('#,##0', 'en_US');
    const textPrimary = Color(0xFF0F172A);
    const textMuted = Color(0xFF64748B);

    return GestureDetector(
      onTap: onTap,
      child: ModernCard(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: onEdit,
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.edit_rounded, size: 13, color: AppTheme.primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 2),
            _Avatar(avatarPath: customer.avatarPath, initial: initial, color: avatarColor, size: 50),
            const SizedBox(height: 6),
            Text(
              customer.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textPrimary),
            ),
            if (customer.shopNumber != null) ...[
              const SizedBox(height: 2),
              Text(
                customer.shopNumber!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.w500),
              ),
            ],
            if (customer.phone != null) ...[
              const SizedBox(height: 2),
              Text(
                customer.phone!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: textMuted),
              ),
            ],
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: unpaidDebts.isNotEmpty
                    ? AppTheme.errorColor.withOpacity(0.1)
                    : AppTheme.successColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                unpaidDebts.isNotEmpty ? '\u20a6${fmt.format(totalOwed)}' : 'No debt',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: unpaidDebts.isNotEmpty ? AppTheme.errorColor : AppTheme.successColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? avatarPath;
  final String initial;
  final Color color;
  final double size;

  const _Avatar({required this.avatarPath, required this.initial, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: avatarPath == null ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.25), color.withOpacity(0.1)],
        ) : null,
        border: Border.all(color: color.withOpacity(0.35), width: 2),
        image: avatarPath != null
            ? DecorationImage(image: FileImage(File(avatarPath!)), fit: BoxFit.cover)
            : null,
      ),
      child: avatarPath == null
          ? Center(child: Text(initial, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: size * 0.35)))
          : null,
    );
  }
}

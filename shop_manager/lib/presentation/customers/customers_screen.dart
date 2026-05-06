import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/quick_add_customer_sheet.dart';
import '../dashboard/debt_provider.dart';
import '../widgets/app_feedback.dart';
import 'customer_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.backgroundStart : const Color(0xFFF1F5F9);
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);

    return Container(
      color: bg,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Customers',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: textPrimary,
                      letterSpacing: -1,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const QuickAddCustomerSheet(),
                    ),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.warningColor,
                            const Color(0xFFD97706),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.warningColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        PhosphorIconsFill.userPlus,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) =>
                    ref.read(customerSearchProvider.notifier).update(val),
                decoration: InputDecoration(
                  hintText: 'Search customers…',
                  prefixIcon: const Icon(
                    PhosphorIconsRegular.magnifyingGlass,
                    color: AppTheme.textMuted,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(PhosphorIconsRegular.x, color: AppTheme.textMuted),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(customerSearchProvider.notifier)
                                .update('');
                          },
                        )
                      : null,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Customer list
            Expanded(
              child: customersAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (customers) {
                  final query = ref.watch(customerSearchProvider).toLowerCase();
                  final filtered = query.isEmpty
                      ? customers
                      : customers
                          .where((c) =>
                              c.name.toLowerCase().contains(query) ||
                              (c.phone?.contains(query) ?? false))
                          .toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIconsRegular.users,
                            size: 64,
                            color: AppTheme.textMuted.withOpacity(0.4),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No customers found',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tap + to add your first customer',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final customer = filtered[i];
                      final initial = customer.name.isNotEmpty
                          ? customer.name[0].toUpperCase()
                          : '?';
                      final colorIndex =
                          customer.name.hashCode % _avatarColors.length;
                      final avatarColor = _avatarColors[colorIndex];

                      return GestureDetector(
                        onTap: () =>
                            _showCustomerDetail(context, customer, ref),
                        child: ModernCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      avatarColor.withOpacity(0.2),
                                      avatarColor.withOpacity(0.1),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: avatarColor.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  initial,
                                  style: TextStyle(
                                    color: avatarColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    if (customer.phone != null) ...[
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(
                                            PhosphorIconsRegular.phone,
                                            size: 13,
                                            color: AppTheme.textMuted,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            customer.phone!,
                                            style: TextStyle(
                                              color: AppTheme.textMuted,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                PhosphorIconsRegular.caretRight,
                                color: AppTheme.textMuted,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerDetail(
      BuildContext context, dynamic customer, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerDetailSheet(customer: customer),
    );
  }

  static const List<Color> _avatarColors = [
    AppTheme.primaryColor,
    AppTheme.accentColor,
    AppTheme.successColor,
    AppTheme.warningColor,
    AppTheme.errorColor,
  ];
}

class _CustomerDetailSheet extends ConsumerWidget {
  final dynamic customer;
  const _CustomerDetailSheet({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsProvider);
    final initial = customer.name.isNotEmpty
        ? customer.name[0].toUpperCase()
        : '?';
    final colorIndex = customer.name.hashCode % _avatarColors.length;
    final avatarColor = _avatarColors[colorIndex];

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLighter,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Profile header
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                avatarColor.withOpacity(0.25),
                                avatarColor.withOpacity(0.1),
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: avatarColor.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: TextStyle(
                                color: avatarColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 24,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (customer.phone != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      PhosphorIconsRegular.phone,
                                      size: 14,
                                      color: AppTheme.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      customer.phone!,
                                      style: TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Debts section
                    const Text(
                      'Outstanding Debts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    debtsAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (e, _) => Text(
                        'Error: $e',
                        style: const TextStyle(color: AppTheme.errorColor),
                      ),
                      data: (debts) {
                        final customerDebts = debts
                            .where((d) =>
                                d.customerId == customer.id && !d.isPaid)
                            .toList();
                        if (customerDebts.isEmpty) {
                          return ModernCard(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Icon(
                                  PhosphorIconsRegular.checkCircle,
                                  size: 40,
                                  color: AppTheme.successColor
                                      .withOpacity(0.5),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'No outstanding debts',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return Column(
                          children: customerDebts.map((d) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ModernCard(
                                padding: const EdgeInsets.all(14),
                                bgColor: d.isOverdue
                                    ? AppTheme.errorColor.withOpacity(0.06)
                                    : AppTheme.surfaceColor,
                                border: Border.all(
                                  color: d.isOverdue
                                      ? AppTheme.errorColor.withOpacity(0.2)
                                      : AppTheme.cardBorder,
                                  width: 1,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            d.note ?? 'Debt',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Due: ${d.dueDate.day}/${d.dueDate.month}/${d.dueDate.year}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: d.isOverdue
                                                  ? AppTheme.errorColor
                                                  : AppTheme.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₦${d.remainingAmount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.errorColor,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        GestureDetector(
                                          onTap: () async {
                                            AppFeedback.showLoading(context);
                                            await ref
                                                .read(debtNotifierProvider
                                                    .notifier)
                                                .markAsPaid(d.id);
                                            if (context.mounted) {
                                              AppFeedback.hideLoading(
                                                  context);
                                              AppFeedback.showSuccess(
                                                context,
                                                'Debt Paid',
                                                'The debt has been marked as paid.',
                                              );
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.successColor
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Mark Paid',
                                              style: TextStyle(
                                                color: AppTheme.successColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static const List<Color> _avatarColors = [
    AppTheme.primaryColor,
    AppTheme.accentColor,
    AppTheme.successColor,
    AppTheme.warningColor,
    AppTheme.errorColor,
  ];
}

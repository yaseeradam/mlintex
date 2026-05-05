import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/quick_add_customer_sheet.dart';
import '../dashboard/debt_provider.dart';
import '../widgets/app_feedback.dart';
import 'customer_provider.dart';

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

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Customers',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.person_add_rounded, color: AppTheme.primaryColor, size: 24),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) =>
                    ref.read(customerSearchProvider.notifier).update(val),
                decoration: InputDecoration(
                  hintText: 'Search customers…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(customerSearchProvider.notifier).update('');
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: customersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (customers) {
                  final query = ref.watch(customerSearchProvider).toLowerCase();
                  final filtered = query.isEmpty
                      ? customers
                      : customers.where((c) =>
                            c.name.toLowerCase().contains(query) ||
                            (c.phone?.contains(query) ?? false)).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: AppTheme.textSecondary.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          const Text('No customers yet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                          const SizedBox(height: 8),
                          const Text('Tap + to add your first customer', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final customer = filtered[i];
                      return GestureDetector(
                        onTap: () => _showCustomerDetail(context, customer),
                        child: GlassContainer(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                                child: Text(
                                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    if (customer.phone != null)
                                      Text(
                                        customer.phone!,
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
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

  void _showCustomerDetail(BuildContext context, dynamic customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerDetailSheet(customer: customer),
    );
  }
}

class _CustomerDetailSheet extends ConsumerWidget {
  final dynamic customer;
  const _CustomerDetailSheet({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                          child: Text(
                            customer.name[0].toUpperCase(),
                            style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 24),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(customer.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                            if (customer.phone != null) Text(customer.phone!, style: const TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Debts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),
                    debtsAsync.when(
                      loading: () => const CircularProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                      data: (debts) {
                        final customerDebts = debts.where((d) => d.customerId == customer.id && !d.isPaid).toList();
                        if (customerDebts.isEmpty) {
                          return const Text('No outstanding debts', style: TextStyle(color: AppTheme.textSecondary));
                        }
                        return Column(
                          children: customerDebts.map((d) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: d.isOverdue ? AppTheme.errorColor.withOpacity(0.08) : const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: d.isOverdue ? AppTheme.errorColor.withOpacity(0.3) : Colors.transparent),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d.note ?? 'Debt', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text('Due: ${d.dueDate.day}/${d.dueDate.month}/${d.dueDate.year}', style: TextStyle(fontSize: 12, color: d.isOverdue ? AppTheme.errorColor : AppTheme.textSecondary)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('₦${d.remainingAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.errorColor, fontSize: 16)),
                                    GestureDetector(
                                      onTap: () async {
                                        AppFeedback.showLoading(context);
                                        await ref.read(debtNotifierProvider.notifier).markAsPaid(d.id);
                                        if (context.mounted) {
                                          AppFeedback.hideLoading(context);
                                          AppFeedback.showSuccess(context, 'Debt Paid', 'The debt has been successfully marked as paid.');
                                        }
                                      },
                                      child: const Text('Mark Paid', style: TextStyle(color: AppTheme.successColor, fontSize: 12, fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )).toList(),
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
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../customers/customer_provider.dart';
import '../widgets/app_feedback.dart';
import '../dashboard/debt_provider.dart';

class AddDebtSheet extends ConsumerStatefulWidget {
  const AddDebtSheet({super.key});

  @override
  ConsumerState<AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends ConsumerState<AddDebtSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedCustomerId;
  String? _selectedCustomerName;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));

  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked != null) setState(() => _reminderTime = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      AppFeedback.showError(context, 'Missing', 'Please select a customer.');
      return;
    }

    AppFeedback.showLoading(context);

    final debtId = const Uuid().v4();
    final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();
    final amount = CurrencyInputFormatter.parse(_amountController.text.trim());

    await ref.read(debtNotifierProvider.notifier).addDebt(
          customerId: _selectedCustomerId!,
          customerName: _selectedCustomerName!,
          amount: amount,
          dueDate: _dueDate,
          note: note,
        );

    if (_reminderEnabled) {
      final reminderDateTime = DateTime(
        _dueDate.year,
        _dueDate.month,
        _dueDate.day,
        _reminderTime.hour,
        _reminderTime.minute,
      );
      if (reminderDateTime.isAfter(DateTime.now())) {
        await NotificationService.scheduleDebtReminder(
          debtId: debtId,
          customerName: _selectedCustomerName!,
          amount: amount,
          scheduledDate: reminderDateTime,
          note: note,
        );
      }
    }

    if (mounted) {
      AppFeedback.hideLoading(context);
      Navigator.pop(context);
      AppFeedback.showSuccess(
        context,
        'Debt Added',
        _reminderEnabled
            ? 'Debt recorded. Reminder set for ${DateFormat('MMM d').format(_dueDate)} at ${_reminderTime.format(context)}.'
            : 'Debt has been recorded successfully.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Colors.white;
    const textPrimary = Color(0xFF0F172A);
    const textMuted = Color(0xFF64748B);
    const borderColor = Color(0xFFE2E8F0);
    const fieldBg = Color(0xFFF8FAFC);
    final customersAsync = ref.watch(customersProvider);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text('New Debt',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.5)),
              const SizedBox(height: 20),

              // Customer
              Text('Customer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
              const SizedBox(height: 8),
              customersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e', style: const TextStyle(color: AppTheme.errorColor)),
                data: (customers) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: fieldBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedCustomerId,
                      hint: Text('Select a customer', style: TextStyle(color: textMuted)),
                      dropdownColor: bg,
                      style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                      items: customers
                          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                          .toList(),
                      onChanged: (val) {
                        final customer = customers.firstWhere((c) => c.id == val);
                        setState(() {
                          _selectedCustomerId = val;
                          _selectedCustomerName = customer.name;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Amount
              Text('Amount (₦)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [CurrencyInputFormatter()],
                decoration: const InputDecoration(hintText: '0.00', prefixText: '₦ '),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Amount is required';
                  if (CurrencyInputFormatter.parse(v.trim()) <= 0) return 'Amount must be greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Due date
              Text('Due Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDueDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: fieldBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 18, color: textMuted),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('MMM d, yyyy').format(_dueDate),
                        style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Note
              Text('Note (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(hintText: 'e.g. Fabric purchase, school fees…'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Reminder toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: _reminderEnabled
                      ? AppTheme.primaryColor.withOpacity(0.06)
                      : fieldBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _reminderEnabled
                        ? AppTheme.primaryColor.withOpacity(0.25)
                        : borderColor,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_outlined,
                      size: 20,
                      color: _reminderEnabled ? AppTheme.primaryColor : textMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Set Reminder',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _reminderEnabled ? AppTheme.primaryColor : textPrimary,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: _reminderEnabled,
                      onChanged: (v) => setState(() => _reminderEnabled = v),
                      activeColor: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),

              // Reminder time picker — shown only when reminder is on
              if (_reminderEnabled) ...[
                const SizedBox(height: 12),
                Text('Reminder Time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickReminderTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 18, color: AppTheme.primaryColor),
                        const SizedBox(width: 10),
                        Text(
                          _reminderTime.format(context),
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text('on ${DateFormat('MMM d, yyyy').format(_dueDate)}',
                            style: TextStyle(color: textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Record Debt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

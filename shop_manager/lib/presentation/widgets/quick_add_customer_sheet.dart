import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'app_feedback.dart';
import '../customers/customer_provider.dart';

class QuickAddCustomerSheet extends ConsumerStatefulWidget {
  const QuickAddCustomerSheet({super.key});

  @override
  ConsumerState<QuickAddCustomerSheet> createState() => _QuickAddCustomerSheetState();
}

class _QuickAddCustomerSheetState extends ConsumerState<QuickAddCustomerSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Add Customer',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'Customer name',
                ),
                validator: (v) => v!.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  hintText: '+1 234 567 8900',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Address (optional)',
                  hintText: 'Customer address',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Add Customer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    AppFeedback.showLoading(context);
    try {
      await ref.read(customerNotifierProvider.notifier).addCustomer(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      );
      if (mounted) {
        AppFeedback.hideLoading(context);
        Navigator.pop(context);
        AppFeedback.showSuccess(context, 'Success', 'Customer added successfully.');
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.hideLoading(context);
        AppFeedback.showError(context, 'Error', 'Failed to add customer.');
      }
    }
  }
}

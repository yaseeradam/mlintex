import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/customer.dart';
import 'app_feedback.dart';
import '../customers/customer_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class QuickAddCustomerSheet extends ConsumerStatefulWidget {
  final Customer? existing;
  const QuickAddCustomerSheet({super.key, this.existing});

  @override
  ConsumerState<QuickAddCustomerSheet> createState() =>
      _QuickAddCustomerSheetState();
}

class _QuickAddCustomerSheetState extends ConsumerState<QuickAddCustomerSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _shopNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _avatarPath;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final c = widget.existing!;
      _nameController.text = c.name;
      _phoneController.text = c.phone ?? '';
      _addressController.text = c.address ?? '';
      _shopNumberController.text = c.shopNumber ?? '';
      _avatarPath = c.avatarPath;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _shopNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSourceSheet(),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _avatarPath = picked.path);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    AppFeedback.showLoading(context);
    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();
      final address = _addressController.text.trim().isEmpty ? null : _addressController.text.trim();
      final shopNumber = _shopNumberController.text.trim().isEmpty ? null : _shopNumberController.text.trim();

      if (_isEditing) {
        await ref.read(customerNotifierProvider.notifier).updateCustomer(
              widget.existing!.copyWith(
                name: name,
                phone: phone,
                address: address,
                shopNumber: shopNumber,
                avatarPath: _avatarPath,
                updatedAt: DateTime.now(),
              ),
            );
      } else {
        await ref.read(customerNotifierProvider.notifier).addCustomer(
              name: name,
              phone: phone,
              address: address,
              shopNumber: shopNumber,
              avatarPath: _avatarPath,
            );
      }

      if (mounted) {
        AppFeedback.hideLoading(context);
        Navigator.pop(context);
        AppFeedback.showSuccess(
          context,
          'Success',
          _isEditing ? 'Customer updated.' : 'Customer added successfully.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.hideLoading(context);
        AppFeedback.showError(context, 'Error', 'Failed to save customer.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.surfaceColor : Colors.white;
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);
    final textMuted = isDark ? AppTheme.textMuted : const Color(0xFF64748B);
    final borderColor = isDark ? AppTheme.cardBorder : const Color(0xFFE2E8F0);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
                24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: borderColor, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Row(children: [
                Icon(PhosphorIconsRegular.userPlus, color: AppTheme.warningColor, size: 22),
                const SizedBox(width: 10),
                Text(
                  _isEditing ? 'Edit Customer' : 'Add Customer',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textPrimary),
                ),
              ]),
              const SizedBox(height: 24),

              // Avatar picker
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 2),
                          image: _avatarPath != null
                              ? DecorationImage(image: FileImage(File(_avatarPath!)), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _avatarPath == null
                            ? Icon(PhosphorIconsRegular.user, size: 40, color: AppTheme.primaryColor.withOpacity(0.5))
                            : null,
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: bg, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text('Tap to upload photo', style: TextStyle(fontSize: 12, color: textMuted)),
              ),
              const SizedBox(height: 20),

              // Name
              _lbl('Full Name *', textMuted),
              TextFormField(
                controller: _nameController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Customer name'),
                validator: (v) => v!.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),

              // Phone
              _lbl('Phone (optional)', textMuted),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: '+234 800 000 0000'),
              ),
              const SizedBox(height: 14),

              // Shop Number
              _lbl('Shop Number (optional)', textMuted),
              TextFormField(
                controller: _shopNumberController,
                decoration: const InputDecoration(hintText: 'e.g. Shop 12, Block B, Onitsha Market'),
              ),
              const SizedBox(height: 14),

              // Address
              _lbl('Address (optional)', textMuted),
              TextFormField(
                controller: _addressController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Customer address'),
                maxLines: 2,
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: Icon(_isEditing ? Icons.save_rounded : PhosphorIconsFill.userPlus, size: 18),
                  label: Text(
                    _isEditing ? 'Save Changes' : 'Add Customer',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warningColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lbl(String t, Color c) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c)),
  );
}

class _ImageSourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.surfaceColor : Colors.white;
    final textPrimary = isDark ? AppTheme.textPrimary : const Color(0xFF0F172A);

    return Container(
      decoration: BoxDecoration(
          color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Text('Choose Photo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
        const SizedBox(height: 20),
        ListTile(
          leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryColor)),
          title: Text('Camera', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        ListTile(
          leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.photo_library_rounded, color: AppTheme.successColor)),
          title: Text('Gallery', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
      ]),
    );
  }
}

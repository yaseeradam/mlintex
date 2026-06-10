import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import 'app_feedback.dart';
import '../products/product_provider.dart';
import '../../domain/entities/product.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../receive/receive_screen.dart';

class QuickAddProductSheet extends ConsumerStatefulWidget {
  final dynamic existing;

  const QuickAddProductSheet({super.key, this.existing});

  @override
  ConsumerState<QuickAddProductSheet> createState() =>
      _QuickAddProductSheetState();
}

class _QuickAddProductSheetState extends ConsumerState<QuickAddProductSheet> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _categoryController = TextEditingController();
  final _receiveQtyController = TextEditingController();
  final _paymentController = TextEditingController();
  final _totalController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _avatarPath;

  final _numFmt = NumberFormat('#,##0', 'en_US');

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.existing as Product;
      _nameController.text = p.name;
      _priceController.text = p.price.toStringAsFixed(2);
      _quantityController.text = p.quantity.toString();
      _categoryController.text = p.category ?? '';
      _avatarPath = p.imagePath;
      _receiveQtyController.text = '0';
      _paymentController.text = '0';
    } else {
      _quantityController.text = '0';
      _receiveQtyController.text = '0';
      _paymentController.text = '0';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _categoryController.dispose();
    _receiveQtyController.dispose();
    _paymentController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  void _updateTotal() {
    final price = CurrencyInputFormatter.parse(_priceController.text);
    final qty = int.tryParse(_receiveQtyController.text.trim()) ?? 0;
    if (price > 0 && qty > 0) {
      _totalController.text = _numFmt.format(price * qty);
    } else {
      _totalController.text = '';
    }
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
      final price = double.parse(_priceController.text.trim().replaceAll(',', ''));
      final quantity = int.parse(_quantityController.text.trim());
      final category = _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim();
      final receiveQty = int.tryParse(_receiveQtyController.text.trim()) ?? 0;
      final payment = CurrencyInputFormatter.parse(_paymentController.text);

      final notifier = ref.read(productNotifierProvider.notifier);
      if (_isEditing) {
        final existing = widget.existing as Product;
        await notifier.updateProduct(
          existing.copyWith(
            name: name,
            price: price,
            quantity: quantity,
            category: category,
            imagePath: _avatarPath,
            updatedAt: DateTime.now(),
            isSynced: false,
          ),
        );
      } else {
        await notifier.addProduct(
          name: name,
          price: price,
          quantity: quantity,
          category: category,
          imagePath: _avatarPath,
        );
      }

      // If receive quantity is entered, log it to the receive ledger
      if (receiveQty > 0) {
        await ref.read(receiveNotifierProvider.notifier).add(
          product: name,
          price: price,
          qty: receiveQty,
          payment: payment,
        );
      }

      if (mounted) {
        AppFeedback.hideLoading(context);
        Navigator.pop(context);
        AppFeedback.showSuccess(
          context,
          'Success',
          _isEditing ? 'Product updated.' : 'Product added successfully.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.hideLoading(context);
        AppFeedback.showError(context, 'Error', 'Failed to save product.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Colors.white;
    const textPrimary = Color(0xFF0F172A);
    const textMuted = Color(0xFF64748B);
    const borderColor = Color(0xFFE2E8F0);
    const accentReceive = Color(0xFF10B981);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.95,
      minChildSize: 0.5,
      maxChildSize: 0.98,
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
                Icon(_isEditing ? PhosphorIconsRegular.pencilSimple : PhosphorIconsRegular.package,
                    color: AppTheme.primaryColor, size: 22),
                const SizedBox(width: 10),
                Text(
                  _isEditing ? 'Edit Product' : 'Add Product',
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
                            ? Icon(PhosphorIconsRegular.package, size: 40, color: AppTheme.primaryColor.withOpacity(0.5))
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
              _lbl('Item Name *', textMuted),
              TextFormField(
                controller: _nameController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'e.g. LIN ROMAN 150y'),
                validator: (v) => v!.trim().isEmpty ? 'Item name is required' : null,
              ),
              const SizedBox(height: 14),

              // Price & Quantity in a Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _lbl('Price *', textMuted),
                        TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [CurrencyInputFormatter()],
                          decoration: const InputDecoration(
                            hintText: '0.00',
                            prefixText: '₦ ',
                          ),
                          onChanged: (_) => setState(_updateTotal),
                          validator: (v) {
                            if (v!.trim().isEmpty) return 'Required';
                            if (double.tryParse(v.replaceAll(',', '')) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _lbl('Quantity *', textMuted),
                        TextFormField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(hintText: '0'),
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Category
              _lbl('Category (optional)', textMuted),
              Consumer(
                builder: (context, ref, child) {
                  final productsAsync = ref.watch(productsProvider);
                  final categories = productsAsync.value
                          ?.map((p) => p.category)
                          .where((c) => c != null && c.toString().isNotEmpty)
                          .map((c) => c.toString())
                          .toSet()
                          .toList() ??
                      [];

                  return Autocomplete<String>(
                    initialValue:
                        TextEditingValue(text: _categoryController.text),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text == '') {
                        return const Iterable<String>.empty();
                      }
                      return categories.where((String option) {
                        return option.toLowerCase().contains(
                            textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selection) {
                      _categoryController.text = selection;
                    },
                    fieldViewBuilder: (context, textEditingController,
                        focusNode, onFieldSubmitted) {
                      textEditingController.addListener(() {
                        _categoryController.text = textEditingController.text;
                      });

                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Beverages',
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                                maxHeight: 200, maxWidth: 300),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),

              // ─── Receive & Payment Section ────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentReceive.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentReceive.withOpacity(0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accentReceive.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.arrow_circle_down_rounded, size: 16, color: accentReceive),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Receive & Payment',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentReceive.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Optional',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accentReceive),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Fill in to log this stock inward to the Receive ledger.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),

                    // Receive Qty & Payment in a Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _lbl('Receive Qty', textMuted),
                              TextFormField(
                                controller: _receiveQtyController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(hintText: '0'),
                                onChanged: (_) => setState(_updateTotal),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _lbl('Payment Made (₦)', textMuted),
                              TextFormField(
                                controller: _paymentController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [CurrencyInputFormatter()],
                                decoration: const InputDecoration(hintText: '0.00'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Total Amount (read-only)
                    _lbl('Total Receive Amount (₦)', textMuted),
                    TextFormField(
                      controller: _totalController,
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixText: '₦ ',
                        filled: true,
                        fillColor: accentReceive.withOpacity(0.06),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: Icon(_isEditing ? Icons.save_rounded : PhosphorIconsFill.package, size: 18),
                  label: Text(
                    _isEditing ? 'Save Changes' : 'Add Product',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
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
    const bg = Colors.white;
    const textPrimary = Color(0xFF0F172A);

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

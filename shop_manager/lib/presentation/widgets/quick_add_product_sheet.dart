import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'app_feedback.dart';
import '../products/product_provider.dart';
import '../../domain/entities/product.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameController.text = widget.existing.name;
      _priceController.text = widget.existing.price.toStringAsFixed(2);
      _quantityController.text = widget.existing.quantity.toString();
      _categoryController.text = widget.existing.category ?? '';
    } else {
      _quantityController.text = '0';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(
                    isEditing ? PhosphorIconsRegular.pencilSimple : PhosphorIconsRegular.package,
                    color: AppTheme.primaryColor,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEditing ? 'Edit Product' : 'Add Product',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                autofocus: !isEditing,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Product Name *',
                  hintText: 'e.g. Coca-Cola 500ml',
                ),
                validator: (v) => v!.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'))
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Price *',
                        hintText: '0.00',
                        prefixText: '₦ ',
                      ),
                      validator: (v) {
                        if (v!.trim().isEmpty) return 'Required';
                        if (double.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Quantity *',
                        hintText: '0',
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
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
                    optionsBuilder:
                        (TextEditingValue textEditingValue) {
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
                          labelText: 'Category (optional)',
                          hintText: 'e.g. Beverages',
                        ),
                      );
                    },
                    optionsViewBuilder:
                        (context, onSelected, options) {
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
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: Icon(
                    isEditing ? PhosphorIconsFill.floppyDisk : PhosphorIconsFill.plus,
                    size: 18,
                  ),
                  label: Text(
                    isEditing ? 'Update Product' : 'Add Product',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
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
      final notifier = ref.read(productNotifierProvider.notifier);
      if (widget.existing != null) {
        final existing = widget.existing as Product;
        await notifier.updateProduct(
          existing.copyWith(
            name: _nameController.text.trim(),
            price: double.parse(_priceController.text),
            quantity: int.parse(_quantityController.text),
            category: _categoryController.text.trim().isEmpty
                ? null
                : _categoryController.text.trim(),
            updatedAt: DateTime.now(),
            isSynced: false,
          ),
        );
      } else {
        await notifier.addProduct(
          name: _nameController.text.trim(),
          price: double.parse(_priceController.text),
          quantity: int.parse(_quantityController.text),
          category: _categoryController.text.trim().isEmpty
              ? null
              : _categoryController.text.trim(),
        );
      }
      if (mounted) {
        AppFeedback.hideLoading(context);
        Navigator.pop(context);
        AppFeedback.showSuccess(context, 'Success',
            widget.existing != null ? 'Product updated.' : 'Product added.');
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.hideLoading(context);
        AppFeedback.showError(context, 'Error', 'Failed to save product.');
      }
    }
  }
}

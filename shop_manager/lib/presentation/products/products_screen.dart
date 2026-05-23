import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/pdf_theme.dart';
import '../../core/utils/file_saver.dart';
import '../../core/utils/product_style_util.dart';
import '../../core/providers/auth_provider.dart';
import '../widgets/quick_add_product_sheet.dart';
import '../widgets/app_feedback.dart';
import 'product_provider.dart';

// ── Screen ─────────────────────────────────────────────────────────────────

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  bool _isGridView = true;

  final _fmt = NumberFormat('#,##0', 'en_US');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF1F5F9);
    const textPrimary = Color(0xFF0F172A);
    const textMuted = Color(0xFF64748B);
    const cardBg = Colors.white;
    const borderColor = Color(0xFFE2E8F0);

    final productsAsync = ref.watch(productsProvider);
    final authState = ref.watch(authProvider);

    return Container(
      color: bg,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            elevation: 0,
            title: const Text(
              'Shop Inventory',
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.errorColor),
                tooltip: 'Export Catalog PDF',
                onPressed: () => productsAsync.whenData((p) => _exportPdf(p, _fmt)),
              ),
              IconButton(
                icon: const Icon(Icons.image_rounded, color: AppTheme.primaryColor),
                tooltip: 'Export Catalog Image',
                onPressed: () => productsAsync.whenData((_) => _exportImage()),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded, color: AppTheme.successColor),
                tooltip: 'Add Product',
                onPressed: () => _showAddSheet(context),
              ),
            ],
          ),
          body: productsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.errorColor))),
            data: (products) {
              final totalValue = products.fold<double>(0, (s, p) => s + p.price * p.quantity);
              final lowStock = products.where((p) => p.quantity < 5).length;

              final query = ref.watch(productSearchProvider).toLowerCase();
              var filtered = query.isEmpty ? products : products.where((p) => p.name.toLowerCase().contains(query)).toList();
              if (_selectedCategory != 'All') {
                filtered = filtered.where((p) => (p.category ?? 'Other') == _selectedCategory).toList();
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderCard(
                      shopName: authState.shopName,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                    ),
                    const SizedBox(height: 16),
                    _FinancialSummaryCard(
                      totalValue: totalValue,
                      totalCount: products.length,
                      lowStockCount: lowStock,
                      fmt: _fmt,
                    ),
                    const SizedBox(height: 16),
                    _QuickActionButtons(
                      onRecordProduct: () => _showAddSheet(context),
                    ),
                    const SizedBox(height: 16),
                    // Toggle + Category Lists
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'INVENTORY CATALOG',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.8,
                          ),
                        ),
                        // Segmented Toggle
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Row(
                            children: [
                              _ViewToggleBtn(
                                icon: PhosphorIconsRegular.squaresFour,
                                active: _isGridView,
                                onTap: () => setState(() => _isGridView = true),
                              ),
                              const SizedBox(width: 4),
                              _ViewToggleBtn(
                                icon: PhosphorIconsRegular.table,
                                active: !_isGridView,
                                onTap: () => setState(() => _isGridView = false),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Search box
                    TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        ref.read(productSearchProvider.notifier).update(val);
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: 'Search products…',
                        prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, color: AppTheme.textMuted, size: 18),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(PhosphorIconsRegular.x, color: AppTheme.textMuted, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(productSearchProvider.notifier).update('');
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Categories
                    _buildCategoryFilter(products),
                    const SizedBox(height: 12),
                    // Dual View Layout
                    _isGridView
                        ? _buildGridView(filtered)
                        : _ProductsLedgerFeed(
                            entries: filtered,
                            fmt: _fmt,
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textMuted: textMuted,
                            onEdit: (p) => _showAddSheet(context, existing: p),
                            onDelete: (p) => _showDeleteDialog(context, p.id, p.name),
                            onExport: (p) => _showRowExportSheet(context, p, authState),
                          ),
                    const SizedBox(height: 100),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(List<dynamic> products) {
    final cats = ['All', ...{...products.map((p) => p.category ?? 'Other')}];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = cats[i];
          final selected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                ),
                boxShadow: selected
                    ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridView(List<dynamic> filtered) {
    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(PhosphorIconsRegular.package, size: 64, color: AppTheme.textMuted.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('No products found', style: TextStyle(color: Color(0xFF64748B), fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Tap + to add a product', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        ]),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final product = filtered[i];
        return _ProductCard(
          product: product,
          onEdit: () => _showAddSheet(context, existing: product),
          onDelete: () => _showDeleteDialog(context, product.id, product.name),
          onIncrease: () => ref.read(productNotifierProvider.notifier).updateQuantity(product.id, 1),
          onDecrease: () => ref.read(productNotifierProvider.notifier).updateQuantity(product.id, -1),
        );
      },
    );
  }

  void _showAddSheet(BuildContext context, {dynamic existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickAddProductSheet(existing: existing),
    );
  }

  void _showDeleteDialog(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Product'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(productNotifierProvider.notifier).deleteProduct(id);
              Navigator.pop(context);
              AppFeedback.showSuccess(context, 'Deleted', 'Product "$name" has been deleted.');
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  void _showRowExportSheet(BuildContext context, dynamic product, AuthState auth) {
    const bg = Colors.white;
    const textPrimary = Color(0xFF0F172A);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Export Product Card', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
            const SizedBox(height: 4),
            Text(
              product.name,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.errorColor, size: 22),
              ),
              title: const Text('Export as PDF Spec Sheet', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
              subtitle: const Text('Share a PDF spec sheet of this product', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              onTap: () {
                Navigator.pop(context);
                _exportRowPdf(product, auth, _fmt);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image_rounded, color: AppTheme.primaryColor, size: 22),
              ),
              title: const Text('Export as Image Card', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
              subtitle: const Text('Share a PNG card of this product', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              onTap: () {
                Navigator.pop(context);
                _exportRowImage(product, auth, _fmt);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportRowPdf(
    dynamic product,
    AuthState auth,
    NumberFormat fmt,
  ) async {
    final pdf = pw.Document(theme: await PdfTheme.load());

    pw.Widget hCell(String t, {pw.Alignment alignment = pw.Alignment.centerLeft}) => pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
    );
    pw.Widget dCell(String t, {bool bold = false, pw.Alignment alignment = pw.Alignment.centerLeft}) => pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(auth.shopName.isEmpty || auth.shopName.toLowerCase() == 'admin' ? 'M Lin Tex' : auth.shopName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text('Product Spec Sheet', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),   // Product Name
              1: const pw.FlexColumnWidth(1.5), // Category
              2: const pw.FlexColumnWidth(1.5), // Price
              3: const pw.FlexColumnWidth(1.2), // Quantity in Stock
              4: const pw.FlexColumnWidth(1.8), // Stock asset value
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  hCell('Product Name'),
                  hCell('Category'),
                  hCell('Unit Price (₦)', alignment: pw.Alignment.centerRight),
                  hCell('Qty in Stock', alignment: pw.Alignment.center),
                  hCell('Asset Value', alignment: pw.Alignment.centerRight),
                ],
              ),
              pw.TableRow(
                children: [
                  dCell(product.name, bold: true),
                  dCell(product.category ?? 'Other'),
                  dCell('${PdfTheme.naira}${fmt.format(product.price)}', alignment: pw.Alignment.centerRight),
                  dCell('${product.quantity}', alignment: pw.Alignment.center),
                  dCell('${PdfTheme.naira}${fmt.format(product.price * product.quantity)}', bold: true, alignment: pw.Alignment.centerRight),
                ],
              ),
            ],
          ),
        ],
      ),
    ));

    final rowPdfBytes = await pdf.save();
    if (!mounted) return;
    await FileSaver.savePdf(context, 'product_spec_${product.id.substring(0, 6)}.pdf', rowPdfBytes);
  }

  Future<void> _exportRowImage(
    dynamic product,
    AuthState auth,
    NumberFormat fmt,
  ) async {
    const bg = Color(0xFFF8FAFC);
    const textColor = Color(0xFF0F172A);
    const mutedColor = Color(0xFF64748B);
    const borderColor = Color(0xFFE2E8F0);
    final style = ProductStyleUtil.getStyle(product.category, product.name);
    final accentColor = style.colors.first;

    final receiptKey = GlobalKey();
    final overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: -9999,
        child: RepaintBoundary(
          key: receiptKey,
          child: Material(
            color: bg,
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(18),
              color: bg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(auth.shopName.isEmpty || auth.shopName.toLowerCase() == 'admin' ? 'M Lin Tex' : auth.shopName,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: accentColor)),
                        const SizedBox(height: 4),
                        const Text('PRODUCT CATALOG CARD',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5)),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: borderColor),
                        const SizedBox(height: 12),
                        Row(children: [
                          Icon(Icons.inventory_2_rounded, size: 14, color: mutedColor),
                          const SizedBox(width: 6),
                          const Text('Store Fabric Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: accentColor, width: 5),
                          ),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.storefront_rounded,
                                color: accentColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Category: ${product.category ?? "Other"}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF1D4ED8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₦${fmt.format(product.price)} × ${product.quantity}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF475569),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '₦${fmt.format(product.price * product.quantity)}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlay);
    await Future.delayed(const Duration(milliseconds: 150));

    try {
      final boundary = receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/product_spec_${product.id.substring(0, 6)}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      if (!mounted) return;
      await FileSaver.saveImage(context, file);
    } finally {
      overlay.remove();
    }
  }

  Future<void> _exportPdf(List<dynamic> products, NumberFormat fmt) async {
    final pdf = pw.Document(theme: await PdfTheme.load());
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => [
        pw.Text('Store Products Catalog', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: ['S/N', 'Product Name', 'Category', 'Price', 'Qty', 'Stock Value']
                  .map((h) => pw.Padding(padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))))
                  .toList(),
            ),
            ...products.asMap().entries.map((e) => pw.TableRow(children: [
              _cCell('${e.key + 1}'), _cCell(e.value.name),
              _cCell(e.value.category ?? 'Other'),
              _cCell('${PdfTheme.naira}${fmt.format(e.value.price)}'), _cCell('${e.value.quantity}'),
              _cCell('${PdfTheme.naira}${fmt.format(e.value.price * e.value.quantity)}'),
            ])),
          ],
        ),
      ],
    ));

    final pdfBytes = await pdf.save();
    if (!mounted) return;
    await FileSaver.savePdf(context, 'products_catalog.pdf', pdfBytes);
  }

  pw.Widget _cCell(String t) => pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(t, style: const pw.TextStyle(fontSize: 7)));

  Future<void> _exportImage() async {
    final overlayState = Overlay.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final products = await ref.read(productsProvider.future);
    if (!mounted) return;

    final fmt = NumberFormat('#,##0', 'en_US');
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final headerBg = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final captureKey = GlobalKey();
    final overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: -9999,
        child: RepaintBoundary(
          key: captureKey,
          child: Material(
            color: bg,
            child: Container(
              color: bg,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Store Catalog', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.successColor)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Table(
                        defaultColumnWidth: const IntrinsicColumnWidth(),
                        border: TableBorder(
                          horizontalInside: BorderSide(color: borderColor, width: 0.5),
                          verticalInside: BorderSide(color: borderColor, width: 0.5),
                        ),
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: headerBg),
                            children: ['S/N', 'Product Name', 'Category', 'Price', 'Qty', 'Stock Value']
                                .map((h) => Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      child: Text(h, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textColor)),
                                    ))
                                .toList(),
                          ),
                          ...products.asMap().entries.map((e) {
                            final i = e.key;
                            final entry = e.value;
                            final rowBg = i.isEven ? bg : (isDark ? const Color(0xFF1A2535) : const Color(0xFFF8FAFC));
                            return TableRow(
                              decoration: BoxDecoration(color: rowBg),
                              children: [
                                _tCell('${i + 1}', mutedColor),
                                _tCell(entry.name, textColor, bold: true),
                                _tCell(entry.category ?? 'Other', AppTheme.primaryColor),
                                _tCell('\u20a6${fmt.format(entry.price)}', textColor),
                                _tCell('${entry.quantity}', textColor),
                                _tCell('\u20a6${fmt.format(entry.price * entry.quantity)}', AppTheme.successColor, bold: true),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlayState.insert(overlay);
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      final boundary = captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/products_catalog.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      if (!mounted) return;
      await FileSaver.saveImage(context, file);
    } catch (e) {
      debugPrint('Image export error: $e');
    } finally {
      overlay.remove();
    }
  }

  Widget _tCell(String text, Color color, {bool bold = false, double size = 10}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    child: Text(text, style: TextStyle(fontSize: size, color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
  );
}

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
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 1))] : [],
        ),
        child: Icon(
          icon,
          size: 16,
          color: active ? AppTheme.primaryColor : const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String shopName;
  final Color cardBg;
  final Color borderColor;
  final Color textPrimary;
  final Color textMuted;

  const _HeaderCard({
    required this.shopName,
    required this.cardBg,
    required this.borderColor,
    required this.textPrimary,
    required this.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    final displayShop = (shopName.isEmpty || shopName.toLowerCase() == 'admin')
        ? 'M Lin Tex'
        : shopName;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            displayShop,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Store Inventory Catalog',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            'Global list of fabric stock, yards, and catalogs',
            style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _FinancialSummaryCard extends StatelessWidget {
  final double totalValue;
  final int totalCount;
  final int lowStockCount;
  final NumberFormat fmt;

  const _FinancialSummaryCard({
    required this.totalValue,
    required this.totalCount,
    required this.lowStockCount,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildItem(String title, String value, Color color, Color bgColor, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.15), width: 1),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 11, color: color),
                  const SizedBox(width: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: color.withOpacity(0.8),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          buildItem('ASSET VALUE', '₦${fmt.format(totalValue)}', const Color(0xFF0F766E), const Color(0xFFF0FDFA), Icons.account_balance_wallet_rounded),
          const SizedBox(width: 8),
          buildItem('FABRIC LINES', '$totalCount', const Color(0xFF4F46E5), const Color(0xFFEEF2FF), Icons.category_rounded),
          const SizedBox(width: 8),
          buildItem('LOW STOCK', '$lowStockCount', const Color(0xFFEF4444), const Color(0xFFFEF2F2), Icons.warning_rounded),
        ],
      ),
    );
  }
}

class _QuickActionButtons extends StatelessWidget {
  final VoidCallback onRecordProduct;

  const _QuickActionButtons({
    required this.onRecordProduct,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: onRecordProduct,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF0D9488).withOpacity(0.2)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 18, color: Color(0xFF0D9488)),
              SizedBox(width: 8),
              Text(
                'Record New Product (IN)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D9488),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductsLedgerFeed extends StatelessWidget {
  final List<dynamic> entries;
  final NumberFormat fmt;
  final Color cardBg;
  final Color borderColor;
  final Color textPrimary;
  final Color textMuted;
  final void Function(dynamic) onEdit;
  final void Function(dynamic) onDelete;
  final void Function(dynamic) onExport;

  const _ProductsLedgerFeed({
    required this.entries,
    required this.fmt,
    required this.cardBg,
    required this.borderColor,
    required this.textPrimary,
    required this.textMuted,
    required this.onEdit,
    required this.onDelete,
    required this.onExport,
  });

  Widget _buildHeaderCell(
    String text, {
    required double width,
    Alignment alignment = Alignment.centerLeft,
    bool showRightDivider = true,
  }) {
    return Container(
      width: width,
      height: 38,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: showRightDivider
            ? const Border(right: BorderSide(color: Colors.white24, width: 0.8))
            : null,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
        textAlign: alignment == Alignment.centerRight
            ? TextAlign.right
            : (alignment == Alignment.center ? TextAlign.center : TextAlign.left),
      ),
    );
  }

  Widget _buildCell(
    String text, {
    required double width,
    bool bold = false,
    Color? textColor,
    Alignment alignment = Alignment.centerLeft,
    bool showRightDivider = true,
    double fontSize = 11,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
  }) {
    return Container(
      width: width,
      height: 48,
      alignment: alignment,
      padding: padding,
      decoration: BoxDecoration(
        border: showRightDivider
            ? const Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 0.8))
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: textColor ?? const Color(0xFF0F172A),
        ),
        textAlign: alignment == Alignment.centerRight
            ? TextAlign.right
            : (alignment == Alignment.center ? TextAlign.center : TextAlign.left),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _showRowActionMenu(BuildContext context, dynamic entry) {
    final style = ProductStyleUtil.getStyle(entry.category, entry.name);
    final accentColor = style.colors.first;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          // Re-watch the products stream to react to quantity updates in real-time!
          final productsList = ref.watch(productsProvider).value ?? [];
          final currentEntry = productsList.where((p) => p.id == entry.id).firstOrNull ?? entry;
          final isLowStock = currentEntry.quantity < 5;

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Spec Header inside bottom sheet
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: style.colors),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          currentEntry.name.isNotEmpty ? currentEntry.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentEntry.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Category: ${currentEntry.category ?? "Other"}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₦${fmt.format(currentEntry.price * currentEntry.quantity)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₦${fmt.format(currentEntry.price)} / unit',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // STOCK QUANTITY ADJUSTER
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Adjust Stock Level',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                      Row(
                        children: [
                          _RowSheetQtyBtn(
                            icon: PhosphorIconsRegular.minus,
                            onTap: () {
                              ref.read(productNotifierProvider.notifier).updateQuantity(currentEntry.id, -1);
                            },
                            color: accentColor,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isLowStock ? AppTheme.errorColor.withOpacity(0.12) : accentColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${currentEntry.quantity}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: isLowStock ? AppTheme.errorColor : accentColor,
                              ),
                            ),
                          ),
                          _RowSheetQtyBtn(
                            icon: PhosphorIconsRegular.plus,
                            onTap: () {
                              ref.read(productNotifierProvider.notifier).updateQuantity(currentEntry.id, 1);
                            },
                            color: accentColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ACTIONS
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_outlined, color: Color(0xFF3B82F6), size: 20),
                  ),
                  title: const Text('Edit Product Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text('Modify name, category, or unit price', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  onTap: () {
                    Navigator.pop(ctx);
                    onEdit(currentEntry);
                  },
                ),
                const SizedBox(height: 4),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.ios_share_rounded, color: Color(0xFF10B981), size: 20),
                  ),
                  title: const Text('Share Spec Card', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text('Generate a beautiful spec PDF or Image', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  onTap: () {
                    Navigator.pop(ctx);
                    onExport(currentEntry);
                  },
                ),
                const SizedBox(height: 4),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                  ),
                  title: const Text('Delete Product', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFFEF4444))),
                  subtitle: const Text('Permanently remove this fabric from inventory', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete(currentEntry);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalRollsCount = 0;
    double totalValuationSum = 0;
    for (final entry in entries) {
      totalRollsCount += entry.quantity as int;
      totalValuationSum += (entry.price * entry.quantity) as double;
    }

    const double productWidth = 130;
    const double categoryWidth = 90;
    const double priceWidth = 85;
    const double qtyWidth = 50;
    const double totalValueWidth = 95;
    const double totalTableWidth = productWidth + categoryWidth + priceWidth + qtyWidth + totalValueWidth; // 450

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: totalTableWidth + 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                        border: Border(
                          left: BorderSide(color: Color(0xFF0F172A), width: 4),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildHeaderCell('Product Name', width: productWidth),
                          _buildHeaderCell('Category', width: categoryWidth),
                          _buildHeaderCell('Price (₦)', width: priceWidth, alignment: Alignment.centerRight),
                          _buildHeaderCell('Qty', width: qtyWidth, alignment: Alignment.center),
                          _buildHeaderCell('Stock Value (₦)', width: totalValueWidth, alignment: Alignment.centerRight, showRightDivider: false),
                        ],
                      ),
                    ),
                    if (entries.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.grid_off_rounded, size: 40, color: textMuted.withOpacity(0.4)),
                            const SizedBox(height: 8),
                            Text(
                              'No products cataloged',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(entries.length, (index) {
                          final entry = entries[index];
                          final style = ProductStyleUtil.getStyle(entry.category, entry.name);
                          final accentColor = style.colors.first;
                          final rowBgColor = index.isEven ? Colors.white : const Color(0xFFFAFAFA);
                          
                          final isLowStock = entry.quantity < 5;
                          final priceStr = fmt.format(entry.price);
                          final qtyStr = entry.quantity.toString();
                          final totalValStr = '₦${fmt.format(entry.price * entry.quantity)}';

                          return Material(
                            color: rowBgColor,
                            child: InkWell(
                              onTap: () => _showRowActionMenu(context, entry),
                              child: Container(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    left: BorderSide(color: Colors.transparent, width: 4), // Category color indicator
                                    bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Custom border cell manually to draw category colored border on the left
                                    Container(
                                      width: productWidth,
                                      height: 48,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                      decoration: BoxDecoration(
                                        border: const Border(
                                          left: BorderSide(color: Colors.transparent, width: 4),
                                          right: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                                        ),
                                        gradient: LinearGradient(
                                          colors: [accentColor, accentColor.withOpacity(0.1)],
                                          stops: const [0.03, 0.03],
                                        ),
                                      ),
                                      child: Text(
                                        entry.name,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    _buildCell(entry.category ?? 'Other', width: categoryWidth, textColor: accentColor),
                                    _buildCell(priceStr, width: priceWidth, alignment: Alignment.centerRight),
                                    _buildCell(
                                      qtyStr,
                                      width: qtyWidth,
                                      alignment: Alignment.center,
                                      bold: true,
                                      textColor: isLowStock ? AppTheme.errorColor : const Color(0xFF0F172A),
                                    ),
                                    _buildCell(
                                      totalValStr,
                                      width: totalValueWidth,
                                      bold: true,
                                      alignment: Alignment.centerRight,
                                      textColor: const Color(0xFF0F766E),
                                      showRightDivider: false,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        border: Border(
                          left: BorderSide(color: Color(0xFF475569), width: 4),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildCell('Totals', width: productWidth, bold: true, textColor: const Color(0xFF475569)),
                          _buildCell('', width: categoryWidth),
                          _buildCell('—', width: priceWidth, alignment: Alignment.centerRight, textColor: const Color(0xFF94A3B8)),
                          _buildCell('$totalRollsCount', width: qtyWidth, bold: true, alignment: Alignment.center, textColor: const Color(0xFF0F172A)),
                          _buildCell(
                            '₦${fmt.format(totalValuationSum)}',
                            width: totalValueWidth,
                            bold: true,
                            alignment: Alignment.centerRight,
                            textColor: const Color(0xFF0F766E),
                            showRightDivider: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 12, color: Color(0xFF94A3B8)),
              SizedBox(width: 4),
              Text(
                '💡 Tip: Tap any row to Edit, Delete or share Product details.',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RowSheetQtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _RowSheetQtyBtn({required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final dynamic product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  Widget build(BuildContext context) {
    final style = ProductStyleUtil.getStyle(product.category, product.name);
    final isLowStock = product.quantity < 5;
    final fmt = NumberFormat('#,##0', 'en_US');
    final accentColor = style.colors.first;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Gradient Banner Section
          Container(
            height: 72,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: style.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Stylized decorative background icon
                Positioned(
                  right: -10,
                  bottom: -10,
                  child: Opacity(
                    opacity: 0.15,
                    child: Icon(
                      style.icon,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Floating category glass tag
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.5),
                    ),
                    child: Text(
                      (product.category ?? 'Fabric').toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                // Category Icon circle in center
                Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      style.icon,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                // Edit/Delete dropdown options menu button
                Positioned(
                  top: 4,
                  right: 4,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      cardColor: Colors.white,
                    ),
                    child: PopupMenuButton<String>(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(PhosphorIconsRegular.dotsThreeVertical, color: Colors.white, size: 16),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      onSelected: (val) {
                        if (val == 'edit') onEdit();
                        if (val == 'delete') onDelete();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(PhosphorIconsRegular.pencilSimple, size: 16, color: Color(0xFF475569)),
                              SizedBox(width: 8),
                              Text('Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(PhosphorIconsRegular.trash, size: 16, color: AppTheme.errorColor),
                              const SizedBox(width: 8),
                              const Text('Delete', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.errorColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Low stock indicator tag
                if (isLowStock)
                  Positioned(
                    bottom: 8,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.errorColor.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ],
                      ),
                      child: const Text(
                        'LOW STOCK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Details & Interactive Adjuster Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            color: Color(0xFF0F172A),
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₦${fmt.format(product.price)} / yd',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _QtyBtn(
                        icon: PhosphorIconsRegular.minus,
                        onTap: onDecrease,
                        color: accentColor,
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: isLowStock 
                              ? AppTheme.errorColor.withOpacity(0.08) 
                              : accentColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isLowStock 
                                ? AppTheme.errorColor.withOpacity(0.15) 
                                : accentColor.withOpacity(0.15),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${product.quantity} yds',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11.5,
                                color: isLowStock ? AppTheme.errorColor : accentColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _QtyBtn(
                        icon: PhosphorIconsRegular.plus,
                        onTap: onIncrease,
                        color: accentColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _QtyBtn({required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(icon, size: 13, color: color),
          ),
        ),
      ),
    );
  }
}

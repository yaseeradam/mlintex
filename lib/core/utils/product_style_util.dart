import 'package:flutter/material.dart';

class ProductStyleUtil {
  static final Map<String, ProductStyleData> _categoryStyles = {
    'fabric': ProductStyleData(
      colors: [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
      icon: Icons.content_cut_rounded,
    ),
    'fabrics': ProductStyleData(
      colors: [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
      icon: Icons.content_cut_rounded,
    ),
    'lace': ProductStyleData(
      colors: [const Color(0xFFF472B6), const Color(0xFFDB2777)],
      icon: Icons.star_rounded,
    ),
    'ankara': ProductStyleData(
      colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      icon: Icons.palette_rounded,
    ),
    'brocade': ProductStyleData(
      colors: [const Color(0xFF0F766E), const Color(0xFF0D9488)],
      icon: Icons.auto_awesome_rounded,
    ),
    'atiku': ProductStyleData(
      colors: [const Color(0xFF0F172A), const Color(0xFF1E293B)],
      icon: Icons.workspace_premium_rounded,
    ),
    'cotton': ProductStyleData(
      colors: [const Color(0xFF34D399), const Color(0xFF059669)],
      icon: Icons.eco_rounded,
    ),
    'silk': ProductStyleData(
      colors: [const Color(0xFFA78BFA), const Color(0xFF7C3AED)],
      icon: Icons.auto_awesome_rounded,
    ),
    'wool': ProductStyleData(
      colors: [const Color(0xFFFB923C), const Color(0xFFEA580C)],
      icon: Icons.loop_rounded,
    ),
    'cashmere': ProductStyleData(
      colors: [const Color(0xFF818CF8), const Color(0xFF4338CA)],
      icon: Icons.workspace_premium_rounded,
    ),
    'velvet': ProductStyleData(
      colors: [const Color(0xFF9333EA), const Color(0xFF7E22CE)],
      icon: Icons.diamond_rounded,
    ),
    'chiffon': ProductStyleData(
      colors: [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
      icon: Icons.air_rounded,
    ),
    'denim': ProductStyleData(
      colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
      icon: Icons.straighten_rounded,
    ),
    'polyester': ProductStyleData(
      colors: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
      icon: Icons.checkroom_rounded,
    ),
    'linen': ProductStyleData(
      colors: [const Color(0xFFFBBF24), const Color(0xFFF59E0B)],
      icon: Icons.checkroom_rounded,
    ),
    'clothing': ProductStyleData(
      colors: [const Color(0xFFF472B6), const Color(0xFFDB2777)],
      icon: Icons.checkroom_rounded,
    ),
    'clothes': ProductStyleData(
      colors: [const Color(0xFFF472B6), const Color(0xFFDB2777)],
      icon: Icons.checkroom_rounded,
    ),
    'roman': ProductStyleData(
      colors: [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
      icon: Icons.content_cut_rounded,
    ),
    'senator': ProductStyleData(
      colors: [const Color(0xFF0F172A), const Color(0xFF1E293B)],
      icon: Icons.workspace_premium_rounded,
    ),
    'native': ProductStyleData(
      colors: [const Color(0xFF16A34A), const Color(0xFF15803D)],
      icon: Icons.star_rounded,
    ),
    'accessories': ProductStyleData(
      colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      icon: Icons.shopping_bag_rounded,
    ),
    'thread': ProductStyleData(
      colors: [const Color(0xFFEC4899), const Color(0xFFBE185D)],
      icon: Icons.loop_rounded,
    ),
    'button': ProductStyleData(
      colors: [const Color(0xFF64748B), const Color(0xFF475569)],
      icon: Icons.circle_rounded,
    ),
    'zip': ProductStyleData(
      colors: [const Color(0xFF64748B), const Color(0xFF475569)],
      icon: Icons.unfold_more_rounded,
    ),
    'zipper': ProductStyleData(
      colors: [const Color(0xFF64748B), const Color(0xFF475569)],
      icon: Icons.unfold_more_rounded,
    ),
  };

  static final List<ProductStyleData> _fallbacks = [
    ProductStyleData(colors: [const Color(0xFF6366F1), const Color(0xFF4F46E5)], icon: Icons.content_cut_rounded),
    ProductStyleData(colors: [const Color(0xFFF472B6), const Color(0xFFDB2777)], icon: Icons.checkroom_rounded),
    ProductStyleData(colors: [const Color(0xFF34D399), const Color(0xFF059669)], icon: Icons.eco_rounded),
    ProductStyleData(colors: [const Color(0xFFFBBF24), const Color(0xFFD97706)], icon: Icons.palette_rounded),
    ProductStyleData(colors: [const Color(0xFFA78BFA), const Color(0xFF7C3AED)], icon: Icons.auto_awesome_rounded),
    ProductStyleData(colors: [const Color(0xFF38BDF8), const Color(0xFF0284C7)], icon: Icons.air_rounded),
  ];

  static ProductStyleData getStyle(String? category, String name) {
    // Check category first
    if (category != null && category.trim().isNotEmpty) {
      final key = category.trim().toLowerCase();
      for (final k in _categoryStyles.keys) {
        if (key.contains(k) || k.contains(key)) {
          return _categoryStyles[k]!;
        }
      }
    }

    // Check product name keywords
    final nameLower = name.toLowerCase();
    for (final k in _categoryStyles.keys) {
      if (nameLower.contains(k)) {
        return _categoryStyles[k]!;
      }
    }

    // Fallback based on name hash
    final seed = name.toLowerCase().codeUnits.fold<int>(0, (p, c) => p + c);
    return _fallbacks[seed % _fallbacks.length];
  }
}

class ProductStyleData {
  final List<Color> colors;
  final IconData icon;

  ProductStyleData({required this.colors, required this.icon});
}

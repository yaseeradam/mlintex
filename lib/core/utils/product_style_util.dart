import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProductStyleUtil {
  static final Map<String, ProductStyleData> _categoryStyles = {
    'fabric': ProductStyleData(
      colors: [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
      icon: PhosphorIconsFill.scissors,
    ),
    'fabrics': ProductStyleData(
      colors: [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
      icon: PhosphorIconsFill.scissors,
    ),
    'lace': ProductStyleData(
      colors: [const Color(0xFFF472B6), const Color(0xFFDB2777)],
      icon: PhosphorIconsFill.star,
    ),
    'ankara': ProductStyleData(
      colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      icon: PhosphorIconsFill.palette,
    ),
    'brocade': ProductStyleData(
      colors: [const Color(0xFF0F766E), const Color(0xFF0D9488)],
      icon: PhosphorIconsFill.starFour,
    ),
    'atiku': ProductStyleData(
      colors: [const Color(0xFF0F172A), const Color(0xFF1E293B)],
      icon: PhosphorIconsFill.crown,
    ),
    'cotton': ProductStyleData(
      colors: [const Color(0xFF34D399), const Color(0xFF059669)],
      icon: PhosphorIconsFill.leaf,
    ),
    'silk': ProductStyleData(
      colors: [const Color(0xFFA78BFA), const Color(0xFF7C3AED)],
      icon: PhosphorIconsFill.sparkle,
    ),
    'wool': ProductStyleData(
      colors: [const Color(0xFFFB923C), const Color(0xFFEA580C)],
      icon: PhosphorIconsFill.spiral,
    ),
    'cashmere': ProductStyleData(
      colors: [const Color(0xFF818CF8), const Color(0xFF4338CA)],
      icon: PhosphorIconsFill.crown,
    ),
    'velvet': ProductStyleData(
      colors: [const Color(0xFF9333EA), const Color(0xFF7E22CE)],
      icon: PhosphorIconsFill.diamond,
    ),
    'chiffon': ProductStyleData(
      colors: [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
      icon: PhosphorIconsFill.wind,
    ),
    'denim': ProductStyleData(
      colors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
      icon: PhosphorIconsFill.pants,
    ),
    'polyester': ProductStyleData(
      colors: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
      icon: PhosphorIconsFill.tShirt,
    ),
    'linen': ProductStyleData(
      colors: [const Color(0xFFFBBF24), const Color(0xFFF59E0B)],
      icon: PhosphorIconsFill.tShirt,
    ),
    'clothing': ProductStyleData(
      colors: [const Color(0xFFF472B6), const Color(0xFFDB2777)],
      icon: PhosphorIconsFill.tShirt,
    ),
    'clothes': ProductStyleData(
      colors: [const Color(0xFFF472B6), const Color(0xFFDB2777)],
      icon: PhosphorIconsFill.tShirt,
    ),
    'roman': ProductStyleData(
      colors: [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
      icon: PhosphorIconsFill.scissors,
    ),
    'senator': ProductStyleData(
      colors: [const Color(0xFF0F172A), const Color(0xFF1E293B)],
      icon: PhosphorIconsFill.crown,
    ),
    'native': ProductStyleData(
      colors: [const Color(0xFF16A34A), const Color(0xFF15803D)],
      icon: PhosphorIconsFill.star,
    ),
    'accessories': ProductStyleData(
      colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      icon: PhosphorIconsFill.handbag,
    ),
    'thread': ProductStyleData(
      colors: [const Color(0xFFEC4899), const Color(0xFFBE185D)],
      icon: PhosphorIconsFill.spiral,
    ),
    'button': ProductStyleData(
      colors: [const Color(0xFF64748B), const Color(0xFF475569)],
      icon: PhosphorIconsFill.circle,
    ),
    'zip': ProductStyleData(
      colors: [const Color(0xFF64748B), const Color(0xFF475569)],
      icon: PhosphorIconsFill.arrowsVertical,
    ),
    'zipper': ProductStyleData(
      colors: [const Color(0xFF64748B), const Color(0xFF475569)],
      icon: PhosphorIconsFill.arrowsVertical,
    ),
  };

  static final List<ProductStyleData> _fallbacks = [
    ProductStyleData(colors: [const Color(0xFF6366F1), const Color(0xFF4F46E5)], icon: PhosphorIconsFill.scissors),
    ProductStyleData(colors: [const Color(0xFFF472B6), const Color(0xFFDB2777)], icon: PhosphorIconsFill.tShirt),
    ProductStyleData(colors: [const Color(0xFF34D399), const Color(0xFF059669)], icon: PhosphorIconsFill.leaf),
    ProductStyleData(colors: [const Color(0xFFFBBF24), const Color(0xFFD97706)], icon: PhosphorIconsFill.palette),
    ProductStyleData(colors: [const Color(0xFFA78BFA), const Color(0xFF7C3AED)], icon: PhosphorIconsFill.sparkle),
    ProductStyleData(colors: [const Color(0xFF38BDF8), const Color(0xFF0284C7)], icon: PhosphorIconsFill.wind),
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

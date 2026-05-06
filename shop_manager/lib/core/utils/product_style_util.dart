import 'package:flutter/material.dart';

class ProductStyleUtil {
  static final Map<String, ProductStyleData> _categoryStyles = {
    'drinks': ProductStyleData(
      colors: [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
      icon: Icons.local_drink_rounded,
    ),
    'beverages': ProductStyleData(
      colors: [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
      icon: Icons.local_drink_rounded,
    ),
    'food': ProductStyleData(
      colors: [const Color(0xFFFB923C), const Color(0xFFEA580C)],
      icon: Icons.restaurant_rounded,
    ),
    'bakery': ProductStyleData(
      colors: [const Color(0xFFFB923C), const Color(0xFFEA580C)],
      icon: Icons.bakery_dining_rounded,
    ),
    'grains': ProductStyleData(
      colors: [const Color(0xFFFBBF24), const Color(0xFFD97706)],
      icon: Icons.grain_rounded,
    ),
    'cooking': ProductStyleData(
      colors: [const Color(0xFFF472B6), const Color(0xFFDB2777)],
      icon: Icons.kitchen_rounded,
    ),
    'snacks': ProductStyleData(
      colors: [const Color(0xFFFBBF24), const Color(0xFFD97706)],
      icon: Icons.fastfood_rounded,
    ),
    'dairy': ProductStyleData(
      colors: [const Color(0xFFA78BFA), const Color(0xFF7C3AED)],
      icon: Icons.icecream_rounded,
    ),
    'household': ProductStyleData(
      colors: [const Color(0xFF34D399), const Color(0xFF059669)],
      icon: Icons.cleaning_services_rounded,
    ),
    'personal care': ProductStyleData(
      colors: [const Color(0xFFFB7185), const Color(0xFFE11D48)],
      icon: Icons.face_retouching_natural_rounded,
    ),
    'cosmetics': ProductStyleData(
      colors: [const Color(0xFFFB7185), const Color(0xFFE11D48)],
      icon: Icons.face_retouching_natural_rounded,
    ),
    'electronics': ProductStyleData(
      colors: [const Color(0xFF818CF8), const Color(0xFF4F46E5)],
      icon: Icons.devices_rounded,
    ),
    'clothing': ProductStyleData(
      colors: [const Color(0xFFF472B6), const Color(0xFFDB2777)],
      icon: Icons.checkroom_rounded,
    ),
    'seasoning': ProductStyleData(
      colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      icon: Icons.eco_rounded,
    ),
    'condiments': ProductStyleData(
      colors: [const Color(0xFFF472B6), const Color(0xFFDB2777)],
      icon: Icons.emoji_food_beverage_rounded,
    ),
  };

  static final List<List<Color>> _fallbackGradients = [
    [const Color(0xFF34D399), const Color(0xFF059669)],
    [const Color(0xFFA78BFA), const Color(0xFF7C3AED)],
    [const Color(0xFFF87171), const Color(0xFFDC2626)],
    [const Color(0xFF60A5FA), const Color(0xFF2563EB)],
    [const Color(0xFFFBBF24), const Color(0xFFD97706)],
    [const Color(0xFF38BDF8), const Color(0xFF0284C7)],
  ];

  static ProductStyleData getStyle(String? category, String name) {
    if (category != null && category.trim().isNotEmpty) {
      final key = category.trim().toLowerCase();
      for (final k in _categoryStyles.keys) {
        if (key.contains(k)) {
          return _categoryStyles[k]!;
        }
      }
    }

    final seed = name.toLowerCase().codeUnits.fold<int>(0, (p, c) => p + c);
    final gradient = _fallbackGradients[seed % _fallbackGradients.length];

    return ProductStyleData(
      colors: gradient,
      icon: Icons.inventory_2_rounded,
    );
  }
}

class ProductStyleData {
  final List<Color> colors;
  final IconData icon;

  ProductStyleData({required this.colors, required this.icon});
}

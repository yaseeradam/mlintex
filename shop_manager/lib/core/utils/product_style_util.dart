import 'package:flutter/material.dart';

class ProductStyleUtil {
  static final Map<String, _StyleData> _categoryStyles = {
    'drinks': _StyleData(
      colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
      icon: Icons.local_drink_rounded,
    ),
    'beverages': _StyleData(
      colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
      icon: Icons.local_drink_rounded,
    ),
    'food': _StyleData(
      colors: [Color(0xFFFB923C), Color(0xFFEA580C)],
      icon: Icons.restaurant_rounded,
    ),
    'snacks': _StyleData(
      colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
      icon: Icons.fastfood_rounded,
    ),
    'electronics': _StyleData(
      colors: [Color(0xFF818CF8), Color(0xFF4F46E5)],
      icon: Icons.devices_rounded,
    ),
    'clothing': _StyleData(
      colors: [Color(0xFFF472B6), Color(0xFFDB2777)],
      icon: Icons.checkroom_rounded,
    ),
    'cosmetics': _StyleData(
      colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
      icon: Icons.face_retouching_natural_rounded,
    ),
  };

  static final List<List<Color>> _fallbackGradients = [
    [Color(0xFF34D399), Color(0xFF059669)],
    [Color(0xFFA78BFA), Color(0xFF7C3AED)],
    [Color(0xFFF87171), Color(0xFFDC2626)],
    [Color(0xFF60A5FA), Color(0xFF2563EB)],
    [Color(0xFFFBBF24), Color(0xFFD97706)],
  ];

  static _StyleData getStyle(String? category, String name) {
    if (category != null && category.trim().isNotEmpty) {
      final key = category.trim().toLowerCase();
      // Try partial match if exact match fails
      for (final k in _categoryStyles.keys) {
        if (key.contains(k)) {
          return _categoryStyles[k]!;
        }
      }
    }

    // Fallback: seed gradient from product name
    final seed = name.toLowerCase().codeUnits.fold<int>(0, (p, c) => p + c);
    final gradient = _fallbackGradients[seed % _fallbackGradients.length];
    
    return _StyleData(
      colors: gradient,
      icon: Icons.inventory_2_rounded,
    );
  }
}

class _StyleData {
  final List<Color> colors;
  final IconData icon;

  _StyleData({required this.colors, required this.icon});
}

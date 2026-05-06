import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeNotifier extends Notifier<ThemeMode> {
  static const _boxName = 'settings';
  static const _keyTheme = 'theme_mode';

  @override
  ThemeMode build() {
    final box = Hive.box(_boxName);
    final modeIndex = box.get(_keyTheme, defaultValue: 0) as int;
    return ThemeMode.values[modeIndex];
  }

  void toggle() {
    final box = Hive.box(_boxName);
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    box.put(_keyTheme, newMode.index);
    state = newMode;
  }

  void setMode(ThemeMode mode) {
    final box = Hive.box(_boxName);
    box.put(_keyTheme, mode.index);
    state = mode;
  }

  bool get isDark => state == ThemeMode.dark;
  bool get isLight => state == ThemeMode.light;
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);

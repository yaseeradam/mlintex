import 'package:flutter_riverpod/flutter_riverpod.dart';

class MockDataSeeder {
  MockDataSeeder();

  /// Production Mode: Mock seeding and data deletion are disabled.
  Future<void> seedIfEmpty() async {
    return;
  }
}

final mockSeederProvider = Provider<MockDataSeeder>((ref) => MockDataSeeder());

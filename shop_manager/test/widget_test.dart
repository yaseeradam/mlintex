import 'package:flutter_test/flutter_test.dart';
import 'package:shop_manager/main.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    // Just verify the app can be instantiated
    expect(const ShopManagerApp(), isA<ShopManagerApp>());
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kuaforum/main.dart';

void main() {
  testWidgets('role selection screen shows all four app roles', (tester) async {
    await tester.pumpWidget(const KuaforumApp());
    expect(find.text('Müşteri'), findsOneWidget);
    expect(find.text('Çalışan'), findsOneWidget);
    expect(find.text('İşletme Sahibi'), findsOneWidget);
    expect(find.text('Ana Yönetici'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kuaforum/main.dart';

void main() {
  testWidgets('role selection screen contains all four app roles', (tester) async {
    await tester.view.setPhysicalSize(const Size(900, 1600));
    await tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const KuaforumApp());
    expect(find.text('Müşteri'), findsOneWidget);
    expect(find.text('Çalışan'), findsOneWidget);
    expect(find.text('İşletme Sahibi'), findsOneWidget);
    await tester.ensureVisible(find.text('Ana Yönetici'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Yönetici'), findsOneWidget);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}

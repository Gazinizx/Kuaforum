import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuaforum/main.dart';

void main() {
  testWidgets('role selection screen contains all four app roles', (tester) async {
    await tester.pumpWidget(const KuaforumApp());
    expect(find.text('Müşteri'), findsOneWidget);
    expect(find.text('Çalışan'), findsOneWidget);
    expect(find.text('İşletme Sahibi'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ana Yönetici'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Ana Yönetici'), findsOneWidget);
  });
}

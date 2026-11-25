import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuaforum/main.dart';

void main() {
  testWidgets('role selection screen contains all four app roles', (tester) async {
    await tester.pumpWidget(const KuaforumApp());
    expect(find.text('Müşteri'), findsOneWidget);
    expect(find.text('Çalışan'), findsOneWidget);
    expect(find.text('İşletme Sahibi'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Ana Yönetici'), 250, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Ana Yönetici'), findsOneWidget);
  });

  testWidgets('role selection requires test account credentials', (tester) async {
    await tester.pumpWidget(const KuaforumApp());
    await tester.tap(find.text('İşletme Sahibi'));
    await tester.pumpAndSettle();
    expect(find.text('Test hesabıyla devam et'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
    expect(find.text('Şifre'), findsOneWidget);
  });

  testWidgets('admin role also requires authenticated test account', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const KuaforumApp());
    await tester.scrollUntilVisible(find.text('Ana Yönetici'), 250, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Ana Yönetici'));
    await tester.pumpAndSettle();
    expect(find.text('Test hesabıyla devam et'), findsOneWidget);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('hero panel action responds to taps', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HeroPanel(
          eyebrow: 'Test',
          title: 'Test action',
          subtitle: 'Action should work',
          icon: Icons.check_circle_outline,
          button: 'Devam',
          onTap: () => tapped = true,
        ),
      ),
    ));

    await tester.tap(find.text('Devam'));
    expect(tapped, isTrue);
  });
}

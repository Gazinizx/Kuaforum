import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuaforum/main.dart';

void main() {
  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('developer role picker shows all four roles without credentials', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: RolePicker()));

    expect(find.text('Müşteri'), findsOneWidget);
    expect(find.text('Çalışan'), findsOneWidget);
    expect(find.text('İşletme Sahibi'), findsOneWidget);
    await tester.ensureVisible(find.text('Ana Yönetici'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Yönetici'), findsOneWidget);
    expect(find.text('E-posta'), findsNothing);
    expect(find.text('Şifre'), findsNothing);
  });

  testWidgets('tapping a role opens its panel immediately', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: RolePicker()));

    await tester.ensureVisible(find.text('İşletme Sahibi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İşletme Sahibi'));
    await tester.pumpAndSettle();

    expect(find.text('İşletme Paneli'), findsOneWidget);
    expect(find.text('Test hesabıyla devam et'), findsNothing);
    expect(find.text('E-posta'), findsNothing);
    expect(find.text('Şifre'), findsNothing);
  });

  testWidgets('role switch menu changes panels with one selection', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: RoleShell(role: AppRole.customer)));

    expect(find.text('Kuaförüm ♡'), findsOneWidget);
    await tester.tap(find.byTooltip('Rol değiştir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Yönetici').last);
    await tester.pumpAndSettle();

    expect(find.text('Yönetim Merkezi'), findsOneWidget);
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

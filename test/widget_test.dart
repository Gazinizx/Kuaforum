import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuaforum/main.dart';

void main() {
  testWidgets('developer test screen lists all four account roles', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: RolePicker()));

    expect(find.text('Müşteri'), findsOneWidget);
    expect(find.text('Çalışan'), findsOneWidget);
    expect(find.text('İşletme Sahibi'), findsOneWidget);
    await tester.ensureVisible(find.text('Ana Yönetici'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Yönetici'), findsOneWidget);
  });

  testWidgets('business role selection asks for a real test account', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: RolePicker()));
    await tester.tap(find.text('İşletme Sahibi'));
    await tester.pumpAndSettle();

    expect(find.text('Test hesabıyla devam et'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
    expect(find.text('Şifre'), findsOneWidget);
  });

  testWidgets('admin role selection also requires a real test account', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: RolePicker()));
    await tester.ensureVisible(find.text('Ana Yönetici'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Yönetici'));
    await tester.pumpAndSettle();

    expect(find.text('Test hesabıyla devam et'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
    expect(find.text('Şifre'), findsOneWidget);
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

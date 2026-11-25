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

  testWidgets('business owner has social feed and publishing tabs', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const KuaforumApp());
    await tester.tap(find.text('İşletme Sahibi'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Keşfet')), findsOneWidget);
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Takip')), findsOneWidget);
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Paylaş')), findsOneWidget);
    expect(find.text('Mesajlar'), findsOneWidget);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('admin navigation has no customer appointment tab', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const KuaforumApp());
    await tester.scrollUntilVisible(find.text('Ana Yönetici'), 250, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Ana Yönetici'));
    await tester.pumpAndSettle();
    expect(find.text('İşletmeler'), findsOneWidget);
    expect(find.text('Kullanıcılar'), findsOneWidget);
    expect(find.text('Keşfet Yönetimi'), findsOneWidget);
    expect(find.text('Randevular'), findsNothing);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}

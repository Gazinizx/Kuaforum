import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kuaforum/main.dart';
import 'package:kuaforum/demo_mode.dart';

void main() {
  setUpAll(() async {
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-publishable-key',
    );
  });

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

    expect(find.text('Yönetim Merkezi'), findsWidgets);
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

  testWidgets('employee demo account has its own posts and can send a message', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DemoWorkspacePage(role: 'employee', section: 'Mesajlar')),
    ));

    expect(find.text('Elif Kaya'), findsOneWidget);
    await tester.tap(find.text('Elif Kaya'));
    await tester.pumpAndSettle();
    final messageField = find.byType(TextField).last;
    await tester.enterText(messageField, 'Test mesajı gönderildi');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Test mesajı gönderildi'), findsOneWidget);
  });

  testWidgets('demo share creates a post without using Supabase', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DemoWorkspacePage(role: 'employee', section: 'Paylaşım')),
    ));

    await tester.tap(find.text('Demo paylaşımı yayınla'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni demo paylaşımı'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Yeni saç tasarımı');
    await tester.tap(find.text('Yayınla'));
    await tester.pumpAndSettle();

    expect(find.text('Yeni saç tasarımı'), findsOneWidget);
  });

  testWidgets('all four demo roles open distinct local identities', (tester) async {
    configureViewport(tester);
    const cases = <(String, String)>[
      ('customer', 'Elif Kaya'),
      ('employee', 'Ayşe Yılmaz'),
      ('owner', 'Derya Akın'),
      ('admin', 'Kuaförüm Yönetim'),
    ];
    for (final item in cases) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: DemoWorkspacePage(role: item.$1, section: 'Profil')),
      ));
      await tester.pumpAndSettle();
      expect(find.text(item.$2), findsOneWidget);
    }
  });

  testWidgets('admin demo includes messages and discover visibility control', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DemoWorkspacePage(role: 'admin', section: 'Keşfet Yönetimi')),
    ));

    expect(find.text('Lale Hair Studio'), findsOneWidget);
    expect(find.text('Keşfet görünürlüğü'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });
}

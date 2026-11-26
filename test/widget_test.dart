import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuaforum/main.dart';
import 'package:kuaforum/demo_mode.dart';

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

  testWidgets('employee demo account can send a message', (tester) async {
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

    // The sent text is intentionally shown in both the latest-message preview
    // and the conversation bubble.
    expect(find.text('Test mesajı gönderildi'), findsNWidgets(2));
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

  testWidgets('demo post comments open and can be added', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DemoWorkspacePage(role: 'customer', section: 'Keşfet')),
    ));

    await tester.tap(find.byIcon(Icons.chat_bubble_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('Yorumlar'), findsOneWidget);
    expect(find.text('Henüz yorum yok. İlk yorumu sen yaz!'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Harika bir çalışma!');
    await tester.tap(find.text('Yorum yap'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chat_bubble_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('Harika bir çalışma!'), findsOneWidget);
  });
  testWidgets('customer demo opens the customer identity', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DemoWorkspacePage(role: 'customer', section: 'Profil')),
    ));
    expect(find.text('Elif Kaya'), findsOneWidget);
  });

  testWidgets('employee demo opens the employee identity', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DemoWorkspacePage(role: 'employee', section: 'Profil')),
    ));
    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
  });

  testWidgets('owner demo opens the owner identity', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DemoWorkspacePage(role: 'owner', section: 'Profil')),
    ));
    expect(find.text('Derya Akın'), findsOneWidget);
  });

  testWidgets('admin demo opens the admin identity', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DemoWorkspacePage(role: 'admin', section: 'Profil')),
    ));
    expect(find.text('Kuaförüm Yönetim'), findsOneWidget);
  });

  testWidgets('admin demo includes discover visibility control', (tester) async {
    configureViewport(tester);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DemoWorkspacePage(role: 'admin', section: 'Keşfet Yönetimi')),
    ));

    expect(find.text('Lale Hair Studio'), findsOneWidget);
    expect(find.text('Keşfet görünürlüğü'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });
}

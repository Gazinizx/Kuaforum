import 'package:flutter_test/flutter_test.dart';
import 'package:kuaforum/main.dart';

void main() {
  testWidgets('normal app launch shows login and registration entry, not role picker', (tester) async {
    await tester.pumpWidget(const KuaforumApp(autoResume: false));

    expect(find.text('Tekrar hoş geldin'), findsOneWidget);
    expect(find.text('Giriş yap'), findsOneWidget);
    expect(find.text('Hesabın yok mu? Kayıt ol'), findsOneWidget);
    expect(find.text('Devam etmek için rolünü seç'), findsNothing);
  });

  testWidgets('login entry can switch to registration form', (tester) async {
    await tester.pumpWidget(const KuaforumApp(autoResume: false));

    await tester.tap(find.text('Hesabın yok mu? Kayıt ol'));
    await tester.pumpAndSettle();

    expect(find.text('Hesabını oluştur'), findsOneWidget);
    expect(find.text('Hesap oluştur'), findsOneWidget);
    expect(find.text('Zaten hesabın var mı? Giriş yap'), findsOneWidget);
    expect(find.text('ADIN'), findsOneWidget);
    expect(find.text('SOYADIN'), findsOneWidget);
    expect(find.text('TELEFON'), findsOneWidget);
    expect(find.text('HESAP TÜRÜ'), findsNothing);
    expect(find.text('İşletme'), findsNothing);
    expect(find.text('Devam etmek için rolünü seç'), findsNothing);
  });
}

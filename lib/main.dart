import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'data/kuaforum_feed_repository.dart';
import 'data/kuaforum_messaging_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://zhvfudtdnvgsqywojjrz.supabase.co',
    publishableKey: 'sb_publishable_TQrHgIVWUTdaxB_-OrGzWA_pAK4cj57',
  );
  runApp(const KuaforumApp());
}

const wine = Color(0xFF8E2947);
const rose = Color(0xFFC65B79);
const blush = Color(0xFFF7DDE3);
const cream = Color(0xFFFFF8F6);
const ink = Color(0xFF39252C);
const muted = Color(0xFF927B82);

class KuaforumApp extends StatelessWidget {
  final bool autoResume;
  const KuaforumApp({super.key, this.autoResume = true});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Kuaförüm',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(seedColor: wine, primary: wine, surface: cream),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(backgroundColor: cream, foregroundColor: ink, elevation: 0, centerTitle: false),
    ),
    home: LoginEntryPage(autoResume: autoResume),
  );
}


class LoginEntryPage extends StatefulWidget {
  final bool autoResume;
  const LoginEntryPage({super.key, this.autoResume = true});
  @override
  State<LoginEntryPage> createState() => _LoginEntryPageState();
}

class _LoginEntryPageState extends State<LoginEntryPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final phone = TextEditingController();
  final inviteCode = TextEditingController();
  bool isRegister = false;
  bool busy = false;
  bool obscurePassword = true;
  String accountType = 'customer';
  String message = '';

  @override
  void initState() {
    super.initState();
    if (!widget.autoResume) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && mounted) _openAccount(user.id);
    });
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
    inviteCode.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final mail = email.text.trim();
    if (isRegister && (firstName.text.trim().isEmpty || lastName.text.trim().isEmpty || phone.text.trim().isEmpty)) {
      setState(() => message = 'Ad, soyad ve telefon bilgilerini doldur.');
      return;
    }
    if (mail.isEmpty || !mail.contains('@')) {
      setState(() => message = 'Geçerli bir e-posta adresi gir.');
      return;
    }
    if (password.text.isEmpty || (isRegister && password.text.length < 8)) {
      setState(() => message = isRegister
          ? 'Şifre en az 8 karakter olmalı.'
          : 'Şifreni gir.');
      return;
    }
    setState(() { busy = true; message = ''; });
    try {
      final auth = Supabase.instance.client.auth;
      if (isRegister) {
        final result = await auth.signUp(
          email: mail,
          password: password.text,
          data: {
            'account_type': 'customer',
            'first_name': firstName.text.trim(),
            'last_name': lastName.text.trim(),
            'full_name': '${firstName.text.trim()} ${lastName.text.trim()}',
            'phone': phone.text.trim(),
          },
        );
        if (result.session == null) {
          if (result.user == null) throw AuthException('Kayıt başlatılamadı.');
          setState(() => message =
              'Hesabın oluşturuldu. E-posta onayı istenirse gelen bağlantıyı açıp giriş yap.');
        } else if (result.user != null) {
          await _openAccount(result.user!.id);
        }
      } else {
        final result = await auth.signInWithPassword(email: mail, password: password.text);
        if (result.user == null) throw AuthException('Giriş yapılamadı.');
        final code = inviteCode.text.trim();
        if (code.isNotEmpty) {
          try {
            await Supabase.instance.client.rpc('claim_employee_invite', params: {'p_code': code});
          } catch (error) {
            await auth.signOut();
            rethrow;
          }
        }
        await _openAccount(result.user!.id);
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => message = error.message);
    } on PostgrestException catch (error) {
      if (mounted) setState(() => message = error.message);
    } catch (error) {
      if (mounted) setState(() => message = 'İşlem tamamlanamadı. Bilgilerini ve bağlantını kontrol et.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resetPassword() async {
    final mail = email.text.trim();
    if (mail.isEmpty || !mail.contains('@')) {
      setState(() => message = 'Şifre sıfırlama bağlantısı için e-posta adresini gir.');
      return;
    }
    setState(() { busy = true; message = ''; });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(mail);
      if (mounted) setState(() => message = 'Şifre sıfırlama bağlantısı e-posta adresine gönderildi.');
    } on AuthException catch (error) {
      if (mounted) setState(() => message = error.message);
    } catch (_) {
      if (mounted) setState(() => message = 'Şifre sıfırlama e-postası gönderilemedi.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openAccount(String userId) async {
    final client = Supabase.instance.client;
    try {
      if (client.auth.currentUser?.id != userId) {
        await client.auth.signOut();
        if (mounted) setState(() => message = 'Oturum doğrulanamadı. Yeniden giriş yap.');
        return;
      }
      final statusRows = await client.rpc('get_my_account_status') as List;
      final profile = statusRows.isEmpty
          ? null
          : Map<String, dynamic>.from(statusRows.first as Map);
      if (!mounted) return;
      if (profile == null) {
        await client.auth.signOut();
        setState(() => message = 'Hesap profili bulunamadı. Destek ekibiyle iletişime geç.');
        return;
      }
      if (profile['is_blocked'] == true) {
        await client.auth.signOut();
        setState(() => message = 'Bu hesabın uygulamaya erişimi kısıtlanmış.');
        return;
      }
      final myAdminPermissions = await client.rpc('get_my_admin_permissions') as List;
      final hasAdminAccess = profile['is_admin'] == true || myAdminPermissions.isNotEmpty;
      if (!mounted) return;
      AppRole role;
      if (hasAdminAccess) {
        role = AppRole.admin;
      } else {
        final employees = await client.from('employees').select('id')
            .eq('user_id', userId).eq('is_active', true).limit(1);
        if (!mounted) return;
        if (profile['account_type'] == 'employee') {
          if (employees.isEmpty) {
            await client.auth.signOut();
            if (mounted) setState(() => message = 'Çalışan hesabın pasif veya işletme bağlantın kaldırılmış. İşletme sahibinle iletişime geç.');
            return;
          }
          role = AppRole.employee;
        } else if (profile['account_type'] == 'business_owner') {
          role = AppRole.owner;
        } else {
          role = AppRole.customer;
        }
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => RoleShell(role: role)),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => message = 'Hesap bilgileri yüklenemedi. Tekrar dene.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(child: Container(
                  width: 82, height: 82,
                  decoration: BoxDecoration(color: blush, borderRadius: BorderRadius.circular(26)),
                  child: const Icon(Icons.content_cut_rounded, size: 45, color: wine),
                )),
                const SizedBox(height: 15),
                const Text('Kuaförüm', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: wine, letterSpacing: -1.2)),
                const Text('Güzelliğin Yeni Adresi ♡', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: muted, fontStyle: FontStyle.italic)),
                const SizedBox(height: 34),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: blush),
                    boxShadow: [BoxShadow(color: wine.withOpacity(.07), blurRadius: 24, offset: const Offset(0, 9))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(isRegister ? 'Hesabını oluştur' : 'Tekrar hoş geldin',
                      style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
                    const SizedBox(height: 6),
                    Text(isRegister ? 'Kuaförüm ailesine katıl.' : 'Devam etmek için hesabına giriş yap.',
                      style: const TextStyle(color: muted, fontSize: 13)),
                    if (isRegister) ...[
                      const SizedBox(height: 20),
                      const Text('ADIN', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      const SizedBox(height: 7),
                      TextField(
                        controller: firstName,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'Adın',
                          prefixIcon: const Icon(Icons.person_outline, color: wine),
                          filled: true, fillColor: cream,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('SOYADIN', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      const SizedBox(height: 7),
                      TextField(
                        controller: lastName,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'Soyadın',
                          prefixIcon: const Icon(Icons.person_outline, color: wine),
                          filled: true, fillColor: cream,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('TELEFON', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      const SizedBox(height: 7),
                      TextField(
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: '05xx xxx xx xx',
                          prefixIcon: const Icon(Icons.phone_outlined, color: wine),
                          filled: true, fillColor: cream,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Text('E-POSTA ADRESİ', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(height: 7),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        hintText: 'ornek@email.com',
                        prefixIcon: const Icon(Icons.mail_outline_rounded, color: wine),
                        filled: true, fillColor: cream,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('ŞİFRE', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(height: 7),
                    TextField(
                      controller: password,
                      obscureText: obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        hintText: 'Şifreni gir',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: wine),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => obscurePassword = !obscurePassword),
                          icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                        filled: true, fillColor: cream,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => busy ? null : submit(),
                    ),
                    if (!isRegister) ...[
                      const SizedBox(height: 14),
                      const Text('ÇALIŞAN DAVET KODU (İSTEĞE BAĞLI)', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .7)),
                      const SizedBox(height: 7),
                      TextField(
                        controller: inviteCode,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'İşletmenin verdiği davet kodu',
                          prefixIcon: const Icon(Icons.badge_outlined, color: wine),
                          filled: true, fillColor: cream,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                    if (isRegister && accountType == 'business_owner')
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text('İşletme hesabı, başvuru ve yönetici onayı sonrasında aktif edilir.',
                          style: TextStyle(color: muted, fontSize: 11)),
                      ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(color: blush.withOpacity(.55), borderRadius: BorderRadius.circular(12)),
                        child: Text(message, style: const TextStyle(color: wine, fontSize: 12, height: 1.4)),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: busy ? null : submit,
                        style: FilledButton.styleFrom(backgroundColor: wine, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        child: busy
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(isRegister ? 'Hesap oluştur' : 'Giriş yap', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!isRegister)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: busy ? null : resetPassword,
                          child: const Text('Şifremi unuttum', style: TextStyle(color: wine)),
                        ),
                      ),
                    TextButton(
                      onPressed: busy ? null : () => setState(() { isRegister = !isRegister; message = ''; }),
                      child: Text(isRegister ? 'Zaten hesabın var mı? Giriş yap' : 'Hesabın yok mu? Kayıt ol',
                        style: const TextStyle(color: wine, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),
                const Text('GÜVENLİ • KOLAY • KİŞİSEL', textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 10, letterSpacing: 1.7, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}


enum AppRole { customer, employee, owner, admin }

class RolePicker extends StatelessWidget {
  const RolePicker({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(22), children: [
      const SizedBox(height: 18),
      Center(child: Container(width: 88, height: 88, decoration: BoxDecoration(color: blush, borderRadius: BorderRadius.circular(28)), child: const Icon(Icons.spa_rounded, size: 52, color: wine))),
      const SizedBox(height: 14),
      const Text('Kuaförüm', textAlign: TextAlign.center, style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: wine, letterSpacing: -1.5)),
      const Text('Güzelliğin Yeni Adresi ♡', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontStyle: FontStyle.italic, color: ink)),
      const SizedBox(height: 34),
      const Text('Devam etmek için rolünü seç', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ink)),
      const SizedBox(height: 14),
      _role(context, AppRole.customer, 'Müşteri', 'Salonları keşfet, stilini bul ve randevunu oluştur.', Icons.favorite_rounded),
      _role(context, AppRole.employee, 'Çalışan', 'Çalışmalarını paylaş, randevularını ve mesajlarını yönet.', Icons.content_cut_rounded),
      _role(context, AppRole.owner, 'İşletme Sahibi', 'Salonunu, ekibini, müşterilerini ve randevularını yönet.', Icons.storefront_rounded),
      _role(context, AppRole.admin, 'Ana Yönetici', 'Platformu, işletmeleri ve keşfet görünürlüğünü yönet.', Icons.admin_panel_settings_rounded),
      const SizedBox(height: 18),
      const Text('Tasarım ön izlemesi • Örnek içerikler kullanılır', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12)),
    ])),
  );
  Future<void> _openRole(BuildContext context, AppRole role) async {
    final email = TextEditingController();
    final password = TextEditingController();
    final credentials = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Test hesabıyla devam et'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-posta')),
          TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Şifre')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Devam et')),
        ],
      ),
    );
    if (credentials != true || !context.mounted) return;
    try {
      final auth = Supabase.instance.client;
      final response = await auth.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );
      final user = response.user;
      if (user == null) throw AuthException('Oturum açılamadı.');
      final statusRows = await auth.rpc('get_my_account_status') as List;
      final profile = statusRows.isEmpty
          ? null
          : Map<String, dynamic>.from(statusRows.first as Map);
      if (profile == null || profile['is_blocked'] == true) {
        await auth.auth.signOut();
        throw AuthException('Bu hesap uygulamaya erişemiyor.');
      }
      var allowed = false;      switch (role) {
        case AppRole.admin:
          allowed = profile['is_admin'] == true;
          break;
        case AppRole.owner:
          allowed = profile['account_type'] == 'business_owner' && profile['is_admin'] != true;
          break;
        case AppRole.employee:
          final employee = await auth.from('employees').select('id')
              .eq('user_id', user.id).eq('is_active', true).limit(1);          allowed = employee.isNotEmpty;
          break;
        case AppRole.customer:
          allowed = profile['account_type'] == 'customer' && profile['is_admin'] != true;
          break;
      }
      if (!allowed) {
        await auth.auth.signOut();
        throw AuthException('Bu hesap seçtiğin role bağlı değil.');
      }
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => RoleShell(role: role)));
    } on AuthException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: wine),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Giriş yapılamadı. Bağlantını ve hesap bilgilerini kontrol et.'), backgroundColor: wine),
        );
      }
    } finally {
      email.dispose();
      password.dispose();
    }
  }
  Widget _role(BuildContext context, AppRole role, String title, String subtitle, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openRole(context, role),
      child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: blush), boxShadow: [BoxShadow(color: wine.withOpacity(.05), blurRadius: 16, offset: const Offset(0, 5))]), child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: blush, borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: wine, size: 25)),
        const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ink)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: muted, fontSize: 12))])),
        const Icon(Icons.chevron_right_rounded, color: wine),
      ])),
    ),
  );
}

class RoleShell extends StatefulWidget {
  final AppRole role;
  const RoleShell({super.key, required this.role});
  @override State<RoleShell> createState() => _RoleShellState();
}
class _RoleShellState extends State<RoleShell> {
  int index = 0;
  late List<String> labels;
  late List<IconData> icons;
  late List<Widget> pages;
  bool adminNavLoading = false;
  String get heading => switch(widget.role) { AppRole.customer => 'Kuaförüm ♡', AppRole.employee => 'Çalışan Paneli', AppRole.owner => 'İşletme Paneli', AppRole.admin => 'Yönetim Merkezi' };
  @override void initState() {
    super.initState();
    switch(widget.role) {
      case AppRole.customer:
        labels = ['Ana Sayfa','Keşfet','Takip','Mesajlar','Profil']; icons = [Icons.home_rounded,Icons.diamond_rounded,Icons.favorite_border,Icons.chat_bubble_outline,Icons.person_outline];
        pages = [const CustomerHome(),const DiscoverPage(),const FollowingPage(),const MessagesPage(),const ProfilePage()];
        break;
      case AppRole.employee:
        labels = ['Ana Sayfa','Randevular','Paylaşım','Mesajlar','Profil']; icons = [Icons.home_rounded,Icons.calendar_month,Icons.add_circle,Icons.chat_bubble_outline,Icons.person_outline];
        pages = [const EmployeeHome(),const AppointmentsPage(title:'Randevularım'),const SharePage(),const MessagesPage(),const ProfilePage()];
        break;
      case AppRole.owner:
        labels = ['Ana Sayfa','Keşfet','Takip','Paylaş','Mesajlar','Profil']; icons = [Icons.home_rounded,Icons.diamond_rounded,Icons.favorite_border,Icons.add_circle,Icons.chat_bubble_outline,Icons.person_outline];
        pages = [const OwnerHome(),const DiscoverPage(),const FollowingPage(),const SharePage(businessPost:true),const MessagesPage(),const OwnerProfilePage()];
        break;
      case AppRole.admin:
        labels = ['Genel Bakış','İşletmeler','Kullanıcılar','Keşfet Yönetimi','Destek','Alt Yöneticiler']; icons = [Icons.dashboard,Icons.store,Icons.people_alt,Icons.explore,Icons.support_agent,Icons.admin_panel_settings];
        pages = [const AdminHome(),const AdminBusinesses(),const AdminUsers(),const DiscoverControl(),const SupportTicketsPage(adminMode:true),const AdminSubAdmins()];
        adminNavLoading = true;
        break;
    }
    if (widget.role == AppRole.admin) _loadAdminNavigation();
  }
  Future<void> _loadAdminNavigation() async {
    final client = Supabase.instance.client;
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() { labels = []; icons = []; pages = []; });
        return;
      }
      final statusRows = await client.rpc('get_my_account_status') as List;
      if (statusRows.isEmpty) {
        if (mounted) setState(() { labels = []; icons = []; pages = []; });
        return;
      }
      final profile = Map<String, dynamic>.from(statusRows.first as Map);
      if (profile['is_blocked'] == true) {
        await client.auth.signOut();
        if (mounted) setState(() { labels = []; icons = []; pages = []; });
        return;
      }
      if (profile['is_admin'] == true) return;
      const keys = ['dashboard','businesses','users','discover','support'];
      const names = ['Genel Bakış','İşletmeler','Kullanıcılar','Keşfet Yönetimi','Destek'];
      const glyphs = [Icons.dashboard,Icons.store,Icons.people_alt,Icons.explore,Icons.support_agent];
      final widgets = <Widget>[const AdminHome(),const AdminBusinesses(),const AdminUsers(),const DiscoverControl(),const SupportTicketsPage(adminMode:true)];
      final permissionRows = await client.rpc('get_my_admin_permissions') as List;
      final permissionSet = Set<String>.from(permissionRows);
      final allowed = <int>[
        for (var i = 0; i < keys.length; i++)
          if (permissionSet.contains(keys[i])) i,
      ];
      if (!mounted) return;
      setState(() {
        labels = allowed.map((i) => names[i]).toList();
        icons = allowed.map((i) => glyphs[i]).toList();
        pages = allowed.map((i) => widgets[i]).toList();
        index = 0;
      });
    } catch (_) {
      if (mounted) setState(() { labels = []; icons = []; pages = []; });
    } finally {
      if (mounted) setState(() => adminNavLoading = false);
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(heading, style: const TextStyle(fontWeight: FontWeight.w800, color: wine)), actions: [IconButton(
      tooltip: 'Bildirimler',
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
        appBar: AppBar(title: Text('Bildirimler')),
        body: NotificationsPage(),
      ))),
      icon: const Icon(Icons.notifications_none_rounded),
    ), const SizedBox(width: 5)]),
    body: adminNavLoading
      ? const Center(child: CircularProgressIndicator(color: wine))
      : pages.isEmpty
        ? const Center(child: Text('Bu hesap için yönetim yetkisi tanımlanmamış.'))
        : IndexedStack(index:index, children:pages),
    bottomNavigationBar: adminNavLoading || pages.isEmpty ? null : NavigationBar(
      selectedIndex:index, onDestinationSelected:(v)=>setState(()=>index=v),
      backgroundColor: Colors.white, indicatorColor: blush, height: 68,
      destinations: List.generate(labels.length,(i)=>NavigationDestination(icon:Icon(icons[i]), selectedIcon:Icon(icons[i],color:wine), label:labels[i])),
    ),
  );
}

class PageBody extends StatelessWidget {
  final List<Widget> children; const PageBody({super.key,required this.children});
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.fromLTRB(18,8,18,24),children:children);
}
class SectionTitle extends StatelessWidget {
  final String title; final String? action; const SectionTitle(this.title,{super.key,this.action});
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(top:22,bottom:12),child:Row(children:[Expanded(child:Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800,color:ink))),if(action!=null) Text(action!,style:const TextStyle(color:rose,fontWeight:FontWeight.bold,fontSize:12))]));
}
class HeroPanel extends StatelessWidget {
  final String eyebrow,title,subtitle; final IconData icon; final String button;
  final VoidCallback? onTap;
  const HeroPanel({super.key,required this.eyebrow,required this.title,required this.subtitle,required this.icon,this.button='Keşfet',this.onTap});
  @override Widget build(BuildContext context)=>Material(color:Colors.transparent,child:InkWell(
    onTap:onTap,borderRadius:BorderRadius.circular(24),
    child:Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF6E2038),Color(0xFFC45B78)],begin:Alignment.topLeft,end:Alignment.bottomRight),borderRadius:BorderRadius.circular(24),boxShadow:[BoxShadow(color:wine.withOpacity(.18),blurRadius:18,offset:const Offset(0,8))]),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(eyebrow.toUpperCase(),style:const TextStyle(color:Color(0xFFFFDDE5),fontSize:10,letterSpacing:1.5,fontWeight:FontWeight.bold)),const SizedBox(height:9),Text(title,style:const TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w800,height:1.15)),const SizedBox(height:7),Text(subtitle,style:const TextStyle(color:Colors.white70,fontSize:12,height:1.4)),const SizedBox(height:14),Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:9),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20)),child:Text(button,style:const TextStyle(color:wine,fontWeight:FontWeight.bold,fontSize:12)))])),const SizedBox(width:10),Container(width:82,height:100,decoration:BoxDecoration(color:Colors.white.withOpacity(.13),borderRadius:BorderRadius.circular(22)),child:Icon(icon,size:54,color:Colors.white))]))));
}
class SearchBarBox extends StatelessWidget {
  final String hint;
  const SearchBarBox({super.key, this.hint = 'Kuaför, çalışan veya şehir ara...'});
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: () => Navigator.push(context, MaterialPageRoute(
      builder: (_) => const BusinessDirectoryPage())),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: blush)),
      child: Row(children: [
        const Icon(Icons.search, color: muted),
        const SizedBox(width: 9),
        Text(hint, style: const TextStyle(color: muted, fontSize: 13)),
      ]),
    ),
  );
}

class BusinessDirectoryPage extends StatefulWidget {
  const BusinessDirectoryPage({super.key});
  @override
  State<BusinessDirectoryPage> createState() => _BusinessDirectoryPageState();
}

class _BusinessDirectoryPageState extends State<BusinessDirectoryPage> {
  final client = Supabase.instance.client;
  final search = TextEditingController();
  List<Map<String, dynamic>> results = [];
  List<Map<String, dynamic>> employeeResults = [];
  bool loading = false;
  bool employeeMode = false;
  String error = '';

  @override
  void dispose() { search.dispose(); super.dispose(); }

  Future<void> findBusinesses() async {
    final term = search.text.trim();
    setState(() { loading = true; error = ''; });
    try {
      var query = client.from('businesses')
        .select('id,name,address,logo_url,is_temporarily_closed')
        .eq('status', 'active');
      if (term.isNotEmpty) {
        final safeTerm = term
            .replaceAll(RegExp(r'[^-a-zA-Z0-9ğüşıöçĞÜŞİÖÇ ]'), ' ')
            .trim();
        if (safeTerm.isNotEmpty) {
          query = query.or('name.ilike.%$safeTerm%,address.ilike.%$safeTerm%');
        }
      }
      final rows = await query.order('name').limit(40);
      final mapped = List<Map<String, dynamic>>.from(rows);
      for (final business in mapped) {
        final rawLogo = business['logo_url'] as String?;
        business['logo_public_url'] = rawLogo == null || rawLogo.isEmpty ? null :
          (rawLogo.startsWith('http') ? rawLogo : client.storage.from('salon-avatars').getPublicUrl(rawLogo));
      }
      if (mounted) setState(() => results = mapped);
    } catch (e) {
      if (mounted) setState(() => error = 'İşletme araması yapılamadı: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> findEmployees() async {
    final term = search.text.trim();
    setState(() { loading = true; error = ''; });
    try {
      var query = client.from('public_business_employees')
        .select('id,business_id,display_name,avatar_url');
      if (term.isNotEmpty) query = query.ilike('display_name', '%$term%');
      final rows = await query.order('display_name').limit(40);
      final employees = List<Map<String, dynamic>>.from(rows);
      final businessIds = employees.map((e) => e['business_id'] as String).toSet().toList();
      final businesses = businessIds.isEmpty ? <Map<String, dynamic>>[] :
        List<Map<String, dynamic>>.from(await client.from('businesses')
          .select('id,name,address').inFilter('id', businessIds));
      final businessById = {for (final b in businesses) b['id'] as String: b};
      for (final employee in employees) {
        final business = businessById[employee['business_id']];
        employee['business_name'] = business?['name'] ?? 'İşletme';
        employee['business_address'] = business?['address'] ?? '';
      }
      if (mounted) setState(() => employeeResults = employees);
    } catch (e) {
      if (mounted) setState(() => error = 'Çalışan araması yapılamadı: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> searchCurrent() => employeeMode ? findEmployees() : findBusinesses();

  Future<void> openBusiness(String businessId) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) =>
      BusinessProfilePage(businessId: businessId)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: cream,
    appBar: AppBar(title: const Text('Kuaför keşfet')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Row(children: [
        ChoiceChip(
          label: const Text('İşletmeler'),
          selected: !employeeMode,
          selectedColor: blush,
          onSelected: (_) {
            setState(() { employeeMode = false; });
            findBusinesses();
          },
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Çalışanlar'),
          selected: employeeMode,
          selectedColor: blush,
          onSelected: (_) {
            setState(() { employeeMode = true; });
            findEmployees();
          },
        ),
      ])),
      Padding(padding: const EdgeInsets.all(16), child: TextField(
        controller: search,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => searchCurrent(),
        decoration: InputDecoration(
          hintText: employeeMode ? 'Çalışan adı ara' : 'İşletme adı veya adres ara',
          prefixIcon: const Icon(Icons.search, color: wine),
          suffixIcon: IconButton(onPressed: searchCurrent,
            icon: const Icon(Icons.arrow_forward, color: wine)),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
      )),
      Expanded(child: loading
        ? const Center(child: CircularProgressIndicator(color: wine))
        : error.isNotEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(20),
              child: Text(error, textAlign: TextAlign.center, style: const TextStyle(color: wine))))
          : employeeMode
            ? employeeResults.isEmpty
              ? const Center(child: Text('Çalışan aramak için yukarıya yaz.', style: TextStyle(color: muted)))
              : ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children:
                  employeeResults.map((employee) {
                    final avatar = employee['avatar_url'] as String?;
                    return Card(color: Colors.white, elevation: 0, child: ListTile(
                      leading: CircleAvatar(backgroundColor: blush,
                        backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        child: avatar == null || avatar.isEmpty ? const Icon(Icons.person, color: wine) : null),
                      title: Text(employee['display_name'] as String? ?? 'Çalışan',
                        style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
                      subtitle: Text(employee['business_name'] as String? ?? 'İşletme',
                        style: const TextStyle(color: muted)),
                      trailing: const Icon(Icons.chevron_right, color: wine),
                      onTap: () => openBusiness(employee['business_id'] as String),
                    ));
                  }).toList())
            : results.isEmpty
              ? const Center(child: Text('İşletme aramak için yukarıya yaz.', style: TextStyle(color: muted)))
              : ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children:
                  results.map((business) {
                    final logo = business['logo_public_url'] as String?;
                    final closed = business['is_temporarily_closed'] == true;
                    return Card(color: Colors.white, elevation: 0, child: ListTile(
                      leading: CircleAvatar(backgroundColor: blush,
                        backgroundImage: logo != null && logo.isNotEmpty ? NetworkImage(logo) : null,
                        child: logo == null || logo.isEmpty ? const Icon(Icons.storefront, color: wine) : null),
                      title: Text(business['name'] as String? ?? 'Kuaför',
                        style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
                      subtitle: Text(closed ? 'Geçici olarak kapalı • ${business['address'] ?? ''}' :
                        (business['address'] as String? ?? 'Adres belirtilmemiş'),
                        style: const TextStyle(color: muted)),
                      trailing: const Icon(Icons.chevron_right, color: wine),
                      onTap: () => openBusiness(business['id'] as String),
                    ));
                  }).toList()),
      ),
    ]),
  );
}

class SalonCard extends StatelessWidget {
  final String name,detail; final String rating; const SalonCard({super.key,required this.name,required this.detail,this.rating='4.9'});
  @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:13),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),border:Border.all(color:blush)),child:Row(children:[Container(width:88,height:88,decoration:BoxDecoration(borderRadius:BorderRadius.circular(15),gradient:const LinearGradient(colors:[Color(0xFFE8C1C9),Color(0xFFB66B7D)])),child:const Icon(Icons.spa_rounded,color:Colors.white,size:38)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(name,style:const TextStyle(fontWeight:FontWeight.w800,color:ink,fontSize:15)),const SizedBox(height:5),Text(detail,style:const TextStyle(color:muted,fontSize:12)),const SizedBox(height:8),Row(children:[const Icon(Icons.star_rounded,color:Color(0xFFE5A93D),size:16),Text(' $rating  •  1.2 km',style:const TextStyle(fontSize:11,color:muted)),const Spacer(),const Icon(Icons.favorite_border,color:rose,size:19)])]))]));
}
class NearbyBusinessesSection extends StatefulWidget {
  const NearbyBusinessesSection({super.key});
  @override
  State<NearbyBusinessesSection> createState() => _NearbyBusinessesSectionState();
}

class _NearbyBusinessesSectionState extends State<NearbyBusinessesSection> {
  late Future<List<Map<String, dynamic>>> businesses;
  @override
  void initState() { super.initState(); businesses = load(); }

  Future<List<Map<String, dynamic>>> load() async =>
      List<Map<String, dynamic>>.from(await Supabase.instance.client
        .from('businesses')
        .select('id,name,address,logo_url,is_temporarily_closed')
        .eq('status', 'active')
        .order('name')
        .limit(5));

  Future<void> openBusiness(Map<String, dynamic> business) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessProfilePage(
      businessId: business['id'] as String,
    )));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: businesses,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Padding(padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator(color: wine)));
      }
      if (snapshot.hasError) {
        return const Text('İşletmeler yüklenemedi. Bağlantını kontrol et.',
          style: TextStyle(color: muted));
      }
      final items = snapshot.data ?? [];
      if (items.isEmpty) {
        return const Text('Henüz onaylı işletme bulunmuyor.', style: TextStyle(color: muted));
      }
      return Column(children: items.map((business) {
        final rawLogo = business['logo_url'] as String?;
        final logo = rawLogo == null || rawLogo.isEmpty ? null :
          (rawLogo.startsWith('http') ? rawLogo : Supabase.instance.client.storage.from('salon-avatars').getPublicUrl(rawLogo));
        final closed = business['is_temporarily_closed'] == true;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: blush)),
          child: Row(children: [
            CircleAvatar(radius: 38, backgroundColor: blush,
              backgroundImage: logo != null && logo.isNotEmpty ? NetworkImage(logo) : null,
              child: logo == null || logo.isEmpty
                ? const Icon(Icons.storefront, color: wine, size: 32) : null),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(business['name'] as String? ?? 'Kuaför',
                style: const TextStyle(fontWeight: FontWeight.w800, color: ink, fontSize: 15)),
              const SizedBox(height: 5),
              Text(business['address'] as String? ?? 'Adres belirtilmemiş',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: muted, fontSize: 12)),
              const SizedBox(height: 7),
              Text(closed ? 'Geçici olarak kapalı' : 'Randevu için görüntüle',
                style: TextStyle(color: closed ? rose : wine, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              SizedBox(height: 34, child: OutlinedButton(
                onPressed: () => openBusiness(business),
                child: const Text('Randevu al', style: TextStyle(fontSize: 11)),
              )),
            ])),
          ]),
        );
      }).toList());
    },
  );
}

class CustomerHome extends StatelessWidget {
  const CustomerHome({super.key});
  void open(BuildContext context,Widget page,String title)=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(appBar:AppBar(title:Text(title)),body:page)));
  @override Widget build(BuildContext context)=>PageBody(children:[
    const Text('Merhaba, Güzellik! ♡',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:4),const Text('Bugün kendine biraz zaman ayır.',style:TextStyle(color:muted)),const SizedBox(height:16),
    HeroPanel(eyebrow:'Stilini keşfet',title:'Hayal ettiğin saç stili burada',subtitle:'İlham al, sana en yakın salonu bul ve kolayca randevu oluştur.',icon:Icons.auto_awesome,button:'Şimdi keşfet  →',onTap:()=>open(context,const BusinessDirectoryPage(),'Kuaför keşfet')),
    const SizedBox(height:15),const SearchBarBox(),const SectionTitle('Yakınındaki Kuaförler',action:'Tümünü Gör →'),
    const NearbyBusinessesSection(),const SectionTitle('Senin için seçtiklerimiz'),const QuickTiles(),
  ]);
}
class QuickTiles extends StatelessWidget {
  const QuickTiles({super.key});
  @override Widget build(BuildContext context)=>Row(children:[
    _tile(context,Icons.calendar_month,'Randevu Al',()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const BusinessDirectoryPage()))),
    _tile(context,Icons.diamond,'Keşfet',()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const DiscoverPage()))),
    _tile(context,Icons.favorite,'Takip Edilen',()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const FollowingPage()))),
  ]);
  Widget _tile(BuildContext context,IconData i,String s,VoidCallback action)=>Expanded(child:Material(color:Colors.white,borderRadius:BorderRadius.circular(16),child:InkWell(onTap:action,borderRadius:BorderRadius.circular(16),child:Container(margin:const EdgeInsets.only(right:8),padding:const EdgeInsets.symmetric(vertical:17,horizontal:5),decoration:BoxDecoration(borderRadius:BorderRadius.circular(16),border:Border.all(color:blush)),child:Column(children:[Icon(i,color:wine),const SizedBox(height:7),Text(s,textAlign:TextAlign.center,style:const TextStyle(fontSize:10,fontWeight:FontWeight.bold,color:ink))])))));
}
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final repository = KuaforumFeedRepository();
  late Future<List<KuaforumFeedPost>> feed;

  @override
  void initState() {
    super.initState();
    feed = repository.fetchDiscoverFeed();
  }

  Future<void> refresh() async {
    final next = repository.fetchDiscoverFeed();
    setState(() => feed = next);
    await next;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<KuaforumFeedPost>>(
    future: feed,
    builder: (context, snapshot) => RefreshIndicator(
      color: wine,
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          const Text('Keşfet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 5),
          const Text('İşletmelerden ve çalışanlardan gerçek paylaşımlar.', style: TextStyle(color: muted)),
          const SizedBox(height: 16),
          const SearchBarBox(hint: 'Salon veya çalışan ara...'),
          const SizedBox(height: 12),
          const SectionTitle('Keşfet akışı'),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Padding(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator(color: wine)))
          else if (snapshot.hasError)
            _FeedMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Paylaşımlar yüklenemedi',
              detail: 'Bağlantını kontrol edip tekrar dene.',
              action: 'Yeniden dene',
              onPressed: refresh,
            )
          else if ((snapshot.data ?? []).isEmpty)
            const _FeedMessage(
              icon: Icons.auto_awesome_outlined,
              title: 'Henüz keşfedilecek paylaşım yok',
              detail: 'İşletmeler ve çalışanlar paylaşım yaptıkça içerikler burada görünecek.',
            )
          else
            ...snapshot.data!.map((post) => LiveFeedPostCard(post: post, repository: repository)),
        ],
      ),
    ),
  );
}

class _FeedMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final String? action;
  final VoidCallback? onPressed;
  const _FeedMessage({required this.icon, required this.title, required this.detail, this.action, this.onPressed});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 12),
    child: Column(children: [
      Icon(icon, color: rose, size: 42),
      const SizedBox(height: 12),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 6),
      Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: muted, height: 1.4)),
      if (action != null) ...[
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onPressed, child: Text(action!)),
      ],
    ]),
  );
}

class LiveFeedPostCard extends StatefulWidget {
  final KuaforumFeedPost post;
  final KuaforumFeedRepository repository;
  const LiveFeedPostCard({super.key, required this.post, required this.repository});
  @override
  State<LiveFeedPostCard> createState() => _LiveFeedPostCardState();
}

class _LiveFeedPostCardState extends State<LiveFeedPostCard> {
  late bool liked;
  late int likes;
  bool busy = false;
  bool followingBusiness = false;
  bool followingAuthor = false;
  bool followStateLoaded = false;
  bool isCustomer = false;
  bool openingChat = false;
  late bool saved;
  bool deleted = false;

  @override
  void initState() {
    super.initState();
    liked = widget.post.isLikedByMe;
    likes = widget.post.likeCount;
    saved = widget.post.isSavedByMe;
    loadFollowState();
  }

  Future<void> loadFollowState() async {
    try {
      final profile = await Supabase.instance.client
          .from('profiles').select('account_type')
          .eq('id', Supabase.instance.client.auth.currentUser!.id).single();
      final customer = profile['account_type'] == 'customer';
      final business = await widget.repository.isFollowingBusiness(widget.post.businessId);
      final author = widget.post.isEmployeePost && !widget.post.isOwnPost
          ? await widget.repository.isFollowingUser(widget.post.authorUserId)
          : false;
      if (!mounted) return;
      setState(() {
        isCustomer = customer;
        followingBusiness = business;
        followingAuthor = author;
        followStateLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => followStateLoaded = true);
    }
  }

  Future<void> toggleBusinessFollow() async {
    final wasFollowing = followingBusiness;
    setState(() => followingBusiness = !wasFollowing);
    try {
      if (wasFollowing) {
        await widget.repository.unfollowBusiness(widget.post.businessId);
      } else {
        await widget.repository.followBusiness(widget.post.businessId);
      }
    } catch (_) {
      if (mounted) {
        setState(() => followingBusiness = wasFollowing);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İşletme takibi güncellenemedi.')));
      }
    }
  }

  Future<void> toggleAuthorFollow() async {
    final wasFollowing = followingAuthor;
    setState(() => followingAuthor = !wasFollowing);
    try {
      if (wasFollowing) {
        await widget.repository.unfollowUser(widget.post.authorUserId);
      } else {
        await widget.repository.followUser(widget.post.authorUserId);
      }
    } catch (_) {
      if (mounted) {
        setState(() => followingAuthor = wasFollowing);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çalışan takibi güncellenemedi.')));
      }
    }
  }

  Future<void> openEmployeeChat() async {
    if (openingChat) return;
    setState(() => openingChat = true);
    try {
      final conversationId = await KuaforumMessagingRepository()
          .startEmployeeConversation(widget.post.authorUserId);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: conversationId,
          title: widget.post.authorName,
          subtitle: widget.post.businessName,
        ),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sohbet açılamadı: $error'), backgroundColor: wine),
      );
    } finally {
      if (mounted) setState(() => openingChat = false);
    }
  }

  Future<void> toggleSaved() async {
    final previous = saved;
    setState(() => saved = !previous);
    try {
      await widget.repository.toggleSave(widget.post.id, currentlySaved: previous);
    } catch (_) {
      if (mounted) {
        setState(() => saved = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paylaşım kaydedilemedi.')));
      }
    }
  }

  Future<void> deleteOwnPost() async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) =>
      AlertDialog(
        title: const Text('Paylaşımı sil'),
        content: const Text('Bu paylaşım ve yorumları kalıcı olarak silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Sil')),
        ],
      ));
    if (confirmed != true) return;
    try {
      await widget.repository.deletePost(widget.post.id);
      if (mounted) setState(() => deleted = true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paylaşım silinemedi: $error'), backgroundColor: wine));
    }
  }

  Future<void> toggleLike() async {
    if (busy) return;
    final previousLiked = liked;
    final previousLikes = likes;
    setState(() {
      busy = true;
      liked = !liked;
      likes += liked ? 1 : -1;
    });
    try {
      await widget.repository.toggleLike(widget.post.id, currentlyLiked: previousLiked);
    } catch (_) {
      if (mounted) {
        setState(() {
          liked = previousLiked;
          likes = previousLikes;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Beğeni kaydedilemedi.')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (deleted) return const SizedBox.shrink();
    return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: blush),
      boxShadow: [BoxShadow(color: wine.withOpacity(.05), blurRadius: 16, offset: const Offset(0, 5))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const CircleAvatar(backgroundColor: blush, child: Icon(Icons.person, color: wine)),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.post.authorName, style: const TextStyle(fontWeight: FontWeight.bold, color: ink)),
          Text(widget.post.businessName, style: const TextStyle(color: muted, fontSize: 10)),
        ])),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz, color: muted),
          onSelected: (value) {
            if (value == 'business') toggleBusinessFollow();
            if (value == 'author') toggleAuthorFollow();
            if (value == 'delete') deleteOwnPost();
          },
          itemBuilder: (_) => [
            if (widget.post.isOwnPost)
              const PopupMenuItem(value: 'delete', child: Text('Paylaşımı sil')),
            if (!widget.post.isOwnPost && followStateLoaded) ...[
              PopupMenuItem(value: 'business', child: Text(followingBusiness ? 'İşletmeyi takipten çık' : 'İşletmeyi takip et')),
              if (widget.post.isEmployeePost)
                PopupMenuItem(value: 'author', child: Text(followingAuthor ? 'Çalışanı takipten çık' : 'Çalışanı takip et')),
            ],
          ],
        ),
      ]),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: widget.post.isVideo
          ? InlineFeedVideo(url: widget.post.mediaUrl)
          : Image.network(
              widget.post.mediaUrl,
              height: 215,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 215,
                color: blush,
                child: const Center(child: Icon(Icons.broken_image_outlined, color: wine, size: 42)),
              ),
            ),
      ),
      const SizedBox(height: 12),
      Text(widget.post.caption, style: const TextStyle(fontWeight: FontWeight.w600, color: ink)),
      const SizedBox(height: 9),
      Row(children: [
        InkWell(
          onTap: toggleLike,
          child: Row(children: [
            Icon(liked ? Icons.favorite : Icons.favorite_border, color: rose),
            const SizedBox(width: 5),
            Text('$likes', style: const TextStyle(color: muted)),
          ]),
        ),
        const SizedBox(width: 18),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => FeedCommentsSheet(
              postId: widget.post.id,
              repository: widget.repository,
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Icon(Icons.mode_comment_outlined, color: muted),
              SizedBox(width: 5),
              Text('Yorumlar', style: TextStyle(color: muted, fontSize: 12)),
            ]),
          ),
        ),
        IconButton(
          tooltip: saved ? 'Kaydedilenlerden çıkar' : 'Kaydet',
          onPressed: toggleSaved,
          icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, color: saved ? wine : muted),
        ),
        IconButton(
          tooltip: 'Paylaşım bağlantısını kopyala',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: '${widget.post.caption}\n${widget.post.mediaUrl}'));
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Paylaşım bağlantısı kopyalandı.')));
          },
          icon: const Icon(Icons.share_outlined, color: muted),
        ),
        Text(
          '${widget.post.createdAt.day}.${widget.post.createdAt.month}.${widget.post.createdAt.year}',
          style: const TextStyle(color: muted, fontSize: 10),
        ),
      ]),
      if (isCustomer && widget.post.isEmployeePost && !widget.post.isOwnPost) ...[
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: openingChat ? null : openEmployeeChat,
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(openingChat ? 'Sohbet açılıyor...' : 'Çalışana Mesaj Gönder'),
            style: OutlinedButton.styleFrom(
              foregroundColor: wine,
              side: const BorderSide(color: blush),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            ),
          ),
        ),
      ],
    ]),
  );
  }
}

class InlineFeedVideo extends StatefulWidget {
  final String url;
  const InlineFeedVideo({super.key, required this.url});

  @override
  State<InlineFeedVideo> createState() => _InlineFeedVideoState();
}

class _InlineFeedVideoState extends State<InlineFeedVideo> {
  VideoPlayerController? controller;
  bool loading = false;
  bool failed = false;

  Future<void> togglePlayback() async {
    if (loading || failed) return;
    final current = controller;
    if (current == null) {
      setState(() => loading = true);
      final next = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      controller = next;
      try {
        await next.initialize();
        if (!mounted) return;
        await next.setLooping(false);
        await next.play();
        if (mounted) setState(() => loading = false);
      } catch (_) {
        if (!mounted) return;
        await next.dispose();
        if (identical(controller, next)) controller = null;
        setState(() {
          loading = false;
          failed = true;
        });
      }
      return;
    }

    if (!current.value.isInitialized) return;
    if (current.value.isPlaying) {
      await current.pause();
    } else {
      await current.play();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Container(
        height: 215,
        width: double.infinity,
        color: ink,
        child: const Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 38),
            SizedBox(height: 7),
            Text('Video oynatılamadı', style: TextStyle(color: Colors.white70)),
          ],
        )),
      );
    }

    final current = controller;
    if (current == null || !current.value.isInitialized) {
      return Container(
        height: 215,
        width: double.infinity,
        color: ink,
        child: Center(child: loading
            ? const CircularProgressIndicator(color: Colors.white)
            : Column(mainAxisSize: MainAxisSize.min, children: [
                IconButton.filled(
                  onPressed: togglePlayback,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: wine,
                    fixedSize: const Size(62, 62),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 38),
                ),
                const SizedBox(height: 7),
                const Text('Videoyu oynat', style: TextStyle(color: Colors.white70)),
              ])),
      );
    }

    return AspectRatio(
      aspectRatio: current.value.aspectRatio > 0
          ? current.value.aspectRatio
          : 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(fit: StackFit.expand, children: [
          VideoPlayer(current),
          if (!current.value.isPlaying)
            Center(child: IconButton.filled(
              onPressed: togglePlayback,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                fixedSize: const Size(62, 62),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 38),
            )),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: VideoProgressIndicator(
              current,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: rose,
                bufferedColor: Colors.white54,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
          Positioned(
            right: 5,
            top: 5,
            child: IconButton(
              onPressed: togglePlayback,
              icon: Icon(
                current.value.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_fill,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class FeedCommentsSheet extends StatefulWidget {
  final String postId;
  final KuaforumFeedRepository repository;

  const FeedCommentsSheet({
    super.key,
    required this.postId,
    required this.repository,
  });

  @override
  State<FeedCommentsSheet> createState() => _FeedCommentsSheetState();
}

class _FeedCommentsSheetState extends State<FeedCommentsSheet> {
  final controller = TextEditingController();
  late Future<List<Map<String, dynamic>>> comments;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    comments = widget.repository.fetchComments(widget.postId);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> sendComment() async {
    if (sending) return;
    final text = controller.text.trim();
    if (text.isEmpty) return;
    setState(() => sending = true);
    try {
      await widget.repository.addComment(widget.postId, text);
      controller.clear();
      if (!mounted) return;
      setState(() => comments = widget.repository.fetchComments(widget.postId));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yorum gönderilemedi: $error'), backgroundColor: wine),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> editComment(Map<String, dynamic> item) async {
    final editController = TextEditingController(text: item['body'] as String? ?? '');
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          decoration: const BoxDecoration(
            color: cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Yorumu düzenle', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ink))),
                IconButton(onPressed: () => Navigator.pop(sheetContext, false), icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: editController,
                autofocus: true,
                maxLength: 1000,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Yorumunu yaz...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: FilledButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                style: FilledButton.styleFrom(backgroundColor: wine, padding: const EdgeInsets.symmetric(vertical: 15)),
                child: const Text('Değişiklikleri kaydet'),
              )),
            ]),
          ),
        ),
      ),
    );
    if (accepted == true) {
      try {
        await widget.repository.updateComment(item['id'] as String, editController.text);
        if (!mounted) return;
        setState(() => comments = widget.repository.fetchComments(widget.postId));
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yorum güncellenemedi: $error'), backgroundColor: wine));
      }
    }
    editController.dispose();
  }

  Future<void> removeComment(Map<String, dynamic> item) async {
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) =>
      AlertDialog(
        title: const Text('Yorumu sil?'),
        content: const Text('Yorumun kalıcı olarak silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil', style: TextStyle(color: wine))),
        ],
      ));
    if (accepted != true) return;
    try {
      await widget.repository.deleteComment(item['id'] as String);
      if (!mounted) return;
      setState(() => comments = widget.repository.fetchComments(widget.postId));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yorum silinemedi: $error'), backgroundColor: wine));
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Container(
      height: MediaQuery.of(context).size.height * .76,
      decoration: const BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(children: [
          const SizedBox(height: 11),
          Container(width: 42, height: 4, decoration: BoxDecoration(
            color: blush, borderRadius: BorderRadius.circular(8),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Row(children: [
              const Expanded(child: Text('Yorumlar', style: TextStyle(
                color: ink, fontSize: 19, fontWeight: FontWeight.w800,
              ))),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: muted),
              ),
            ]),
          ),
          const Divider(height: 1, color: blush),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: comments,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: wine));
                }
                if (snapshot.hasError) {
                  return const Center(child: Text(
                    'Yorumlar yüklenemedi. Tekrar deneyebilirsin.',
                    style: TextStyle(color: muted),
                  ));
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 38, color: rose),
                      SizedBox(height: 9),
                      Text('Henüz yorum yok', style: TextStyle(
                        color: ink, fontWeight: FontWeight.bold,
                      )),
                      SizedBox(height: 4),
                      Text('İlk yorumu sen yaz ♡', style: TextStyle(color: muted)),
                    ],
                  ));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(color: blush, height: 18),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final date = DateTime.tryParse(item['created_at'] as String? ?? '')?.toLocal();
                    final dateText = date == null
                        ? ''
                        : '${date.day}.${date.month}.${date.year}';
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: blush,
                        child: Icon(Icons.person, size: 19, color: wine),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: Text(
                              item['author_name'] as String? ?? 'Kuaförüm kullanıcısı',
                              style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
                            )),
                            Text(dateText, style: const TextStyle(color: muted, fontSize: 10)),
                            if (item['user_id'] == Supabase.instance.client.auth.currentUser?.id)
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                iconSize: 18,
                                icon: const Icon(Icons.more_horiz, color: muted),
                                onSelected: (value) {
                                  if (value == 'edit') editComment(item);
                                  if (value == 'delete') removeComment(item);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                                  PopupMenuItem(value: 'delete', child: Text('Sil')),
                                ],
                              ),
                          ]),
                          const SizedBox(height: 4),
                          Text(item['body'] as String? ?? '',
                            style: const TextStyle(color: ink, height: 1.35)),
                        ],
                      )),
                    ]);
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: 'Güzel bir yorum yaz...',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: blush),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: blush),
                  ),
                ),
              )),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: sending ? null : sendComment,
                style: IconButton.styleFrom(backgroundColor: wine, foregroundColor: Colors.white),
                icon: sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white,
                      ))
                    : const Icon(Icons.send_rounded),
              ),
            ]),
          ),
        ]),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {final String text;final bool active;final VoidCallback? onTap;const _Chip(this.text,{this.active=false,this.onTap});@override Widget build(BuildContext context)=>ActionChip(onPressed:onTap,label:Text(text,style:TextStyle(color:active?Colors.white:ink,fontSize:11)),backgroundColor:active?wine:Colors.white,side:BorderSide(color:blush));}
class FollowingPage extends StatefulWidget {
  const FollowingPage({super.key});
  @override
  State<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage> {
  final repository = KuaforumFeedRepository();
  late Future<List<KuaforumFeedPost>> feed;

  @override
  void initState() {
    super.initState();
    feed = repository.fetchFollowingFeed();
  }

  Future<void> refresh() async {
    final next = repository.fetchFollowingFeed();
    setState(() => feed = next);
    await next;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<KuaforumFeedPost>>(
    future: feed,
    builder: (context, snapshot) => RefreshIndicator(
      color: wine,
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          const Text('Takip Edilen', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 8),
          const Text('Takip ettiğin işletme ve çalışanların paylaşımları.', style: TextStyle(color: muted)),
          const SectionTitle('Senin akışın'),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Padding(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator(color: wine)))
          else if (snapshot.hasError)
            _FeedMessage(icon: Icons.cloud_off_outlined, title: 'Akış yüklenemedi', detail: 'Bağlantını kontrol edip tekrar dene.', action: 'Yeniden dene', onPressed: refresh)
          else if ((snapshot.data ?? []).isEmpty)
            const _FeedMessage(icon: Icons.people_outline, title: 'Henüz takip ettiğin hesap yok', detail: 'Keşfet bölümünden beğendiğin işletmeleri ve çalışanları takip edebilirsin.')
          else
            ...snapshot.data!.map((post) => LiveFeedPostCard(post: post, repository: repository)),
        ],
      ),
    ),
  );
}

class AppointmentsPage extends StatefulWidget {
  final String title;
  final bool ownerMode;
  const AppointmentsPage({super.key, required this.title, this.ownerMode = false});
  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  final client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> appointments;
  String filter = 'Aktif';

  @override
  void initState() {
    super.initState();
    appointments = loadAppointments();
  }

  Future<List<Map<String, dynamic>>> loadAppointments() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Oturum bulunamadı. Yeniden giriş yapın.');
    final profile = await client.from('profiles')
        .select('account_type').eq('id', user.id).single();
    if (profile['account_type'] == 'customer') {
      final rows = await client.from('appointments').select(
        'id,starts_at,ends_at,status,requires_business_approval,'
        'businesses(id,name),services(name),employees(display_name),business_reviews(id,rating,body)'
      ).eq('customer_id', user.id).order('starts_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows).map((item) => {
        ...item,
        'appointment_id': item['id'],
        'business_id': (item['businesses'] as Map?)?['id'],
        'business_name': (item['businesses'] as Map?)?['name'] ?? 'İşletme',
        'review': ((item['business_reviews'] as List?) ?? const []).isNotEmpty
            ? Map<String, dynamic>.from(((item['business_reviews'] as List).first as Map))
            : null,
        'reviewed': ((item['business_reviews'] as List?) ?? const []).isNotEmpty,
        'service_name': (item['services'] as Map?)?['name'] ?? 'Hizmet',
        'employee_name': (item['employees'] as Map?)?['display_name'] ?? 'Çalışan',
      }).toList();
    }
    if (profile['account_type'] == 'business_owner') {
      final business = await client.from('businesses').select('id')
          .eq('owner_id', user.id).maybeSingle();
      if (business == null) throw Exception('İşletme kaydınız bulunamadı.');
      final rows = await client.rpc('get_business_appointments', params: {
        'p_business_id': business['id'],
        'p_mine_only': widget.ownerMode,
      });
      return List<Map<String, dynamic>>.from(rows as List);
    }
    final employee = await client.from('employees')
        .select('id,business_id')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .maybeSingle();
    if (employee == null) throw Exception('Aktif çalışan kaydınız bulunamadı.');
    final rows = await client.rpc('get_business_appointments', params: {
      'p_business_id': employee['business_id'],
      'p_mine_only': true,
    });
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> refreshAppointments() async {
    final next = loadAppointments();
    setState(() => appointments = next);
    await next;
  }

  String statusLabel(String status) => switch (status) {
    'pending' => 'Onay bekliyor',
    'confirmed' => 'Onaylandı',
    'completed' => 'Tamamlandı',
    'cancelled' => 'İptal edildi',
    'no_show' => 'Gelmedi',
    _ => status,
  };

  Future<void> rateAppointment(Map<String, dynamic> appointment) async {
    final existing = appointment['review'] is Map
        ? Map<String, dynamic>.from(appointment['review'] as Map)
        : null;
    int rating = (existing?['rating'] as num?)?.toInt() ?? 5;
    final body = TextEditingController(text: existing?['body']?.toString() ?? '');
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) =>
      StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: Text(existing == null ? 'İşletmeyi değerlendir' : 'Değerlendirmeyi düzenle'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Hizmet deneyimin nasıldı?'),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (index) =>
            IconButton(
              onPressed: () => setDialogState(() => rating = index + 1),
              icon: Icon(index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: const Color(0xFFE5A93D), size: 30),
            ))),
          TextField(controller: body, maxLength: 1000, maxLines: 3,
            decoration: const InputDecoration(labelText: 'Yorumun (isteğe bağlı)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(existing == null ? 'Gönder' : 'Kaydet')),
        ],
      )));
    if (accepted == true) {
      try {
        final values = {'rating': rating, 'body': body.text.trim()};
        if (existing == null) {
          await client.from('business_reviews').insert({
            'business_id': appointment['business_id'],
            'customer_id': client.auth.currentUser!.id,
            'appointment_id': appointment['appointment_id'],
            ...values,
          });
        } else {
          await client.from('business_reviews').update(values)
              .eq('id', existing['id']).eq('customer_id', client.auth.currentUser!.id);
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(existing == null ? 'Değerlendirmen kaydedildi.' : 'Değerlendirmen güncellendi.')));
        await refreshAppointments();
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Değerlendirme kaydedilemedi: $error'), backgroundColor: wine));
      }
    }
    body.dispose();
  }

  Future<void> deleteReview(Map<String, dynamic> appointment) async {
    final review = appointment['review'] is Map
        ? Map<String, dynamic>.from(appointment['review'] as Map)
        : null;
    if (review == null) return;
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) =>
      AlertDialog(
        title: const Text('Değerlendirmeyi sil?'),
        content: const Text('Bu değerlendirme kalıcı olarak silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil', style: TextStyle(color: wine))),
        ],
      ));
    if (accepted != true) return;
    try {
      await client.from('business_reviews').delete()
          .eq('id', review['id']).eq('customer_id', client.auth.currentUser!.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Değerlendirmen silindi.')));
      await refreshAppointments();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Değerlendirme silinemedi: $error'), backgroundColor: wine));
    }
  }

  Future<void> changeStatus(Map<String, dynamic> appointment, String status) async {
    try {
      if (status == 'cancelled') {
        await client.rpc('cancel_appointment', params: {
          'p_appointment_id': appointment['appointment_id'],
        });
      } else if (status == 'approve' || status == 'reject') {
        await client.rpc('review_appointment_request', params: {
          'p_appointment_id': appointment['appointment_id'],
          'p_decision': status,
        });
      } else {
        await client.rpc('update_appointment_status', params: {
          'p_appointment_id': appointment['appointment_id'],
          'p_status': status,
        });
      }
      if (!mounted) return;
      final message = status == 'completed' ? 'Randevu tamamlandı.' :
        status == 'no_show' ? 'Gelmedi olarak işaretlendi.' :
        status == 'approve' ? 'Randevu onaylandı.' :
        status == 'reject' ? 'Randevu reddedildi.' : 'Randevu iptal edildi.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await refreshAppointments();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem yapılamadı: $error'), backgroundColor: wine),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: appointments,
    builder: (context, snapshot) {
      final all = snapshot.data ?? const <Map<String, dynamic>>[];
      final visible = all.where((item) {
        final status = item['status'] as String? ?? '';
        if (filter == 'Aktif') return status == 'pending' || status == 'confirmed';
        if (filter == 'Geçmiş') return status == 'completed' || status == 'cancelled' || status == 'no_show';
        return status == 'pending';
      }).toList();
      return RefreshIndicator(
        color: wine,
        onRefresh: refreshAppointments,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, children: [
              _Chip('Aktif', active: filter == 'Aktif', onTap: () => setState(() => filter = 'Aktif')),
              _Chip('Bekleyen', active: filter == 'Bekleyen', onTap: () => setState(() => filter = 'Bekleyen')),
              _Chip('Geçmiş', active: filter == 'Geçmiş', onTap: () => setState(() => filter = 'Geçmiş')),
            ]),
            const SizedBox(height: 16),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator(color: wine)))
            else if (snapshot.hasError)
              _FeedMessage(icon: Icons.cloud_off_outlined, title: 'Randevular yüklenemedi', detail: snapshot.error.toString())
            else if (visible.isEmpty)
              const _FeedMessage(icon: Icons.calendar_month_outlined, title: 'Randevu bulunamadı', detail: 'Bu bölümde henüz gösterilecek randevu yok.')
            else
              ...visible.map((item) {
                final status = item['status'] as String? ?? '';
                final startsAt = DateTime.tryParse(item['starts_at']?.toString() ?? '')?.toLocal();
                final dateText = startsAt == null ? 'Tarih bilgisi yok' :
                  '${startsAt.day.toString().padLeft(2, '0')}.${startsAt.month.toString().padLeft(2, '0')}.${startsAt.year} • ${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: blush)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const CircleAvatar(radius: 22, backgroundColor: blush, child: Icon(Icons.person, color: wine)),
                      const SizedBox(width: 11),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item['customer_name']?.toString() ?? item['business_name']?.toString() ?? 'Müşteri', style: const TextStyle(fontWeight: FontWeight.bold, color: ink)),
                        Text('${item['service_name']?.toString() ?? 'Hizmet'} • ${item['employee_name']?.toString() ?? 'Çalışan'}', style: const TextStyle(color: muted, fontSize: 12)),
                        Text(dateText, style: const TextStyle(color: ink, fontSize: 12)),
                      ])),
                      Text(statusLabel(status), style: const TextStyle(color: wine, fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                    if (status == 'completed' && item.containsKey('business_id') && item['reviewed'] != true) ...[
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(
                        onPressed: () => rateAppointment(item),
                        icon: const Icon(Icons.star_outline_rounded),
                        label: const Text('Değerlendir'),
                      )),
                    ] else if (status == 'completed' && item.containsKey('business_id') && item['reviewed'] == true) ...[
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton.icon(
                          onPressed: () => rateAppointment(item),
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          label: const Text('Düzenle'),
                        ),
                        TextButton.icon(
                          onPressed: () => deleteReview(item),
                          icon: const Icon(Icons.delete_outline, size: 17),
                          label: const Text('Sil'),
                          style: TextButton.styleFrom(foregroundColor: wine),
                        ),
                      ]),
                    ],
                    if ((status == 'confirmed' || status == 'pending') && item.containsKey('business_name')) ...[
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerRight, child: TextButton(
                        onPressed: () => changeStatus(item, 'cancelled'),
                        child: const Text('Randevuyu iptal et', style: TextStyle(color: wine)),
                      )),
                    ] else if (status == 'pending' && item['requires_business_approval'] == true) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: OutlinedButton(
                          onPressed: () => changeStatus(item, 'reject'),
                          child: const Text('Reddet'),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: wine, foregroundColor: Colors.white),
                          onPressed: () => changeStatus(item, 'approve'),
                          child: const Text('Onayla'),
                        )),
                      ]),
                    ] else if (status == 'confirmed') ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: OutlinedButton(
                          onPressed: () => changeStatus(item, 'no_show'),
                          child: const Text('Gelmedi'),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: wine, foregroundColor: Colors.white),
                          onPressed: () => changeStatus(item, 'completed'),
                          child: const Text('Tamamlandı'),
                        )),
                      ]),
                    ],
                  ]),
                );
              }),
          ],
        ),
      );
    },
  );
}
class AppointmentTile extends StatelessWidget {
  final String name, service, time, status;
  const AppointmentTile({super.key, required this.name, required this.service, required this.time, required this.status});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: blush)),
    child: Row(children: [
      const CircleAvatar(radius: 24, backgroundColor: blush, child: Icon(Icons.person, color: wine)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: ink)),
        Text(service, style: const TextStyle(color: muted, fontSize: 12)),
        Text(time, style: const TextStyle(color: ink, fontSize: 12)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFE3F3E8), borderRadius: BorderRadius.circular(12)),
        child: Text(status, style: const TextStyle(color: Color(0xFF32734B), fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    ]),
  );
}

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final repository = KuaforumMessagingRepository();
  final searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> conversations;
  Future<List<Map<String, dynamic>>>? businessResults;
  bool openingBusinessChat = false;

  @override
  void initState() {
    super.initState();
    conversations = repository.fetchConversations();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    final next = repository.fetchConversations();
    setState(() => conversations = next);
    await next;
  }

  Future<void> searchBusinesses() async {
    final query = searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => businessResults = repository.searchBusinesses(query));
  }

  Future<void> openBusinessChat(Map<String, dynamic> business) async {
    if (openingBusinessChat) return;
    setState(() => openingBusinessChat = true);
    try {
      final id = await repository.startBusinessConversation(business['id'] as String);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: id,
          title: business['name'] as String? ?? 'İşletme',
          subtitle: 'İşletme',
        ),
      ));
      if (mounted) {
        setState(() {
          conversations = repository.fetchConversations();
          businessResults = null;
          searchController.clear();
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşletmeyle sohbet başlatılamadı: $error'), backgroundColor: wine),
      );
    } finally {
      if (mounted) setState(() => openingBusinessChat = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: conversations,
    builder: (context, snapshot) => RefreshIndicator(
      color: wine,
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          const Text('Mesajlar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 5),
          const Text('İşletmelere veya çalışanlara doğrudan mesaj gönderebilirsin.', style: TextStyle(color: muted)),
          const SizedBox(height: 14),
          const Text('İşletmeye mesaj gönder', style: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => searchBusinesses(),
              decoration: InputDecoration(
                hintText: 'İşletme adı ara...',
                prefixIcon: const Icon(Icons.search, color: wine),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: blush)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: blush)),
              ),
            )),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: searchBusinesses,
              style: IconButton.styleFrom(backgroundColor: wine, foregroundColor: Colors.white),
              icon: const Icon(Icons.search),
            ),
          ]),
          if (businessResults != null)
            FutureBuilder<List<Map<String, dynamic>>>(
              future: businessResults,
              builder: (context, result) {
                if (result.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.all(14), child: Center(child: CircularProgressIndicator(color: wine)));
                }
                if (result.hasError) {
                  return const Padding(padding: EdgeInsets.all(12), child: Text('İşletmeler aranamadı. Tekrar dene.', style: TextStyle(color: wine)));
                }
                final items = result.data ?? [];
                if (items.isEmpty) {
                  return const Padding(padding: EdgeInsets.all(12), child: Text('Bu isimle aktif işletme bulunamadı.', style: TextStyle(color: muted)));
                }
                return Column(children: items.map((business) => Card(
                  color: Colors.white,
                  elevation: 0,
                  margin: const EdgeInsets.only(top: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: blush)),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: blush, child: Icon(Icons.storefront_outlined, color: wine)),
                    title: Text(business['name'] as String? ?? 'İşletme', style: const TextStyle(color: ink, fontWeight: FontWeight.bold)),
                    subtitle: Text(business['address'] as String? ?? 'Doğrudan işletmeyle sohbet et', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chat_bubble_outline, color: wine),
                    onTap: openingBusinessChat ? null : () => openBusinessChat(business),
                  ),
                )).toList());
              },
            ),
          const SizedBox(height: 20),
          const Text('Sohbetlerin', style: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: wine)))
          else if (snapshot.hasError)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Icon(Icons.cloud_off_outlined, color: muted, size: 38),
                const SizedBox(height: 8),
                const Text('Mesajlar yüklenemedi.', style: TextStyle(color: ink, fontWeight: FontWeight.bold)),
                TextButton(onPressed: refresh, child: const Text('Tekrar dene')),
              ]),
            )
          else if ((snapshot.data ?? []).isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24, horizontal: 12),
              child: Column(children: [
                Icon(Icons.forum_outlined, color: rose, size: 42),
                SizedBox(height: 10),
                Text('Henüz sohbetin yok', style: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('Yukarıdan işletme arayarak doğrudan sohbet başlatabilirsin.', textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.4)),
              ]),
            )
          else
            ...snapshot.data!.map((conversation) => Card(
              color: Colors.white,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: blush)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                leading: CircleAvatar(
                  backgroundColor: blush,
                  child: Icon(conversation['employee_id'] == null ? Icons.storefront_outlined : Icons.person, color: wine),
                ),
                title: Text(conversation['peer_name'] as String? ?? 'Sohbet', style: const TextStyle(fontWeight: FontWeight.bold, color: ink)),
                subtitle: Text(
                  '${conversation['business_name'] ?? 'İşletme'}  •  ${conversation['last_message'] ?? ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: wine),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatPage(
                    conversationId: conversation['id'] as String,
                    title: conversation['peer_name'] as String? ?? 'Sohbet',
                    subtitle: conversation['business_name'] as String? ?? 'İşletme',
                  ),
                )).then((_) => refresh()),
              ),
            )),
        ],
      ),
    ),
  );
}

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String title;
  final String subtitle;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.title,
    required this.subtitle,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final repository = KuaforumMessagingRepository();
  final controller = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> messageStream;
  bool sending = false;
  String? sendError;
  final Set<String> hiddenMessageIds = {};

  @override
  void initState() {
    super.initState();
    loadHiddenMessages();
    messageStream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', widget.conversationId)
        .order('created_at')
        .map((rows) => rows.map((row) => Map<String, dynamic>.from(row)).toList());
  }

  Future<void> loadHiddenMessages() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final rows = await Supabase.instance.client.from('message_hidden_for_me')
          .select('message_id').eq('user_id', userId);
      if (!mounted) return;
      setState(() => hiddenMessageIds.addAll(rows.map((row) => row['message_id'] as String)));
    } catch (_) {
      // The chat remains usable if hidden-message metadata cannot be refreshed.
    }
  }

  Future<void> hideMessage(String messageId) async {
    try {
      await repository.hideMessageForMe(messageId);
      if (mounted) setState(() => hiddenMessageIds.add(messageId));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesaj gizlenemedi: $error'), backgroundColor: wine));
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (sending) return;
    final body = controller.text.trim();
    if (body.isEmpty) return;
    setState(() { sending = true; sendError = null; });
    try {
      await repository.sendMessage(widget.conversationId, body);
      controller.clear();
    } catch (error) {
      if (mounted) setState(() => sendError = 'Mesaj gönderilemedi: $error');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: cream,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.title, style: const TextStyle(color: wine, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(widget.subtitle, style: const TextStyle(color: muted, fontSize: 11)),
      ]),
    ),
    body: Column(children: [
      Expanded(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: messageStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Mesajlar alınamadı. İnternet bağlantını kontrol et.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: wine));
            }
            final rows = snapshot.data!
                .where((row) => !hiddenMessageIds.contains(row['id'] as String))
                .toList();
            if (rows.isEmpty) {
              return const Center(child: Text('Sohbet başladı. İlk mesajı sen gönder ♡', style: TextStyle(color: muted)));
            }
            final userId = Supabase.instance.client.auth.currentUser?.id;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                final mine = row['sender_id'] == userId;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'hide') hideMessage(row['id'] as String);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'hide', child: Text('Benden sil')),
                    ],
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: mine ? wine : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: mine ? null : Border.all(color: blush),
                      ),
                      child: Text(row['body'] as String? ?? '', style: TextStyle(color: mine ? Colors.white : ink, height: 1.35)),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      if (sendError != null)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text(sendError!, style: const TextStyle(color: wine, fontSize: 11))),
      SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          color: Colors.white,
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => send(),
                decoration: InputDecoration(
                  hintText: 'Mesajını yaz...',
                  filled: true,
                  fillColor: cream,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : send,
              style: IconButton.styleFrom(backgroundColor: wine, foregroundColor: Colors.white),
              icon: sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
            ),
          ]),
        ),
      ),
    ]),
  );
}
class ActiveSessionsPage extends StatefulWidget {
  const ActiveSessionsPage({super.key});
  @override State<ActiveSessionsPage> createState() => _ActiveSessionsPageState();
}

class _ActiveSessionsPageState extends State<ActiveSessionsPage> {
  final client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> sessions;

  @override
  void initState() {
    super.initState();
    sessions = load();
  }

  Future<List<Map<String, dynamic>>> load() async =>
    List<Map<String, dynamic>>.from(await client.rpc('get_my_sessions') as List);

  Future<void> refresh() async {
    final next = load();
    setState(() => sessions = next);
    await next;
  }

  String formatDate(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return 'Bilinmiyor';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> revoke(Map<String, dynamic> session) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) =>
      AlertDialog(
        title: const Text('Oturumu kapat'),
        content: const Text('Seçilen cihazın oturumu kapatılacak. Bu cihaz tekrar giriş yapmak zorunda kalacak.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Oturumu kapat', style: TextStyle(color: wine))),
        ],
      ));
    if (confirmed != true) return;
    try {
      await client.rpc('revoke_my_session', params: {'p_session_id': session['session_id']});
      await refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seçilen cihazın oturumu kapatıldı.')),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Oturum kapatılamadı: $error'), backgroundColor: wine),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: sessions,
    builder: (context, snapshot) => RefreshIndicator(
      color: wine,
      onRefresh: refresh,
      child: ListView(padding: const EdgeInsets.all(18), children: [
        const Text('Aktif Cihazlar', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 6),
        const Text('Hesabının açık olduğu cihazları görüntüleyebilir ve diğer cihazlardan çıkış yapabilirsin.',
          style: TextStyle(color: muted)),
        const SizedBox(height: 12),
        if (snapshot.connectionState == ConnectionState.waiting)
          const Center(child: CircularProgressIndicator(color: wine))
        else if (snapshot.hasError)
          _FeedMessage(icon: Icons.cloud_off_outlined, title: 'Oturumlar yüklenemedi', detail: snapshot.error.toString())
        else if ((snapshot.data ?? []).isEmpty)
          const _FeedMessage(icon: Icons.devices_outlined, title: 'Aktif oturum bulunamadı', detail: 'Yeniden giriş yaparak oturumunu görebilirsin.')
        else
          ...(snapshot.data ?? []).map((session) {
            final current = session['is_current'] == true;
            final agent = session['user_agent']?.toString().trim();
            final ip = session['ip_address']?.toString();
            return Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 9),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: blush,
                  child: Icon((agent ?? '').toLowerCase().contains('android') ? Icons.phone_android : Icons.devices, color: wine)),
                title: Text(agent == null || agent.isEmpty ? 'Bilinmeyen cihaz' : agent,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
                subtitle: Text(
                  "Son etkinlik: ${formatDate(session['last_active_at'])}\n"
                  "Başlangıç: ${formatDate(session['created_at'])}"
                  "${ip == null || ip.isEmpty ? '' : '\nIP: $ip'}",
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
                trailing: current
                  ? const Text('Bu cihaz', style: TextStyle(color: wine, fontWeight: FontWeight.bold, fontSize: 11))
                  : IconButton(
                      tooltip: 'Uzaktan çıkış yap',
                      onPressed: () => revoke(session),
                      icon: const Icon(Icons.logout, color: wine),
                    ),
              ),
            );
          }),
      ]),
    ),
  );
}

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});
  @override State<NotificationPreferencesPage> createState() => _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState extends State<NotificationPreferencesPage> {
  final client = Supabase.instance.client;
  final Map<String, bool> values = {
    'appointments': true,
    'messages': true,
    'social': true,
    'support': true,
    'account': true,
  };
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Oturum bulunamadı.');
      final row = await client.from('notification_preferences')
        .select('appointments,messages,social,support,account')
        .eq('user_id', userId).maybeSingle();
      if (row != null && mounted) {
        setState(() {
          for (final key in values.keys) {
            values[key] = row[key] as bool? ?? true;
          }
        });
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bildirim tercihleri yüklenemedi: $error'), backgroundColor: wine),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> updateValue(String key, bool value) async {
    final previous = values[key]!;
    setState(() { values[key] = value; saving = true; });
    try {
      await client.from('notification_preferences').upsert({
        'user_id': client.auth.currentUser!.id,
        ...values,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (error) {
      if (mounted) {
        setState(() => values[key] = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tercih kaydedilemedi: $error'), backgroundColor: wine),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    const Text('Bildirim Tercihleri', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
    const SizedBox(height: 6),
    const Text('Hangi konularda bildirim almak istediğini seç.', style: TextStyle(color: muted)),
    if (loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: wine))),
    if (!loading) ...[
      SwitchListTile(
        value: values['appointments']!, activeColor: wine,
        onChanged: (value) => updateValue('appointments', value),
        title: const Text('Randevular', style: TextStyle(color: ink)),
        subtitle: const Text('Randevu onayı, iptali ve kara liste uyarıları'),
      ),
      SwitchListTile(
        value: values['messages']!, activeColor: wine,
        onChanged: (value) => updateValue('messages', value),
        title: const Text('Mesajlar', style: TextStyle(color: ink)),
        subtitle: const Text('Yeni mesaj ve sohbet hareketleri'),
      ),
      SwitchListTile(
        value: values['social']!, activeColor: wine,
        onChanged: (value) => updateValue('social', value),
        title: const Text('Sosyal etkileşimler', style: TextStyle(color: ink)),
        subtitle: const Text('Takip, beğeni, yorum ve paylaşım bildirimleri'),
      ),
      SwitchListTile(
        value: values['support']!, activeColor: wine,
        onChanged: (value) => updateValue('support', value),
        title: const Text('Destek', style: TextStyle(color: ink)),
        subtitle: const Text('Destek taleplerindeki yeni mesajlar ve durum değişiklikleri'),
      ),
      SwitchListTile(
        value: values['account']!, activeColor: wine,
        onChanged: (value) => updateValue('account', value),
        title: const Text('Hesap ve çalışan işlemleri', style: TextStyle(color: ink)),
        subtitle: const Text('Hesap güvenliği, çalışan bağlantısı ve izin bildirimleri'),
      ),
      if (saving) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Kaydediliyor…', style: TextStyle(color: muted, fontSize: 12))),
    ],
  ]);
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> notifications;
  @override
  void initState() { super.initState(); notifications = load(); }

  Future<List<Map<String, dynamic>>> load() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Oturum bulunamadı.');
    return List<Map<String, dynamic>>.from(await client.from('notifications')
      .select('id,title,body,created_at,read_at')
      .eq('user_id', userId).order('created_at', ascending: false).limit(100));
  }

  Future<void> refresh() async { final next = load(); setState(() => notifications = next); await next; }

  Future<void> markRead(String id) async {
    await client.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', id);
    await refresh();
  }

  Future<void> markAllRead(List<Map<String, dynamic>> rows) async {
    final unread = rows.where((row) => row['read_at'] == null).map((row) => row['id'] as String).toList();
    if (unread.isEmpty) return;
    await client.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()})
      .inFilter('id', unread);
    await refresh();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: notifications,
    builder: (context, snapshot) => RefreshIndicator(
      onRefresh: refresh,
      child: ListView(padding: const EdgeInsets.all(18), children: [
        Row(children: [
          const Expanded(child: Text('Bildirimler', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink))),
          if (snapshot.hasData)
            TextButton(onPressed: () => markAllRead(snapshot.data!), child: const Text('Tümünü okundu işaretle')),
        ]),
        if (snapshot.connectionState == ConnectionState.waiting)
          const Center(child: CircularProgressIndicator(color: wine))
        else if (snapshot.hasError)
          _FeedMessage(icon: Icons.cloud_off_outlined, title: 'Bildirimler yüklenemedi', detail: snapshot.error.toString())
        else if ((snapshot.data ?? []).isEmpty)
          const _FeedMessage(icon: Icons.notifications_none, title: 'Henüz bildirimin yok', detail: 'Randevu ve hesap hareketlerin burada görünecek.')
        else
          ...(snapshot.data ?? []).map((row) {
            final unread = row['read_at'] == null;
            return Card(
              color: unread ? blush.withOpacity(.45) : Colors.white,
              elevation: 0,
              child: ListTile(
                leading: Icon(unread ? Icons.notifications_active : Icons.notifications_none,
                  color: unread ? wine : muted),
                title: Text(row['title'] as String? ?? 'Bildirim',
                  style: TextStyle(color: ink, fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
                subtitle: Text(row['body'] as String? ?? '', style: const TextStyle(color: muted)),
                onTap: unread ? () => markRead(row['id'] as String) : null,
              ),
            );
          }),
      ]),
    ),
  );
}

class SupportTicketsPage extends StatefulWidget {
  final bool adminMode;
  const SupportTicketsPage({super.key, this.adminMode = false});
  @override
  State<SupportTicketsPage> createState() => _SupportTicketsPageState();
}

class _SupportTicketsPageState extends State<SupportTicketsPage> {
  final client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> tickets;
  @override
  void initState() { super.initState(); tickets = load(); }

  Future<List<Map<String, dynamic>>> load() async =>
      List<Map<String, dynamic>>.from(await client.from('support_tickets')
        .select('id,subject,status,updated_at,created_by')
        .order('updated_at', ascending: false));

  Future<void> refresh() async { final next = load(); setState(() => tickets = next); await next; }

  Future<void> createTicket() async {
    final subject = TextEditingController();
    final body = TextEditingController();
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) =>
      AlertDialog(
        title: const Text('Yeni destek talebi'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: subject, decoration: const InputDecoration(labelText: 'Konu')),
          TextField(controller: body, minLines: 2, maxLines: 5,
            decoration: const InputDecoration(labelText: 'Sorununu açıkla')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Gönder')),
        ],
      ));
    if (accepted != true) { subject.dispose(); body.dispose(); return; }
    if (subject.text.trim().length < 3 || body.text.trim().isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konu en az 3 karakter olmalı ve mesaj boş bırakılamaz.')));
      subject.dispose();
      body.dispose();
      return;
    }
    try {
      final userId = client.auth.currentUser!.id;
      final row = await client.from('support_tickets').insert({
        'created_by': userId, 'subject': subject.text.trim(),
      }).select('id').single();
      await client.from('support_ticket_messages').insert({
        'ticket_id': row['id'], 'sender_id': userId, 'body': body.text.trim(),
      });
      await refresh();
      if (mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) =>
        SupportTicketChatPage(ticketId: row['id'] as String, subject: subject.text.trim(), adminMode: false)));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Destek talebi oluşturulamadı: $error'), backgroundColor: wine));
    } finally {
      subject.dispose();
      body.dispose();
    }
  }

  String statusLabel(String status) => switch (status) {
    'in_review' => 'İnceleniyor',
    'resolved' => 'Çözüldü',
    'closed' => 'Kapatıldı',
    _ => 'Bekliyor',
  };

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: tickets,
    builder: (context, snapshot) => RefreshIndicator(
      onRefresh: refresh,
      child: ListView(padding: const EdgeInsets.all(18), children: [
        Text(widget.adminMode ? 'Destek Talepleri' : 'Yardım ve Destek',
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 12),
        if (!widget.adminMode)
          ElevatedButton.icon(onPressed: createTicket,
            icon: const Icon(Icons.add), label: const Text('Yeni destek talebi')),
        if (snapshot.connectionState == ConnectionState.waiting)
          const Center(child: CircularProgressIndicator(color: wine))
        else if (snapshot.hasError)
          _FeedMessage(icon: Icons.cloud_off_outlined, title: 'Talepler yüklenemedi', detail: snapshot.error.toString())
        else if ((snapshot.data ?? []).isEmpty)
          const _FeedMessage(icon: Icons.support_agent, title: 'Henüz destek talebi yok', detail: 'Yardıma ihtiyaç duyduğunda yeni talep oluşturabilirsin.')
        else
          ...(snapshot.data ?? []).map((ticket) => Card(
            color: Colors.white, elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.support_agent, color: wine),
              title: Text(ticket['subject'] as String? ?? 'Destek talebi',
                style: const TextStyle(color: ink, fontWeight: FontWeight.w600)),
              subtitle: Text(statusLabel(ticket['status'] as String? ?? 'pending'),
                style: const TextStyle(color: muted)),
              trailing: const Icon(Icons.chevron_right, color: muted),
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  SupportTicketChatPage(
                    ticketId: ticket['id'] as String,
                    subject: ticket['subject'] as String? ?? 'Destek',
                    adminMode: widget.adminMode,
                  )));
                if (mounted) refresh();
              },
            ),
          )),
      ]),
    ),
  );
}

class SupportTicketChatPage extends StatefulWidget {
  final String ticketId;
  final String subject;
  final bool adminMode;
  const SupportTicketChatPage({super.key, required this.ticketId, required this.subject, required this.adminMode});
  @override
  State<SupportTicketChatPage> createState() => _SupportTicketChatPageState();
}

class _SupportTicketChatPageState extends State<SupportTicketChatPage> {
  final client = Supabase.instance.client;
  final controller = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> messages;
  String status = 'pending';
  bool sending = false;

  @override
  void initState() {
    super.initState();
    loadStatus();
    messages = client.from('support_ticket_messages').stream(primaryKey: ['id'])
      .eq('ticket_id', widget.ticketId).order('created_at')
      .map((rows) => rows.map((row) => Map<String, dynamic>.from(row)).toList());
  }

  Future<void> loadStatus() async {
    try {
      final row = await client.from('support_tickets').select('status')
        .eq('id', widget.ticketId).single();
      if (mounted) setState(() => status = row['status'] as String? ?? 'pending');
    } catch (_) {}
  }

  Future<void> send() async {
    final body = controller.text.trim();
    if (sending || body.isEmpty || status == 'closed') return;
    setState(() => sending = true);
    try {
      await client.from('support_ticket_messages').insert({
        'ticket_id': widget.ticketId,
        'sender_id': client.auth.currentUser!.id,
        'body': body,
      });
      await client.from('support_tickets').update({'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', widget.ticketId);
      controller.clear();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesaj gönderilemedi: $error'), backgroundColor: wine));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> changeStatus(String value) async {
    try {
      await client.from('support_tickets').update({
        'status': value,
        'closed_at': value == 'closed' ? DateTime.now().toUtc().toIso8601String() : null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.ticketId);
      if (mounted) setState(() => status = value);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Talep durumu değiştirilemedi: $error'), backgroundColor: wine));
    }
  }

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: cream,
    appBar: AppBar(
      title: Text(widget.subject, style: const TextStyle(color: wine, fontWeight: FontWeight.bold)),
      actions: [
        if (widget.adminMode)
          PopupMenuButton<String>(
            onSelected: changeStatus,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pending', child: Text('Bekliyor')),
              PopupMenuItem(value: 'in_review', child: Text('İnceleniyor')),
              PopupMenuItem(value: 'resolved', child: Text('Çözüldü')),
              PopupMenuItem(value: 'closed', child: Text('Kapat')),
            ],
          )
        else if (status != 'closed')
          TextButton(onPressed: () => changeStatus('closed'), child: const Text('Talebi kapat')),
      ],
    ),
    body: Column(children: [
      Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: messages,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: wine));
          final userId = client.auth.currentUser?.id;
          return ListView(padding: const EdgeInsets.all(16), children: snapshot.data!.map((message) {
            final mine = message['sender_id'] == userId;
            return Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .8),
                decoration: BoxDecoration(color: mine ? wine : Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Text(message['body'] as String? ?? '', style: TextStyle(color: mine ? Colors.white : ink)),
              ),
            );
          }).toList());
        },
      )),
      if (status != 'closed')
        SafeArea(child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: TextField(controller: controller, minLines: 1, maxLines: 4,
              decoration: const InputDecoration(hintText: 'Mesajını yaz...'))),
            IconButton(onPressed: sending ? null : send, icon: const Icon(Icons.send, color: wine)),
          ]),
        ))
      else
        const Padding(padding: EdgeInsets.all(16), child: Text('Bu destek talebi kapatıldı.', style: TextStyle(color: muted))),
    ]),
  );
}

class EmployeeSchedulePage extends StatefulWidget {
  const EmployeeSchedulePage({super.key});
  @override State<EmployeeSchedulePage> createState() => _EmployeeSchedulePageState();
}
class _EmployeeSchedulePageState extends State<EmployeeSchedulePage> {
  final client = Supabase.instance.client;
  final labels = const ['Pazar','Pazartesi','Salı','Çarşamba','Perşembe','Cuma','Cumartesi'];
  String? employeeId;
  List<Map<String, dynamic>> days = [];
  bool loading = true, saving = false;
  @override void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) throw Exception('Oturum bulunamadı.');
      final employee = await client.from('employees').select('id,business_id')
        .eq('user_id', user.id).eq('is_active', true).maybeSingle();
      if (employee == null) throw Exception('Aktif çalışan kaydı bulunamadı.');
      employeeId = employee['id'] as String;
      final results = await Future.wait([
        client.from('employee_working_hours').select('weekday,opens_at,closes_at,is_closed').eq('employee_id', employeeId!),
        client.from('business_hours').select('weekday,opens_at,closes_at,is_closed').eq('business_id', employee['business_id']),
      ]);
      final own = {for (final row in results[0]) row['weekday'] as int: row};
      final business = {for (final row in results[1]) row['weekday'] as int: row};
      days = List.generate(7, (index) {
        final row = own[index] ?? business[index];
        return {'weekday': index,
          'opens_at': row?['opens_at']?.toString().substring(0,5) ?? '09:00',
          'closes_at': row?['closes_at']?.toString().substring(0,5) ?? '18:00',
          'is_closed': row?['is_closed'] as bool? ?? (index == 0)};
      });
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Çalışma saatleri yüklenemedi: $error'), backgroundColor: wine));
    } finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> chooseTime(int day, String field) async {
    final parts = (days[day][field] as String).split(':');
    final selected = await showTimePicker(context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])));
    if (selected == null) return;
    setState(() => days[day][field] = '${selected.hour.toString().padLeft(2,'0')}:${selected.minute.toString().padLeft(2,'0')}');
  }

  Future<void> save() async {
    if (employeeId == null) return;
    setState(() => saving = true);
    try {
      await client.from('employee_working_hours').upsert(
        days.map((day) => {...day, 'employee_id': employeeId}).toList(),
        onConflict: 'employee_id,weekday');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çalışma saatlerin kaydedildi.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saatler kaydedilemedi: $error'), backgroundColor: wine));
    } finally { if (mounted) setState(() => saving = false); }
  }

  @override Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: wine));
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Çalışma Saatlerim', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
      const Text('Randevu saatleri işletmenin açık olduğu zamanlarla birlikte bu programa göre hesaplanır.', style: TextStyle(color: muted)),
      ...days.asMap().entries.map((entry) {
        final index = entry.key, day = entry.value;
        return Card(color: Colors.white, elevation: 0, child: Padding(padding: const EdgeInsets.all(10),
          child: Column(children: [
            SwitchListTile(contentPadding: EdgeInsets.zero,
              title: Text(labels[index], style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
              subtitle: Text(day['is_closed'] == true ? 'Kapalı' : '${day['opens_at']} – ${day['closes_at']}', style: const TextStyle(color: muted)),
              value: day['is_closed'] != true,
              onChanged: (open) => setState(() => day['is_closed'] = !open), activeColor: wine),
            if (day['is_closed'] != true)
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => chooseTime(index, 'opens_at'), child: Text('Açılış ${day['opens_at']}'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => chooseTime(index, 'closes_at'), child: Text('Kapanış ${day['closes_at']}'))),
              ]),
          ])));
      }),
      ElevatedButton(onPressed: saving ? null : save, child: saving ? const CircularProgressIndicator() : const Text('Çalışma saatlerini kaydet')),
    ]);
  }
}

class EmployeeTimeOffPage extends StatefulWidget {
  const EmployeeTimeOffPage({super.key});
  @override State<EmployeeTimeOffPage> createState() => _EmployeeTimeOffPageState();
}
class _EmployeeTimeOffPageState extends State<EmployeeTimeOffPage> {
  final client = Supabase.instance.client;
  final reason = TextEditingController();
  String? employeeId;
  DateTime start = DateTime.now().add(const Duration(days: 1));
  DateTime end = DateTime.now().add(const Duration(days: 1));
  late Future<List<Map<String, dynamic>>> requests;
  bool loading = true, sending = false;
  @override void initState() { super.initState(); load(); }
  @override void dispose() { reason.dispose(); super.dispose(); }

  Future<void> load() async {
    try {
      final employee = await client.from('employees').select('id')
        .eq('user_id', client.auth.currentUser!.id).eq('is_active', true).single();
      employeeId = employee['id'] as String;
      requests = client.from('employee_time_off').select('id,starts_at,ends_at,reason,status')
        .eq('employee_id', employeeId!).order('created_at', ascending: false)
        .then((rows) => List<Map<String, dynamic>>.from(rows));
    } catch (error) { requests = Future.error(error); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> chooseDate(bool isStart) async {
    final selected = await showDatePicker(context: context, initialDate: isStart ? start : end,
      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (selected == null) return;
    setState(() { if (isStart) { start = selected; if (end.isBefore(start)) end = start; } else { end = selected; } });
  }

  Future<void> submit() async {
    if (employeeId == null || end.isBefore(start)) return;
    setState(() => sending = true);
    try {
      await client.from('employee_time_off').insert({
        'employee_id': employeeId,
        'starts_at': DateTime(start.year,start.month,start.day).toUtc().toIso8601String(),
        'ends_at': DateTime(end.year,end.month,end.day,23,59,59).toUtc().toIso8601String(),
        'reason': reason.text.trim(),
      });
      reason.clear(); await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İzin talebin işletme sahibine iletildi.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İzin talebi gönderilemedi: $error'), backgroundColor: wine));
    } finally { if (mounted) setState(() => sending = false); }
  }

  @override Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: wine));
    return FutureBuilder<List<Map<String, dynamic>>>(future: requests, builder: (context, snapshot) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        const Text('İzin Talebi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
        OutlinedButton(onPressed: () => chooseDate(true), child: Text('Başlangıç: ${start.day}.${start.month}.${start.year}')),
        OutlinedButton(onPressed: () => chooseDate(false), child: Text('Bitiş: ${end.day}.${end.month}.${end.year}')),
        TextField(controller: reason, decoration: const InputDecoration(labelText: 'Açıklama (isteğe bağlı)')),
        ElevatedButton(onPressed: sending ? null : submit, child: sending ? const CircularProgressIndicator() : const Text('İzin talebi gönder')),
        const SectionTitle('İzin geçmişim'),
        if (snapshot.hasError) Text('İzinler yüklenemedi: ${snapshot.error}', style: const TextStyle(color: wine))
        else ...(snapshot.data ?? []).map((row) => Card(color: Colors.white, elevation: 0, child: ListTile(
          title: Text('${DateTime.parse(row['starts_at'] as String).toLocal().day} – ${DateTime.parse(row['ends_at'] as String).toLocal().day}', style: const TextStyle(color: ink)),
          subtitle: Text(row['reason'] as String? ?? '', style: const TextStyle(color: muted)),
          trailing: Text(switch (row['status']) { 'approved' => 'Onaylandı', 'rejected' => 'Reddedildi', _ => 'Bekliyor' }, style: const TextStyle(color: wine)),
        ))),
      ]));
  }
}

class OwnerTimeOffPage extends StatefulWidget {
  const OwnerTimeOffPage({super.key});
  @override State<OwnerTimeOffPage> createState() => _OwnerTimeOffPageState();
}
class _OwnerTimeOffPageState extends State<OwnerTimeOffPage> {
  final client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> requests;
  @override void initState() { super.initState(); requests = load(); }
  Future<List<Map<String, dynamic>>> load() async {
    final business = await client.from('businesses').select('id').eq('owner_id', client.auth.currentUser!.id).single();
    final employees = await client.from('employees').select('id').eq('business_id', business['id']);
    final ids = employees.map((e) => e['id'] as String).toList();
    if (ids.isEmpty) return [];
    return List<Map<String, dynamic>>.from(await client.from('employee_time_off')
      .select('id,employee_id,starts_at,ends_at,reason,status,employees(display_name)')
      .inFilter('employee_id', ids).order('created_at', ascending: false));
  }
  Future<void> review(Map<String, dynamic> row, String status) async {
    try {
      await client.from('employee_time_off').update({'status': status, 'reviewed_by': client.auth.currentUser!.id}).eq('id', row['id']);
      final next = load(); setState(() => requests = next); await next;
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İzin talebi güncellenemedi: $error'), backgroundColor: wine));
    }
  }
  @override Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(future: requests,
    builder: (context, snapshot) => ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Çalışan İzin Talepleri', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
      if (snapshot.connectionState == ConnectionState.waiting) const Center(child: CircularProgressIndicator(color: wine))
      else if (snapshot.hasError) Text('İzin talepleri yüklenemedi: ${snapshot.error}', style: const TextStyle(color: wine))
      else if ((snapshot.data ?? []).isEmpty) const Text('Henüz izin talebi yok.', style: TextStyle(color: muted))
      else ...(snapshot.data ?? []).map((row) {
        final employee = row['employees'] is Map ? row['employees'] as Map : {};
        return Card(color: Colors.white, elevation: 0, child: Padding(padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(employee['display_name'] as String? ?? 'Çalışan', style: const TextStyle(fontWeight: FontWeight.w700, color: ink)),
            Text('${DateTime.parse(row['starts_at'] as String).toLocal()} – ${DateTime.parse(row['ends_at'] as String).toLocal()}', style: const TextStyle(color: muted, fontSize: 12)),
            Text(row['reason'] as String? ?? '', style: const TextStyle(color: muted)),
            Text('Durum: ${row['status']}', style: const TextStyle(color: wine)),
            if (row['status'] == 'pending') Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => review(row, 'rejected'), child: const Text('Reddet'))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(onPressed: () => review(row, 'approved'), child: const Text('Onayla'))),
            ]),
          ])));
      }),
    ]));
}

class MyFollowingPage extends StatefulWidget {
  const MyFollowingPage({super.key});
  @override State<MyFollowingPage> createState() => _MyFollowingPageState();
}
class _MyFollowingPageState extends State<MyFollowingPage> {
  final client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> following;
  @override void initState() { super.initState(); following = load(); }

  Future<List<Map<String, dynamic>>> load() async {
    final userId = client.auth.currentUser!.id;
    final rows = await client.from('feed_follows')
      .select('id,followed_user_id,followed_business_id')
      .eq('follower_user_id', userId).order('created_at', ascending: false);
    final userIds = rows.map((r) => r['followed_user_id'] as String?).whereType<String>().toSet().toList();
    final businessIds = rows.map((r) => r['followed_business_id'] as String?).whereType<String>().toSet().toList();
    final profiles = userIds.isEmpty ? [] : await client.from('public_profiles')
      .select('id,full_name,avatar_url').inFilter('id', userIds);
    final businesses = businessIds.isEmpty ? [] : await client.from('businesses')
      .select('id,name,logo_url').inFilter('id', businessIds);
    final profileMap = {for (final p in profiles) p['id'] as String: p};
    final businessMap = {for (final b in businesses) b['id'] as String: b};
    return rows.map((row) {
      final businessId = row['followed_business_id'] as String?;
      final userId = row['followed_user_id'] as String?;
      if (businessId != null) {
        final b = businessMap[businessId] ?? {};
        return {'id': row['id'], 'target_id': businessId, 'is_business': true,
          'name': b['name'] ?? 'İşletme', 'avatar': b['logo_url']};
      }
      final targetUserId = userId!;
      final p = profileMap[targetUserId] ?? {};
      return {'id': row['id'], 'target_id': targetUserId, 'is_business': false,
        'name': p['full_name'] ?? 'Kullanıcı', 'avatar': p['avatar_url']};
    }).toList();
  }

  Future<void> unfollow(Map<String, dynamic> item) async {
    try {
      final userId = client.auth.currentUser!.id;
      if (item['is_business'] == true) {
        await client.from('feed_follows').delete().eq('follower_user_id', userId)
          .eq('followed_business_id', item['target_id']);
      } else {
        await client.from('feed_follows').delete().eq('follower_user_id', userId)
          .eq('followed_user_id', item['target_id']);
      }
      final next = load(); setState(() => following = next); await next;
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Takip kaldırılamadı: $error'), backgroundColor: wine));
    }
  }

  @override Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: following,
    builder: (context, snapshot) => ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Takip Ettiklerim', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
      if (snapshot.connectionState == ConnectionState.waiting)
        const Center(child: CircularProgressIndicator(color: wine))
      else if (snapshot.hasError)
        Text('Takip listesi yüklenemedi: ${snapshot.error}', style: const TextStyle(color: wine))
      else if ((snapshot.data ?? []).isEmpty)
        const Text('Henüz takip ettiğin işletme veya çalışan yok.', style: TextStyle(color: muted))
      else
        ...(snapshot.data ?? []).map((item) {
          final avatar = item['avatar'] as String?;
          return Card(color: Colors.white, elevation: 0, child: ListTile(
            leading: CircleAvatar(backgroundColor: blush,
              backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar == null || avatar.isEmpty ? Icon(item['is_business'] == true ? Icons.storefront : Icons.person, color: wine) : null),
            title: Text(item['name'] as String, style: const TextStyle(color: ink, fontWeight: FontWeight.w600)),
            subtitle: Text(item['is_business'] == true ? 'İşletme' : 'Çalışan', style: const TextStyle(color: muted)),
            trailing: TextButton(onPressed: () => unfollow(item), child: const Text('Takibi bırak')),
          ));
        }),
    ]),
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final client = Supabase.instance.client;
  late Future<Map<String, dynamic>> profile;
  bool uploading = false;

  @override
  void initState() { super.initState(); profile = loadProfile(); }
  Future<Map<String, dynamic>> loadProfile() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Oturum bulunamadı.');
    final publicProfile = Map<String, dynamic>.from(await client.from('public_profiles')
      .select('id,full_name,account_type,avatar_url').eq('id', user.id).single());
    final contactRows = await client.rpc('get_my_profile_contact') as List;
    final contact = contactRows.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(contactRows.first as Map);
    final row = <String, dynamic>{
      ...publicProfile,
      'email': user.email ?? '',
      'phone': contact['phone'] ?? '',
      'full_name': contact['full_name'] ?? publicProfile['full_name'],
    };
    if (row['account_type'] == 'customer') {
      final memberships = await client.from('business_memberships')
          .select('business_id,businesses(name,address)')
          .eq('customer_id', user.id);
      row['memberships'] = memberships.map((item) => Map<String, dynamic>.from(item)).toList();
    } else {
      row['memberships'] = <Map<String, dynamic>>[];
    }
    return row;
  }

  Future<void> joinBusiness() async {
    final code = TextEditingController();
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) =>
      AlertDialog(
        title: const Text('İşletmeye katıl'),
        content: TextField(controller: code, textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'İşletme katılım kodu')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Katıl')),
        ],
      ));
    if (accepted == true && code.text.trim().isNotEmpty) {
      try {
        await client.rpc('join_business_by_code', params: {'p_code': code.text.trim()});
        await refreshProfile();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İşletmeye başarıyla katıldın.')));
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İşletmeye katılınamadı: $error'), backgroundColor: wine));
      }
    }
    code.dispose();
  }

  Future<void> leaveBusiness(String businessId) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) =>
      AlertDialog(
        title: const Text('İşletmeden ayrıl'),
        content: const Text('Bu işletmeyle bağlantın kaldırılacak. Devam etmek istiyor musun?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Ayrıl')),
        ],
      ));
    if (confirmed != true) return;
    try {
      await client.rpc('leave_business', params: {'p_business_id': businessId});
      await refreshProfile();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşletmeden ayrılamadın: $error'), backgroundColor: wine));
    }
  }
  Future<void> refreshProfile() async { final next = loadProfile(); setState(() => profile = next); await next; }

  Future<void> editPhone(String current) async {
    final controller = TextEditingController(text: current);
    final save = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Telefon numarası'),
      content: TextField(controller: controller, keyboardType: TextInputType.phone,
        maxLength: 13, decoration: const InputDecoration(hintText: '05xx xxx xx xx', prefixIcon: Icon(Icons.phone))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
        ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Kaydet')),
      ],
    ));
    if (save == true) {
      try {
        final normalized = controller.text.replaceAll(RegExp(r'[^0-9+]'), '');
        final digits = normalized.startsWith('+90')
            ? normalized.substring(3)
            : normalized.startsWith('90') && normalized.length == 12
                ? normalized.substring(2)
                : normalized.startsWith('0')
                    ? normalized.substring(1)
                    : normalized;
        if (!RegExp(r'^5[0-9]{9}$').hasMatch(digits)) {
          throw Exception('05 ile başlayan 11 haneli geçerli bir cep telefonu gir.');
        }
        await client.from('profiles').update({'phone': '0$digits'})
          .eq('id', client.auth.currentUser!.id);
        await refreshProfile();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Telefon numaran güncellendi.')));
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Telefon güncellenemedi: $error'), backgroundColor: wine));
      }
    }
    controller.dispose();
  }

  Future<void> changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) =>
      AlertDialog(
        title: const Text('Şifre değiştir'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: current, obscureText: true,
            decoration: const InputDecoration(labelText: 'Mevcut şifre')),
          TextField(controller: next, obscureText: true,
            decoration: const InputDecoration(labelText: 'Yeni şifre')),
          TextField(controller: confirm, obscureText: true,
            decoration: const InputDecoration(labelText: 'Yeni şifre tekrar')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Değiştir')),
        ],
      ));
    if (accepted == true) {
      try {
        if (next.text.length < 8 || next.text != confirm.text) {
          throw Exception('Yeni şifre en az 8 karakter olmalı ve iki alan eşleşmeli.');
        }
        final userEmail = client.auth.currentUser?.email;
        if (userEmail == null) throw Exception('Hesap e-postası bulunamadı.');
        await client.auth.signInWithPassword(email: userEmail, password: current.text);
        await client.auth.updateUser(UserAttributes(password: next.text));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şifren başarıyla değiştirildi.')));
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Şifre değiştirilemedi: $error'), backgroundColor: wine));
      }
    }
    current.dispose();
    next.dispose();
    confirm.dispose();
  }

  Future<void> uploadAvatar() async {
    final user = client.auth.currentUser;
    if (user == null || uploading) return;
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 2048, maxHeight: 2048);
    if (image == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 88,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Profil Fotoğrafını Düzenle',
          toolbarColor: wine,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Profil Fotoğrafını Düzenle',
          aspectRatioLockEnabled: true,
        ),
      ],
    );
    if (cropped == null) return;
    setState(() => uploading = true);
    try {
      final file = File(cropped.path);
      if (await file.length() > 5 * 1024 * 1024) throw Exception('Fotoğraf 5 MB sınırını aşıyor.');
      const contentType = 'image/jpeg';
      final path = 'profiles/${user.id}/avatar.jpg';
      await client.storage.from('salon-avatars').upload(path, file,
        fileOptions: FileOptions(upsert: true, contentType: contentType));
      final url = client.storage.from('salon-avatars').getPublicUrl(path);
      await client.from('profiles').update({'avatar_url': url}).eq('id', user.id);
      await refreshProfile();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil fotoğrafı yüklenemedi: $error'), backgroundColor: wine),
      );
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> deleteAccount() async {
    final password = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) =>
      AlertDialog(
        title: const Text('Hesabını kalıcı olarak sil'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Hesabın ve hesabına bağlı kişisel verilerin silinmesini onaylıyor musun? Bu işlem geri alınamaz.'),
          const SizedBox(height: 12),
          TextField(controller: password, obscureText: true,
            decoration: const InputDecoration(labelText: 'Mevcut şifren')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hesabımı sil', style: TextStyle(color: wine))),
        ],
      ));
    if (confirmed != true) { password.dispose(); return; }
    try {
      await client.functions.invoke('delete-my-account', body: {'password': password.text});
      await client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const KuaforumApp(autoResume: false)),
        (route) => false,
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hesap silinemedi: $error'), backgroundColor: wine));
    } finally {
      password.dispose();
    }
  }

  Future<void> leaveEmployeeBusiness() async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) =>
      AlertDialog(
        title: const Text('İşletmeden ayrıl'),
        content: const Text('Çalışan bağlantın kaldırılacak ve hesabın müşteri hesabına dönecek. Daha sonra başka bir işletmeye katılabilirsin. Devam edilsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ayrıl', style: TextStyle(color: wine))),
        ],
      ));
    if (confirmed != true) return;
    try {
      await client.rpc('leave_employee_business');
      await client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const KuaforumApp(autoResume: false)),
        (route) => false,
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşletmeden ayrılamadın: $error'), backgroundColor: wine),
      );
    }
  }

  Future<void> logout() async {
    await client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const KuaforumApp(autoResume: false)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: profile,
    builder: (context, snapshot) => PageBody(children: [
      Center(child: Stack(children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: blush,
          backgroundImage: snapshot.data?['avatar_url'] != null ? NetworkImage(snapshot.data!['avatar_url'].toString()) : null,
          child: snapshot.data?['avatar_url'] == null ? const Icon(Icons.person, size: 55, color: wine) : null,
        ),
        Positioned(right: 0, bottom: 0, child: IconButton.filled(
          style: IconButton.styleFrom(backgroundColor: wine),
          onPressed: uploading ? null : uploadAvatar,
          icon: uploading ? const SizedBox(width: 18,height: 18,child: CircularProgressIndicator(strokeWidth: 2,color: Colors.white)) : const Icon(Icons.camera_alt, color: Colors.white, size: 18),
        )),
      ])),
      const SizedBox(height: 10),
      if (snapshot.connectionState == ConnectionState.waiting)
        const Center(child: CircularProgressIndicator(color: wine))
      else if (snapshot.hasError)
        Text('Profil yüklenemedi: ${snapshot.error}', style: const TextStyle(color: wine))
      else ...[
        Text(snapshot.data!['full_name']?.toString() ?? 'Kuaförüm kullanıcısı',
          textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink)),
        Text(snapshot.data!['email']?.toString() ?? '', textAlign: TextAlign.center, style: const TextStyle(color: muted)),
        Text(snapshot.data!['phone']?.toString() ?? 'Telefon eklenmemiş', textAlign: TextAlign.center, style: const TextStyle(color: muted)),
        const SizedBox(height: 20),
        ...[
          ('Telefon numarasını düzenle', Icons.phone_outlined, () => editPhone(snapshot.data!['phone']?.toString() ?? '')),
          ('Şifre değiştir', Icons.lock_outline, changePassword),
          ('Randevularım', Icons.calendar_month, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppointmentsPage(title: 'Randevularım')))),
          ('Yardım ve Destek', Icons.support_agent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportTicketsPage()))),
          ('Bildirim Tercihleri', Icons.notifications_active_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Bildirim Tercihleri')), body: const NotificationPreferencesPage())))),
          ('Aktif Cihazlar', Icons.devices_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Aktif Cihazlar')), body: const ActiveSessionsPage())))),
          ('Çıkış Yap', Icons.logout, logout),
          if (snapshot.data!['account_type'] == 'customer') ('Hesabı kalıcı sil', Icons.delete_forever, deleteAccount),
        ].map((item) => Card(color: Colors.white, elevation: 0, child: ListTile(
          leading: Icon(item.$2, color: wine),
          title: Text(item.$1, style: const TextStyle(color: ink, fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right, color: muted),
          onTap: item.$3,
        ))),
        if (snapshot.data!['account_type'] == 'employee') ...[
          Card(color: Colors.white, elevation: 0, child: ListTile(
            leading: const Icon(Icons.link_off, color: wine),
            title: const Text('İşletmeden ayrıl', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: muted),
            onTap: leaveEmployeeBusiness,
          )),
          const SectionTitle('Çalışma ve İzin'),
          Card(color: Colors.white, elevation: 0, child: ListTile(
            leading: const Icon(Icons.schedule, color: wine),
            title: const Text('Çalışma saatlerim', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: muted),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
              appBar: AppBar(title: Text('Çalışma Saatlerim')), body: EmployeeSchedulePage()))),
          )),
          Card(color: Colors.white, elevation: 0, child: ListTile(
            leading: const Icon(Icons.event_busy, color: wine),
            title: const Text('İzin talebi', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: muted),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
              appBar: AppBar(title: Text('İzin Talebi')), body: EmployeeTimeOffPage()))),
          )),
        ],
        if (snapshot.data!['account_type'] == 'customer') ...[
          Card(color: Colors.white, elevation: 0, child: ListTile(
            leading: const Icon(Icons.favorite_border, color: wine),
            title: const Text('Takip ettiklerim', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: muted),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
              appBar: AppBar(title: Text('Takip Ettiklerim')), body: MyFollowingPage()))),
          )),
          const SectionTitle('İşletmelerim'),
          ...(snapshot.data!['memberships'] as List<Map<String, dynamic>>).map((membership) {
            final business = membership['businesses'] is Map
                ? Map<String, dynamic>.from(membership['businesses'] as Map)
                : <String, dynamic>{};
            return Card(color: Colors.white, elevation: 0, child: ListTile(
              leading: const Icon(Icons.storefront_outlined, color: wine),
              title: Text(business['name'] as String? ?? 'İşletme', style: const TextStyle(color: ink)),
              subtitle: Text(business['address'] as String? ?? '', style: const TextStyle(color: muted)),
              trailing: TextButton(onPressed: () => leaveBusiness(membership['business_id'] as String),
                child: const Text('Ayrıl')),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessProfilePage(
                businessId: membership['business_id'] as String,
              ))),
            ));
          }),
          Card(color: Colors.white, elevation: 0, child: ListTile(
            leading: const Icon(Icons.add_business_outlined, color: wine),
            title: const Text('İşletmeye katıl', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: muted),
            onTap: joinBusiness,
          )),
        ],
      ],
    ]),
  );
}
class BusinessProfilePage extends StatefulWidget {
  final String businessId;
  const BusinessProfilePage({super.key, required this.businessId});
  @override State<BusinessProfilePage> createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends State<BusinessProfilePage> {
  final client = Supabase.instance.client;
  final feedRepository = KuaforumFeedRepository();
  final messagingRepository = KuaforumMessagingRepository();
  late Future<Map<String, dynamic>> data;
  bool following = false;
  bool followBusy = false;

  @override
  void initState() {
    super.initState();
    data = load();
  }

  Future<Map<String, dynamic>> load() async {
    final business = Map<String, dynamic>.from(await client.from('businesses')
      .select('id,name,address,logo_url,is_temporarily_closed')
      .eq('id', widget.businessId).eq('status', 'active').single());
    final results = await Future.wait([
      client.from('services').select('id,name,price,duration_minutes')
        .eq('business_id', widget.businessId).eq('is_active', true).order('name'),
      client.from('public_business_employees').select('id,display_name,avatar_url')
        .eq('business_id', widget.businessId).order('display_name'),
      client.from('business_reviews').select('id,customer_id,rating,body,created_at')
        .eq('business_id', widget.businessId).order('created_at', ascending: false).limit(30),
      client.from('feed_follows').select('id').eq('followed_business_id', widget.businessId),
    ]);
    final services = List<Map<String, dynamic>>.from(results[0]);
    final employees = List<Map<String, dynamic>>.from(results[1]);
    final reviews = List<Map<String, dynamic>>.from(results[2]);
    final followers = results[3] as List;
    final customerIds = reviews.map((r) => r['customer_id'] as String).toSet().toList();
    final profiles = customerIds.isEmpty ? [] : await client.from('public_profiles')
      .select('id,full_name,avatar_url').inFilter('id', customerIds);
    final profileMap = {for (final p in profiles) p['id'] as String: p};
    for (final review in reviews) {
      review['customer_profile'] = profileMap[review['customer_id']] ?? {};
    }
    final posts = await feedRepository.fetchBusinessFeed(widget.businessId);
    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      following = await feedRepository.isFollowingBusiness(widget.businessId);
    }
    return {
      'business': business,
      'services': services,
      'employees': employees,
      'reviews': reviews,
      'followers': followers.length,
      'posts': posts,
    };
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => data = next);
    await next;
  }

  Future<void> toggleFollow() async {
    if (followBusy) return;
    setState(() { followBusy = true; following = !following; });
    try {
      if (following) {
        await feedRepository.followBusiness(widget.businessId);
      } else {
        await feedRepository.unfollowBusiness(widget.businessId);
      }
    } catch (error) {
      if (mounted) {
        setState(() => following = !following);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Takip durumu güncellenemedi: $error'), backgroundColor: wine),
        );
      }
    } finally {
      if (mounted) setState(() => followBusy = false);
    }
  }

  Future<void> messageBusiness(String businessName) async {
    try {
      final conversationId = await messagingRepository.startBusinessConversation(widget.businessId);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(
        conversationId: conversationId,
        title: businessName,
        subtitle: 'İşletme',
      )));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşletmeye mesaj gönderilemedi: $error'), backgroundColor: wine),
      );
    }
  }

  Future<void> bookAppointment(String businessName) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      appBar: AppBar(title: Text(businessName)),
      body: BusinessBookingPage(businessId: widget.businessId, businessName: businessName),
    )));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: data,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator(color: wine)));
      }
      if (snapshot.hasError || snapshot.data == null) {
        return Scaffold(appBar: AppBar(), body: Center(
          child: Text('İşletme profili yüklenemedi: ${snapshot.error ?? ''}', style: const TextStyle(color: wine)),
        ));
      }
      final business = snapshot.data!['business'] as Map<String, dynamic>;
      final services = snapshot.data!['services'] as List<Map<String, dynamic>>;
      final employees = snapshot.data!['employees'] as List<Map<String, dynamic>>;
      final reviews = snapshot.data!['reviews'] as List<Map<String, dynamic>>;
      final posts = snapshot.data!['posts'] as List<KuaforumFeedPost>;
      final rawLogo = business['logo_url'] as String?;
      final logo = rawLogo == null || rawLogo.isEmpty ? null :
        (rawLogo.startsWith('http') ? rawLogo : client.storage.from('salon-avatars').getPublicUrl(rawLogo));
      final average = reviews.isEmpty ? 'Yeni' :
        (reviews.fold<double>(0, (sum, r) => sum + ((r['rating'] as num?)?.toDouble() ?? 0)) / reviews.length).toStringAsFixed(1);
      final closed = business['is_temporarily_closed'] == true;
      return Scaffold(
        backgroundColor: cream,
        appBar: AppBar(title: const Text('İşletme Profili')),
        body: RefreshIndicator(
          color: wine,
          onRefresh: refresh,
          child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
            Center(child: CircleAvatar(
              radius: 48, backgroundColor: blush,
              backgroundImage: logo == null ? null : NetworkImage(logo),
              child: logo == null ? const Icon(Icons.storefront, size: 48, color: wine) : null,
            )),
            const SizedBox(height: 10),
            Text(business['name'] as String? ?? 'Kuaför', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: ink)),
            Text(business['address'] as String? ?? 'Adres belirtilmemiş',
              textAlign: TextAlign.center, style: const TextStyle(color: muted)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.star_rounded, color: Color(0xFFE5A93D), size: 20),
              const SizedBox(width: 4),
              Text('$average  •  ${reviews.length} değerlendirme  •  ${snapshot.data!['followers']} takipçi',
                style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
            if (closed) const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('İşletme şu anda geçici olarak kapalı.', textAlign: TextAlign.center,
                style: TextStyle(color: wine, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: followBusy ? null : toggleFollow,
              icon: Icon(following ? Icons.favorite : Icons.favorite_border),
              label: Text(following ? 'Takip ediliyor' : 'İşletmeyi takip et'),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => messageBusiness(business['name'] as String? ?? 'İşletme'),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('İşletmeye mesaj gönder'),
            ),
            const SectionTitle('Hizmetler'),
            if (services.isEmpty) const Text('Henüz hizmet eklenmemiş.', style: TextStyle(color: muted))
            else ...services.map((service) => Card(
              color: Colors.white, elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.content_cut, color: wine),
                title: Text(service['name'] as String? ?? 'Hizmet', style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
                subtitle: Text('${service['duration_minutes']} dakika', style: const TextStyle(color: muted)),
                trailing: Text('${service['price']} ₺', style: const TextStyle(color: wine, fontWeight: FontWeight.w800)),
              ),
            )),
            const SectionTitle('Çalışanlarımız'),
            if (employees.isEmpty) const Text('Henüz aktif çalışan bulunmuyor.', style: TextStyle(color: muted))
            else ...employees.map((employee) {
              final avatar = employee['avatar_url'] as String?;
              return Card(
                color: Colors.white, elevation: 0,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: blush,
                    backgroundImage: avatar == null || avatar.isEmpty ? null : NetworkImage(avatar),
                    child: avatar == null || avatar.isEmpty ? const Icon(Icons.person, color: wine) : null,
                  ),
                  title: Text(employee['display_name'] as String? ?? 'Çalışan', style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
                ),
              );
            }),
            const SectionTitle('Paylaşımlar'),
            if (posts.isEmpty) const Text('Bu işletme henüz paylaşım yapmamış.', style: TextStyle(color: muted))
            else ...posts.map((post) => LiveFeedPostCard(post: post, repository: feedRepository)),
            const SectionTitle('Müşteri Değerlendirmeleri'),
            if (reviews.isEmpty) const Text('Henüz değerlendirme yok.', style: TextStyle(color: muted))
            else ...reviews.map((review) {
              final profile = review['customer_profile'] is Map ? review['customer_profile'] as Map : {};
              return Card(color: Colors.white, elevation: 0, child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(profile['full_name'] as String? ?? 'Müşteri',
                      style: const TextStyle(color: ink, fontWeight: FontWeight.w700))),
                    const Icon(Icons.star_rounded, color: Color(0xFFE5A93D), size: 18),
                    Text(' ${review['rating']}/5', style: const TextStyle(color: ink, fontWeight: FontWeight.bold)),
                  ]),
                  if ((review['body'] as String? ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(review['body'] as String, style: const TextStyle(color: muted, height: 1.4)),
                  ],
                ]),
              ));
            }),
          ]),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.all(14),
          child: SizedBox(height: 50, child: FilledButton(
            onPressed: closed ? null : () => bookAppointment(business['name'] as String? ?? 'İşletme'),
            style: FilledButton.styleFrom(backgroundColor: wine, foregroundColor: Colors.white),
            child: Text(closed ? 'Geçici olarak kapalı' : 'Randevu al'),
          )),
        ),
      );
    },
  );
}

class BusinessBookingPage extends StatefulWidget {
  final String businessId;
  final String businessName;
  const BusinessBookingPage({super.key, required this.businessId, required this.businessName});
  @override
  State<BusinessBookingPage> createState() => _BusinessBookingPageState();
}

class _BusinessBookingPageState extends State<BusinessBookingPage> {
  final client = Supabase.instance.client;
  List<Map<String, dynamic>> services = [];
  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> slots = [];
  String? serviceId;
  String? employeeId;
  String? selectedSlot;
  DateTime selectedDate = DateTime.now();
  bool loading = true;
  bool loadingSlots = false;
  bool booking = false;
  bool businessClosed = false;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final business = await client.from('businesses')
          .select('is_temporarily_closed').eq('id', widget.businessId).single();
      businessClosed = business['is_temporarily_closed'] as bool? ?? false;
      if (businessClosed) return;
      final results = await Future.wait([
        client.from('services').select('id,name,price,duration_minutes')
          .eq('business_id', widget.businessId).eq('is_active', true).order('name'),
        client.from('employees').select('id,display_name')
          .eq('business_id', widget.businessId).eq('is_active', true).not('user_id', 'is', null).order('display_name'),
      ]);
      services = List<Map<String, dynamic>>.from(results[0]);
      employees = List<Map<String, dynamic>>.from(results[1]);
      serviceId = services.isEmpty ? null : services.first['id'] as String;
      if (serviceId != null) await loadSlots();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Randevu bilgileri yüklenemedi: $error'), backgroundColor: wine));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String dateValue(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> loadSlots() async {
    if (serviceId == null) return;
    setState(() { loadingSlots = true; slots = []; selectedSlot = null; });
    try {
      final targets = employeeId == null
          ? employees
          : employees.where((e) => e['id'] == employeeId).toList();
      final all = <String, Map<String, dynamic>>{};
      for (final employee in targets) {
        final rows = await client.rpc('get_available_appointment_slots', params: {
          'p_business_id': widget.businessId,
          'p_employee_id': employee['id'],
          'p_service_id': serviceId,
          'p_date': dateValue(selectedDate),
        });
        for (final raw in rows as List) {
          final row = Map<String, dynamic>.from(raw);
          final start = row['slot_start'] as String;
          all.putIfAbsent(start, () => {...row, 'employee_id': employee['id']});
        }
      }
      final result = all.values.toList()
        ..sort((a, b) => DateTime.parse(a['slot_start'] as String)
          .compareTo(DateTime.parse(b['slot_start'] as String)));
      if (mounted) setState(() => slots = result);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uygun saatler alınamadı: $error'), backgroundColor: wine));
    } finally {
      if (mounted) setState(() => loadingSlots = false);
    }
  }

  Future<void> chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate.isBefore(DateTime.now()) ? DateTime.now() : selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null) return;
    setState(() => selectedDate = date);
    await loadSlots();
  }

  Future<void> book() async {
    if (serviceId == null || selectedSlot == null) return;
    final slot = slots.firstWhere((s) => s['slot_start'] == selectedSlot);
    setState(() => booking = true);
    try {
      await client.rpc('book_appointment', params: {
        'p_business_id': widget.businessId,
        'p_employee_id': slot['employee_id'],
        'p_service_id': serviceId,
        'p_starts_at': selectedSlot,
        'p_customer_note': null,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Randevu talebin oluşturuldu.')));
      Navigator.pop(context);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Randevu oluşturulamadı: $error'), backgroundColor: wine));
      await loadSlots();
    } finally {
      if (mounted) setState(() => booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: wine));
    if (businessClosed) return const Center(
      child: Padding(padding: EdgeInsets.all(24),
        child: Text('Bu işletme şu anda geçici olarak kapalı. Yeni randevu kabul edilmiyor.',
          textAlign: TextAlign.center, style: TextStyle(color: muted))),
    );
    return PageBody(children: [
      Text(widget.businessName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 6),
      const Text('Hizmetini, çalışanını ve sana uygun saati seç.', style: TextStyle(color: muted)),
      const SizedBox(height: 18),
      DropdownButtonFormField<String>(
        value: serviceId,
        decoration: const InputDecoration(labelText: 'Hizmet seç'),
        items: services.map((service) => DropdownMenuItem(
          value: service['id'] as String,
          child: Text('${service['name']} • ${service['price']} ₺'),
        )).toList(),
        onChanged: (value) async { setState(() => serviceId = value); await loadSlots(); },
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String?>(
        value: employeeId,
        decoration: const InputDecoration(labelText: 'Çalışan seç'),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Fark etmez')),
          ...employees.map((employee) => DropdownMenuItem<String?>(
            value: employee['id'] as String,
            child: Text(employee['display_name'] as String? ?? 'Çalışan'),
          )),
        ],
        onChanged: (value) async { setState(() => employeeId = value); await loadSlots(); },
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: chooseDate,
        icon: const Icon(Icons.calendar_month),
        label: Text(dateValue(selectedDate))),
      const SizedBox(height: 14),
      const Text('Uygun saatler', style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
      const SizedBox(height: 8),
      if (loadingSlots)
        const Center(child: CircularProgressIndicator(color: wine))
      else if (slots.isEmpty)
        const Text('Bu gün için uygun saat bulunamadı.', style: TextStyle(color: muted))
      else
        Wrap(spacing: 8, runSpacing: 8, children: slots.map((slot) {
          final start = DateTime.parse(slot['slot_start'] as String).toLocal();
          final label = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
          final value = slot['slot_start'] as String;
          return ChoiceChip(label: Text(label), selected: selectedSlot == value,
            onSelected: (_) => setState(() => selectedSlot = value), selectedColor: blush);
        }).toList()),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: booking || selectedSlot == null ? null : book,
        child: booking ? const CircularProgressIndicator() : const Text('Randevu talebi oluştur')),
    ]);
  }
}

class _HomeActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HomeActionTile({required this.icon, required this.label, required this.onTap});
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Material(color: Colors.white, borderRadius: BorderRadius.circular(16),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
        child: Container(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(border: Border.all(color: blush), borderRadius: BorderRadius.circular(16)),
          child: Column(children: [Icon(icon, color: wine), const SizedBox(height: 7),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w700))])))));
}

class _Metric extends StatelessWidget {final String value,label;const _Metric(this.value,this.label);@override Widget build(BuildContext context)=>Column(children:[Text(value,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:wine)),Text(label,style:const TextStyle(fontSize:11,color:muted))]);}
class EmployeeHome extends StatefulWidget {
  const EmployeeHome({super.key});
  @override
  State<EmployeeHome> createState() => _EmployeeHomeState();
}

class _EmployeeHomeState extends State<EmployeeHome> {
  late Future<Map<String, dynamic>> data;
  @override
  void initState() { super.initState(); data = load(); }

  Future<Map<String, dynamic>> load() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Oturum bulunamadı.');
    final employee = await client.from('employees')
        .select('id,business_id,display_name')
        .eq('user_id', user.id).eq('is_active', true).maybeSingle();
    if (employee == null) throw Exception('Aktif çalışan kaydı bulunamadı.');
    final rows = List<Map<String, dynamic>>.from(await client.rpc(
      'get_business_appointments',
      params: {'p_business_id': employee['business_id'], 'p_mine_only': true},
    ) as List);
    final today = DateTime.now();
    final todays = rows.where((row) {
      final date = DateTime.parse(row['starts_at'] as String).toLocal();
      return date.year == today.year && date.month == today.month && date.day == today.day;
    }).toList();
    rows.sort((a, b) => DateTime.parse(a['starts_at'] as String)
        .compareTo(DateTime.parse(b['starts_at'] as String)));
    return {'employee': employee, 'appointments': rows, 'today': todays.length};
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: data,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator(color: wine));
      }
      if (snapshot.hasError || snapshot.data == null) {
        return Center(child: Text('Çalışan paneli yüklenemedi: ${snapshot.error ?? ''}',
          style: const TextStyle(color: muted)));
      }
      final employee = snapshot.data!['employee'] as Map<String, dynamic>;
      final appointments = snapshot.data!['appointments'] as List<Map<String, dynamic>>;
      return PageBody(children: [
        Text('Merhaba, ${employee['display_name'] ?? 'Çalışan'}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
        const Text('Bugünkü çalışma planın', style: TextStyle(color: muted)),
        const SizedBox(height: 16),
        Row(children: [
          _StatCard((snapshot.data!['today'] as int).toString(), 'Bugün Randevu'),
          _StatCard(appointments.length.toString(), 'Toplam Randevu'),
          _StatCard(appointments.where((a) => a['status'] == 'completed').length.toString(), 'Tamamlanan'),
        ]),
        const SizedBox(height: 16),
        const HeroPanel(eyebrow: 'Portfolyonu büyüt', title: 'Çalışmalarını paylaş',
          subtitle: 'Yaptığın işleri paylaş, müşterilerine ilham ver ve kariyerini büyüt.',
          icon: Icons.camera_alt, button: 'Paylaşım yap →'),
        const SectionTitle('Randevularım'),
        if (appointments.isEmpty)
          const Text('Henüz randevun bulunmuyor.', style: TextStyle(color: muted))
        else
          ...appointments.take(5).map((row) => AppointmentTile(
            name: row['customer_name'] as String? ?? 'Müşteri',
            service: row['service_name'] as String? ?? 'Hizmet',
            time: DateTime.parse(row['starts_at'] as String).toLocal().toString().substring(0, 16),
            status: row['status'] as String? ?? 'pending',
          )),
      ]);
    },
  );
}
class _StatCard extends StatelessWidget {final String v,l;const _StatCard(this.v,this.l);@override Widget build(BuildContext context)=>Expanded(child:Container(margin:const EdgeInsets.only(right:7),padding:const EdgeInsets.symmetric(vertical:15),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:blush)),child:Column(children:[Text(v,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:20,color:wine)),Text(l,textAlign:TextAlign.center,style:const TextStyle(fontSize:10,color:muted))])));}
class SharePage extends StatefulWidget {
  final bool businessPost;
  const SharePage({super.key,this.businessPost=false});
  @override State<SharePage> createState()=>_SharePageState();
}
class _SharePageState extends State<SharePage> {
  final caption=TextEditingController(); final picker=ImagePicker(); XFile? selectedMedia; bool isVideo=false;
  Future<void> chooseMedia(bool video) async { final file=video?await picker.pickVideo(source:ImageSource.gallery,maxDuration:const Duration(minutes:2)):await picker.pickImage(source:ImageSource.gallery,imageQuality:88); if(file!=null&&mounted)setState(() { selectedMedia=file; isVideo=video; }); }
  @override void dispose(){caption.dispose();super.dispose();}
  Future<void> publish() async {
    final text = caption.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paylaşımına kısa bir açıklama ekle.')));
      return;
    }
    if (selectedMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yayınlamak için fotoğraf veya video seçmelisin.')));
      return;
    }
    try {
      await KuaforumFeedRepository().publishPost(
        mediaFile: File(selectedMedia!.path),
        caption: text,
      );
      if (!mounted) return;
      setState(() {
        caption.clear();
        selectedMedia = null;
        isVideo = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paylaşımın Keşfet akışına yayınlandı.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paylaşım yayınlanamadı: $error'), backgroundColor: wine),
      );
    }
  }
  @override Widget build(BuildContext context)=>PageBody(children:[
    Row(children:[const Expanded(child:Text('Yeni Paylaşım',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:ink))),Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:blush,borderRadius:BorderRadius.circular(20)),child:Text(widget.businessPost?'İŞLETME':'ÇALIŞAN',style:const TextStyle(color:wine,fontWeight:FontWeight.w800,fontSize:10,letterSpacing:1)))]),
    const SizedBox(height:5),Text(widget.businessPost?'Salonunun güzelliklerini müşterilerinle paylaş.':'Yaptığın işleri paylaş, ilham ver ve portfolyonu büyüt.',style:const TextStyle(color:muted)),
    const SizedBox(height:16),
    Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(24),border:Border.all(color:blush),boxShadow:[BoxShadow(color:wine.withOpacity(.07),blurRadius:18,offset:const Offset(0,7))]),child:Column(children:[
      Container(height:230,width:double.infinity,decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),gradient:const LinearGradient(colors:[Color(0xFFF4DCE2),Color(0xFFD88DA2),Color(0xFF8E2947)],begin:Alignment.topLeft,end:Alignment.bottomRight)),child:Stack(children:[
        Positioned(right:14,top:14,child:Container(padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:Colors.white.withOpacity(.85),shape:BoxShape.circle),child:const Icon(Icons.auto_awesome,color:wine))),
        Center(child:selectedMedia!=null&&!isVideo?ClipRRect(borderRadius:BorderRadius.circular(18),child:Image.file(File(selectedMedia!.path),width:double.infinity,height:230,fit:BoxFit.cover)):Column(mainAxisSize:MainAxisSize.min,children:[Icon(isVideo?Icons.videocam_rounded:Icons.add_photo_alternate_rounded,size:54,color:Colors.white),const SizedBox(height:9),Text(selectedMedia==null?'Fotoğraf veya video seç':'Video hazır',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),const SizedBox(height:4),const Text('En güzel dönüşümünü burada göster ♡',style:TextStyle(color:Colors.white70,fontSize:11))])),
        Positioned(left:12,bottom:12,child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:BoxDecoration(color:Colors.black.withOpacity(.2),borderRadius:BorderRadius.circular(18)),child:const Text('ÖN İZLEME',style:TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.bold,letterSpacing:1))))
      ])),
      const SizedBox(height:12),Row(children:[
        Expanded(child:OutlinedButton.icon(onPressed:()=>chooseMedia(false),icon:const Icon(Icons.image_outlined),label:const Text('Fotoğraf'),style:OutlinedButton.styleFrom(foregroundColor:wine,side:const BorderSide(color:blush),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))))),
        const SizedBox(width:9),Expanded(child:OutlinedButton.icon(onPressed:()=>chooseMedia(true),icon:const Icon(Icons.videocam_outlined),label:const Text('Video'),style:OutlinedButton.styleFrom(foregroundColor:wine,side:const BorderSide(color:blush),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)))))
      ]),
      const SizedBox(height:14),TextField(controller:caption,maxLines:4,maxLength:500,decoration:InputDecoration(hintText:'Bu güzel çalışmayı anlat... ♡',filled:true,fillColor:cream,border:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:BorderSide.none),prefixIcon:const Icon(Icons.edit_note,color:wine))),
      const SizedBox(height:4),Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:cream,borderRadius:BorderRadius.circular(14)),child:const Row(children:[Icon(Icons.public,color:wine),SizedBox(width:9),Expanded(child:Text('Paylaşımın, işletmenin Keşfet görünürlüğü ve takip sistemi kurallarına göre ilgili akışlarda gösterilir.',style:TextStyle(color:muted,fontSize:11,height:1.35))) ])),
      const SizedBox(height:10),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:publish,icon:const Icon(Icons.send_rounded),label:const Text('Paylaşımı Yayınla'),style:FilledButton.styleFrom(backgroundColor:wine,foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(vertical:16),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)))))
    ])),
    const SizedBox(height:14),const Row(children:[Icon(Icons.lightbulb_outline,color:rose,size:18),SizedBox(width:7),Expanded(child:Text('İpucu: Öncesi/sonrası fotoğrafları ve kullandığın işlemi ekleyerek daha çok kişiye ulaş.',style:TextStyle(color:muted,fontSize:11)))])
  ]);
}

class OwnerProfilePage extends StatefulWidget {
  const OwnerProfilePage({super.key});
  @override
  State<OwnerProfilePage> createState() => _OwnerProfilePageState();
}

class _OwnerProfilePageState extends State<OwnerProfilePage> {
  final client = Supabase.instance.client;
  late Future<Map<String, dynamic>> data;

  @override
  void initState() {
    super.initState();
    data = load();
  }

  Future<Map<String, dynamic>> load() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Oturum bulunamadı.');
    final business = await client.from('businesses')
        .select('id,name,address,logo_url,status')
        .eq('owner_id', user.id)
        .maybeSingle();
    if (business == null) throw Exception('İşletme bilgisi bulunamadı.');
    final businessId = business['id'] as String;
    final followers = await client.from('feed_follows')
        .select('id').eq('followed_business_id', businessId);
    final posts = await client.from('feed_posts')
        .select('id').eq('business_id', businessId);
    return {
      'business': Map<String, dynamic>.from(business),
      'followers': followers.length,
      'posts': posts.length,
    };
  }

  Future<void> logout() async {
    await client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const KuaforumApp(autoResume: false)),
      (route) => false,
    );
  }

  void open(BuildContext context, String section) {
    final page = switch (section) {
      'Randevu Yönetimi' => const OwnerAppointments(),
      'Çalışan Randevuları' => const OwnerEmployeeAppointments(),
      'Müşterilerim' => const CustomersPage(),
      'Ayarlar' => const SettingsPage(),
      _ => const SettingsPage(),
    };
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(section,
          style: const TextStyle(color: wine, fontWeight: FontWeight.bold))),
        body: page,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: data,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator(color: wine));
      }
      if (snapshot.hasError || snapshot.data == null) {
        return Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('İşletme profili yüklenemedi: ${snapshot.error ?? 'Bilinmeyen hata'}',
            textAlign: TextAlign.center, style: const TextStyle(color: muted)),
        ));
      }
      final business = snapshot.data!['business'] as Map<String, dynamic>;
      final logo = business['logo_url'] as String?;
      final address = (business['address'] as String?)?.trim() ?? '';
      return PageBody(children: [
        Center(child: CircleAvatar(
          radius: 48,
          backgroundColor: blush,
          backgroundImage: logo != null && logo.isNotEmpty ? NetworkImage(logo) : null,
          child: logo == null || logo.isEmpty
              ? const Icon(Icons.storefront, size: 48, color: wine) : null,
        )),
        const SizedBox(height: 10),
        Text(business['name'] as String? ?? 'İşletmem',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: ink)),
        Text(address.isEmpty ? 'Adres eklenmemiş' : address,
          textAlign: TextAlign.center, style: const TextStyle(color: muted)),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _Metric((snapshot.data!['followers'] as int).toString(), 'Takipçi'),
          _Metric('—', 'Takip'),
          _Metric((snapshot.data!['posts'] as int).toString(), 'Paylaşım'),
        ]),
        const SizedBox(height: 18),
        const SectionTitle('İşletme Yönetimi'),
        ...['Randevu Yönetimi', 'Çalışan Randevuları', 'Müşterilerim', 'Ayarlar'].map((section) =>
          Card(color: Colors.white, elevation: 0, child: ListTile(
            leading: const Icon(Icons.circle_outlined, color: wine),
            title: Text(section, style: const TextStyle(color: ink, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: muted),
            onTap: () => open(context, section),
          ))),
        Card(color: Colors.white, elevation: 0, child: ListTile(
          leading: const Icon(Icons.devices_outlined, color: wine),
          title: const Text('Aktif Cihazlar', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right, color: muted),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Aktif Cihazlar')),
            body: const ActiveSessionsPage(),
          ))),
        )),
        Card(color: Colors.white, elevation: 0, child: ListTile(
          leading: const Icon(Icons.notifications_active_outlined, color: wine),
          title: const Text('Bildirim Tercihleri', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right, color: muted),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Bildirim Tercihleri')),
            body: const NotificationPreferencesPage(),
          ))),
        )),
        Card(color: Colors.white, elevation: 0, child: ListTile(
          leading: const Icon(Icons.logout, color: wine),
          title: const Text('Çıkış Yap', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right, color: muted),
          onTap: logout,
        )),
      ]);
    },
  );
}
class EmployeeManagementPage extends StatefulWidget {
  const EmployeeManagementPage({super.key});
  @override
  State<EmployeeManagementPage> createState() => _EmployeeManagementPageState();
}

class _EmployeeManagementPageState extends State<EmployeeManagementPage> {
  final client = Supabase.instance.client;
  late Future<Map<String, dynamic>> data;

  @override
  void initState() {
    super.initState();
    data = load();
  }

  Future<Map<String, dynamic>> load() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Oturum bulunamadı.');
    final business = await client.from('businesses').select('id')
        .eq('owner_id', user.id).maybeSingle();
    if (business == null) throw Exception('İşletme kaydı bulunamadı.');
    final employees = await client.from('employees')
        .select('id,display_name,is_active,user_id')
        .eq('business_id', business['id']).order('created_at');
    final employeeUserIds = employees
        .map((row) => row['user_id'])
        .whereType<String>()
        .toSet()
        .toList();
    final avatars = employeeUserIds.isEmpty
        ? <dynamic>[]
        : await client.from('public_profiles')
            .select('id,avatar_url')
            .inFilter('id', employeeUserIds);
    final avatarByUserId = {
      for (final profile in avatars)
        profile['id'] as String: profile['avatar_url'] as String?,
    };
    final employeesWithAvatars = employees.map((row) {
      final employee = Map<String, dynamic>.from(row);
      employee['avatar_url'] = avatarByUserId[employee['user_id']];
      return employee;
    }).toList();
    return {'business_id': business['id'], 'employees': employeesWithAvatars};
  }

  Future<void> refreshData() async {
    final next = load();
    setState(() => data = next);
    await next;
  }

  Future<void> inviteEmployee(String businessId) async {
    final firstName = TextEditingController();
    final lastName = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Çalışan hesabı oluştur'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: firstName, textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Ad')),
            TextField(controller: lastName, textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Soyad')),
            TextField(controller: phone, keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon')),
            TextField(controller: email, keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-posta')),
            TextField(controller: password, obscureText: true,
              decoration: const InputDecoration(labelText: 'İlk giriş şifresi (en az 8 karakter)')),
            const SizedBox(height: 8),
            const Text('Çalışana e-posta doğrulama bağlantısı gönderilir. Hesabı doğruladıktan sonra belirlediğin şifreyle giriş yapabilir.',
              style: TextStyle(color: muted, fontSize: 12)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Hesabı oluştur')),
        ],
      ),
    );
    if (accepted != true) {
      firstName.dispose(); lastName.dispose(); phone.dispose(); email.dispose(); password.dispose();
      return;
    }
    try {
      if ([firstName.text, lastName.text, phone.text, email.text, password.text]
          .any((value) => value.trim().isEmpty)) {
        throw Exception('Ad, soyad, telefon, e-posta ve şifre zorunludur.');
      }
      if (!email.text.trim().contains('@') || password.text.length < 8) {
        throw Exception('E-posta geçerli olmalı ve şifre en az 8 karakter olmalıdır.');
      }
      await client.functions.invoke('create-employee-account', body: {
        'business_id': businessId,
        'first_name': firstName.text.trim(),
        'last_name': lastName.text.trim(),
        'phone': phone.text.trim(),
        'email': email.text.trim().toLowerCase(),
        'password': password.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Çalışan hesabı oluşturuldu. E-posta doğrulaması bekleniyor.')),
      );
      await refreshData();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çalışan hesabı oluşturulamadı: $error'), backgroundColor: wine),
      );
    } finally {
      firstName.dispose(); lastName.dispose(); phone.dispose(); email.dispose(); password.dispose();
    }
  }

  Future<void> removeEmployee(String employeeId, String name) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) =>
      AlertDialog(
        title: const Text('Çalışanı kaldır'),
        content: Text('$name işletmenden kaldırılacak. Çalışanın hesabı müşteri hesabına dönecek; geçmiş randevu kayıtları korunacak.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Çalışanı kaldır', style: TextStyle(color: wine))),
        ],
      ));
    if (confirmed != true) return;
    try {
      await client.rpc('remove_employee', params: {'p_employee_id': employeeId});
      await refreshData();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çalışan kaldırılamadı: $error'), backgroundColor: wine),
      );
    }
  }

  Future<void> setActive(String employeeId, bool active) async {
    try {
      await client.rpc('set_employee_active', params: {
        'p_employee_id': employeeId,
        'p_is_active': active,
      });
      await refreshData();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çalışan durumu değiştirilemedi: $error'), backgroundColor: wine),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: data,
    builder: (context, snapshot) => RefreshIndicator(
      color: wine,
      onRefresh: refreshData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          const Text('Çalışanlar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 12),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator(color: wine))
          else if (snapshot.hasError)
            _FeedMessage(icon: Icons.cloud_off_outlined, title: 'Çalışanlar yüklenemedi', detail: snapshot.error.toString())
          else ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: wine, foregroundColor: Colors.white),
              onPressed: () => inviteEmployee(snapshot.data!['business_id'] as String),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Çalışan Davet Et'),
            ),
            const SizedBox(height: 12),
            if ((snapshot.data!['employees'] as List).isEmpty)
              const _FeedMessage(icon: Icons.people_outline, title: 'Henüz çalışan yok', detail: 'Çalışan Davet Et bölümünden ekibine yeni çalışan ekleyebilirsin.')
            else
              ...(snapshot.data!['employees'] as List).map((raw) {
                final employee = Map<String, dynamic>.from(raw as Map);
                final active = employee['is_active'] == true;
                return Card(
                  color: Colors.white,
                  elevation: 0,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: blush,
                      backgroundImage: (employee['avatar_url'] as String?)?.isNotEmpty == true
                          ? NetworkImage(employee['avatar_url'] as String)
                          : null,
                      child: (employee['avatar_url'] as String?)?.isNotEmpty == true
                          ? null
                          : const Icon(Icons.person, color: wine),
                    ),
                    title: Text(employee['display_name']?.toString() ?? 'Çalışan', style: const TextStyle(color: ink, fontWeight: FontWeight.bold)),
                    subtitle: Text(active ? (employee['user_id'] == null ? 'Davet bekliyor' : 'Aktif çalışan') : 'Pasif çalışan'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Switch(
                        value: active,
                        activeColor: wine,
                        onChanged: (value) => setActive(employee['id'].toString(), value),
                      ),
                      IconButton(
                        tooltip: 'Çalışanı kaldır',
                        onPressed: () => removeEmployee(
                          employee['id'].toString(),
                          employee['display_name']?.toString() ?? 'Çalışan',
                        ),
                        icon: const Icon(Icons.person_remove_alt_1, color: wine),
                      ),
                    ]),
                  ),
                );
              }),
          ],
        ],
      ),
    ),
  );
}
class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});
  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  final client = Supabase.instance.client;
  late Future<Map<String, dynamic>> data;

  @override
  void initState() {
    super.initState();
    data = load();
  }

  Future<Map<String, dynamic>> load() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Oturum bulunamadı.');
    final business = await client.from('businesses').select('id')
        .eq('owner_id', user.id).maybeSingle();
    if (business == null) throw Exception('İşletme kaydı bulunamadı.');
    final services = await client.from('services')
        .select('id,name,price,duration_minutes,is_active')
        .eq('business_id', business['id']).order('created_at');
    return {'business_id': business['id'], 'services': services};
  }

  Future<void> refreshData() async {
    final next = load();
    setState(() => data = next);
    await next;
  }

  Future<void> editService(String businessId, {Map<String, dynamic>? service}) async {
    final name = TextEditingController(text: service?['name']?.toString() ?? '');
    final price = TextEditingController(text: service?['price']?.toString() ?? '');
    final duration = TextEditingController(text: service?['duration_minutes']?.toString() ?? '30');
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(service == null ? 'Yeni hizmet' : 'Hizmeti düzenle'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Hizmet adı')),
          TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Fiyat (₺)')),
          TextField(controller: duration, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Süre (dakika)')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Kaydet')),
        ],
      ),
    );
    if (save != true) { name.dispose(); price.dispose(); duration.dispose(); return; }
    final parsedPrice = double.tryParse(price.text.trim().replaceAll(',', '.'));
    final parsedDuration = int.tryParse(duration.text.trim());
    if (name.text.trim().isEmpty || parsedPrice == null || parsedPrice < 0 || parsedDuration == null || parsedDuration < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hizmet adı, geçerli fiyat ve en az 5 dakikalık süre girin.')));
      name.dispose(); price.dispose(); duration.dispose(); return;
    }
    try {
      final values = {'name': name.text.trim(), 'price': parsedPrice, 'duration_minutes': parsedDuration};
      if (service == null) {
        await client.from('services').insert({...values, 'business_id': businessId, 'is_active': true});
      } else {
        await client.from('services').update(values).eq('id', service['id']);
      }
      await refreshData();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hizmet kaydedilemedi: $error'), backgroundColor: wine),
      );
    } finally {
      name.dispose(); price.dispose(); duration.dispose();
    }
  }

  Future<void> toggleService(String id, bool active) async {
    try {
      await client.from('services').update({'is_active': active}).eq('id', id);
      await refreshData();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hizmet durumu değiştirilemedi: $error'), backgroundColor: wine),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: data,
    builder: (context, snapshot) => RefreshIndicator(
      color: wine,
      onRefresh: refreshData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          const Text('Hizmetler', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 12),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator(color: wine))
          else if (snapshot.hasError)
            _FeedMessage(icon: Icons.cloud_off_outlined, title: 'Hizmetler yüklenemedi', detail: snapshot.error.toString())
          else ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: wine, foregroundColor: Colors.white),
              onPressed: () => editService(snapshot.data!['business_id'] as String),
              icon: const Icon(Icons.add),
              label: const Text('Yeni Hizmet Ekle'),
            ),
            const SizedBox(height: 12),
            if ((snapshot.data!['services'] as List).isEmpty)
              const _FeedMessage(icon: Icons.content_cut, title: 'Henüz hizmet eklenmemiş', detail: 'Müşterilerin randevu alabilmesi için hizmetlerini ekle.')
            else
              ...(snapshot.data!['services'] as List).map((raw) {
                final service = Map<String, dynamic>.from(raw as Map);
                final active = service['is_active'] == true;
                return Card(
                  color: Colors.white,
                  elevation: 0,
                  child: ListTile(
                    leading: const Icon(Icons.content_cut, color: wine),
                    title: Text(service['name']?.toString() ?? 'Hizmet', style: const TextStyle(color: ink, fontWeight: FontWeight.w600)),
                    subtitle: Text('₺${service['price']} • ${service['duration_minutes']} dakika • ${active ? 'Aktif' : 'Pasif'}'),
                    onTap: () => editService(snapshot.data!['business_id'] as String, service: service),
                    trailing: Switch(
                      value: active,
                      activeColor: wine,
                      onChanged: (value) => toggleService(service['id'].toString(), value),
                    ),
                  ),
                );
              }),
          ],
        ],
      ),
    ),
  );
}

class OwnerHome extends StatefulWidget {
  const OwnerHome({super.key});
  @override
  State<OwnerHome> createState() => _OwnerHomeState();
}

class _OwnerHomeState extends State<OwnerHome> {
  late Future<Map<String, dynamic>> data;
  @override
  void initState() { super.initState(); data = load(); }

  Future<Map<String, dynamic>> load() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Oturum bulunamadı.');
    final business = await client.from('businesses').select('id,name')
        .eq('owner_id', user.id).maybeSingle();
    if (business == null) throw Exception('İşletme bulunamadı.');
    final rows = List<Map<String, dynamic>>.from(await client.rpc(
      'get_business_appointments',
      params: {'p_business_id': business['id'], 'p_mine_only': false},
    ) as List);
    final customers = List<Map<String, dynamic>>.from(await client.rpc(
      'get_business_customers', params: {'p_business_id': business['id']},
    ) as List);
    final today = DateTime.now();
    final todays = rows.where((row) {
      final date = DateTime.parse(row['starts_at'] as String).toLocal();
      return date.year == today.year && date.month == today.month && date.day == today.day;
    }).toList();
    rows.sort((a, b) => DateTime.parse(b['starts_at'] as String)
        .compareTo(DateTime.parse(a['starts_at'] as String)));
    return {'business': business, 'appointments': rows, 'today': todays.length,
      'customers': customers.length};
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: data,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator(color: wine));
      }
      if (snapshot.hasError || snapshot.data == null) {
        return Center(child: Text('İşletme özeti yüklenemedi: ${snapshot.error ?? ''}',
          style: const TextStyle(color: muted)));
      }
      final business = snapshot.data!['business'] as Map<String, dynamic>;
      final appointments = snapshot.data!['appointments'] as List<Map<String, dynamic>>;
      return PageBody(children: [
        Text('${business['name'] ?? 'İşletme Yönetimi'}',
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 14),
        HeroPanel(eyebrow: 'İşletme paneli', title: 'İşletmeni yönet',
          subtitle: 'Randevularını, ekibini ve müşteri deneyimini tek yerden takip et.',
          icon: Icons.storefront, button: 'Yönetim araçları'),
        const SizedBox(height: 14),
        Row(children: [
          _StatCard((snapshot.data!['today'] as int).toString(), 'Bugünkü Randevu'),
          _StatCard((snapshot.data!['customers'] as int).toString(), 'Müşteri'),
          _StatCard(appointments.length.toString(), 'Toplam Randevu'),
        ]),
        const SectionTitle('Son Randevular', action: 'Tümünü Gör'),
        if (appointments.isEmpty)
          const Text('Henüz randevu bulunmuyor.', style: TextStyle(color: muted))
        else
          ...appointments.take(3).map((row) => AppointmentTile(
            name: row['customer_name'] as String? ?? 'Müşteri',
            service: row['service_name'] as String? ?? 'Hizmet',
            time: DateTime.parse(row['starts_at'] as String).toLocal().toString().substring(0, 16),
            status: row['status'] as String? ?? 'pending',
          )),
        const SectionTitle('Hızlı Yönetim'),
        Row(children: [
          Expanded(child: _HomeActionTile(icon: Icons.calendar_month, label: 'Randevular', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerAppointments())))),
          Expanded(child: _HomeActionTile(icon: Icons.people_alt_outlined, label: 'Müşteriler', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersPage())))),
          Expanded(child: _HomeActionTile(icon: Icons.settings_outlined, label: 'Ayarlar', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())))),
        ]),
      ]);
    },
  );
}
class OwnerAppointments extends StatelessWidget {
  const OwnerAppointments({super.key});
  @override
  Widget build(BuildContext context) => const AppointmentsPage(
    title: 'Randevum',
    ownerMode: true,
  );
}

class OwnerEmployeeAppointments extends StatelessWidget {
  const OwnerEmployeeAppointments({super.key});
  @override
  Widget build(BuildContext context) => const AppointmentsPage(
    title: 'Çalışan Randevuları',
    ownerMode: false,
  );
}
class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});
  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final client = Supabase.instance.client;
  final search = TextEditingController();
  late Future<Map<String, dynamic>> data;
  String query = '';

  @override
  void initState() {
    super.initState();
    data = load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> load() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Oturum bulunamadı.');
    final business = await client.from('businesses').select('id')
        .eq('owner_id', user.id).maybeSingle();
    if (business == null) throw Exception('İşletme kaydı bulunamadı.');
    final customers = await client.rpc('get_business_customers', params: {
      'p_business_id': business['id'],
    });
    return {'business_id': business['id'], 'customers': List<Map<String, dynamic>>.from(customers as List)};
  }

  Future<void> refreshData() async {
    final next = load();
    setState(() => data = next);
    await next;
  }

  Future<void> toggleBlacklist(String businessId, Map<String, dynamic> customer, bool blocked) async {
    try {
      await client.rpc('set_customer_blacklist', params: {
        'p_business_id': businessId,
        'p_customer_id': customer['customer_id'],
        'p_blocked': blocked,
        'p_reason': blocked ? 'İşletme tarafından kara listeye alındı' : null,
      });
      await refreshData();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kara liste güncellenemedi: $error'), backgroundColor: wine),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: data,
    builder: (context, snapshot) {
      final customers = (snapshot.data?['customers'] as List<Map<String, dynamic>>? ?? [])
          .where((customer) {
            final value = '${customer['full_name'] ?? ''} ${customer['phone'] ?? ''}'.toLowerCase();
            return value.contains(query.toLowerCase());
          }).toList();
      return RefreshIndicator(
        color: wine,
        onRefresh: refreshData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            const Text('Müşterilerim', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 12),
            TextField(
              controller: search,
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                hintText: 'İsim veya telefon ara...',
                prefixIcon: const Icon(Icons.search, color: wine),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: blush)),
              ),
            ),
            const SizedBox(height: 12),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator(color: wine))
            else if (snapshot.hasError)
              _FeedMessage(icon: Icons.cloud_off_outlined, title: 'Müşteriler yüklenemedi', detail: snapshot.error.toString())
            else if (customers.isEmpty)
              const _FeedMessage(icon: Icons.people_outline, title: 'Müşteri bulunamadı', detail: 'Arama ölçütünü değiştir veya işletmene bağlı müşterileri bekle.')
            else
              ...customers.map((customer) {
                final blocked = customer['is_blacklisted'] == true;
                return Card(
                  color: Colors.white,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: blush,
                      child: Icon(blocked ? Icons.block : Icons.person, color: wine),
                    ),
                    title: Text(customer['full_name']?.toString() ?? 'Müşteri', style: const TextStyle(fontWeight: FontWeight.bold, color: ink)),
                    subtitle: Text('${customer['phone'] ?? 'Telefon yok'} • ${customer['appointment_count'] ?? 0} randevu'),
                    isThreeLine: true,
                    trailing: TextButton(
                      onPressed: () => toggleBlacklist(snapshot.data!['business_id'] as String, customer, !blocked),
                      child: Text(blocked ? 'Listeden çıkar' : 'Kara listeye al',
                        style: TextStyle(color: blocked ? Colors.green.shade700 : wine, fontSize: 11)),
                    ),
                  ),
                );
              }),
          ],
        ),
      );
    },
  );
}
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void open(BuildContext context, String section) {
    final page = switch (section) {
      'İşletme Profili' => const BusinessDetailsPage(),
      'Çalışanlar' => const EmployeeManagementPage(),
      'Hizmetler' => const ServicesPage(),
      'Çalışma Saatleri' => const WorkingHoursPage(),
      'Randevu Aralığı' => const AppointmentIntervalPage(),
      'Çalışan İzinleri' => const OwnerTimeOffPage(),
      _ => null,
    };
    if (page == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(section, style: const TextStyle(color: wine, fontWeight: FontWeight.bold))),
        body: page,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => PageBody(children: [
    const Text('Ayarlar', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
    const SizedBox(height: 12),
    ...['İşletme Profili','Çalışanlar','Hizmetler','Çalışma Saatleri','Randevu Aralığı','Çalışan İzinleri'].map((section) => Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(switch (section) {
          'İşletme Profili' => Icons.storefront_outlined,
          'Çalışanlar' => Icons.people_outline,
          'Hizmetler' => Icons.content_cut,
          'Çalışma Saatleri' => Icons.schedule,
          'Randevu Aralığı' => Icons.timelapse,
          'Çalışan İzinleri' => Icons.event_busy,
          _ => Icons.settings_outlined,
        }, color: wine),
        title: Text(section, style: const TextStyle(fontWeight: FontWeight.w600, color: ink)),
        trailing: const Icon(Icons.chevron_right, color: muted),
        onTap: () => open(context, section),
      ),
    )),
  ]);
}

class BusinessDetailsPage extends StatefulWidget {
  const BusinessDetailsPage({super.key});
  @override
  State<BusinessDetailsPage> createState() => _BusinessDetailsPageState();
}

class _BusinessDetailsPageState extends State<BusinessDetailsPage> {
  final client = Supabase.instance.client;
  final name = TextEditingController();
  final address = TextEditingController();
  String? businessId;
  bool loading = true;
  bool saving = false;
  bool temporarilyClosed = false;
  bool uploadingLogo = false;
  String? logoPath;

  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { name.dispose(); address.dispose(); super.dispose(); }

  Future<void> load() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) throw Exception('Oturum bulunamadı.');
      final row = await client.from('businesses')
          .select('id,name,address,is_temporarily_closed,logo_url').eq('owner_id', user.id).maybeSingle();
      if (row == null) throw Exception('İşletme bulunamadı.');
      businessId = row['id'] as String;
      name.text = row['name'] as String? ?? '';
      address.text = row['address'] as String? ?? '';
      temporarilyClosed = row['is_temporarily_closed'] as bool? ?? false;
      logoPath = row['logo_url'] as String?;
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşletme bilgileri yüklenemedi: $error')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> uploadLogo() async {
    final user = client.auth.currentUser;
    if (user == null || businessId == null || uploadingLogo) return;
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery, imageQuality: 90, maxWidth: 2048, maxHeight: 2048,
    );
    if (image == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 88,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'İşletme Fotoğrafını Düzenle',
          toolbarColor: wine,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'İşletme Fotoğrafını Düzenle',
          aspectRatioLockEnabled: true,
        ),
      ],
    );
    if (cropped == null) return;
    setState(() => uploadingLogo = true);
    try {
      final file = File(cropped.path);
      if (await file.length() > 5 * 1024 * 1024) {
        throw Exception('Logo 5 MB sınırını aşıyor.');
      }
      const contentType = 'image/jpeg';
      final path = 'businesses/$businessId/logo_${DateTime.now().microsecondsSinceEpoch}.jpg';
      await client.storage.from('salon-avatars').upload(path, file,
        fileOptions: FileOptions(contentType: contentType, upsert: false));
      await client.rpc('set_my_business_logo', params: {
        'p_business_id': businessId, 'p_logo_path': path,
      });
      final oldPath = logoPath;
      if (oldPath != null && oldPath.startsWith('businesses/$businessId/')) {
        try { await client.storage.from('salon-avatars').remove([oldPath]); } catch (_) {}
      }
      if (mounted) {
        setState(() => logoPath = path);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İşletme fotoğrafı güncellendi.')),
        );
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşletme fotoğrafı yüklenemedi: $error'), backgroundColor: wine),
      );
    } finally {
      if (mounted) setState(() => uploadingLogo = false);
    }
  }

  Future<void> setTemporaryClosed(bool value) async {
    if (businessId == null) return;
    setState(() => temporarilyClosed = value);
    try {
      await client.rpc('set_business_temporarily_closed', params: {
        'p_business_id': businessId, 'p_closed': value,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(value ? 'İşletme geçici olarak kapatıldı.' : 'İşletme yeniden açıldı.')));
    } catch (error) {
      if (mounted) {
        setState(() => temporarilyClosed = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İşletme durumu değiştirilemedi: $error'), backgroundColor: wine));
      }
    }
  }

  Future<void> save() async {
    if (businessId == null || name.text.trim().isEmpty) return;
    setState(() => saving = true);
    try {
      await client.rpc('update_my_business_profile', params: {
        'p_business_id': businessId,
        'p_name': name.text.trim(),
        'p_address': address.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İşletme profili güncellendi.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil güncellenemedi: $error'), backgroundColor: wine));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: wine));
    return PageBody(children: [
      const Text('İşletme bilgileri', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 16),
      Center(child: Column(children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: blush,
          backgroundImage: logoPath == null ? null : NetworkImage(
            logoPath!.startsWith('http') ? logoPath! : client.storage.from('salon-avatars').getPublicUrl(logoPath!),
          ),
          child: logoPath == null ? const Icon(Icons.storefront, size: 42, color: wine) : null,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: uploadingLogo ? null : uploadLogo,
          icon: uploadingLogo
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.camera_alt_outlined),
          label: const Text('İşletme fotoğrafını değiştir'),
        ),
      ])),
      const SizedBox(height: 14),
      TextField(controller: name, textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'İşletme adı')),
      const SizedBox(height: 12),
      TextField(controller: address, maxLines: 2,
        decoration: const InputDecoration(labelText: 'Adres')),
      const SizedBox(height: 10),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: temporarilyClosed,
        onChanged: setTemporaryClosed,
        activeColor: wine,
        title: const Text('İşletmeyi geçici olarak kapat', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
        subtitle: const Text('Kapalıyken yeni randevu alınamaz. Mevcut randevular korunur.', style: TextStyle(color: muted)),
      ),
      const SizedBox(height: 18),
      ElevatedButton(onPressed: saving ? null : save,
        child: saving ? const CircularProgressIndicator() : const Text('Değişiklikleri kaydet')),
    ]);
  }
}

class AppointmentIntervalPage extends StatefulWidget {
  const AppointmentIntervalPage({super.key});
  @override
  State<AppointmentIntervalPage> createState() => _AppointmentIntervalPageState();
}

class _AppointmentIntervalPageState extends State<AppointmentIntervalPage> {
  final client = Supabase.instance.client;
  String? businessId;
  int selected = 30;
  bool loading = true;
  bool saving = false;
  static const intervals = [10, 15, 20, 30, 45, 60];

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) throw Exception('Oturum bulunamadı.');
      final row = await client.from('businesses')
          .select('id,appointment_interval_minutes')
          .eq('owner_id', user.id).maybeSingle();
      if (row == null) throw Exception('İşletme bulunamadı.');
      businessId = row['id'] as String;
      selected = (row['appointment_interval_minutes'] as num?)?.toInt() ?? 30;
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Randevu aralığı yüklenemedi: $error')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    if (businessId == null) return;
    setState(() => saving = true);
    try {
      await client.rpc('update_appointment_interval', params: {
        'p_business_id': businessId, 'p_interval_minutes': selected,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Randevu aralığı kaydedildi.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Randevu aralığı kaydedilemedi: $error'), backgroundColor: wine));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: wine));
    return PageBody(children: [
      const Text('Randevu Aralığı', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 8),
      const Text('Yeni randevu saatlerinin kaç dakikada bir açılacağını belirle.', style: TextStyle(color: muted)),
      const SizedBox(height: 18),
      Wrap(spacing: 10, runSpacing: 10, children: intervals.map((minutes) =>
        ChoiceChip(label: Text('$minutes dakika'), selected: selected == minutes,
          onSelected: (_) => setState(() => selected = minutes),
          selectedColor: blush)).toList()),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: saving ? null : save,
        child: saving ? const CircularProgressIndicator() : const Text('Kaydet')),
    ]);
  }
}
class WorkingHoursPage extends StatefulWidget {
  const WorkingHoursPage({super.key});
  @override
  State<WorkingHoursPage> createState() => _WorkingHoursPageState();
}

class _WorkingHoursPageState extends State<WorkingHoursPage> {
  final client = Supabase.instance.client;
  final labels = const ['Pazar','Pazartesi','Salı','Çarşamba','Perşembe','Cuma','Cumartesi'];
  String? businessId;
  List<Map<String, dynamic>> days = [];
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) throw Exception('Oturum bulunamadı.');
      final business = await client.from('businesses').select('id')
          .eq('owner_id', user.id).maybeSingle();
      if (business == null) throw Exception('İşletme kaydı bulunamadı.');
      businessId = business['id'] as String;
      final rows = await client.from('business_hours').select('weekday,opens_at,closes_at,is_closed')
          .eq('business_id', businessId!);
      final byDay = {for (final row in rows) row['weekday'] as int: row};
      days = List.generate(7, (index) {
        final row = byDay[index];
        return {
          'weekday': index,
          'opens_at': row?['opens_at']?.toString().substring(0,5) ?? '09:00',
          'closes_at': row?['closes_at']?.toString().substring(0,5) ?? '18:00',
          'is_closed': row?['is_closed'] as bool? ?? (index == 0),
        };
      });
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çalışma saatleri yüklenemedi: $error'), backgroundColor: wine),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> chooseTime(int day, String field) async {
    final parts = (days[day][field] as String).split(':');
    final initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final selected = await showTimePicker(context: context, initialTime: initial);
    if (selected == null) return;
    setState(() => days[day][field] =
      '${selected.hour.toString().padLeft(2,'0')}:${selected.minute.toString().padLeft(2,'0')}');
  }

  Future<void> save() async {
    if (businessId == null) return;
    setState(() => saving = true);
    try {
      await client.from('business_hours').upsert(
        days.map((day) => {...day, 'business_id': businessId}).toList(),
        onConflict: 'business_id,weekday',
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Çalışma saatleri kaydedildi.')),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydedilemedi: $error'), backgroundColor: wine),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(children: [
    const Text('Çalışma Saatleri', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
    const SizedBox(height: 8),
    const Text('İşletmenin haftalık açık olduğu saatleri belirle.', style: TextStyle(color: muted)),
    const SizedBox(height: 12),
    if (loading)
      const Center(child: CircularProgressIndicator(color: wine))
    else if (businessId == null)
      const Text('İşletme bilgisi yüklenemedi.')
    else ...[
      ...List.generate(7, (index) {
        final day = days[index];
        final closed = day['is_closed'] as bool;
        return Card(
          color: Colors.white,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 9),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Row(children: [
                Expanded(child: Text(labels[index], style: const TextStyle(fontWeight: FontWeight.bold, color: ink))),
                const Text('Kapalı', style: TextStyle(color: muted, fontSize: 12)),
                Switch(
                  value: closed,
                  activeColor: wine,
                  onChanged: (value) => setState(() => day['is_closed'] = value),
                ),
              ]),
              if (!closed)
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => chooseTime(index, 'opens_at'),
                    child: Text('Açılış  ${day['opens_at']}'),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(
                    onPressed: () => chooseTime(index, 'closes_at'),
                    child: Text('Kapanış  ${day['closes_at']}'),
                  )),
                ]),
            ]),
          ),
        );
      }),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: wine, foregroundColor: Colors.white),
        onPressed: saving ? null : save,
        child: Text(saving ? 'Kaydediliyor...' : 'Saatleri Kaydet'),
      )),
    ],
  ]);
}

class AdminSubAdmins extends StatefulWidget {
  const AdminSubAdmins({super.key});
  @override State<AdminSubAdmins> createState() => _AdminSubAdminsState();
}
class _AdminSubAdminsState extends State<AdminSubAdmins> {
  final client = Supabase.instance.client;
  final email = TextEditingController();
  final permissions = <String>{};
  bool loading = true;
  bool saving = false;
  List<Map<String, dynamic>> admins = [];
  static const options = <String, String>{
    'dashboard': 'Genel bakış', 'businesses': 'İşletme yönetimi',
    'users': 'Kullanıcı yönetimi', 'discover': 'Keşfet yönetimi',
    'support': 'Destek yönetimi',
  };
  @override void initState() { super.initState(); load(); }
  @override void dispose() { email.dispose(); super.dispose(); }
  Future<void> load() async {
    try {
      final rows = await client.rpc('admin_list_subadmins') as List;
      admins = List<Map<String, dynamic>>.from(rows);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alt yöneticiler yüklenemedi: $error')));
    } finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> save() async {
    final address = email.text.trim();
    if (!address.contains('@') || permissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli e-posta ve en az bir yetki seç.')));
      return;
    }
    setState(() => saving = true);
    try {
      await client.rpc('admin_set_subadmin', params: {
        'p_email': address, 'p_permissions': permissions.toList(),
      });
      if (!mounted) return;
      email.clear(); permissions.clear();
      await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alt yönetici yetkileri kaydedildi.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yetkiler kaydedilemedi: $error')));
    } finally { if (mounted) setState(() => saving = false); }
  }
  Future<void> revoke(Map<String, dynamic> admin) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) =>
      AlertDialog(
        title: const Text('Alt yöneticiyi kaldır'),
        content: Text('${admin['email'] ?? 'Bu hesap'} için tüm yönetim yetkileri kaldırılacak.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yetkileri kaldır')),
        ],
      ));
    if (confirmed != true) return;
    try {
      await client.rpc('admin_set_subadmin', params: {
        'p_email': admin['email'], 'p_permissions': <String>[],
      });
      if (!mounted) return;
      await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alt yönetici yetkileri kaldırıldı.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yetkiler kaldırılamadı: $error')));
    }
  }
  Future<void> edit(Map<String, dynamic> admin) async {
    email.text = admin['email']?.toString() ?? '';
    permissions..clear()
      ..addAll(List<String>.from(admin['permissions'] ?? const []));
    await showDialog<void>(context: context, builder: (dialogContext) =>
      StatefulBuilder(builder: (context, refreshDialog) => AlertDialog(
        title: Text(admin['full_name']?.toString() ?? 'Alt yönetici'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ...options.entries.map((entry) => CheckboxListTile(
            contentPadding: EdgeInsets.zero, title: Text(entry.value),
            value: permissions.contains(entry.key), activeColor: wine,
            onChanged: (value) => refreshDialog(() {
              if (value == true) { permissions.add(entry.key); }
              else { permissions.remove(entry.key); }
            }),
          )),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç')),
          FilledButton(onPressed: () async {
            Navigator.pop(dialogContext); await save();
          }, child: const Text('Kaydet')),
        ],
      )));
    if (!mounted) return;
    email.clear(); permissions.clear();
  }
  @override Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18), children: [
      const Text('Alt Yönetici Yetkileri', style: TextStyle(
        fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 6),
      const Text('Mevcut müşteri hesabını e-posta adresiyle seçip yönetim alanlarını yetkilendir.',
        style: TextStyle(color: muted)),
      const SizedBox(height: 16),
      TextField(controller: email, keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Kullanıcı e-posta adresi')),
      const SizedBox(height: 8),
      ...options.entries.map((entry) => CheckboxListTile(
        contentPadding: EdgeInsets.zero, title: Text(entry.value),
        value: permissions.contains(entry.key), activeColor: wine,
        onChanged: (value) => setState(() {
          if (value == true) { permissions.add(entry.key); }
          else { permissions.remove(entry.key); }
        }),
      )),
      const SizedBox(height: 8),
      FilledButton(onPressed: saving ? null : save,
        child: Text(saving ? 'Kaydediliyor...' : 'Alt yönetici yetkilerini kaydet')),
      const SectionTitle('Yetkili hesaplar'),
      if (loading) const Center(child: CircularProgressIndicator(color: wine))
      else if (admins.isEmpty) const Text('Henüz alt yönetici eklenmedi.',
        style: TextStyle(color: muted))
      else ...admins.map((admin) => Card(color: Colors.white, elevation: 0,
        child: ListTile(
          leading: const CircleAvatar(backgroundColor: blush,
            child: Icon(Icons.admin_panel_settings, color: wine)),
          title: Text(admin['full_name']?.toString() ?? 'Kullanıcı'),
          subtitle: Text('${admin['email'] ?? ''} • '
            '${(admin['permissions'] as List? ?? []).length} yetki'),
          trailing: Wrap(children: [
            IconButton(icon: const Icon(Icons.edit_outlined, color: wine),
              onPressed: () => edit(admin)),
            IconButton(icon: const Icon(Icons.delete_outline, color: wine),
              onPressed: () => revoke(admin)),
          ]),
        ),
      )),
    ],
  );
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override State<AdminHome> createState() => _AdminHomeState();
}
class _AdminHomeState extends State<AdminHome> {
  late Future<Map<String, dynamic>> stats;
  @override
  void initState() { super.initState(); stats = load(); }
  Future<Map<String, dynamic>> load() async {
    final rows = await Supabase.instance.client.rpc('admin_dashboard_stats');
    final row = (rows as List).first as Map;
    return Map<String, dynamic>.from(row);
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: stats,
    builder: (context, snapshot) => PageBody(children: [
      const Text('Genel Bakış', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 14),
      const HeroPanel(eyebrow: 'Platform kontrolü', title: 'Kuaförüm ekosistemini yönet',
        subtitle: 'Kuaförüm platformunun genel durumunu görüntüle.',
        icon: Icons.admin_panel_settings, button: 'Platformu yönet'),
      const SizedBox(height: 14),
      if (snapshot.connectionState == ConnectionState.waiting)
        const Center(child: CircularProgressIndicator(color: wine))
      else if (snapshot.hasError)
        _FeedMessage(icon: Icons.cloud_off_outlined, title: 'İstatistikler yüklenemedi', detail: snapshot.error.toString())
      else
        Row(children: [
          Expanded(child: _StatCard(snapshot.data!['business_count'].toString(), 'İşletme')),
          Expanded(child: _StatCard(snapshot.data!['user_count'].toString(), 'Kullanıcı')),
          Expanded(child: _StatCard(snapshot.data!['post_count'].toString(), 'Paylaşım')),
        ]),
      const SectionTitle('Yönetim araçları'),
      const Text('İşletme onayları, kullanıcı güvenliği ve Keşfet erişimleri. Ana yönetici hesabında randevu alma veya müşteri ekranları bulunmaz.', style: TextStyle(color: muted, height: 1.5)),
    ]),
  );
}
class AdminBusinesses extends StatefulWidget {
  const AdminBusinesses({super.key});
  @override State<AdminBusinesses> createState() => _AdminBusinessesState();
}

class _AdminBusinessesState extends State<AdminBusinesses> {
  final client = Supabase.instance.client;
  final search = TextEditingController();
  late Future<List<Map<String, dynamic>>> businesses;
  String query = '';

  @override
  void initState() { super.initState(); businesses = load(); }
  @override
  void dispose() { search.dispose(); super.dispose(); }

  Future<List<Map<String, dynamic>>> load() async =>
    List<Map<String, dynamic>>.from(await client.rpc('admin_list_businesses') as List);

  Future<void> refreshData() async {
    final next = load();
    setState(() => businesses = next);
    await next;
  }

  Future<void> setStatus(String id, String status) async {
    try {
      await client.rpc('admin_set_business_status', params: {'p_business_id': id, 'p_status': status});
      await refreshData();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İşletme durumu değiştirilemedi: $error')));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: businesses,
    builder: (context, snapshot) {
      final items = (snapshot.data ?? []).where((b) =>
        '${b['name'] ?? ''} ${b['address'] ?? ''}'.toLowerCase().contains(query.toLowerCase())).toList();
      return RefreshIndicator(
        onRefresh: refreshData,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(18), children: [
          const Text('İşletme Yönetimi', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 12),
          TextField(controller: search, onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(hintText: 'İşletme ara...', prefixIcon: Icon(Icons.search))),
          const SizedBox(height: 12),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator(color: wine))
          else if (snapshot.hasError)
            _FeedMessage(icon: Icons.cloud_off_outlined, title: 'İşletmeler yüklenemedi', detail: snapshot.error.toString())
          else if (items.isEmpty)
            const _FeedMessage(icon: Icons.store_outlined, title: 'İşletme bulunamadı', detail: 'Arama ölçütünü değiştir.')
          else
            ...items.map((b) {
              final status = b['status']?.toString() ?? 'inactive';
              final paid = b['discover_paid'] == true;
              return Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 10),
                child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const CircleAvatar(backgroundColor: blush, child: Icon(Icons.store, color: wine)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(b['name']?.toString() ?? 'İşletme', style: const TextStyle(fontWeight: FontWeight.bold, color: ink)),
                      Text(b['address']?.toString() ?? 'Adres yok', style: const TextStyle(color: muted, fontSize: 12)),
                    ])),
                    PopupMenuButton<String>(
                      onSelected: (value) => setStatus(b['id'].toString(), value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'active', child: Text('Aktif yap')),
                        PopupMenuItem(value: 'inactive', child: Text('Geçici kapat')),
                        PopupMenuItem(value: 'rejected', child: Text('Reddet')),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text('Durum: ${status == 'active' ? 'Aktif' : status == 'rejected' ? 'Reddedildi' : 'Pasif'}',
                    style: const TextStyle(color: muted, fontSize: 12)),
                  if (paid)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Keşfet üst sıra hakkı tanımlı.',
                        style: TextStyle(color: muted, fontSize: 12)),
                    ) else const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Keşfet üst sıra hakkı tanımlı değil.',
                        style: TextStyle(color: muted, fontSize: 12)),
                    ),
                ])),
              );
            }),
        ]),
      );
    },
  );
}
class AdminUsers extends StatefulWidget {
  const AdminUsers({super.key});
  @override State<AdminUsers> createState() => _AdminUsersState();
}

class _AdminUsersState extends State<AdminUsers> {
  final client = Supabase.instance.client;
  final search = TextEditingController();
  late Future<List<Map<String, dynamic>>> users;
  String query = '';
  @override
  void initState() { super.initState(); users = load(); }
  @override
  void dispose() { search.dispose(); super.dispose(); }
  Future<List<Map<String, dynamic>>> load() async =>
    List<Map<String, dynamic>>.from(await client.rpc('admin_list_users') as List);
  Future<void> refreshData() async { final next = load(); setState(() => users = next); await next; }
  Future<void> setBlocked(String id, bool blocked) async {
    try {
      await client.rpc('set_user_blocked', params: {'p_user_id': id, 'p_blocked': blocked});
      await refreshData();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kullanıcı durumu değiştirilemedi: $error')));
    }
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: users,
    builder: (context, snapshot) {
      final items = (snapshot.data ?? []).where((u) =>
        '${u['full_name'] ?? ''} ${u['email'] ?? ''} ${u['phone'] ?? ''}'.toLowerCase().contains(query.toLowerCase())).toList();
      return RefreshIndicator(onRefresh: refreshData, child: ListView(
        physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(18), children: [
          const Text('Kullanıcı Yönetimi', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 12),
          TextField(controller: search, onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(hintText: 'İsim, e-posta veya telefon ara...', prefixIcon: Icon(Icons.search))),
          const SizedBox(height: 12),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator(color: wine))
          else if (snapshot.hasError)
            _FeedMessage(icon: Icons.cloud_off_outlined, title: 'Kullanıcılar yüklenemedi', detail: snapshot.error.toString())
          else if (items.isEmpty)
            const _FeedMessage(icon: Icons.people_outline, title: 'Kullanıcı bulunamadı', detail: 'Arama ölçütünü değiştir.')
          else
            ...items.map((u) {
              final admin = u['is_admin'] == true;
              final blocked = u['is_blocked'] == true;
              return Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: blush, child: Icon(admin ? Icons.admin_panel_settings : Icons.person, color: wine)),
                  title: Text(u['full_name']?.toString() ?? 'Kullanıcı', style: const TextStyle(fontWeight: FontWeight.bold, color: ink)),
                  subtitle: Text('${u['email'] ?? ''} • ${u['account_type'] ?? 'customer'} • ${blocked ? 'Engelli' : 'Aktif'}'),
                  trailing: admin ? const Icon(Icons.verified_user, color: wine) : IconButton(
                    tooltip: blocked ? 'Engeli kaldır' : 'Engelle',
                    icon: Icon(blocked ? Icons.lock_open : Icons.block, color: wine),
                    onPressed: () => setBlocked(u['id'].toString(), !blocked),
                  ),
                ),
              );
            }),
        ],
      ));
    },
  );
}
class DiscoverControl extends StatefulWidget {
  const DiscoverControl({super.key});
  @override State<DiscoverControl> createState() => _DiscoverControlState();
}
class _DiscoverControlState extends State<DiscoverControl> {
  final client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> businesses;
  @override
  void initState() { super.initState(); businesses = load(); }
  Future<List<Map<String, dynamic>>> load() async =>
    List<Map<String, dynamic>>.from(await client.rpc('admin_list_discover_businesses') as List);
  Future<void> refreshData() async { final next = load(); setState(() => businesses = next); await next; }
  Future<void> update(String id, bool enabled) async {
    try {
      await client.rpc('admin_set_discover_visibility', params: {'p_business_id': id, 'p_enabled': enabled});
      await refreshData();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Keşfet erişimi güncellenemedi: $error'), backgroundColor: wine),
      );
    }
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: businesses,
    builder: (context, snapshot) {
      final eligible = (snapshot.data ?? []).where((b) => b['status'] == 'active' && b['discover_paid'] == true).toList();
      return RefreshIndicator(onRefresh: refreshData, child: ListView(
        physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(18), children: [
          const Text('Keşfet Görünürlüğü', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 8),
          const Text('Üst sıralarda gösterim hakkı olan aktif işletmelerin görünürlüğünü buradan yönet.', style: TextStyle(color: muted)),
          const SizedBox(height: 14),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator(color: wine))
          else if (snapshot.hasError)
            _FeedMessage(icon: Icons.cloud_off_outlined, title: 'Erişim bilgileri yüklenemedi', detail: snapshot.error.toString())
          else if (eligible.isEmpty)
            const _FeedMessage(icon: Icons.explore_outlined, title: 'Uygun işletme yok', detail: 'Üst sıra görünürlüğü hakkı tanımlanmış aktif işletme bulunmuyor.')
          else
            ...eligible.map((business) => SwitchListTile(
              value: business['discover_enabled'] == true,
              onChanged: (value) => update(business['id'].toString(), value),
              activeThumbColor: wine,
              secondary: const Icon(Icons.store, color: wine),
              title: Text(business['name']?.toString() ?? 'İşletme', style: const TextStyle(fontWeight: FontWeight.bold, color: ink)),
              subtitle: Text(business['discover_enabled'] == true ? 'Keşfet üst sıralarında açık' : 'Keşfet üst sıralarında kapalı'),
            )),
        ],
      ));
    },
  );
}
).hasMatch(normalized)) {
          throw Exception('Geçerli bir Türkiye cep telefonu numarası gir.');
        }
        await client.from('profiles').update({'phone': normalized})
          .eq('id', client.auth.currentUser!.id);
        await refreshProfile();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Telefon numaran güncellendi.')));
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Telefon güncellenemedi: $error'),backgroundColor:wine));
      }
    }
    controller.dispose();
  }

  Future<void> changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) =>
      AlertDialog(
        title: const Text('Şifre değiştir'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: current, obscureText: true,
            decoration: const InputDecoration(labelText: 'Mevcut şifre')),
          TextField(controller: next, obscureText: true,
            decoration: const InputDecoration(labelText: 'Yeni şifre')),
          TextField(controller: confirm, obscureText: true,
            decoration: const InputDecoration(labelText: 'Yeni şifre tekrar')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Değiştir')),
        ],
      ));
    if (accepted == true) {
      try {
        if (next.text.length < 8 || next.text != confirm.text) {
          throw Exception('Yeni şifre en az 8 karakter olmalı ve iki alan eşleşmeli.');
        }
        final userEmail = client.auth.currentUser?.email;
        if (userEmail == null) throw Exception('Hesap e-postası bulunamadı.');
        await client.auth.signInWithPassword(email: userEmail, password: current.text);
        await client.auth.updateUser(UserAttributes(password: next.text));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şifren başarıyla değiştirildi.')));
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Şifre değiştirilemedi: $error'), backgroundColor: wine));
      }
    }
    current.dispose();
    next.dispose();
    confirm.dispose();
  }

  Future<void> uploadAvatar() async {
    final user = client.auth.currentUser;
    if (user == null || uploading) return;
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 2048, maxHeight: 2048);
    if (image == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 88,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Profil Fotoğrafını Düzenle',
          toolbarColor: wine,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Profil Fotoğrafını Düzenle',
          aspectRatioLockEnabled: true,
        ),
      ],
    );
    if (cropped == null) return;
    setState(() => uploading = true);
    try {
      final file = File(cropped.path);
      if (await file.length() > 5 * 1024 * 1024) throw Exception('Fotoğraf 5 MB sınırını aşıyor.');
      const contentType = 'image/jpeg';
      final path = 'profiles/${user.id}/avatar.jpg';
      await client.storage.from('salon-avatars').upload(path, file,
        fileOptions: FileOptions(upsert: true, contentType: contentType));
      final url = client.storage.from('salon-avatars').getPublicUrl(path);
      await client.from('profiles').update({'avatar_url': url}).eq('id', user.id);
      await refreshProfile();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil fotoğrafı yüklenemedi: $error'), backgroundColor: wine),
      );
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> deleteAccount() async {
    final password = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) =>
      AlertDialog(
        title: const Text('Hesabını kalıcı olarak sil'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Hesabın ve hesabına bağlı kişisel verilerin silinmesini onaylıyor musun? Bu işlem geri alınamaz.'),
          const SizedBox(height: 12),
          TextField(controller: password, obscureText: true,
            decoration: const InputDecoration(labelText: 'Mevcut şifren')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hesabımı sil', style: TextStyle(color: wine))),
        ],
      ));
    if (confirmed != true) { password.dispose(); return; }
    try {
      await client.functions.invoke('delete-my-account', body: {'password': password.text});
      await client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const KuaforumApp(autoResume: false)),
        (route) => false,
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hesap silinemedi: $error'), backgroundColor: wine));
    } finally {
      password.dispose();
    }
  }

  Future<void> leaveEmployeeBusiness() async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) =>
      AlertDialog(
        title: const Text('İşletmeden ayrıl'),
        content: const Text('Çalışan bağlantın kaldırılacak ve hesabın müşteri hesabına dönecek. Daha sonra başka bir işletmeye katılabilirsin. Devam edilsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ayrıl', style: TextStyle(color: wine))),
        ],
      ));
    if (confirmed != true) return;
    try {
      await client.rpc('leave_employee_business');
      await client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const KuaforumApp(autoResume: false)),
        (route) => false,
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşletmeden ayrılamadın: $error'), backgroundColor: wine),
      );
    }
  }

  Future<void> logout() async {
    await client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const KuaforumApp(autoResume: false)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: profile,
    builder: (context, snapshot) => PageBody(children: [
      Center(child: Stack(children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: blush,
          backgroundImage: snapshot.data?['avatar_url'] != null ? NetworkImage(snapshot.data!['avatar_url'].toString()) : null,
          child: snapshot.data?['avatar_url'] == null ? const Icon(Icons.person, size: 55, color: wine) : null,
        ),
        Positioned(right: 0, bottom: 0, child: IconButton.filled(
          style: IconButton.styleFrom(backgroundColor: wine),
          onPressed: uploading ? null : uploadAvatar,
          icon: uploading ? const SizedBox(width: 18,height: 18,child: CircularProgressIndicator(strokeWidth: 2,color: Colors.white)) : const Icon(Icons.camera_alt, color: Colors.white, size: 18),
        )),
      ])),
      const SizedBox(height: 10),
      if (snapshot.connectionState == ConnectionState.waiting)
        const Center(child: CircularProgressIndicator(color: wine))
      else if (snapshot.hasError)
        Text('Profil yüklenemedi: ${snapshot.error}', style: const TextStyle(color: wine))
      else ...[
        Text(snapshot.data!['full_name']?.toString() ?? 'Kuaförüm kullanıcısı',
          textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink)),
        Text(snapshot.data!['email']?.toString() ?? '', textAlign: TextAlign.center, style: const TextStyle(color: muted)),
        Text(snapshot.data!['phone']?.toString() ?? 'Telefon eklenmemiş', textAlign: TextAlign.center, style: const TextStyle(color: muted)),
        const SizedBox(height: 20),
        ...[
          ('Telefon numarasını düzenle', Icons.phone_outlined, () => editPhone(snapshot.data!['phone']?.toString() ?? '')),
          ('Şifre değiştir', Icons.lock_outline, changePassword),
          ('Randevularım', Icons.calendar_month, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppointmentsPage(title: 'Randevularım')))),
          ('Yardım ve Destek', Icons.support_agent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportTicketsPage()))),
          ('Bildirim Tercihleri', Icons.notifications_active_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Bildirim Tercihleri')), body: const NotificationPreferencesPage())))),
          ('Aktif Cihazlar', Icons.devices_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Aktif Cihazlar')), body: const ActiveSessionsPage())))),
          ('Çıkış Yap', Icons.logout, logout),
          if (snapshot.data!['account_type'] == 'customer') ('Hesabı kalıcı sil', Icons.delete_forever, deleteAccount),
        ].map((item) => Card(color: Colors.white, elevation: 0, child: ListTile(
          leading: Icon(item.$2, color: wine),
          title: Text(item.$1, style: const TextStyle(color: ink, fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right, color: muted),
          onTap: item.$3,
        ))),
        if (snapshot.data!['account_type'] == 'employee') ...[
          Card(color: Colors.white, elevation: 0, child: ListTile(
            leading: const Icon(Icons.link_off, color: wine),
            title: const Text('İşletmeden ayrıl', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: muted),
            onTap: leaveEmployeeBusiness,
          )),
          const SectionTitle('Çalışma ve İzin'),
          Card(color: Colors.white, elevation: 0, child: ListTile(
            leading: const Icon(Icons.schedule, color: wine),
            title: const Text('Çalışma saatlerim', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: muted),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
              appBar: AppBar(title: Text('Çalışma Saatlerim')), body: EmployeeSchedulePage()))),
          )),
          Card(color: Colors.white, elevation: 0, child: ListTile(
            leading: const Icon(Icons.event_busy, color: wine),
            title: const Text('İzin talebi', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: muted),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
              appBar: AppBar(title: Text('İzin Talebi')), body: EmployeeTimeOffPage()))),
          )),
        ],
        if (snapshot.data!['account_type'] == 'customer') ...[
          Card(color: Colors.white, elevation: 0, child: ListTile(
            leading: const Icon(Icons.favorite_border, color: wine),
            title: const Text('Takip ettiklerim', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: muted),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
              appBar: AppBar(title: Text('Takip Ettiklerim')), body: MyFollowingPage()))),
          )),
          const SectionTitle('İşletmelerim'),
          ...(snapshot.data!['memberships'] as List<Map<String, dynamic>>).map((membership) {
            final business = membership['businesses'] is Map
                ? Map<String, dynamic>.from(membership['businesses'] as Map)
                : <String, dynamic>{};
            return Card(color: Colors.white, elevation: 0, child: ListTile(
              leading: const Icon(Icons.storefront_outlined, color: wine),
              title: Text(business['name'] as String? ?? 'İşletme', style: const TextStyle(color: ink)),
              subtitle: Text(business['address'] as String? ?? '', style: const TextStyle(color: muted)),
              trailing: TextButton(onPressed: () => leaveBusiness(membership['business_id'] as String),
                child: const Text('Ayrıl')),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessProfilePage(
                businessId: membership['business_id'] as String,
              ))),
            ));
          }),
          Card(color: Colors.white, elevation: 0, child: ListTile(
            leading: const Icon(Icons.add_business_outlined, color: wine),
            title: const Text('İşletmeye katıl', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: muted),
            onTap: joinBusiness,
          )),
        ],
      ],
    ]),
  );
}
class BusinessProfilePage extends StatefulWidget {
  final String businessId;
  const BusinessProfilePage({super.key, required this.businessId});
  @override State<BusinessProfilePage> createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends State<BusinessProfilePage> {
  final client = Supabase.instance.client;
  final feedRepository = KuaforumFeedRepository();
  final messagingRepository = KuaforumMessagingRepository();
  late Future<Map<String, dynamic>> data;
  bool following = false;
  bool followBusy = false;

  @override
  void initState() {
    super.initState();
    data = load();
  }

  Future<Map<String, dynamic>> load() async {
    final business = Map<String, dynamic>.from(await client.from('businesses')
      .select('id,name,address,logo_url,is_temporarily_closed')
      .eq('id', widget.businessId).eq('status', 'active').single());
    final results = await Future.wait([
      client.from('services').select('id,name,price,duration_minutes')
        .eq('business_id', widget.businessId).eq('is_active', true).order('name'),
      client.from('public_business_employees').select('id,display_name,avatar_url')
        .eq('business_id', widget.businessId).order('display_name'),
      client.from('business_reviews').select('id,customer_id,rating,body,created_at')
        .eq('business_id', widget.businessId).order('created_at', ascending: false).limit(30),
      client.from('feed_follows').select('id').eq('followed_business_id', widget.businessId),
    ]);
    final services = List<Map<String, dynamic>>.from(results[0]);
    final employees = List<Map<String, dynamic>>.from(results[1]);
    final reviews = List<Map<String, dynamic>>.from(results[2]);
    final followers = results[3] as List;
    final customerIds = reviews.map((r) => r['customer_id'] as String).toSet().toList();
    final profiles = customerIds.isEmpty ? [] : await client.from('public_profiles')
      .select('id,full_name,avatar_url').inFilter('id', customerIds);
    final profileMap = {for (final p in profiles) p['id'] as String: p};
    for (final review in reviews) {
      review['customer_profile'] = profileMap[review['customer_id']] ?? {};
    }
    final posts = await feedRepository.fetchBusinessFeed(widget.businessId);
    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      following = await feedRepository.isFollowingBusiness(widget.businessId);
    }
    return {
      'business': business,
      'services': services,
      'employees': employees,
      'reviews': reviews,
      'followers': followers.length,
      'posts': posts,
    };
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => data = next);
    await next;
  }

  Future<void> toggleFollow() async {
    if (followBusy) return;
    setState(() { followBusy = true; following = !following; });
    try {
      if (following) {
        await feedRepository.followBusiness(widget.businessId);
      } else {
        await feedRepository.unfollowBusiness(widget.businessId);
      }
    } catch (error) {
      if (mounted) {
        setState(() => following = !following);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Takip durumu güncellenemedi: $error'), backgroundColor: wine),
        );
      }
    } finally {
      if (mounted) setState(() => followBusy = false);
    }
  }

  Future<void> messageBusiness(String businessName) async {
    try {
      final conversationId = await messagingRepository.startBusinessConversation(widget.businessId);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(
        conversationId: conversationId,
        title: businessName,
        subtitle: 'İşletme',
      )));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşletmeye mesaj gönderilemedi: $error'), backgroundColor: wine),
      );
    }
  }

  Future<void> bookAppointment(String businessName) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      appBar: AppBar(title: Text(businessName)),
      body: BusinessBookingPage(businessId: widget.businessId, businessName: businessName),
    )));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: data,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator(color: wine)));
      }
      if (snapshot.hasError || snapshot.data == null) {
        return Scaffold(appBar: AppBar(), body: Center(
          child: Text('İşletme profili yüklenemedi: ${snapshot.error ?? ''}', style: const TextStyle(color: wine)),
        ));
      }
      final business = snapshot.data!['business'] as Map<String, dynamic>;
      final services = snapshot.data!['services'] as List<Map<String, dynamic>>;
      final employees = snapshot.data!['employees'] as List<Map<String, dynamic>>;
      final reviews = snapshot.data!['reviews'] as List<Map<String, dynamic>>;
      final posts = snapshot.data!['posts'] as List<KuaforumFeedPost>;
      final rawLogo = business['logo_url'] as String?;
      final logo = rawLogo == null || rawLogo.isEmpty ? null :
        (rawLogo.startsWith('http') ? rawLogo : client.storage.from('salon-avatars').getPublicUrl(rawLogo));
      final average = reviews.isEmpty ? 'Yeni' :
        (reviews.fold<double>(0, (sum, r) => sum + ((r['rating'] as num?)?.toDouble() ?? 0)) / reviews.length).toStringAsFixed(1);
      final closed = business['is_temporarily_closed'] == true;
      return Scaffold(
        backgroundColor: cream,
        appBar: AppBar(title: const Text('İşletme Profili')),
        body: RefreshIndicator(
          color: wine,
          onRefresh: refresh,
          child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
            Center(child: CircleAvatar(
              radius: 48, backgroundColor: blush,
              backgroundImage: logo == null ? null : NetworkImage(logo),
              child: logo == null ? const Icon(Icons.storefront, size: 48, color: wine) : null,
            )),
            const SizedBox(height: 10),
            Text(business['name'] as String? ?? 'Kuaför', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: ink)),
            Text(business['address'] as String? ?? 'Adres belirtilmemiş',
              textAlign: TextAlign.center, style: const TextStyle(color: muted)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.star_rounded, color: Color(0xFFE5A93D), size: 20),
              const SizedBox(width: 4),
              Text('$average  •  ${reviews.length} değerlendirme  •  ${snapshot.data!['followers']} takipçi',
                style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
            if (closed) const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('İşletme şu anda geçici olarak kapalı.', textAlign: TextAlign.center,
                style: TextStyle(color: wine, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: followBusy ? null : toggleFollow,
              icon: Icon(following ? Icons.favorite : Icons.favorite_border),
              label: Text(following ? 'Takip ediliyor' : 'İşletmeyi takip et'),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => messageBusiness(business['name'] as String? ?? 'İşletme'),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('İşletmeye mesaj gönder'),
            ),
            const SectionTitle('Hizmetler'),
            if (services.isEmpty) const Text('Henüz hizmet eklenmemiş.', style: TextStyle(color: muted))
            else ...services.map((service) => Card(
              color: Colors.white, elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.content_cut, color: wine),
                title: Text(service['name'] as String? ?? 'Hizmet', style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
                subtitle: Text('${service['duration_minutes']} dakika', style: const TextStyle(color: muted)),
                trailing: Text('${service['price']} ₺', style: const TextStyle(color: wine, fontWeight: FontWeight.w800)),
              ),
            )),
            const SectionTitle('Çalışanlarımız'),
            if (employees.isEmpty) const Text('Henüz aktif çalışan bulunmuyor.', style: TextStyle(color: muted))
            else ...employees.map((employee) {
              final avatar = employee['avatar_url'] as String?;
              return Card(
                color: Colors.white, elevation: 0,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: blush,
                    backgroundImage: avatar == null || avatar.isEmpty ? null : NetworkImage(avatar),
                    child: avatar == null || avatar.isEmpty ? const Icon(Icons.person, color: wine) : null,
                  ),
                  title: Text(employee['display_name'] as String? ?? 'Çalışan', style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
                ),
              );
            }),
            const SectionTitle('Paylaşımlar'),
            if (posts.isEmpty) const Text('Bu işletme henüz paylaşım yapmamış.', style: TextStyle(color: muted))
            else ...posts.map((post) => LiveFeedPostCard(post: post, repository: feedRepository)),
            const SectionTitle('Müşteri Değerlendirmeleri'),
            if (reviews.isEmpty) const Text('Henüz değerlendirme yok.', style: TextStyle(color: muted))
            else ...reviews.map((review) {
              final profile = review['customer_profile'] is Map ? review['customer_profile'] as Map : {};
              return Card(color: Colors.white, elevation: 0, child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(profile['full_name'] as String? ?? 'Müşteri',
                      style: const TextStyle(color: ink, fontWeight: FontWeight.w700))),
                    const Icon(Icons.star_rounded, color: Color(0xFFE5A93D), size: 18),
                    Text(' ${review['rating']}/5', style: const TextStyle(color: ink, fontWeight: FontWeight.bold)),
                  ]),
                  if ((review['body'] as String? ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(review['body'] as String, style: const TextStyle(color: muted, height: 1.4)),
                  ],
                ]),
              ));
            }),
          ]),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.all(14),
          child: SizedBox(height: 50, child: FilledButton(
            onPressed: closed ? null : () => bookAppointment(business['name'] as String? ?? 'İşletme'),
            style: FilledButton.styleFrom(backgroundColor: wine, foregroundColor: Colors.white),
            child: Text(closed ? 'Geçici olarak kapalı' : 'Randevu al'),
          )),
        ),
      );
    },
  );
}

class BusinessBookingPage extends StatefulWidget {
  final String businessId;
  final String businessName;
  const BusinessBookingPage({super.key, required this.businessId, required this.businessName});
  @override
  State<BusinessBookingPage> createState() => _BusinessBookingPageState();
}

class _BusinessBookingPageState extends State<BusinessBookingPage> {
  final client = Supabase.instance.client;
  List<Map<String, dynamic>> services = [];
  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> slots = [];
  String? serviceId;
  String? employeeId;
  String? selectedSlot;
  DateTime selectedDate = DateTime.now();
  bool loading = true;
  bool loadingSlots = false;
  bool booking = false;
  bool businessClosed = false;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final business = await client.from('businesses')
          .select('is_temporarily_closed').eq('id', widget.businessId).single();
      businessClosed = business['is_temporarily_closed'] as bool? ?? false;
      if (businessClosed) return;
      final results = await Future.wait([
        client.from('services').select('id,name,price,duration_minutes')
          .eq('business_id', widget.businessId).eq('is_active', true).order('name'),
        client.from('employees').select('id,display_name')
          .eq('business_id', widget.businessId).eq('is_active', true).not('user_id', 'is', null).order('display_name'),
      ]);
      services = List<Map<String, dynamic>>.from(results[0]);
      employees = List<Map<String, dynamic>>.from(results[1]);
      serviceId = services.isEmpty ? null : services.first['id'] as String;
      if (serviceId != null) await loadSlots();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Randevu bilgileri yüklenemedi: $error'), backgroundColor: wine));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String dateValue(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> loadSlots() async {
    if (serviceId == null) return;
    setState(() { loadingSlots = true; slots = []; selectedSlot = null; });
    try {
      final targets = employeeId == null
          ? employees
          : employees.where((e) => e['id'] == employeeId).toList();
      final all = <String, Map<String, dynamic>>{};
      for (final employee in targets) {
        final rows = await client.rpc('get_available_appointment_slots', params: {
          'p_business_id': widget.businessId,
          'p_employee_id': employee['id'],
          'p_service_id': serviceId,
          'p_date': dateValue(selectedDate),
        });
        for (final raw in rows as List) {
          final row = Map<String, dynamic>.from(raw);
          final start = row['slot_start'] as String;
          all.putIfAbsent(start, () => {...row, 'employee_id': employee['id']});
        }
      }
      final result = all.values.toList()
        ..sort((a, b) => DateTime.parse(a['slot_start'] as String)
          .compareTo(DateTime.parse(b['slot_start'] as String)));
      if (mounted) setState(() => slots = result);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uygun saatler alınamadı: $error'), backgroundColor: wine));
    } finally {
      if (mounted) setState(() => loadingSlots = false);
    }
  }

  Future<void> chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate.isBefore(DateTime.now()) ? DateTime.now() : selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null) return;
    setState(() => selectedDate = date);
    await loadSlots();
  }

  Future<void> book() async {
    if (serviceId == null || selectedSlot == null) return;
    final slot = slots.firstWhere((s) => s['slot_start'] == selectedSlot);
    setState(() => booking = true);
    try {
      await client.rpc('book_appointment', params: {
        'p_business_id': widget.businessId,
        'p_employee_id': slot['employee_id'],
        'p_service_id': serviceId,
        'p_starts_at': selectedSlot,
        'p_customer_note': null,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Randevu talebin oluşturuldu.')));
      Navigator.pop(context);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Randevu oluşturulamadı: $error'), backgroundColor: wine));
      await loadSlots();
    } finally {
      if (mounted) setState(() => booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: wine));
    if (businessClosed) return const Center(
      child: Padding(padding: EdgeInsets.all(24),
        child: Text('Bu işletme şu anda geçici olarak kapalı. Yeni randevu kabul edilmiyor.',
          textAlign: TextAlign.center, style: TextStyle(color: muted))),
    );
    return PageBody(children: [
      Text(widget.businessName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 6),
      const Text('Hizmetini, çalışanını ve sana uygun saati seç.', style: TextStyle(color: muted)),
      const SizedBox(height: 18),
      DropdownButtonFormField<String>(
        value: serviceId,
        decoration: const InputDecoration(labelText: 'Hizmet seç'),
        items: services.map((service) => DropdownMenuItem(
          value: service['id'] as String,
          child: Text('${service['name']} • ${service['price']} ₺'),
        )).toList(),
        onChanged: (value) async { setState(() => serviceId = value); await loadSlots(); },
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String?>(
        value: employeeId,
        decoration: const InputDecoration(labelText: 'Çalışan seç'),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Fark etmez')),
          ...employees.map((employee) => DropdownMenuItem<String?>(
            value: employee['id'] as String,
            child: Text(employee['display_name'] as String? ?? 'Çalışan'),
          )),
        ],
        onChanged: (value) async { setState(() => employeeId = value); await loadSlots(); },
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: chooseDate,
        icon: const Icon(Icons.calendar_month),
        label: Text(dateValue(selectedDate))),
      const SizedBox(height: 14),
      const Text('Uygun saatler', style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
      const SizedBox(height: 8),
      if (loadingSlots)
        const Center(child: CircularProgressIndicator(color: wine))
      else if (slots.isEmpty)
        const Text('Bu gün için uygun saat bulunamadı.', style: TextStyle(color: muted))
      else
        Wrap(spacing: 8, runSpacing: 8, children: slots.map((slot) {
          final start = DateTime.parse(slot['slot_start'] as String).toLocal();
          final label = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
          final value = slot['slot_start'] as String;
          return ChoiceChip(label: Text(label), selected: selectedSlot == value,
            onSelected: (_) => setState(() => selectedSlot = value), selectedColor: blush);
        }).toList()),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: booking || selectedSlot == null ? null : book,
        child: booking ? const CircularProgressIndicator() : const Text('Randevu talebi oluştur')),
    ]);
  }
}

class _Metric extends StatelessWidget {final String value,label;const _Metric(this.value,this.label);@override Widget build(BuildContext context)=>Column(children:[Text(value,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:wine)),Text(label,style:const TextStyle(fontSize:11,color:muted))]);}
class EmployeeHome extends StatefulWidget {
  const EmployeeHome({super.key});
  @override
  State<EmployeeHome> createState() => _EmployeeHomeState();
}

class _EmployeeHomeState extends State<EmployeeHome> {
  late Future<Map<String, dynamic>> data;
  @override
  void initState() { super.initState(); data = load(); }

  Future<Map<String, dynamic>> load() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Oturum bulunamadı.');
    final employee = await client.from('employees')
        .select('id,business_id,display_name')
        .eq('user_id', user.id).eq('is_active', true).maybeSingle();
    if (employee == null) throw Exception('Aktif çalışan kaydı bulunamadı.');
    final rows = List<Map<String, dynamic>>.from(await client.rpc(
      'get_business_appointments',
      params: {'p_business_id': employee['business_id'], 'p_mine_only': true},
    ) as List);
    final today = DateTime.now();
    final todays = rows.where((row) {
      final date = DateTime.parse(row['starts_at'] as String).toLocal();
      return date.year == today.year && date.month == today.month && date.day == today.day;
    }).toList();
    rows.sort((a, b) => DateTime.parse(a['starts_at'] as String)
        .compareTo(DateTime.parse(b['starts_at'] as String)));
    return {'employee': employee, 'appointments': rows, 'today': todays.length};
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: data,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator(color: wine));
      }
      if (snapshot.hasError || snapshot.data == null) {
        return Center(child: Text('Çalışan paneli yüklenemedi: ${snapshot.error ?? ''}',
          style: const TextStyle(color: muted)));
      }
      final employee = snapshot.data!['employee'] as Map<String, dynamic>;
      final appointments = snapshot.data!['appointments'] as List<Map<String, dynamic>>;
      return PageBody(children: [
        Text('Merhaba, ${employee['display_name'] ?? 'Çalışan'}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
        const Text('Bugünkü çalışma planın', style: TextStyle(color: muted)),
        const SizedBox(height: 16),
        Row(children: [
          _StatCard((snapshot.data!['today'] as int).toString(), 'Bugün Randevu'),
          _StatCard(appointments.length.toString(), 'Toplam Randevu'),
          _StatCard(appointments.where((a) => a['status'] == 'completed').length.toString(), 'Tamamlanan'),
        ]),
        const SizedBox(height: 16),
        const HeroPanel(eyebrow: 'Portfolyonu büyüt', title: 'Çalışmalarını paylaş',
          subtitle: 'Yaptığın işleri paylaş, müşterilerine ilham ver ve kariyerini büyüt.',
          icon: Icons.camera_alt, button: 'Paylaşım yap →'),
        const SectionTitle('Randevularım'),
        if (appointments.isEmpty)
          const Text('Henüz randevun bulunmuyor.', style: TextStyle(color: muted))
        else
          ...appointments.take(5).map((row) => AppointmentTile(
            name: row['customer_name'] as String? ?? 'Müşteri',
            service: row['service_name'] as String? ?? 'Hizmet',
            time: DateTime.parse(row['starts_at'] as String).toLocal().toString().substring(0, 16),
            status: row['status'] as String? ?? 'pending',
          )),
      ]);
    },
  );
}
class _StatCard extends StatelessWidget {final String v,l;const _StatCard(this.v,this.l);@override Widget build(BuildContext context)=>Expanded(child:Container(margin:const EdgeInsets.only(right:7),padding:const EdgeInsets.symmetric(vertical:15),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:blush)),child:Column(children:[Text(v,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:20,color:wine)),Text(l,textAlign:TextAlign.center,style:const TextStyle(fontSize:10,color:muted))])));}
class SharePage extends StatefulWidget {
  final bool businessPost;
  const SharePage({super.key,this.businessPost=false});
  @override State<SharePage> createState()=>_SharePageState();
}
class _SharePageState extends State<SharePage> {
  final caption=TextEditingController(); final picker=ImagePicker(); XFile? selectedMedia; bool isVideo=false;
  Future<void> chooseMedia(bool video) async { final file=video?await picker.pickVideo(source:ImageSource.gallery,maxDuration:const Duration(minutes:2)):await picker.pickImage(source:ImageSource.gallery,imageQuality:88); if(file!=null&&mounted)setState(() { selectedMedia=file; isVideo=video; }); }
  @override void dispose(){caption.dispose();super.dispose();}
  Future<void> publish() async {
    final text = caption.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paylaşımına kısa bir açıklama ekle.')));
      return;
    }
    if (selectedMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yayınlamak için fotoğraf veya video seçmelisin.')));
      return;
    }
    try {
      await KuaforumFeedRepository().publishPost(
        mediaFile: File(selectedMedia!.path),
        caption: text,
      );
      if (!mounted) return;
      setState(() {
        caption.clear();
        selectedMedia = null;
        isVideo = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paylaşımın Keşfet akışına yayınlandı.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paylaşım yayınlanamadı: $error'), backgroundColor: wine),
      );
    }
  }
  @override Widget build(BuildContext context)=>PageBody(children:[
    Row(children:[const Expanded(child:Text('Yeni Paylaşım',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:ink))),Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:blush,borderRadius:BorderRadius.circular(20)),child:Text(widget.businessPost?'İŞLETME':'ÇALIŞAN',style:const TextStyle(color:wine,fontWeight:FontWeight.w800,fontSize:10,letterSpacing:1)))]),
    const SizedBox(height:5),Text(widget.businessPost?'Salonunun güzelliklerini müşterilerinle paylaş.':'Yaptığın işleri paylaş, ilham ver ve portfolyonu büyüt.',style:const TextStyle(color:muted)),
    const SizedBox(height:16),
    Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(24),border:Border.all(color:blush),boxShadow:[BoxShadow(color:wine.withOpacity(.07),blurRadius:18,offset:const Offset(0,7))]),child:Column(children:[
      Container(height:230,width:double.infinity,decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),gradient:const LinearGradient(colors:[Color(0xFFF4DCE2),Color(0xFFD88DA2),Color(0xFF8E2947)],begin:Alignment.topLeft,end:Alignment.bottomRight)),child:Stack(children:[
        Positioned(right:14,top:14,child:Container(padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:Colors.white.withOpacity(.85),shape:BoxShape.circle),child:const Icon(Icons.auto_awesome,color:wine))),
        Center(child:selectedMedia!=null&&!isVideo?ClipRRect(borderRadius:BorderRadius.circular(18),child:Image.file(File(selectedMedia!.path),width:double.infinity,height:230,fit:BoxFit.cover)):Column(mainAxisSize:MainAxisSize.min,children:[Icon(isVideo?Icons.videocam_rounded:Icons.add_photo_alternate_rounded,size:54,color:Colors.white),const SizedBox(height:9),Text(selectedMedia==null?'Fotoğraf veya video seç':'Video hazır',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),const SizedBox(height:4),const Text('En güzel dönüşümünü burada göster ♡',style:TextStyle(color:Colors.white70,fontSize:11))])),
        Positioned(left:12,bottom:12,child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:BoxDecoration(color:Colors.black.withOpacity(.2),borderRadius:BorderRadius.circular(18)),child:const Text('ÖN İZLEME',style:TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.bold,letterSpacing:1))))
      ])),
      const SizedBox(height:12),Row(children:[
        Expanded(child:OutlinedButton.icon(onPressed:()=>chooseMedia(false),icon:const Icon(Icons.image_outlined),label:const Text('Fotoğraf'),style:OutlinedButton.styleFrom(foregroundColor:wine,side:const BorderSide(color:blush),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))))),
        const SizedBox(width:9),Expanded(child:OutlinedButton.icon(onPressed:()=>chooseMedia(true),icon:const Icon(Icons.videocam_outlined),label:const Text('Video'),style:OutlinedButton.styleFrom(foregroundColor:wine,side:const BorderSide(color:blush),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)))))
      ]),
      const SizedBox(height:14),TextField(controller:caption,maxLines:4,maxLength:500,decoration:InputDecoration(hintText:'Bu güzel çalışmayı anlat... ♡',filled:true,fillColor:cream,border:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:BorderSide.none),prefixIcon:const Icon(Icons.edit_note,color:wine))),
      const SizedBox(height:4),Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:cream,borderRadius:BorderRadius.circular(14)),child:const Row(children:[Icon(Icons.public,color:wine),SizedBox(width:9),Expanded(child:Text('Paylaşımın, işletmenin Keşfet görünürlüğü ve takip sistemi kurallarına göre ilgili akışlarda gösterilir.',style:TextStyle(color:muted,fontSize:11,height:1.35))) ])),
      const SizedBox(height:10),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:publish,icon:const Icon(Icons.send_rounded),label:const Text('Paylaşımı Yayınla'),style:FilledButton.styleFrom(backgroundColor:wine,foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(vertical:16),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)))))
    ])),
    const SizedBox(height:14),const Row(children:[Icon(Icons.lightbulb_outline,color:rose,size:18),SizedBox(width:7),Expanded(child:Text('İpucu: Öncesi/sonrası fotoğrafları ve kullandığın işlemi ekleyerek daha çok kişiye ulaş.',style:TextStyle(color:muted,fontSize:11)))])
  ]);
}

class OwnerProfilePage extends StatefulWidget {
  const OwnerProfilePage({super.key});
  @override
  State<OwnerProfilePage> createState() => _OwnerProfilePageState();
}

class _OwnerProfilePageState extends State<OwnerProfilePage> {
  final client = Supabase.instance.client;
  late Future<Map<String, dynamic>> data;

  @override
  void initState() {
    super.initState();
    data = load();
  }

  Future<Map<String, dynamic>> load() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Oturum bulunamadı.');
    final business = await client.from('businesses')
        .select('id,name,address,logo_url,status')
        .eq('owner_id', user.id)
        .maybeSingle();
    if (business == null) throw Exception('İşletme bilgisi bulunamadı.');
    final businessId = business['id'] as String;
    final followers = await client.from('feed_follows')
        .select('id').eq('followed_business_id', businessId);
    final posts = await client.from('feed_posts')
        .select('id').eq('business_id', businessId);
    return {
      'business': Map<String, dynamic>.from(business),
      'followers': followers.length,
      'posts': posts.length,
    };
  }

  Future<void> logout() async {
    await client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const KuaforumApp(autoResume: false)),
      (route) => false,
    );
  }

  void open(BuildContext context, String section) {
    final page = switch (section) {
      'Randevu Yönetimi' => const OwnerAppointments(),
      'Çalışan Randevuları' => const OwnerEmployeeAppointments(),
      'Müşterilerim' => const CustomersPage(),
      'Ayarlar' => const SettingsPage(),
      _ => const SettingsPage(),
    };
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(section,
          style: const TextStyle(color: wine, fontWeight: FontWeight.bold))),
        body: page,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: data,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator(color: wine));
      }
      if (snapshot.hasError || snapshot.data == null) {
        return Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('İşletme profili yüklenemedi: ${snapshot.error ?? 'Bilinmeyen hata'}',
            textAlign: TextAlign.center, style: const TextStyle(color: muted)),
        ));
      }
      final business = snapshot.data!['business'] as Map<String, dynamic>;
      final logo = business['logo_url'] as String?;
      final address = (business['address'] as String?)?.trim() ?? '';
      return PageBody(children: [
        Center(child: CircleAvatar(
          radius: 48,
          backgroundColor: blush,
          backgroundImage: logo != null && logo.isNotEmpty ? NetworkImage(logo) : null,
          child: logo == null || logo.isEmpty
              ? const Icon(Icons.storefront, size: 48, color: wine) : null,
        )),
        const SizedBox(height: 10),
        Text(business['name'] as String? ?? 'İşletmem',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: ink)),
        Text(address.isEmpty ? 'Adres eklenmemiş' : address,
          textAlign: TextAlign.center, style: const TextStyle(color: muted)),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _Metric((snapshot.data!['followers'] as int).toString(), 'Takipçi'),
          _Metric('—', 'Takip'),
          _Metric((snapshot.data!['posts'] as int).toString(), 'Paylaşım'),
        ]),
        const SizedBox(height: 18),
        const SectionTitle('İşletme Yönetimi'),
        ...['Randevu Yönetimi', 'Çalışan Randevuları', 'Müşterilerim', 'Ayarlar'].map((section) =>
          Card(color: Colors.white, elevation: 0, child: ListTile(
            leading: const Icon(Icons.circle_outlined, color: wine),
            title: Text(section, style: const TextStyle(color: ink, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, color: muted),
            onTap: () => open(context, section),
          ))),
        Card(color: Colors.white, elevation: 0, child: ListTile(
          leading: const Icon(Icons.devices_outlined, color: wine),
          title: const Text('Aktif Cihazlar', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right, color: muted),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Aktif Cihazlar')),
            body: const ActiveSessionsPage(),
          ))),
        )),
        Card(color: Colors.white, elevation: 0, child: ListTile(
          leading: const Icon(Icons.notifications_active_outlined, color: wine),
          title: const Text('Bildirim Tercihleri', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right, color: muted),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Bildirim Tercihleri')),
            body: const NotificationPreferencesPage(),
          ))),
        )),
        Card(color: Colors.white, elevation: 0, child: ListTile(
          leading: const Icon(Icons.logout, color: wine),
          title: const Text('Çıkış Yap', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right, color: muted),
          onTap: logout,
        )),
      ]);
    },
  );
}
class EmployeeManagementPage extends StatefulWidget {
  const EmployeeManagementPage({super.key});
  @override
  State<EmployeeManagementPage> createState() => _EmployeeManagementPageState();
}

class _EmployeeManagementPageState extends State<EmployeeManagementPage> {
  final client = Supabase.instance.client;
  late Future<Map<String, dynamic>> data;

  @override
  void initState() {
    super.initState();
    data = load();
  }

  Future<Map<String, dynamic>> load() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Oturum bulunamadı.');
    final business = await client.from('businesses').select('id')
        .eq('owner_id', user.id).maybeSingle();
    if (business == null) throw Exception('İşletme kaydı bulunamadı.');
    final employees = await client.from('employees')
        .select('id,display_name,is_active,user_id')
        .eq('business_id', business['id']).order('created_at');
    final employeeUserIds = employees
        .map((row) => row['user_id'])
        .whereType<String>()
        .toSet()
        .toList();
    final avatars = employeeUserIds.isEmpty
        ? <dynamic>[]
        : await client.from('public_profiles')
            .select('id,avatar_url')
            .inFilter('id', employeeUserIds);
    final avatarByUserId = {
      for (final profile in avatars)
        profile['id'] as String: profile['avatar_url'] as String?,
    };
    final employeesWithAvatars = employees.map((row) {
      final employee = Map<String, dynamic>.from(row);
      employee['avatar_url'] = avatarByUserId[employee['user_id']];
      return employee;
    }).toList();
    return {'business_id': business['id'], 'employees': employeesWithAvatars};
  }

  Future<void> refreshData() async {
    final next = load();
    setState(() => data = next);
    await next;
  }

  Future<void> inviteEmployee(String businessId) async {
    final firstName = TextEditingController();
    final lastName = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Çalışan hesabı oluştur'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: firstName, textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Ad')),
            TextField(controller: lastName, textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Soyad')),
            TextField(controller: phone, keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon')),
            TextField(controller: email, keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-posta')),
            TextField(controller: password, obscureText: true,
              decoration: const InputDecoration(labelText: 'İlk giriş şifresi (en az 8 karakter)')),
            const SizedBox(height: 8),
            const Text('Çalışana e-posta doğrulama bağlantısı gönderilir. Hesabı doğruladıktan sonra belirlediğin şifreyle giriş yapabilir.',
              style: TextStyle(color: muted, fontSize: 12)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Hesabı oluştur')),
        ],
      ),
    );
    if (accepted != true) {
      firstName.dispose(); lastName.dispose(); phone.dispose(); email.dispose(); password.dispose();
      return;
    }
    try {
      if ([firstName.text, lastName.text, phone.text, email.text, password.text]
          .any((value) => value.trim().isEmpty)) {
        throw Exception('Ad, soyad, telefon, e-posta ve şifre zorunludur.');
      }
      if (!email.text.trim().contains('@') || password.text.length < 8) {
        throw Exception('E-posta geçerli olmalı ve şifre en az 8 karakter olmalıdır.');
      }
      await client.functions.invoke('create-employee-account', body: {
        'business_id': businessId,
        'first_name': firstName.text.trim(),
        'last_name': lastName.text.trim(),
        'phone': phone.text.trim(),
        'email': email.text.trim().toLowerCase(),
        'password': password.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Çalışan hesabı oluşturuldu. E-posta doğrulaması bekleniyor.')),
      );
      await refreshData();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çalışan hesabı oluşturulamadı: $error'), backgroundColor: wine),
      );
    } finally {
      firstName.dispose(); lastName.dispose(); phone.dispose(); email.dispose(); password.dispose();
    }
  }

  Future<void> removeEmployee(String employeeId, String name) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) =>
      AlertDialog(
        title: const Text('Çalışanı kaldır'),
        content: Text('$name işletmenden kaldırılacak. Çalışanın hesabı müşteri hesabına dönecek; geçmiş randevu kayıtları korunacak.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Çalışanı kaldır', style: TextStyle(color: wine))),
        ],
      ));
    if (confirmed != true) return;
    try {
      await client.rpc('remove_employee', params: {'p_employee_id': employeeId});
      await refreshData();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çalışan kaldırılamadı: $error'), backgroundColor: wine),
      );
    }
  }

  Future<void> setActive(String employeeId, bool active) async {
    try {
      await client.rpc('set_employee_active', params: {
        'p_employee_id': employeeId,
        'p_is_active': active,
      });
      await refreshData();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çalışan durumu değiştirilemedi: $error'), backgroundColor: wine),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: data,
    builder: (context, snapshot) => RefreshIndicator(
      color: wine,
      onRefresh: refreshData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          const Text('Çalışanlar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 12),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator(color: wine))
          else if (snapshot.hasError)
            _FeedMessage(icon: Icons.cloud_off_outlined, title: 'Çalışanlar yüklenemedi', detail: snapshot.error.toString())
          else ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: wine, foregroundColor: Colors.white),
              onPressed: () => inviteEmployee(snapshot.data!['business_id'] as String),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Çalışan Davet Et'),
            ),
            const SizedBox(height: 12),
            if ((snapshot.data!['employees'] as List).isEmpty)
              const _FeedMessage(icon: Icons.people_outline, title: 'Henüz çalışan yok', detail: 'Çalışan Davet Et bölümünden ekibine yeni çalışan ekleyebilirsin.')
            else
              ...(snapshot.data!['employees'] as List).map((raw) {
                final employee = Map<String, dynamic>.from(raw as Map);
                final active = employee['is_active'] == true;
                return Card(
                  color: Colors.white,
                  elevation: 0,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: blush,
                      backgroundImage: (employee['avatar_url'] as String?)?.isNotEmpty == true
                          ? NetworkImage(employee['avatar_url'] as String)
                          : null,
                      child: (employee['avatar_url'] as String?)?.isNotEmpty == true
                          ? null
                          : const Icon(Icons.person, color: wine),
                    ),
                    title: Text(employee['display_name']?.toString() ?? 'Çalışan', style: const TextStyle(color: ink, fontWeight: FontWeight.bold)),
                    subtitle: Text(active ? (employee['user_id'] == null ? 'Davet bekliyor' : 'Aktif çalışan') : 'Pasif çalışan'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Switch(
                        value: active,
                        activeColor: wine,
                        onChanged: (value) => setActive(employee['id'].toString(), value),
                      ),
                      IconButton(
                        tooltip: 'Çalışanı kaldır',
                        onPressed: () => removeEmployee(
                          employee['id'].toString(),
                          employee['display_name']?.toString() ?? 'Çalışan',
                        ),
                        icon: const Icon(Icons.person_remove_alt_1, color: wine),
                      ),
                    ]),
                  ),
                );
              }),
          ],
        ],
      ),
    ),
  );
}
class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});
  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  final client = Supabase.instance.client;
  late Future<Map<String, dynamic>> data;

  @override
  void initState() {
    super.initState();
    data = load();
  }

  Future<Map<String, dynamic>> load() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Oturum bulunamadı.');
    final business = await client.from('businesses').select('id')
        .eq('owner_id', user.id).maybeSingle();
    if (business == null) throw Exception('İşletme kaydı bulunamadı.');
    final services = await client.from('services')
        .select('id,name,price,duration_minutes,is_active')
        .eq('business_id', business['id']).order('created_at');
    return {'business_id': business['id'], 'services': services};
  }

  Future<void> refreshData() async {
    final next = load();
    setState(() => data = next);
    await next;
  }

  Future<void> editService(String businessId, {Map<String, dynamic>? service}) async {
    final name = TextEditingController(text: service?['name']?.toString() ?? '');
    final price = TextEditingController(text: service?['price']?.toString() ?? '');
    final duration = TextEditingController(text: service?['duration_minutes']?.toString() ?? '30');
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(service == null ? 'Yeni hizmet' : 'Hizmeti düzenle'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Hizmet adı')),
          TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Fiyat (₺)')),
          TextField(controller: duration, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Süre (dakika)')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Kaydet')),
        ],
      ),
    );
    if (save != true) { name.dispose(); price.dispose(); duration.dispose(); return; }
    final parsedPrice = double.tryParse(price.text.trim().replaceAll(',', '.'));
    final parsedDuration = int.tryParse(duration.text.trim());
    if (name.text.trim().isEmpty || parsedPrice == null || parsedPrice < 0 || parsedDuration == null || parsedDuration < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hizmet adı, geçerli fiyat ve en az 5 dakikalık süre girin.')));
      name.dispose(); price.dispose(); duration.dispose(); return;
    }
    try {
      final values = {'name': name.text.trim(), 'price': parsedPrice, 'duration_minutes': parsedDuration};
      if (service == null) {
        await client.from('services').insert({...values, 'business_id': businessId, 'is_active': true});
      } else {
        await client.from('services').update(values).eq('id', service['id']);
      }
      await refreshData();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hizmet kaydedilemedi: $error'), backgroundColor: wine),
      );
    } finally {
      name.dispose(); price.dispose(); duration.dispose();
    }
  }

  Future<void> toggleService(String id, bool active) async {
    try {
      await client.from('services').update({'is_active': active}).eq('id', id);
      await refreshData();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hizmet durumu değiştirilemedi: $error'), backgroundColor: wine),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: data,
    builder: (context, snapshot) => RefreshIndicator(
      color: wine,
      onRefresh: refreshData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          const Text('Hizmetler', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 12),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator(color: wine))
          else if (snapshot.hasError)
            _FeedMessage(icon: Icons.cloud_off_outlined, title: 'Hizmetler yüklenemedi', detail: snapshot.error.toString())
          else ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: wine, foregroundColor: Colors.white),
              onPressed: () => editService(snapshot.data!['business_id'] as String),
              icon: const Icon(Icons.add),
              label: const Text('Yeni Hizmet Ekle'),
            ),
            const SizedBox(height: 12),
            if ((snapshot.data!['services'] as List).isEmpty)
              const _FeedMessage(icon: Icons.content_cut, title: 'Henüz hizmet eklenmemiş', detail: 'Müşterilerin randevu alabilmesi için hizmetlerini ekle.')
            else
              ...(snapshot.data!['services'] as List).map((raw) {
                final service = Map<String, dynamic>.from(raw as Map);
                final active = service['is_active'] == true;
                return Card(
                  color: Colors.white,
                  elevation: 0,
                  child: ListTile(
                    leading: const Icon(Icons.content_cut, color: wine),
                    title: Text(service['name']?.toString() ?? 'Hizmet', style: const TextStyle(color: ink, fontWeight: FontWeight.w600)),
                    subtitle: Text('₺${service['price']} • ${service['duration_minutes']} dakika • ${active ? 'Aktif' : 'Pasif'}'),
                    onTap: () => editService(snapshot.data!['business_id'] as String, service: service),
                    trailing: Switch(
                      value: active,
                      activeColor: wine,
                      onChanged: (value) => toggleService(service['id'].toString(), value),
                    ),
                  ),
                );
              }),
          ],
        ],
      ),
    ),
  );
}

class OwnerHome extends StatefulWidget {
  const OwnerHome({super.key});
  @override
  State<OwnerHome> createState() => _OwnerHomeState();
}

class _OwnerHomeState extends State<OwnerHome> {
  late Future<Map<String, dynamic>> data;
  @override
  void initState() { super.initState(); data = load(); }

  Future<Map<String, dynamic>> load() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Oturum bulunamadı.');
    final business = await client.from('businesses').select('id,name')
        .eq('owner_id', user.id).maybeSingle();
    if (business == null) throw Exception('İşletme bulunamadı.');
    final rows = List<Map<String, dynamic>>.from(await client.rpc(
      'get_business_appointments',
      params: {'p_business_id': business['id'], 'p_mine_only': false},
    ) as List);
    final customers = List<Map<String, dynamic>>.from(await client.rpc(
      'get_business_customers', params: {'p_business_id': business['id']},
    ) as List);
    final today = DateTime.now();
    final todays = rows.where((row) {
      final date = DateTime.parse(row['starts_at'] as String).toLocal();
      return date.year == today.year && date.month == today.month && date.day == today.day;
    }).toList();
    rows.sort((a, b) => DateTime.parse(b['starts_at'] as String)
        .compareTo(DateTime.parse(a['starts_at'] as String)));
    return {'business': business, 'appointments': rows, 'today': todays.length,
      'customers': customers.length};
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: data,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator(color: wine));
      }
      if (snapshot.hasError || snapshot.data == null) {
        return Center(child: Text('İşletme özeti yüklenemedi: ${snapshot.error ?? ''}',
          style: const TextStyle(color: muted)));
      }
      final business = snapshot.data!['business'] as Map<String, dynamic>;
      final appointments = snapshot.data!['appointments'] as List<Map<String, dynamic>>;
      return PageBody(children: [
        Text('${business['name'] ?? 'İşletme Yönetimi'}',
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 14),
        HeroPanel(eyebrow: 'İşletme paneli', title: 'İşletmeni yönet',
          subtitle: 'Randevularını, ekibini ve müşteri deneyimini tek yerden takip et.',
          icon: Icons.storefront, button: 'Yönetim araçları'),
        const SizedBox(height: 14),
        Row(children: [
          _StatCard((snapshot.data!['today'] as int).toString(), 'Bugünkü Randevu'),
          _StatCard((snapshot.data!['customers'] as int).toString(), 'Müşteri'),
          _StatCard(appointments.length.toString(), 'Toplam Randevu'),
        ]),
        const SectionTitle('Son Randevular', action: 'Tümünü Gör'),
        if (appointments.isEmpty)
          const Text('Henüz randevu bulunmuyor.', style: TextStyle(color: muted))
        else
          ...appointments.take(3).map((row) => AppointmentTile(
            name: row['customer_name'] as String? ?? 'Müşteri',
            service: row['service_name'] as String? ?? 'Hizmet',
            time: DateTime.parse(row['starts_at'] as String).toLocal().toString().substring(0, 16),
            status: row['status'] as String? ?? 'pending',
          )),
        const SectionTitle('Hızlı Yönetim'),
        const QuickTiles(),
      ]);
    },
  );
}
class OwnerAppointments extends StatelessWidget {
  const OwnerAppointments({super.key});
  @override
  Widget build(BuildContext context) => const AppointmentsPage(
    title: 'Randevum',
    ownerMode: true,
  );
}

class OwnerEmployeeAppointments extends StatelessWidget {
  const OwnerEmployeeAppointments({super.key});
  @override
  Widget build(BuildContext context) => const AppointmentsPage(
    title: 'Çalışan Randevuları',
    ownerMode: false,
  );
}
class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});
  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final client = Supabase.instance.client;
  final search = TextEditingController();
  late Future<Map<String, dynamic>> data;
  String query = '';

  @override
  void initState() {
    super.initState();
    data = load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> load() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Oturum bulunamadı.');
    final business = await client.from('businesses').select('id')
        .eq('owner_id', user.id).maybeSingle();
    if (business == null) throw Exception('İşletme kaydı bulunamadı.');
    final customers = await client.rpc('get_business_customers', params: {
      'p_business_id': business['id'],
    });
    return {'business_id': business['id'], 'customers': List<Map<String, dynamic>>.from(customers as List)};
  }

  Future<void> refreshData() async {
    final next = load();
    setState(() => data = next);
    await next;
  }

  Future<void> toggleBlacklist(String businessId, Map<String, dynamic> customer, bool blocked) async {
    try {
      await client.rpc('set_customer_blacklist', params: {
        'p_business_id': businessId,
        'p_customer_id': customer['customer_id'],
        'p_blocked': blocked,
        'p_reason': blocked ? 'İşletme tarafından kara listeye alındı' : null,
      });
      await refreshData();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kara liste güncellenemedi: $error'), backgroundColor: wine),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: data,
    builder: (context, snapshot) {
      final customers = (snapshot.data?['customers'] as List<Map<String, dynamic>>? ?? [])
          .where((customer) {
            final value = '${customer['full_name'] ?? ''} ${customer['phone'] ?? ''}'.toLowerCase();
            return value.contains(query.toLowerCase());
          }).toList();
      return RefreshIndicator(
        color: wine,
        onRefresh: refreshData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            const Text('Müşterilerim', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 12),
            TextField(
              controller: search,
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                hintText: 'İsim veya telefon ara...',
                prefixIcon: const Icon(Icons.search, color: wine),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: blush)),
              ),
            ),
            const SizedBox(height: 12),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator(color: wine))
            else if (snapshot.hasError)
              _FeedMessage(icon: Icons.cloud_off_outlined, title: 'Müşteriler yüklenemedi', detail: snapshot.error.toString())
            else if (customers.isEmpty)
              const _FeedMessage(icon: Icons.people_outline, title: 'Müşteri bulunamadı', detail: 'Arama ölçütünü değiştir veya işletmene bağlı müşterileri bekle.')
            else
              ...customers.map((customer) {
                final blocked = customer['is_blacklisted'] == true;
                return Card(
                  color: Colors.white,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: blush,
                      child: Icon(blocked ? Icons.block : Icons.person, color: wine),
                    ),
                    title: Text(customer['full_name']?.toString() ?? 'Müşteri', style: const TextStyle(fontWeight: FontWeight.bold, color: ink)),
                    subtitle: Text('${customer['phone'] ?? 'Telefon yok'} • ${customer['appointment_count'] ?? 0} randevu'),
                    isThreeLine: true,
                    trailing: TextButton(
                      onPressed: () => toggleBlacklist(snapshot.data!['business_id'] as String, customer, !blocked),
                      child: Text(blocked ? 'Listeden çıkar' : 'Kara listeye al',
                        style: TextStyle(color: blocked ? Colors.green.shade700 : wine, fontSize: 11)),
                    ),
                  ),
                );
              }),
          ],
        ),
      );
    },
  );
}
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void open(BuildContext context, String section) {
    final page = switch (section) {
      'İşletme Profili' => const BusinessDetailsPage(),
      'Çalışanlar' => const EmployeeManagementPage(),
      'Hizmetler' => const ServicesPage(),
      'Çalışma Saatleri' => const WorkingHoursPage(),
      'Randevu Aralığı' => const AppointmentIntervalPage(),
      'Çalışan İzinleri' => const OwnerTimeOffPage(),
      _ => null,
    };
    if (page == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(section, style: const TextStyle(color: wine, fontWeight: FontWeight.bold))),
        body: page,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => PageBody(children: [
    const Text('Ayarlar', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
    const SizedBox(height: 12),
    ...['İşletme Profili','Çalışanlar','Hizmetler','Çalışma Saatleri','Randevu Aralığı','Çalışan İzinleri'].map((section) => Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(switch (section) {
          'İşletme Profili' => Icons.storefront_outlined,
          'Çalışanlar' => Icons.people_outline,
          'Hizmetler' => Icons.content_cut,
          'Çalışma Saatleri' => Icons.schedule,
          'Randevu Aralığı' => Icons.timelapse,
          'Çalışan İzinleri' => Icons.event_busy,
          _ => Icons.settings_outlined,
        }, color: wine),
        title: Text(section, style: const TextStyle(fontWeight: FontWeight.w600, color: ink)),
        trailing: const Icon(Icons.chevron_right, color: muted),
        onTap: () => open(context, section),
      ),
    )),
  ]);
}

class BusinessDetailsPage extends StatefulWidget {
  const BusinessDetailsPage({super.key});
  @override
  State<BusinessDetailsPage> createState() => _BusinessDetailsPageState();
}

class _BusinessDetailsPageState extends State<BusinessDetailsPage> {
  final client = Supabase.instance.client;
  final name = TextEditingController();
  final address = TextEditingController();
  String? businessId;
  bool loading = true;
  bool saving = false;
  bool temporarilyClosed = false;
  bool uploadingLogo = false;
  String? logoPath;

  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { name.dispose(); address.dispose(); super.dispose(); }

  Future<void> load() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) throw Exception('Oturum bulunamadı.');
      final row = await client.from('businesses')
          .select('id,name,address,is_temporarily_closed,logo_url').eq('owner_id', user.id).maybeSingle();
      if (row == null) throw Exception('İşletme bulunamadı.');
      businessId = row['id'] as String;
      name.text = row['name'] as String? ?? '';
      address.text = row['address'] as String? ?? '';
      temporarilyClosed = row['is_temporarily_closed'] as bool? ?? false;
      logoPath = row['logo_url'] as String?;
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşletme bilgileri yüklenemedi: $error')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> uploadLogo() async {
    final user = client.auth.currentUser;
    if (user == null || businessId == null || uploadingLogo) return;
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery, imageQuality: 90, maxWidth: 2048, maxHeight: 2048,
    );
    if (image == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 88,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'İşletme Fotoğrafını Düzenle',
          toolbarColor: wine,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'İşletme Fotoğrafını Düzenle',
          aspectRatioLockEnabled: true,
        ),
      ],
    );
    if (cropped == null) return;
    setState(() => uploadingLogo = true);
    try {
      final file = File(cropped.path);
      if (await file.length() > 5 * 1024 * 1024) {
        throw Exception('Logo 5 MB sınırını aşıyor.');
      }
      const contentType = 'image/jpeg';
      final path = 'businesses/$businessId/logo_${DateTime.now().microsecondsSinceEpoch}.jpg';
      await client.storage.from('salon-avatars').upload(path, file,
        fileOptions: FileOptions(contentType: contentType, upsert: false));
      await client.rpc('set_my_business_logo', params: {
        'p_business_id': businessId, 'p_logo_path': path,
      });
      final oldPath = logoPath;
      if (oldPath != null && oldPath.startsWith('businesses/$businessId/')) {
        try { await client.storage.from('salon-avatars').remove([oldPath]); } catch (_) {}
      }
      if (mounted) {
        setState(() => logoPath = path);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İşletme fotoğrafı güncellendi.')),
        );
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşletme fotoğrafı yüklenemedi: $error'), backgroundColor: wine),
      );
    } finally {
      if (mounted) setState(() => uploadingLogo = false);
    }
  }

  Future<void> setTemporaryClosed(bool value) async {
    if (businessId == null) return;
    setState(() => temporarilyClosed = value);
    try {
      await client.rpc('set_business_temporarily_closed', params: {
        'p_business_id': businessId, 'p_closed': value,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(value ? 'İşletme geçici olarak kapatıldı.' : 'İşletme yeniden açıldı.')));
    } catch (error) {
      if (mounted) {
        setState(() => temporarilyClosed = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İşletme durumu değiştirilemedi: $error'), backgroundColor: wine));
      }
    }
  }

  Future<void> save() async {
    if (businessId == null || name.text.trim().isEmpty) return;
    setState(() => saving = true);
    try {
      await client.rpc('update_my_business_profile', params: {
        'p_business_id': businessId,
        'p_name': name.text.trim(),
        'p_address': address.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İşletme profili güncellendi.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil güncellenemedi: $error'), backgroundColor: wine));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: wine));
    return PageBody(children: [
      const Text('İşletme bilgileri', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 16),
      Center(child: Column(children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: blush,
          backgroundImage: logoPath == null ? null : NetworkImage(
            logoPath!.startsWith('http') ? logoPath! : client.storage.from('salon-avatars').getPublicUrl(logoPath!),
          ),
          child: logoPath == null ? const Icon(Icons.storefront, size: 42, color: wine) : null,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: uploadingLogo ? null : uploadLogo,
          icon: uploadingLogo
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.camera_alt_outlined),
          label: const Text('İşletme fotoğrafını değiştir'),
        ),
      ])),
      const SizedBox(height: 14),
      TextField(controller: name, textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'İşletme adı')),
      const SizedBox(height: 12),
      TextField(controller: address, maxLines: 2,
        decoration: const InputDecoration(labelText: 'Adres')),
      const SizedBox(height: 10),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: temporarilyClosed,
        onChanged: setTemporaryClosed,
        activeColor: wine,
        title: const Text('İşletmeyi geçici olarak kapat', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
        subtitle: const Text('Kapalıyken yeni randevu alınamaz. Mevcut randevular korunur.', style: TextStyle(color: muted)),
      ),
      const SizedBox(height: 18),
      ElevatedButton(onPressed: saving ? null : save,
        child: saving ? const CircularProgressIndicator() : const Text('Değişiklikleri kaydet')),
    ]);
  }
}

class AppointmentIntervalPage extends StatefulWidget {
  const AppointmentIntervalPage({super.key});
  @override
  State<AppointmentIntervalPage> createState() => _AppointmentIntervalPageState();
}

class _AppointmentIntervalPageState extends State<AppointmentIntervalPage> {
  final client = Supabase.instance.client;
  String? businessId;
  int selected = 30;
  bool loading = true;
  bool saving = false;
  static const intervals = [10, 15, 20, 30, 45, 60];

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) throw Exception('Oturum bulunamadı.');
      final row = await client.from('businesses')
          .select('id,appointment_interval_minutes')
          .eq('owner_id', user.id).maybeSingle();
      if (row == null) throw Exception('İşletme bulunamadı.');
      businessId = row['id'] as String;
      selected = (row['appointment_interval_minutes'] as num?)?.toInt() ?? 30;
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Randevu aralığı yüklenemedi: $error')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    if (businessId == null) return;
    setState(() => saving = true);
    try {
      await client.rpc('update_appointment_interval', params: {
        'p_business_id': businessId, 'p_interval_minutes': selected,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Randevu aralığı kaydedildi.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Randevu aralığı kaydedilemedi: $error'), backgroundColor: wine));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: wine));
    return PageBody(children: [
      const Text('Randevu Aralığı', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 8),
      const Text('Yeni randevu saatlerinin kaç dakikada bir açılacağını belirle.', style: TextStyle(color: muted)),
      const SizedBox(height: 18),
      Wrap(spacing: 10, runSpacing: 10, children: intervals.map((minutes) =>
        ChoiceChip(label: Text('$minutes dakika'), selected: selected == minutes,
          onSelected: (_) => setState(() => selected = minutes),
          selectedColor: blush)).toList()),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: saving ? null : save,
        child: saving ? const CircularProgressIndicator() : const Text('Kaydet')),
    ]);
  }
}
class WorkingHoursPage extends StatefulWidget {
  const WorkingHoursPage({super.key});
  @override
  State<WorkingHoursPage> createState() => _WorkingHoursPageState();
}

class _WorkingHoursPageState extends State<WorkingHoursPage> {
  final client = Supabase.instance.client;
  final labels = const ['Pazar','Pazartesi','Salı','Çarşamba','Perşembe','Cuma','Cumartesi'];
  String? businessId;
  List<Map<String, dynamic>> days = [];
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) throw Exception('Oturum bulunamadı.');
      final business = await client.from('businesses').select('id')
          .eq('owner_id', user.id).maybeSingle();
      if (business == null) throw Exception('İşletme kaydı bulunamadı.');
      businessId = business['id'] as String;
      final rows = await client.from('business_hours').select('weekday,opens_at,closes_at,is_closed')
          .eq('business_id', businessId!);
      final byDay = {for (final row in rows) row['weekday'] as int: row};
      days = List.generate(7, (index) {
        final row = byDay[index];
        return {
          'weekday': index,
          'opens_at': row?['opens_at']?.toString().substring(0,5) ?? '09:00',
          'closes_at': row?['closes_at']?.toString().substring(0,5) ?? '18:00',
          'is_closed': row?['is_closed'] as bool? ?? (index == 0),
        };
      });
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çalışma saatleri yüklenemedi: $error'), backgroundColor: wine),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> chooseTime(int day, String field) async {
    final parts = (days[day][field] as String).split(':');
    final initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final selected = await showTimePicker(context: context, initialTime: initial);
    if (selected == null) return;
    setState(() => days[day][field] =
      '${selected.hour.toString().padLeft(2,'0')}:${selected.minute.toString().padLeft(2,'0')}');
  }

  Future<void> save() async {
    if (businessId == null) return;
    setState(() => saving = true);
    try {
      await client.from('business_hours').upsert(
        days.map((day) => {...day, 'business_id': businessId}).toList(),
        onConflict: 'business_id,weekday',
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Çalışma saatleri kaydedildi.')),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydedilemedi: $error'), backgroundColor: wine),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(children: [
    const Text('Çalışma Saatleri', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
    const SizedBox(height: 8),
    const Text('İşletmenin haftalık açık olduğu saatleri belirle.', style: TextStyle(color: muted)),
    const SizedBox(height: 12),
    if (loading)
      const Center(child: CircularProgressIndicator(color: wine))
    else if (businessId == null)
      const Text('İşletme bilgisi yüklenemedi.')
    else ...[
      ...List.generate(7, (index) {
        final day = days[index];
        final closed = day['is_closed'] as bool;
        return Card(
          color: Colors.white,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 9),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Row(children: [
                Expanded(child: Text(labels[index], style: const TextStyle(fontWeight: FontWeight.bold, color: ink))),
                const Text('Kapalı', style: TextStyle(color: muted, fontSize: 12)),
                Switch(
                  value: closed,
                  activeColor: wine,
                  onChanged: (value) => setState(() => day['is_closed'] = value),
                ),
              ]),
              if (!closed)
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => chooseTime(index, 'opens_at'),
                    child: Text('Açılış  ${day['opens_at']}'),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(
                    onPressed: () => chooseTime(index, 'closes_at'),
                    child: Text('Kapanış  ${day['closes_at']}'),
                  )),
                ]),
            ]),
          ),
        );
      }),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: wine, foregroundColor: Colors.white),
        onPressed: saving ? null : save,
        child: Text(saving ? 'Kaydediliyor...' : 'Saatleri Kaydet'),
      )),
    ],
  ]);
}

class AdminSubAdmins extends StatefulWidget {
  const AdminSubAdmins({super.key});
  @override State<AdminSubAdmins> createState() => _AdminSubAdminsState();
}
class _AdminSubAdminsState extends State<AdminSubAdmins> {
  final client = Supabase.instance.client;
  final email = TextEditingController();
  final permissions = <String>{};
  bool loading = true;
  bool saving = false;
  List<Map<String, dynamic>> admins = [];
  static const options = <String, String>{
    'dashboard': 'Genel bakış', 'businesses': 'İşletme yönetimi',
    'users': 'Kullanıcı yönetimi', 'discover': 'Keşfet yönetimi',
    'support': 'Destek yönetimi',
  };
  @override void initState() { super.initState(); load(); }
  @override void dispose() { email.dispose(); super.dispose(); }
  Future<void> load() async {
    try {
      final rows = await client.rpc('admin_list_subadmins') as List;
      admins = List<Map<String, dynamic>>.from(rows);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alt yöneticiler yüklenemedi: $error')));
    } finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> save() async {
    final address = email.text.trim();
    if (!address.contains('@') || permissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli e-posta ve en az bir yetki seç.')));
      return;
    }
    setState(() => saving = true);
    try {
      await client.rpc('admin_set_subadmin', params: {
        'p_email': address, 'p_permissions': permissions.toList(),
      });
      if (!mounted) return;
      email.clear(); permissions.clear();
      await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alt yönetici yetkileri kaydedildi.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yetkiler kaydedilemedi: $error')));
    } finally { if (mounted) setState(() => saving = false); }
  }
  Future<void> revoke(Map<String, dynamic> admin) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) =>
      AlertDialog(
        title: const Text('Alt yöneticiyi kaldır'),
        content: Text('${admin['email'] ?? 'Bu hesap'} için tüm yönetim yetkileri kaldırılacak.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yetkileri kaldır')),
        ],
      ));
    if (confirmed != true) return;
    try {
      await client.rpc('admin_set_subadmin', params: {
        'p_email': admin['email'], 'p_permissions': <String>[],
      });
      if (!mounted) return;
      await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alt yönetici yetkileri kaldırıldı.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yetkiler kaldırılamadı: $error')));
    }
  }
  Future<void> edit(Map<String, dynamic> admin) async {
    email.text = admin['email']?.toString() ?? '';
    permissions..clear()
      ..addAll(List<String>.from(admin['permissions'] ?? const []));
    await showDialog<void>(context: context, builder: (dialogContext) =>
      StatefulBuilder(builder: (context, refreshDialog) => AlertDialog(
        title: Text(admin['full_name']?.toString() ?? 'Alt yönetici'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ...options.entries.map((entry) => CheckboxListTile(
            contentPadding: EdgeInsets.zero, title: Text(entry.value),
            value: permissions.contains(entry.key), activeColor: wine,
            onChanged: (value) => refreshDialog(() {
              if (value == true) { permissions.add(entry.key); }
              else { permissions.remove(entry.key); }
            }),
          )),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç')),
          FilledButton(onPressed: () async {
            Navigator.pop(dialogContext); await save();
          }, child: const Text('Kaydet')),
        ],
      )));
    if (!mounted) return;
    email.clear(); permissions.clear();
  }
  @override Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18), children: [
      const Text('Alt Yönetici Yetkileri', style: TextStyle(
        fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 6),
      const Text('Mevcut müşteri hesabını e-posta adresiyle seçip yönetim alanlarını yetkilendir.',
        style: TextStyle(color: muted)),
      const SizedBox(height: 16),
      TextField(controller: email, keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Kullanıcı e-posta adresi')),
      const SizedBox(height: 8),
      ...options.entries.map((entry) => CheckboxListTile(
        contentPadding: EdgeInsets.zero, title: Text(entry.value),
        value: permissions.contains(entry.key), activeColor: wine,
        onChanged: (value) => setState(() {
          if (value == true) { permissions.add(entry.key); }
          else { permissions.remove(entry.key); }
        }),
      )),
      const SizedBox(height: 8),
      FilledButton(onPressed: saving ? null : save,
        child: Text(saving ? 'Kaydediliyor...' : 'Alt yönetici yetkilerini kaydet')),
      const SectionTitle('Yetkili hesaplar'),
      if (loading) const Center(child: CircularProgressIndicator(color: wine))
      else if (admins.isEmpty) const Text('Henüz alt yönetici eklenmedi.',
        style: TextStyle(color: muted))
      else ...admins.map((admin) => Card(color: Colors.white, elevation: 0,
        child: ListTile(
          leading: const CircleAvatar(backgroundColor: blush,
            child: Icon(Icons.admin_panel_settings, color: wine)),
          title: Text(admin['full_name']?.toString() ?? 'Kullanıcı'),
          subtitle: Text('${admin['email'] ?? ''} • '
            '${(admin['permissions'] as List? ?? []).length} yetki'),
          trailing: Wrap(children: [
            IconButton(icon: const Icon(Icons.edit_outlined, color: wine),
              onPressed: () => edit(admin)),
            IconButton(icon: const Icon(Icons.delete_outline, color: wine),
              onPressed: () => revoke(admin)),
          ]),
        ),
      )),
    ],
  );
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override State<AdminHome> createState() => _AdminHomeState();
}
class _AdminHomeState extends State<AdminHome> {
  late Future<Map<String, dynamic>> stats;
  @override
  void initState() { super.initState(); stats = load(); }
  Future<Map<String, dynamic>> load() async {
    final rows = await Supabase.instance.client.rpc('admin_dashboard_stats');
    final row = (rows as List).first as Map;
    return Map<String, dynamic>.from(row);
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: stats,
    builder: (context, snapshot) => PageBody(children: [
      const Text('Genel Bakış', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 14),
      const HeroPanel(eyebrow: 'Platform kontrolü', title: 'Kuaförüm ekosistemini yönet',
        subtitle: 'Kuaförüm platformunun genel durumunu görüntüle.',
        icon: Icons.admin_panel_settings, button: 'Platformu yönet'),
      const SizedBox(height: 14),
      if (snapshot.connectionState == ConnectionState.waiting)
        const Center(child: CircularProgressIndicator(color: wine))
      else if (snapshot.hasError)
        _FeedMessage(icon: Icons.cloud_off_outlined, title: 'İstatistikler yüklenemedi', detail: snapshot.error.toString())
      else
        Row(children: [
          Expanded(child: _StatCard(snapshot.data!['business_count'].toString(), 'İşletme')),
          Expanded(child: _StatCard(snapshot.data!['user_count'].toString(), 'Kullanıcı')),
          Expanded(child: _StatCard(snapshot.data!['post_count'].toString(), 'Paylaşım')),
        ]),
      const SectionTitle('Yönetim araçları'),
      const Text('İşletme onayları, kullanıcı güvenliği ve Keşfet erişimleri. Ana yönetici hesabında randevu alma veya müşteri ekranları bulunmaz.', style: TextStyle(color: muted, height: 1.5)),
    ]),
  );
}
class AdminBusinesses extends StatefulWidget {
  const AdminBusinesses({super.key});
  @override State<AdminBusinesses> createState() => _AdminBusinessesState();
}

class _AdminBusinessesState extends State<AdminBusinesses> {
  final client = Supabase.instance.client;
  final search = TextEditingController();
  late Future<List<Map<String, dynamic>>> businesses;
  String query = '';

  @override
  void initState() { super.initState(); businesses = load(); }
  @override
  void dispose() { search.dispose(); super.dispose(); }

  Future<List<Map<String, dynamic>>> load() async =>
    List<Map<String, dynamic>>.from(await client.rpc('admin_list_businesses') as List);

  Future<void> refreshData() async {
    final next = load();
    setState(() => businesses = next);
    await next;
  }

  Future<void> setStatus(String id, String status) async {
    try {
      await client.rpc('admin_set_business_status', params: {'p_business_id': id, 'p_status': status});
      await refreshData();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İşletme durumu değiştirilemedi: $error')));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: businesses,
    builder: (context, snapshot) {
      final items = (snapshot.data ?? []).where((b) =>
        '${b['name'] ?? ''} ${b['address'] ?? ''}'.toLowerCase().contains(query.toLowerCase())).toList();
      return RefreshIndicator(
        onRefresh: refreshData,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(18), children: [
          const Text('İşletme Yönetimi', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 12),
          TextField(controller: search, onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(hintText: 'İşletme ara...', prefixIcon: Icon(Icons.search))),
          const SizedBox(height: 12),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator(color: wine))
          else if (snapshot.hasError)
            _FeedMessage(icon: Icons.cloud_off_outlined, title: 'İşletmeler yüklenemedi', detail: snapshot.error.toString())
          else if (items.isEmpty)
            const _FeedMessage(icon: Icons.store_outlined, title: 'İşletme bulunamadı', detail: 'Arama ölçütünü değiştir.')
          else
            ...items.map((b) {
              final status = b['status']?.toString() ?? 'inactive';
              final paid = b['discover_paid'] == true;
              return Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 10),
                child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const CircleAvatar(backgroundColor: blush, child: Icon(Icons.store, color: wine)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(b['name']?.toString() ?? 'İşletme', style: const TextStyle(fontWeight: FontWeight.bold, color: ink)),
                      Text(b['address']?.toString() ?? 'Adres yok', style: const TextStyle(color: muted, fontSize: 12)),
                    ])),
                    PopupMenuButton<String>(
                      onSelected: (value) => setStatus(b['id'].toString(), value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'active', child: Text('Aktif yap')),
                        PopupMenuItem(value: 'inactive', child: Text('Geçici kapat')),
                        PopupMenuItem(value: 'rejected', child: Text('Reddet')),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text('Durum: ${status == 'active' ? 'Aktif' : status == 'rejected' ? 'Reddedildi' : 'Pasif'}',
                    style: const TextStyle(color: muted, fontSize: 12)),
                  if (paid)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Keşfet üst sıra hakkı tanımlı.',
                        style: TextStyle(color: muted, fontSize: 12)),
                    ) else const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Keşfet üst sıra hakkı tanımlı değil.',
                        style: TextStyle(color: muted, fontSize: 12)),
                    ),
                ])),
              );
            }),
        ]),
      );
    },
  );
}
class AdminUsers extends StatefulWidget {
  const AdminUsers({super.key});
  @override State<AdminUsers> createState() => _AdminUsersState();
}

class _AdminUsersState extends State<AdminUsers> {
  final client = Supabase.instance.client;
  final search = TextEditingController();
  late Future<List<Map<String, dynamic>>> users;
  String query = '';
  @override
  void initState() { super.initState(); users = load(); }
  @override
  void dispose() { search.dispose(); super.dispose(); }
  Future<List<Map<String, dynamic>>> load() async =>
    List<Map<String, dynamic>>.from(await client.rpc('admin_list_users') as List);
  Future<void> refreshData() async { final next = load(); setState(() => users = next); await next; }
  Future<void> setBlocked(String id, bool blocked) async {
    try {
      await client.rpc('set_user_blocked', params: {'p_user_id': id, 'p_blocked': blocked});
      await refreshData();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kullanıcı durumu değiştirilemedi: $error')));
    }
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: users,
    builder: (context, snapshot) {
      final items = (snapshot.data ?? []).where((u) =>
        '${u['full_name'] ?? ''} ${u['email'] ?? ''} ${u['phone'] ?? ''}'.toLowerCase().contains(query.toLowerCase())).toList();
      return RefreshIndicator(onRefresh: refreshData, child: ListView(
        physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(18), children: [
          const Text('Kullanıcı Yönetimi', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 12),
          TextField(controller: search, onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(hintText: 'İsim, e-posta veya telefon ara...', prefixIcon: Icon(Icons.search))),
          const SizedBox(height: 12),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator(color: wine))
          else if (snapshot.hasError)
            _FeedMessage(icon: Icons.cloud_off_outlined, title: 'Kullanıcılar yüklenemedi', detail: snapshot.error.toString())
          else if (items.isEmpty)
            const _FeedMessage(icon: Icons.people_outline, title: 'Kullanıcı bulunamadı', detail: 'Arama ölçütünü değiştir.')
          else
            ...items.map((u) {
              final admin = u['is_admin'] == true;
              final blocked = u['is_blocked'] == true;
              return Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: blush, child: Icon(admin ? Icons.admin_panel_settings : Icons.person, color: wine)),
                  title: Text(u['full_name']?.toString() ?? 'Kullanıcı', style: const TextStyle(fontWeight: FontWeight.bold, color: ink)),
                  subtitle: Text('${u['email'] ?? ''} • ${u['account_type'] ?? 'customer'} • ${blocked ? 'Engelli' : 'Aktif'}'),
                  trailing: admin ? const Icon(Icons.verified_user, color: wine) : IconButton(
                    tooltip: blocked ? 'Engeli kaldır' : 'Engelle',
                    icon: Icon(blocked ? Icons.lock_open : Icons.block, color: wine),
                    onPressed: () => setBlocked(u['id'].toString(), !blocked),
                  ),
                ),
              );
            }),
        ],
      ));
    },
  );
}
class DiscoverControl extends StatefulWidget {
  const DiscoverControl({super.key});
  @override State<DiscoverControl> createState() => _DiscoverControlState();
}
class _DiscoverControlState extends State<DiscoverControl> {
  final client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> businesses;
  @override
  void initState() { super.initState(); businesses = load(); }
  Future<List<Map<String, dynamic>>> load() async =>
    List<Map<String, dynamic>>.from(await client.rpc('admin_list_discover_businesses') as List);
  Future<void> refreshData() async { final next = load(); setState(() => businesses = next); await next; }
  Future<void> update(String id, bool enabled) async {
    try {
      await client.rpc('admin_set_discover_visibility', params: {'p_business_id': id, 'p_enabled': enabled});
      await refreshData();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Keşfet erişimi güncellenemedi: $error'), backgroundColor: wine),
      );
    }
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: businesses,
    builder: (context, snapshot) {
      final eligible = (snapshot.data ?? []).where((b) => b['status'] == 'active' && b['discover_paid'] == true).toList();
      return RefreshIndicator(onRefresh: refreshData, child: ListView(
        physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(18), children: [
          const Text('Keşfet Görünürlüğü', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 8),
          const Text('Üst sıralarda gösterim hakkı olan aktif işletmelerin görünürlüğünü buradan yönet.', style: TextStyle(color: muted)),
          const SizedBox(height: 14),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator(color: wine))
          else if (snapshot.hasError)
            _FeedMessage(icon: Icons.cloud_off_outlined, title: 'Erişim bilgileri yüklenemedi', detail: snapshot.error.toString())
          else if (eligible.isEmpty)
            const _FeedMessage(icon: Icons.explore_outlined, title: 'Uygun işletme yok', detail: 'Üst sıra görünürlüğü hakkı tanımlanmış aktif işletme bulunmuyor.')
          else
            ...eligible.map((business) => SwitchListTile(
              value: business['discover_enabled'] == true,
              onChanged: (value) => update(business['id'].toString(), value),
              activeThumbColor: wine,
              secondary: const Icon(Icons.store, color: wine),
              title: Text(business['name']?.toString() ?? 'İşletme', style: const TextStyle(fontWeight: FontWeight.bold, color: ink)),
              subtitle: Text(business['discover_enabled'] == true ? 'Keşfet üst sıralarında açık' : 'Keşfet üst sıralarında kapalı'),
            )),
        ],
      ));
    },
  );
}

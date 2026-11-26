import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
          setState(() => message = 'Doğrulama bağlantısı e-posta adresine gönderildi. E-postanı kontrol et.');
        } else if (result.user != null) {
          await _openAccount(result.user!.id);
        }
      } else {
        final result = await auth.signInWithPassword(email: mail, password: password.text);
        if (result.user == null) throw AuthException('Giriş yapılamadı.');
        await _openAccount(result.user!.id);
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => message = error.message);
    } catch (error) {
      if (mounted) setState(() => message = 'İşlem tamamlanamadı. Bilgilerini ve bağlantını kontrol et.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openAccount(String userId) async {
    final client = Supabase.instance.client;
    try {
      final profile = await client.from('profiles')
          .select('account_type,is_admin,is_blocked')
          .eq('id', userId)
          .maybeSingle();
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
      AppRole role;
      if (profile['is_admin'] == true) {
        role = AppRole.admin;
      } else {
        final employees = await client.from('employees').select('id')
            .eq('user_id', userId).eq('is_active', true).limit(1);
        if (!mounted) return;
        if (employees.isNotEmpty) {
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

class DemoPost {
  final String author, caption, audience;
  final String? mediaPath;
  final bool businessPost;
  int likes;
  bool liked;
  DemoPost({required this.author, required this.caption, required this.audience, this.businessPost=false, this.likes=0, this.liked=false, this.mediaPath});
}
final ValueNotifier<List<DemoPost>> demoPosts = ValueNotifier([
  DemoPost(author:'Zeynep Kaya',caption:'Işıltılı dalgalar ✨',audience:'Çalışan',likes:12500),
  DemoPost(author:'Merve Demir',caption:'Yeni sezon renk geçişi ♡',audience:'Çalışan',likes:8700),
  DemoPost(author:'Luxe Beauty Salon',caption:'Salonumuzdan günün dönüşümü ✨',audience:'İşletme',businessPost:true,likes:6200),
]);

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
      final profile = await auth.from('profiles')
          .select('account_type,is_admin,is_blocked')
          .eq('id', user.id)
          .maybeSingle();
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
  late final List<String> labels;
  late final List<IconData> icons;
  late final List<Widget> pages;
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
        pages = [const OwnerHome(),const DiscoverPage(),const FollowingPage(),const SharePage(publisherName:'Luxe Beauty Salon',businessPost:true),const MessagesPage(),const OwnerProfilePage()];
        break;
      case AppRole.admin:
        labels = ['Genel Bakış','İşletmeler','Kullanıcılar','Keşfet Yönetimi']; icons = [Icons.dashboard,Icons.store,Icons.people_alt,Icons.explore];
        pages = [const AdminHome(),const AdminBusinesses(),const AdminUsers(),const DiscoverControl()];
        break;
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(heading, style: const TextStyle(fontWeight: FontWeight.w800, color: wine)), actions: [IconButton(onPressed: (){}, icon: const Icon(Icons.notifications_none_rounded)), const SizedBox(width: 5)]),
    body: IndexedStack(index:index, children:pages),
    bottomNavigationBar: NavigationBar(
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
  const HeroPanel({super.key,required this.eyebrow,required this.title,required this.subtitle,required this.icon,this.button='Keşfet'});
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF6E2038),Color(0xFFC45B78)],begin:Alignment.topLeft,end:Alignment.bottomRight),borderRadius:BorderRadius.circular(24),boxShadow:[BoxShadow(color:wine.withOpacity(.18),blurRadius:18,offset:const Offset(0,8))]),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(eyebrow.toUpperCase(),style:const TextStyle(color:Color(0xFFFFDDE5),fontSize:10,letterSpacing:1.5,fontWeight:FontWeight.bold)),const SizedBox(height:9),Text(title,style:const TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w800,height:1.15)),const SizedBox(height:7),Text(subtitle,style:const TextStyle(color:Colors.white70,fontSize:12,height:1.4)),const SizedBox(height:14),Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:9),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20)),child:Text(button,style:const TextStyle(color:wine,fontWeight:FontWeight.bold,fontSize:12)))])),const SizedBox(width:10),Container(width:82,height:100,decoration:BoxDecoration(color:Colors.white.withOpacity(.13),borderRadius:BorderRadius.circular(22)),child:Icon(icon,size:54,color:Colors.white))]));
}
class SearchBarBox extends StatelessWidget {
  final String hint; const SearchBarBox({super.key,this.hint='Kuaför, çalışan veya şehir ara...'});
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:15,vertical:14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:blush)),child:Row(children:[const Icon(Icons.search,color:muted),const SizedBox(width:9),Text(hint,style:const TextStyle(color:muted,fontSize:13))]));
}
class SalonCard extends StatelessWidget {
  final String name,detail; final String rating; const SalonCard({super.key,required this.name,required this.detail,this.rating='4.9'});
  @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:13),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),border:Border.all(color:blush)),child:Row(children:[Container(width:88,height:88,decoration:BoxDecoration(borderRadius:BorderRadius.circular(15),gradient:const LinearGradient(colors:[Color(0xFFE8C1C9),Color(0xFFB66B7D)])),child:const Icon(Icons.spa_rounded,color:Colors.white,size:38)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(name,style:const TextStyle(fontWeight:FontWeight.w800,color:ink,fontSize:15)),const SizedBox(height:5),Text(detail,style:const TextStyle(color:muted,fontSize:12)),const SizedBox(height:8),Row(children:[const Icon(Icons.star_rounded,color:Color(0xFFE5A93D),size:16),Text(' $rating  •  1.2 km',style:const TextStyle(fontSize:11,color:muted)),const Spacer(),const Icon(Icons.favorite_border,color:rose,size:19)])]))]));
}
class CustomerHome extends StatelessWidget {
  const CustomerHome({super.key});
  @override Widget build(BuildContext context)=>PageBody(children:[
    const Text('Merhaba, Güzellik! ♡',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:4),const Text('Bugün kendine biraz zaman ayır.',style:TextStyle(color:muted)),    const SizedBox(height:16),const HeroPanel(eyebrow:'Stilini keşfet',title:'Hayal ettiğin saç stili burada',subtitle:'İlham al, sana en yakın salonu bul ve kolayca randevu oluştur.',icon:Icons.auto_awesome,button:'Şimdi keşfet  →'),
    const SizedBox(height:15),const SearchBarBox(),const SectionTitle('Yakınındaki Kuaförler',action:'Tümünü Gör →'),
    const SalonCard(name:'Luxe Beauty Salon',detail:'Melikgazi • Saç, bakım ve renklendirme'),
    const SalonCard(name:'Rose Hair Studio',detail:'Talas • Kesim ve profesyonel bakım'),
    const SectionTitle('Senin için seçtiklerimiz'),const QuickTiles(),
  ]);
}
class QuickTiles extends StatelessWidget {
  const QuickTiles({super.key});
  @override Widget build(BuildContext context)=>Row(children:[_tile(Icons.calendar_month,'Randevu Al'),_tile(Icons.diamond,'Keşfet'),_tile(Icons.favorite,'Takip Edilen')]);
  Widget _tile(IconData i,String s)=>Expanded(child:Container(margin:const EdgeInsets.only(right:8),padding:const EdgeInsets.symmetric(vertical:17,horizontal:5),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:blush)),child:Column(children:[Icon(i,color:wine),const SizedBox(height:7),Text(s,textAlign:TextAlign.center,style:const TextStyle(fontSize:10,fontWeight:FontWeight.bold,color:ink))])));
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
          const SearchBarBox(hint: 'Saç modeli, salon veya çalışan ara...'),
          const SizedBox(height: 12),
          const Wrap(spacing: 8, children: [_Chip('Tümü', true), _Chip('Saç Kesimi'), _Chip('Boyama'), _Chip('Ombre'), _Chip('Topuz')]),
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

  @override
  void initState() {
    super.initState();
    liked = widget.post.isLikedByMe;
    likes = widget.post.likeCount;
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
  Widget build(BuildContext context) => Container(
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
        if (!widget.post.isOwnPost && followStateLoaded)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: muted),
            onSelected: (value) {
              if (value == 'business') toggleBusinessFollow();
              if (value == 'author') toggleAuthorFollow();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'business', child: Text(followingBusiness ? 'İşletmeyi takipten çık' : 'İşletmeyi takip et')),
              if (widget.post.isEmployeePost)
                PopupMenuItem(value: 'author', child: Text(followingAuthor ? 'Çalışanı takipten çık' : 'Çalışanı takip et')),
            ],
          )
        else
          const Icon(Icons.more_horiz, color: muted),
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
        const Spacer(),
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

class _Chip extends StatelessWidget {final String text;final bool active;final VoidCallback? onTap;const _Chip(this.text,[this.active=false],{this.onTap});@override Widget build(BuildContext context)=>ActionChip(onPressed:onTap,label:Text(text,style:TextStyle(color:active?Colors.white:ink,fontSize:11)),backgroundColor:active?wine:Colors.white,side:BorderSide(color:blush));}
class PostCard extends StatelessWidget {
  final String name,caption,likes; final DemoPost? post;
  const PostCard({super.key,required this.name,required this.caption,required this.likes,this.post});
  @override Widget build(BuildContext context)=>Container(
    margin:const EdgeInsets.only(bottom:16),padding:const EdgeInsets.all(12),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),border:Border.all(color:blush),boxShadow:[BoxShadow(color:wine.withOpacity(.05),blurRadius:16,offset:const Offset(0,5))]),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[CircleAvatar(backgroundColor:blush,child:Icon(post?.businessPost==true?Icons.storefront:Icons.person,color:wine)),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(name,style:const TextStyle(fontWeight:FontWeight.bold,color:ink)),Text(post?.audience??'Kuaförüm topluluğu',style:const TextStyle(color:muted,fontSize:10))])),const Icon(Icons.more_horiz,color:muted)]),
      const SizedBox(height:12),
      Container(height:215,width:double.infinity,decoration:BoxDecoration(borderRadius:BorderRadius.circular(17),gradient:const LinearGradient(colors:[Color(0xFFE9C5CC),Color(0xFFB66A7D),Color(0xFF6E2038)],begin:Alignment.topLeft,end:Alignment.bottomRight)),child:Stack(children:[if(post?.mediaPath!=null) ClipRRect(borderRadius:BorderRadius.circular(17),child:Image.file(File(post!.mediaPath!),width:double.infinity,height:215,fit:BoxFit.cover)) else ...[Positioned(right:16,top:14,child:Icon(Icons.auto_awesome,color:Colors.white.withOpacity(.8),size:28)),const Center(child:Icon(Icons.photo_camera_back_rounded,size:58,color:Colors.white70))],Positioned(left:14,bottom:14,child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:BoxDecoration(color:Colors.black.withOpacity(.22),borderRadius:BorderRadius.circular(20)),child:const Text('KUAFÖRÜM  •  İLHAM VER',style:TextStyle(color:Colors.white,fontSize:9,letterSpacing:1.2,fontWeight:FontWeight.bold))))])),
      const SizedBox(height:12),Text(caption,style:const TextStyle(fontWeight:FontWeight.w600,color:ink)),
      const SizedBox(height:9),Row(children:[
        InkWell(onTap:post==null?null:(){post!.liked=!post!.liked;post!.likes+=post!.liked?1:-1;demoPosts.value=[...demoPosts.value];},child:Row(children:[Icon(post?.liked==true?Icons.favorite:Icons.favorite_border,color:rose),const SizedBox(width:5),Text(post==null?likes:post!.likes.toString(),style:const TextStyle(color:muted))])),
        const SizedBox(width:18),const Icon(Icons.mode_comment_outlined,color:muted),const SizedBox(width:5),const Text('Yorum yap',style:TextStyle(color:muted,fontSize:12)),const Spacer(),const Icon(Icons.bookmark_border,color:muted)
      ])
    ]),
  );
}

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
        'businesses(name),services(name),employees(display_name)'
      ).eq('customer_id', user.id).order('starts_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows).map((item) => {
        ...item,
        'appointment_id': item['id'],
        'business_name': (item['businesses'] as Map?)?['name'] ?? 'İşletme',
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
        'p_mine_only': false,
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

  Future<void> changeStatus(Map<String, dynamic> appointment, String status) async {
    try {
      if (status == 'cancelled') {
        await client.rpc('cancel_appointment', params: {
          'p_appointment_id': appointment['appointment_id'],
        });
      } else {
        await client.rpc('update_appointment_status', params: {
          'p_appointment_id': appointment['appointment_id'],
          'p_status': status,
        });
      }
      if (!mounted) return;
      final message = status == 'completed' ? 'Randevu tamamlandı.' :
        status == 'no_show' ? 'Gelmedi olarak işaretlendi.' : 'Randevu iptal edildi.';
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
              _Chip('Aktif', filter == 'Aktif', onTap: () => setState(() => filter = 'Aktif')),
              _Chip('Bekleyen', filter == 'Bekleyen', onTap: () => setState(() => filter = 'Bekleyen')),
              _Chip('Geçmiş', filter == 'Geçmiş', onTap: () => setState(() => filter = 'Geçmiş')),
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
                    if (status == 'confirmed') ...[
                      const SizedBox(height: 12),
                      if (item.containsKey('business_name'))
                        Align(alignment: Alignment.centerRight, child: TextButton(
                          onPressed: () => changeStatus(item, 'cancelled'),
                          child: const Text('Randevuyu iptal et', style: TextStyle(color: wine)),
                        ))
                      else
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

  @override
  void initState() {
    super.initState();
    messageStream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', widget.conversationId)
        .order('created_at')
        .map((rows) => rows.map((row) => Map<String, dynamic>.from(row)).toList());
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
            final rows = snapshot.data!;
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
class ProfilePage extends StatelessWidget {const ProfilePage({super.key});@override Widget build(BuildContext context)=>PageBody(children:[const Center(child:CircleAvatar(radius:48,backgroundColor:blush,child:Icon(Icons.person,size:55,color:wine))),const SizedBox(height:10),const Text('Gizem Yılmaz ♡',textAlign:TextAlign.center,style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:ink)),const Text('@gizemyilmaz',textAlign:TextAlign.center,style:TextStyle(color:muted)),const SizedBox(height:18),const Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[_Metric('28','Takipçi'),_Metric('12','Takip'),_Metric('45','Paylaşım')]),const SizedBox(height:20),...['Profilimi Düzenle','Randevularım','Favorilerim','Takip Ettiklerim','Ayarlar','Çıkış Yap'].map((s)=>Card(color:Colors.white,elevation:0,child:ListTile(leading:const Icon(Icons.circle_outlined,color:wine),title:Text(s,style:const TextStyle(color:ink,fontWeight:FontWeight.w600)),trailing:const Icon(Icons.chevron_right,color:muted),onTap:s=='Randevularım'?()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AppointmentsPage(title:'Randevularım'))):s=='Çıkış Yap'?() async {await Supabase.instance.client.auth.signOut();if(context.mounted)Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder:(_)=>const KuaforumApp(autoResume:false)),(route)=>false);}:null)))]);}
class _Metric extends StatelessWidget {final String value,label;const _Metric(this.value,this.label);@override Widget build(BuildContext context)=>Column(children:[Text(value,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:wine)),Text(label,style:const TextStyle(fontSize:11,color:muted))]);}
class EmployeeHome extends StatelessWidget {const EmployeeHome({super.key});@override Widget build(BuildContext context)=>PageBody(children:[const Text('Merhaba Ayşe 👋',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800,color:ink)),const Text('Harika işler çıkarmaya devam et!',style:TextStyle(color:muted)),const SizedBox(height:16),const Row(children:[_StatCard('12','Bugün Randevu'),_StatCard('28','Toplam Randevu'),_StatCard('4.9','Puan')]),const SizedBox(height:16),const HeroPanel(eyebrow:'Portfolyonu büyüt',title:'Çalışmalarını paylaş',subtitle:'Yaptığın işleri paylaş, müşterilerine ilham ver ve kariyerini büyüt.',icon:Icons.camera_alt,button:'Paylaşım yap →'),const SectionTitle('Bugünkü Randevular',action:'Tümünü Gör'),const AppointmentTile(name:'Elif Demir',service:'Saç Kesimi',time:'09:30',status:'Devam Ediyor'),const AppointmentTile(name:'Merve Aksoy',service:'Keratin Bakım',time:'11:00',status:'Onaylandı')]);}
class _StatCard extends StatelessWidget {final String v,l;const _StatCard(this.v,this.l);@override Widget build(BuildContext context)=>Expanded(child:Container(margin:const EdgeInsets.only(right:7),padding:const EdgeInsets.symmetric(vertical:15),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:blush)),child:Column(children:[Text(v,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:20,color:wine)),Text(l,textAlign:TextAlign.center,style:const TextStyle(fontSize:10,color:muted))])));}
class SharePage extends StatefulWidget {
  final String publisherName; final bool businessPost;
  const SharePage({super.key,this.publisherName='Ayşe Demir',this.businessPost=false});
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

class OwnerProfilePage extends StatelessWidget {
  const OwnerProfilePage({super.key});
  void open(BuildContext context,String section){
    final page=switch(section){
      'Randevu Yönetimi'=>const OwnerAppointments(),
      'Çalışan Randevuları'=>const OwnerAppointments(),
      'Müşterilerim'=>const CustomersPage(),
      'Çalışanlar'=>const EmployeeManagementPage(),
      'Hizmetler'=>const ServicesPage(),
      _=>const SettingsPage(),    };
    Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(appBar:AppBar(title:Text(section,style:const TextStyle(color:wine,fontWeight:FontWeight.bold))),body:page)));
  }
  @override Widget build(BuildContext context)=>PageBody(children:[
    const Center(child:CircleAvatar(radius:48,backgroundColor:blush,child:Icon(Icons.storefront,size:48,color:wine))),
    const SizedBox(height:10),const Text('Luxe Beauty Salon',textAlign:TextAlign.center,style:TextStyle(fontSize:21,fontWeight:FontWeight.w800,color:ink)),
    const Text('İşletme hesabı • Kayseri',textAlign:TextAlign.center,style:TextStyle(color:muted)),
    const SizedBox(height:18),const Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[_Metric('2.4K','Takipçi'),_Metric('180','Takip'),_Metric('96','Paylaşım')]),
    const SizedBox(height:18),const SectionTitle('İşletme Yönetimi'),
    ...['Randevu Yönetimi','Çalışan Randevuları','Müşterilerim','Çalışanlar','Hizmetler','Çalışma Saatleri','İşletme Ayarları','Bildirimler'].map((s)=>Card(color:Colors.white,elevation:0,child:ListTile(leading:const Icon(Icons.circle_outlined,color:wine),title:Text(s,style:const TextStyle(color:ink,fontWeight:FontWeight.w600)),trailing:const Icon(Icons.chevron_right,color:muted),onTap:()=>open(context,s)))),
  ]);
}
class EmployeeManagementPage extends StatelessWidget {
  const EmployeeManagementPage({super.key});
  @override Widget build(BuildContext context)=>PageBody(children:[const Text('Çalışanlar',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:12),const _PrimaryButton('Çalışan Davet Et'),...['Ayşe Demir','Mehmet Yıldız','Zeynep Kaya'].map((n)=>ListTile(leading:const CircleAvatar(backgroundColor:blush,child:Icon(Icons.person,color:wine)),title:Text(n,style:const TextStyle(color:ink,fontWeight:FontWeight.bold)),subtitle:const Text('Aktif çalışan'),trailing:const Icon(Icons.more_vert,color:muted)))]);
}
class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});
  @override Widget build(BuildContext context)=>PageBody(children:[const Text('Hizmetler',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:12),const _PrimaryButton('Yeni Hizmet Ekle'),...['Saç Kesimi  •  ₺800','Saç Boyama  •  ₺1.800','Ombre  •  ₺2.500','Keratin Bakım  •  ₺1.400'].map((s)=>Card(color:Colors.white,elevation:0,child:ListTile(leading:const Icon(Icons.content_cut,color:wine),title:Text(s,style:const TextStyle(color:ink,fontWeight:FontWeight.w600)),trailing:const Icon(Icons.edit_outlined,color:muted))))]);
}

class OwnerHome extends StatelessWidget {const OwnerHome({super.key});@override Widget build(BuildContext context)=>PageBody(children:[const Text('İşletme Yönetimi',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:14),const HeroPanel(eyebrow:'Luxe Beauty Salon',title:'Güzelliğin profesyonel adresi',subtitle:'İşletmeni, ekibini ve müşteri deneyimini tek yerden yönet.',icon:Icons.storefront,button:'İşletme paneli'),const SizedBox(height:14),const Row(children:[_StatCard('12','Bugünkü Randevu'),_StatCard('1.248','Toplam Müşteri'),_StatCard('4.9','Puan')]),const SectionTitle('Son Randevular',action:'Tümünü Gör'),const AppointmentTile(name:'Ayşe Demir',service:'Saç Kesimi',time:'Bugün • 16:30',status:'Onaylandı'),const SectionTitle('Hızlı Yönetim'),const QuickTiles()]);}
class OwnerAppointments extends StatelessWidget {
  const OwnerAppointments({super.key});
  @override
  Widget build(BuildContext context) => const AppointmentsPage(
    title: 'Randevu Yönetimi',
    ownerMode: true,
  );
}
class CustomersPage extends StatelessWidget {const CustomersPage({super.key});@override Widget build(BuildContext context)=>PageBody(children:[const Text('Müşterilerim',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:12),const SearchBarBox(hint:'Müşteri ara...'),const SectionTitle('Müşteri Listesi'),...['Ayşe Demir','Elif Yılmaz','Merve Aksoy','Derya Şahin','Zeynep Kaya'].map((n)=>ListTile(leading:const CircleAvatar(backgroundColor:blush,child:Icon(Icons.person,color:wine)),title:Text(n,style:const TextStyle(fontWeight:FontWeight.bold,color:ink)),subtitle:const Text('+90 545 123 45 67'),trailing:const Icon(Icons.more_vert,color:muted)))]);}
class SettingsPage extends StatelessWidget {const SettingsPage({super.key});@override Widget build(BuildContext context)=>PageBody(children:[const Text('Ayarlar',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:12),...['İşletme Bilgileri','Çalışma Saatleri','Hizmetler','Çalışanlar','Çalışan Davet Et','Bildirim Ayarları','Güvenlik','Yardım ve Destek'].map((s)=>Card(color:Colors.white,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),child:ListTile(leading:const Icon(Icons.settings_outlined,color:wine),title:Text(s,style:const TextStyle(fontWeight:FontWeight.w600,color:ink)),trailing:const Icon(Icons.chevron_right,color:muted))))]);}
class AdminHome extends StatelessWidget {const AdminHome({super.key});@override Widget build(BuildContext context)=>PageBody(children:[const Text('Ana Yönetici',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:14),const HeroPanel(eyebrow:'Platform kontrolü',title:'Kuaförüm ekosistemini yönet',subtitle:'İşletmeleri, kullanıcıları ve Keşfet erişimlerini kontrol et.',icon:Icons.admin_panel_settings,button:'Platformu yönet'),const SizedBox(height:14),const Row(children:[_StatCard('248','İşletme'),_StatCard('12.5K','Kullanıcı'),_StatCard('1.8K','Paylaşım')]),const SectionTitle('Yönetim araçları'),const Text('İşletme onayları, kullanıcı güvenliği ve Keşfet erişimleri. Ana yönetici hesabında randevu alma veya müşteri ekranları bulunmaz.',style:TextStyle(color:muted,height:1.5)),]);}
class AdminBusinesses extends StatelessWidget {const AdminBusinesses({super.key});@override Widget build(BuildContext context)=>PageBody(children:[const Text('İşletme Yönetimi',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:12),const SearchBarBox(hint:'İşletme ara...'),const SectionTitle('İşletmeler'),...['Luxe Beauty Salon','Rose Hair Studio','Tasarımhane Kuaför','Mira Güzellik'].map((n)=>ListTile(leading:const CircleAvatar(backgroundColor:blush,child:Icon(Icons.store,color:wine)),title:Text(n,style:const TextStyle(fontWeight:FontWeight.bold,color:ink)),subtitle:const Text('Aktif • Keşfet erişimi açık'),trailing:const Icon(Icons.more_vert,color:muted)))]);}
class AdminUsers extends StatelessWidget {const AdminUsers({super.key});@override Widget build(BuildContext context)=>PageBody(children:[const Text('Kullanıcı Yönetimi',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:12),const SearchBarBox(hint:'Kullanıcı ara...'),const SectionTitle('Son kayıtlar'),...['Gizem Yılmaz','Ayşe Demir','Zeynep Kaya','Merve Demir'].map((n)=>ListTile(leading:const CircleAvatar(backgroundColor:blush,child:Icon(Icons.person,color:wine)),title:Text(n,style:const TextStyle(fontWeight:FontWeight.bold,color:ink)),subtitle:const Text('Müşteri hesabı'),trailing:const Icon(Icons.more_vert,color:muted)))]);}
class DiscoverControl extends StatefulWidget {const DiscoverControl({super.key});@override State<DiscoverControl> createState()=>_DiscoverControlState();}
class _DiscoverControlState extends State<DiscoverControl> {
  final Map<String,bool> enabled={'Luxe Beauty Salon':true,'Rose Hair Studio':true,'Tasarımhane Kuaför':false};
  @override Widget build(BuildContext context)=>PageBody(children:[    const Text('Keşfet Görünürlüğü',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:8),
    const Text('İşletmelerin paylaşımlarının herkese açık Keşfet akışında görünmesini buradan yönet.',style:TextStyle(color:muted)),
    const SectionTitle('Erişim yönetimi'),
    ...enabled.keys.map((n)=>SwitchListTile(value:enabled[n]!,onChanged:(v)=>setState(()=>enabled[n]=v),activeThumbColor:wine,secondary:const Icon(Icons.store,color:wine),title:Text(n,style:const TextStyle(fontWeight:FontWeight.bold,color:ink)),subtitle:const Text('Keşfet görünürlüğü'))),
  ]);
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  const _PrimaryButton(this.label);
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: wine,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: () {},
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );
}
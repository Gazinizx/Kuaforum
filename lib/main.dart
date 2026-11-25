import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'data/kuaforum_feed_repository.dart';
import 'employee_invite_claim_page.dart';

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
  const KuaforumApp({super.key});
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
    home: const AuthGate(),
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
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: blush)),
        child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: blush, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.vpn_key_rounded, color: wine)),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Çalışan davet kodun mu var?', style: TextStyle(color: ink, fontWeight: FontWeight.w800)),
            SizedBox(height: 3),
            Text('Kodunu kullanarak işletmene katıl.', style: TextStyle(color: muted, fontSize: 12)),
          ])),
          IconButton(
            tooltip: 'Davet kodunu kullan',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => EmployeeInviteClaimPage(
                onClaimed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const RoleShell(role: AppRole.employee)),
                  (_) => false,
                ),
              ),
            )),
            icon: const Icon(Icons.arrow_forward_ios_rounded, color: wine, size: 18),
          ),
        ]),
      ),
      const SizedBox(height: 28),
      const Text('Devam etmek için rolünü seç', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ink)),
      const SizedBox(height: 14),
      _role(context, AppRole.customer, 'Müşteri', 'Salonları keşfet, stilini bul ve randevunu oluştur.', Icons.favorite_rounded),
      _role(context, AppRole.employee, 'Çalışan', 'Çalışmalarını paylaş, randevularını ve mesajlarını yönet.', Icons.content_cut_rounded),
      _role(context, AppRole.owner, 'İşletme Sahibi', 'Salonunu, ekibini, müşterilerini ve randevularını yönet.', Icons.storefront_rounded),
      _role(context, AppRole.admin, 'Ana Yönetici', 'Platformu, işletmeleri ve keşfet görünürlüğünü yönet.', Icons.admin_panel_settings_rounded),
      const SizedBox(height: 18),
      const Text('Geliştirici test ekranı • Normal giriş ekranı yayın öncesinde eklenecek', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12)),
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
        pages = [const OwnerHome(),const DiscoverPage(),const FollowingPage(),const SharePage(businessPost:true),const MessagesPage(),const OwnerProfilePage()];
        break;
      case AppRole.admin:
        labels = ['Genel Bakış','İşletmeler','Kullanıcılar','Keşfet Yönetimi']; icons = [Icons.dashboard,Icons.store,Icons.people_alt,Icons.explore];
        pages = [const AdminHome(),const AdminBusinesses(),const AdminUsers(),const DiscoverControl()];
        break;
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(heading, style: const TextStyle(fontWeight: FontWeight.w800, color: wine)), actions: [IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsPage())), icon: const Icon(Icons.notifications_none_rounded)), const SizedBox(width: 5)]),
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
  final String eyebrow, title, subtitle;
  final IconData icon;
  final String button;
  final VoidCallback? onTap;

  const HeroPanel({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.button = 'Keşfet',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF6E2038), Color(0xFFC45B78)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: wine.withOpacity(.18),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow.toUpperCase(), style: const TextStyle(
            color: Color(0xFFFFDDE5), fontSize: 10, letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          )),
          const SizedBox(height: 9),
          Text(title, style: const TextStyle(
            color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800,
            height: 1.15,
          )),
          const SizedBox(height: 7),
          Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
          const SizedBox(height: 14),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(button, style: const TextStyle(color: wine, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(width: 5),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: wine),
                ]),
              ),
            ),
          ),
        ],
      )),
      const SizedBox(width: 10),
      Container(
        width: 82,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.13),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(icon, size: 54, color: Colors.white),
      ),
    ]),
  );
}
class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  final repository = KuaforumFeedRepository();
  final searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> businesses;

  @override
  void initState() {
    super.initState();
    businesses = repository.fetchActiveBusinesses();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void searchBusinesses() {
    setState(() {
      businesses = repository.fetchActiveBusinesses(
        searchQuery: searchController.text,
      );
    });
  }

  @override
  Widget build(BuildContext context) => PageBody(children: [
    const Text('Merhaba, Güzellik! ♡', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: ink)),
    const SizedBox(height: 4),
    const Text('Bugün kendine biraz zaman ayır.', style: TextStyle(color: muted)),
    const SizedBox(height: 16),
    HeroPanel(
      eyebrow: 'Stilini keşfet',
      title: 'Hayal ettiğin saç stili burada',
      subtitle: 'İlham al, salonunu bul ve kolayca randevu oluştur.',
      icon: Icons.auto_awesome,
      button: 'Şimdi keşfet',
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: cream,
          appBar: AppBar(title: const Text('Keşfet', style: TextStyle(color: wine, fontWeight: FontWeight.w800))),
          body: const DiscoverPage(),
        ),
      )),
    ),
    const SizedBox(height: 15),
    Row(children: [
      Expanded(child: OutlinedButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const CustomerAppointmentsPage(),
        )),
        style: OutlinedButton.styleFrom(
          foregroundColor: wine,
          side: const BorderSide(color: blush),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
        icon: const Icon(Icons.calendar_month_outlined, size: 18),
        label: const Text('Randevularım'),
      )),
      const SizedBox(width: 8),
      Expanded(child: OutlinedButton.icon(
        onPressed: () async {
          final controller = TextEditingController();
          final accepted = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('İşletmeye katıl'),
              content: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'İşletme katılım kodu',
                  hintText: 'Örn. ABC123',
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Katıl')),
              ],
            ),
          );
          final code = controller.text.trim();
          controller.dispose();
          if (accepted != true || code.isEmpty) return;
          try {
            final businessId = await repository.joinBusinessByCode(code);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('İşletmeye başarıyla katıldın.')),
            );
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => BusinessProfilePage(businessId: businessId),
            ));
          } catch (error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('İşletmeye katılınamadı: $error')),
              );
            }
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: wine,
          side: const BorderSide(color: blush),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
        icon: const Icon(Icons.store_mall_directory_outlined, size: 18),
        label: const Text('İşletmeye katıl'),
      )),
    ]),
    const SizedBox(height: 14),
    TextField(
      controller: searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => searchBusinesses(),
      decoration: InputDecoration(
        hintText: 'Kuaför veya salon adı ara...',
        prefixIcon: const Icon(Icons.search, color: wine),
        suffixIcon: IconButton(
          onPressed: searchBusinesses,
          icon: const Icon(Icons.arrow_forward_rounded, color: wine),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: blush),
        ),
      ),
    ),
    const SectionTitle('Aktif kuaförler'),
    FutureBuilder<List<Map<String, dynamic>>>(
      future: businesses,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(color: wine)),
          );
        }
        if (snapshot.hasError) {
          return const _FeedMessage(
            icon: Icons.store_mall_directory_outlined,
            title: 'Kuaförler yüklenemedi',
            detail: 'Bağlantını kontrol edip tekrar dene.',
          );
        }
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) {
          return const _FeedMessage(
            icon: Icons.search_off,
            title: 'İşletme bulunamadı',
            detail: 'Farklı bir salon adı deneyebilirsin.',
          );
        }
        return Column(children: rows.map((business) {
          final logoUrl = business['logo_url'] as String?;
          return Card(
            color: Colors.white,
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
              side: const BorderSide(color: blush),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: blush,
                backgroundImage: logoUrl == null ? null : NetworkImage(logoUrl),
                child: logoUrl == null ? const Icon(Icons.storefront, color: wine) : null,
              ),
              title: Text(business['name'] as String? ?? 'Kuaförüm işletmesi', style: const TextStyle(color: ink, fontWeight: FontWeight.w800)),
              subtitle: Text(business['address'] as String? ?? 'Adres bilgisi eklenmemiş', style: const TextStyle(color: muted, fontSize: 11)),
              trailing: const Icon(Icons.chevron_right, color: muted),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => BusinessProfilePage(businessId: business['id'] as String),
              )),
            ),
          );
        }).toList());
      },
    ),
    const SectionTitle('Senin için seçtiklerimiz'),
    const QuickTiles(),
  ]);
}

class QuickTiles extends StatelessWidget {
  final bool ownerMode;
  const QuickTiles({super.key, this.ownerMode = false});

  void open(BuildContext context, int index) {
    if (!ownerMode) {
      final title = switch (index) {
        0 => 'Randevularım',
        1 => 'Keşfet',
        _ => 'Takip Edilenler',
      };
      final page = switch (index) {
        0 => const CustomerAppointmentsPage(),
        1 => const DiscoverPage(),
        _ => const FollowingPage(),
      };
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: cream,
          appBar: AppBar(
            title: Text(title, style: const TextStyle(color: wine, fontWeight: FontWeight.w800)),
          ),
          body: page,
        ),
      ));
      return;
    }

    final section = switch (index) {
      0 => 'Randevu Yönetimi',
      1 => 'Müşterilerim',
      _ => 'İşletme Ayarları',
    };
    final page = switch (index) {
      0 => const OwnerAppointments(),
      1 => const CustomersPage(),
      _ => const SettingsPage(),
    };
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: Text(section, style: const TextStyle(color: wine, fontWeight: FontWeight.bold)),
        ),
        body: page,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final items = ownerMode
        ? const [
            (Icons.calendar_month, 'Randevular'),
            (Icons.people_alt_outlined, 'Müşteriler'),
            (Icons.settings_outlined, 'Ayarlar'),
          ]
        : const [
            (Icons.calendar_month, 'Randevularım'),
            (Icons.diamond, 'Keşfet'),
            (Icons.favorite, 'Takip Edilen'),
          ];

    return Row(
      children: List.generate(items.length, (index) {
        final item = items[index];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => open(context, index),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: blush),
                  ),
                  child: Column(
                    children: [
                      Icon(item.$1, color: wine),
                      const SizedBox(height: 7),
                      Text(
                        item.$2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final repository = KuaforumFeedRepository();
  final searchController = TextEditingController();
  late Future<List<KuaforumFeedPost>> feed;
  String selectedCategory = 'Tümü';

  static const categories = [
    'Tümü',
    'Saç Kesimi',
    'Boyama',
    'Ombre',
    'Topuz',
    'Bakım',
    'Genel',
  ];

  @override
  void initState() {
    super.initState();
    feed = repository.fetchDiscoverFeed();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void applyFilters() {
    setState(() {
      feed = repository.fetchDiscoverFeed(
        searchQuery: searchController.text,
        category: selectedCategory,
      );
    });
  }

  Future<void> refresh() async {
    final next = repository.fetchDiscoverFeed(
      searchQuery: searchController.text,
      category: selectedCategory,
    );
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
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => applyFilters(),
            decoration: InputDecoration(
              hintText: 'Saç modeli, salon veya çalışan ara...',
              prefixIcon: const Icon(Icons.search, color: wine),
              suffixIcon: IconButton(
                onPressed: applyFilters,
                icon: const Icon(Icons.arrow_forward_rounded, color: wine),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: blush),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: blush),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 7,
            children: categories.map((category) => ChoiceChip(
              label: Text(category),
              selected: selectedCategory == category,
              onSelected: (_) {
                setState(() => selectedCategory = category);
                applyFilters();
              },
              selectedColor: blush,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selectedCategory == category ? wine : muted,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
              side: const BorderSide(color: blush),
            )).toList(),
          ),
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
              title: 'Sonuç bulunamadı',
              detail: 'Arama kelimeni veya seçtiğin kategoriyi değiştirebilirsin.',
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
  bool deleted = false;
  late String caption;

  @override
  void initState() {
    super.initState();
    liked = widget.post.isLikedByMe;
    likes = widget.post.likeCount;
    caption = widget.post.caption;
    loadFollowState();
  }

  Future<void> chooseAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
    );
    if (picked == null || !mounted) return;
    setState(() => avatarBusy = true);
    try {
      await repository.uploadProfileAvatar(File(picked.path));
      if (!mounted) return;
      setState(() => data = load());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil fotoğrafın güncellendi.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil fotoğrafı yüklenemedi: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => avatarBusy = false);
    }
  }

  Future<void> loadFollowState() async {
    try {
      final business = await widget.repository.isFollowingBusiness(widget.post.businessId);
      final author = widget.post.isEmployeePost && !widget.post.isOwnPost
          ? await widget.repository.isFollowingUser(widget.post.authorUserId)
          : false;
      if (!mounted) return;
      setState(() {
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

  Future<void> editPost() async {
    final controller = TextEditingController(text: caption);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Paylaşımı düzenle'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Paylaşım açıklaması',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    final updatedCaption = controller.text.trim();
    controller.dispose();
    if (confirmed != true || updatedCaption.isEmpty) return;
    try {
      await widget.repository.updatePostCaption(widget.post.id, updatedCaption);
      if (mounted) setState(() => caption = updatedCaption);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paylaşım güncellenemedi: $error')),
        );
      }
    }
  }

  Future<void> removePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Paylaşım silinsin mi?'),
        content: const Text('Bu paylaşım ve bağlı yorumları kalıcı olarak silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: wine),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deletePost(widget.post.id);
      if (mounted) {
        setState(() => deleted = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paylaşım silindi.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paylaşım silinemedi: $error')),
        );
      }
    }
  }

  Future<void> reportPost() async {
    const reasons = [
      'Spam',
      'Uygunsuz içerik',
      'Taciz veya hakaret',
      'Sahte hesap / yanıltıcı',
      'Diğer',
    ];
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Paylaşımı şikâyet et'),
        children: reasons.map((item) => SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, item),
          child: Text(item),
        )).toList(),
      ),
    );
    if (reason == null) return;
    try {
      await widget.repository.reportPost(widget.post.id, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şikâyetin alındı. Teşekkür ederiz.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Şikâyet gönderilemedi: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (deleted) return const SizedBox.shrink();
    final avatarUrl = widget.post.isEmployeePost
        ? widget.post.authorAvatarUrl
        : widget.post.businessLogoUrl;
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
        InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => widget.post.isEmployeePost
                ? PublicUserProfilePage(userId: widget.post.authorUserId)
                : BusinessProfilePage(businessId: widget.post.businessId),
          )),
          child: CircleAvatar(
            backgroundColor: blush,
            backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
            child: avatarUrl == null ? const Icon(Icons.person, color: wine) : null,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => widget.post.isEmployeePost
                  ? PublicUserProfilePage(userId: widget.post.authorUserId)
                  : BusinessProfilePage(businessId: widget.post.businessId),
            )),
            child: Text(widget.post.authorName, style: const TextStyle(fontWeight: FontWeight.bold, color: ink)),
          ),
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => BusinessProfilePage(businessId: widget.post.businessId),
            )),
            child: Text(widget.post.businessName, style: const TextStyle(color: muted, fontSize: 10)),
          ),
        ])),
        if (widget.post.isOwnPost || followStateLoaded)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: muted),
            onSelected: (value) {
              if (value == 'business') toggleBusinessFollow();
              if (value == 'author') toggleAuthorFollow();
              if (value == 'edit') editPost();
              if (value == 'delete') removePost();
              if (value == 'report') reportPost();
            },
            itemBuilder: (_) => widget.post.isOwnPost
                ? [
                    const PopupMenuItem(value: 'edit', child: Text('Açıklamayı düzenle')),
                    const PopupMenuItem(value: 'delete', child: Text('Paylaşımı sil')),
                  ]
                : [
                    PopupMenuItem(value: 'business', child: Text(followingBusiness ? 'İşletmeyi takipten çık' : 'İşletmeyi takip et')),
                    if (widget.post.isEmployeePost)
                      PopupMenuItem(value: 'author', child: Text(followingAuthor ? 'Çalışanı takipten çık' : 'Çalışanı takip et')),
                    const PopupMenuItem(value: 'report', child: Text('Paylaşımı şikâyet et')),
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
      Text(caption, style: const TextStyle(fontWeight: FontWeight.w600, color: ink)),
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
      if (!mounted) return;
      controller.clear();
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

class _Chip extends StatelessWidget {final String text;final bool active;const _Chip(this.text,[this.active=false]);@override Widget build(BuildContext context)=>Chip(label:Text(text,style:TextStyle(color:active?Colors.white:ink,fontSize:11)),backgroundColor:active?wine:Colors.white,side:BorderSide(color:blush));}
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

String _appointmentStatusLabel(String status) => switch (status) {
  'pending' => 'Bekliyor',
  'confirmed' => 'Onaylandı',
  'cancelled' => 'İptal edildi',
  'completed' => 'Tamamlandı',
  'no_show' => 'Gelmedi',
  _ => status,
};

String _appointmentDateLabel(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return '';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day.$month.${date.year} • $hour:$minute';
}

class _BusinessAppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final bool ownerMode;
  final VoidCallback onComplete;
  final VoidCallback onNoShow;
  final VoidCallback onCancel;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _BusinessAppointmentCard({
    required this.appointment,
    required this.ownerMode,
    required this.onComplete,
    required this.onNoShow,
    required this.onCancel,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final status = appointment['status'] as String? ?? 'pending';
    final requiresApproval = appointment['requires_business_approval'] == true;
    final isPendingApproval = status == 'pending' && requiresApproval;
    final statusColor = status == 'confirmed'
        ? const Color(0xFF32734B)
        : status == 'pending'
            ? const Color(0xFF94631A)
            : muted;
    final date = _appointmentDateLabel(appointment['starts_at'] as String? ?? '');
    final customer = appointment['customer_name'] as String? ?? 'Müşteri';
    final service = appointment['service_name'] as String? ?? 'Hizmet';
    final employee = appointment['employee_name'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: blush),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: blush,
            child: Icon(Icons.person_outline, color: wine),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(customer, style: const TextStyle(color: ink, fontWeight: FontWeight.w800)),
              Text(service, style: const TextStyle(color: muted, fontSize: 12)),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              _appointmentStatusLabel(status),
              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.calendar_month_outlined, color: wine, size: 16),
          const SizedBox(width: 6),
          Text(date, style: const TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w600)),
          if (employee.isNotEmpty) ...[
            const Spacer(),
            const Icon(Icons.content_cut, color: muted, size: 14),
            const SizedBox(width: 4),
            Flexible(child: Text(employee, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 11))),
          ],
        ]),
        if (isPendingApproval && ownerMode) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: onReject,
              style: OutlinedButton.styleFrom(foregroundColor: wine, side: const BorderSide(color: blush)),
              child: const Text('Reddet'),
            )),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(
              onPressed: onApprove,
              style: FilledButton.styleFrom(backgroundColor: wine),
              child: const Text('Onayla'),
            )),
          ]),
        ] else if (status == 'confirmed') ...[
          const SizedBox(height: 12),
          Wrap(spacing: 7, runSpacing: 4, children: [
            TextButton.icon(
              onPressed: onComplete,
              icon: const Icon(Icons.check_circle_outline, size: 17),
              label: const Text('Tamamlandı'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF32734B)),
            ),
            TextButton.icon(
              onPressed: onNoShow,
              icon: const Icon(Icons.person_off_outlined, size: 17),
              label: const Text('Gelmedi'),
              style: TextButton.styleFrom(foregroundColor: muted),
            ),
            TextButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close, size: 17),
              label: const Text('İptal et'),
              style: TextButton.styleFrom(foregroundColor: wine),
            ),
          ]),
        ] else if (isPendingApproval) ...[
          const SizedBox(height: 8),
          const Text('İşletme sahibinin özel onayı bekleniyor.', style: TextStyle(color: muted, fontSize: 11)),
        ],
      ]),
    );
  }
}

class AppointmentsPage extends StatefulWidget {
  final String title;
  const AppointmentsPage({super.key, required this.title});

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  final repository = KuaforumFeedRepository();
  late Future<List<Map<String, dynamic>>> appointments;
  String selectedFilter = 'Tümü';

  @override
  void initState() {
    super.initState();
    appointments = load();
  }

  Future<List<Map<String, dynamic>>> load() async {
    final employee = await repository.fetchMyEmployeeContext();
    return repository.fetchBusinessAppointments(
      employee['business_id'] as String,
      mineOnly: true,
    );
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => appointments = next);
    await next;
  }

  Future<void> performAction(String id, String action) async {
    try {
      if (action == 'complete' || action == 'no_show') {
        await repository.updateAppointmentStatus(id, status: action == 'complete' ? 'completed' : 'no_show');
      } else if (action == 'cancel') {
        await repository.cancelAppointment(id);
      }
      if (!mounted) return;
      await refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Randevu güncellenemedi: $error')),
        );
      }
    }
  }

  bool matchesFilter(Map<String, dynamic> row) {
    final status = row['status'] as String? ?? '';
    if (selectedFilter == 'Bekleyen') return status == 'pending';
    if (selectedFilter == 'Onaylanan') return status == 'confirmed';
    if (selectedFilter == 'Tamamlanan') return status == 'completed';
    return true;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: appointments,
    builder: (context, snapshot) => RefreshIndicator(
      color: wine,
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          Text(widget.title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 12),
          Wrap(spacing: 7, children: ['Tümü', 'Bekleyen', 'Onaylanan', 'Tamamlanan'].map((filter) => ChoiceChip(
            label: Text(filter),
            selected: selectedFilter == filter,
            onSelected: (_) => setState(() => selectedFilter = filter),
            selectedColor: blush,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(color: selectedFilter == filter ? wine : muted, fontWeight: FontWeight.w700, fontSize: 11),
            side: const BorderSide(color: blush),
          )).toList()),
          const SectionTitle('Randevularım'),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: wine)))
          else if (snapshot.hasError)
            _FeedMessage(
              icon: Icons.calendar_month_outlined,
              title: 'Randevular yüklenemedi',
              detail: 'Çalışan hesabının aktif işletme bağlantısını kontrol et.',
              action: 'Yeniden dene',
              onPressed: refresh,
            )
          else
            ...snapshot.data!.where(matchesFilter).map((row) => _BusinessAppointmentCard(
              appointment: row,
              ownerMode: false,
              onComplete: () => performAction(row['appointment_id'] as String, 'complete'),
              onNoShow: () => performAction(row['appointment_id'] as String, 'no_show'),
              onCancel: () => performAction(row['appointment_id'] as String, 'cancel'),
              onApprove: () {},
              onReject: () {},
            )),
          if (snapshot.hasData && snapshot.data!.where(matchesFilter).isEmpty)
            const _FeedMessage(icon: Icons.event_available_outlined, title: 'Bu filtrede randevu yok', detail: 'Yeni randevu geldiğinde burada göreceksin.'),
        ],
      ),
    ),
  );
}

class _BookingInitData {
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> employees;
  const _BookingInitData(this.services, this.employees);
}

class BookingPage extends StatefulWidget {
  final String businessId;
  final String businessName;
  const BookingPage({
    super.key,
    required this.businessId,
    required this.businessName,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final repository = KuaforumFeedRepository();
  final noteController = TextEditingController();
  late Future<_BookingInitData> data;
  Future<List<Map<String, dynamic>>>? slots;
  String? selectedServiceId;
  String? selectedEmployeeId;
  String? selectedSlot;
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
  bool booking = false;

  @override
  void initState() {
    super.initState();
    data = load();
  }

  Future<_BookingInitData> load() async {
    final values = await Future.wait([
      repository.fetchBusinessServices(widget.businessId),
      repository.fetchBusinessEmployees(widget.businessId),
    ]);
    final services = (values[0] as List<Map<String, dynamic>>)
        .where((row) => row['is_active'] == true)
        .toList();
    final employees = values[1] as List<Map<String, dynamic>>;
    return _BookingInitData(services, employees);
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  void ensureSelection(_BookingInitData value) {
    selectedServiceId ??= value.services.isEmpty ? null : value.services.first['id'] as String;
    selectedEmployeeId ??= value.employees.isEmpty ? null : value.employees.first['id'] as String;
    if (slots == null && selectedServiceId != null && selectedEmployeeId != null) {
      slots = loadSlots();
    }
  }

  Future<List<Map<String, dynamic>>> loadSlots() {
    return repository.fetchAvailableAppointmentSlots(
      businessId: widget.businessId,
      employeeId: selectedEmployeeId!,
      serviceId: selectedServiceId!,
      date: selectedDate,
    );
  }

  void updateSelection({String? serviceId, String? employeeId, DateTime? date}) {
    setState(() {
      if (serviceId != null) selectedServiceId = serviceId;
      if (employeeId != null) selectedEmployeeId = employeeId;
      if (date != null) selectedDate = date;
      selectedSlot = null;
      slots = selectedServiceId == null || selectedEmployeeId == null
          ? null
          : loadSlots();
    });
  }

  Future<void> chooseDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isBefore(today) ? today : selectedDate,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year, today.month, today.day).add(const Duration(days: 45)),
      helpText: 'Randevu gününü seç',
    );
    if (picked != null) updateSelection(date: picked);
  }

  String timeLabel(String value) {
    final time = DateTime.parse(value).toLocal();
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> submitBooking() async {
    if (booking || selectedSlot == null || selectedServiceId == null || selectedEmployeeId == null) return;
    setState(() => booking = true);
    try {
      await repository.bookAppointment(
        businessId: widget.businessId,
        employeeId: selectedEmployeeId!,
        serviceId: selectedServiceId!,
        startsAt: selectedSlot!,
        customerNote: noteController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Randevu talebin oluşturuldu.')),
      );
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => const CustomerAppointmentsPage(),
      ));
    } catch (error) {
      if (mounted) {
        setState(() {
          selectedSlot = null;
          slots = loadSlots();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Randevu oluşturulamadı: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => booking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: cream,
    appBar: AppBar(
      title: const Text('Randevu Oluştur', style: TextStyle(color: wine, fontWeight: FontWeight.w800)),
    ),
    body: FutureBuilder<_BookingInitData>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: wine));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const _FeedMessage(icon: Icons.calendar_month_outlined, title: 'Randevu ekranı açılamadı', detail: 'İşletme bilgileri yüklenemedi.');
        }
        final value = snapshot.data!;
        ensureSelection(value);
        if (value.services.isEmpty || value.employees.isEmpty) {
          return const _FeedMessage(
            icon: Icons.event_busy_outlined,
            title: 'Randevu için bilgiler eksik',
            detail: 'İşletmenin aktif hizmet ve çalışan tanımlaması gerekiyor.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
          children: [
            Text(widget.businessName, style: const TextStyle(color: ink, fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            const Text('Hizmetini, çalışanını ve sana uygun saati seç.', style: TextStyle(color: muted)),
            const SectionTitle('Hizmet seç'),
            DropdownButtonFormField<String>(
              value: selectedServiceId,
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
              items: value.services.map((service) {
                final price = service['price'] as num? ?? 0;
                final duration = service['duration_minutes'] as int? ?? 30;
                return DropdownMenuItem(
                  value: service['id'] as String,
                  child: Text('${service['name']} • ${price.toStringAsFixed(0)} ₺ • $duration dk'),
                );
              }).toList(),
              onChanged: (id) {
                if (id != null) updateSelection(serviceId: id);
              },
            ),
            const SectionTitle('Çalışan seç'),
            DropdownButtonFormField<String>(
              value: selectedEmployeeId,
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
              items: value.employees.map((employee) => DropdownMenuItem(
                value: employee['id'] as String,
                child: Text(employee['display_name'] as String? ?? 'Çalışan'),
              )).toList(),
              onChanged: (id) {
                if (id != null) updateSelection(employeeId: id);
              },
            ),
            const SectionTitle('Tarih seç'),
            OutlinedButton.icon(
              onPressed: chooseDate,
              style: OutlinedButton.styleFrom(
                foregroundColor: wine,
                side: const BorderSide(color: blush),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('${selectedDate.day.toString().padLeft(2, '0')}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year}'),
            ),
            const SectionTitle('Uygun saatler'),
            if (slots == null)
              const Text('Önce hizmet ve çalışan seç.', style: TextStyle(color: muted))
            else
              FutureBuilder<List<Map<String, dynamic>>>(
                future: slots,
                builder: (context, slotSnapshot) {
                  if (slotSnapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(18),
                      child: Center(child: CircularProgressIndicator(color: wine)),
                    );
                  }
                  if (slotSnapshot.hasError) {
                    return const Text('Uygun saatler yüklenemedi.', style: TextStyle(color: muted));
                  }
                  final options = slotSnapshot.data ?? [];
                  if (options.isEmpty) {
                    return const Text('Bu gün için uygun saat bulunamadı.', style: TextStyle(color: muted));
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options.map((slot) {
                      final start = slot['slot_start'] as String;
                      final selected = selectedSlot == start;
                      return ChoiceChip(
                        label: Text(timeLabel(start)),
                        selected: selected,
                        onSelected: (_) => setState(() => selectedSlot = start),
                        selectedColor: blush,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(color: selected ? wine : muted, fontWeight: FontWeight.w700),
                        side: const BorderSide(color: blush),
                      );
                    }).toList(),
                  );
                },
              ),
            const SectionTitle('Not (isteğe bağlı)'),
            TextField(
              controller: noteController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'İşletmeye iletmek istediğin bir not var mı?',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: blush)),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: selectedSlot == null || booking ? null : submitBooking,
              style: FilledButton.styleFrom(backgroundColor: wine, padding: const EdgeInsets.symmetric(vertical: 15)),
              icon: booking
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline),
              label: Text(booking ? 'Oluşturuluyor...' : 'Randevuyu onayla'),
            ),
          ],
        );
      },
    ),
  );
}

class CustomerAppointmentsPage extends StatefulWidget {
  const CustomerAppointmentsPage({super.key});

  @override
  State<CustomerAppointmentsPage> createState() => _CustomerAppointmentsPageState();
}

class _CustomerAppointmentsPageState extends State<CustomerAppointmentsPage> {
  final repository = KuaforumFeedRepository();
  late Future<List<Map<String, dynamic>>> appointments;
  String selectedFilter = 'Aktif';

  @override
  void initState() {
    super.initState();
    appointments = repository.fetchCustomerAppointments();
  }

  Future<void> refresh() async {
    final next = repository.fetchCustomerAppointments();
    setState(() => appointments = next);
    await next;
  }

  Future<void> cancel(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Randevuyu iptal et?'),
        content: const Text('Onaylanmış randevun iptal edilecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: wine),
            child: const Text('İptal et'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await repository.cancelAppointment(id);
      if (!mounted) return;
      await refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Randevu iptal edilemedi: $error')),
        );
      }
    }
  }

  bool matchesFilter(Map<String, dynamic> row) {
    final status = row['status'] as String? ?? '';
    final isActive = status == 'confirmed' || status == 'pending';
    return selectedFilter == 'Tümü' ||
        (selectedFilter == 'Aktif' && isActive) ||
        (selectedFilter == 'Geçmiş' && !isActive);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: cream,
    appBar: AppBar(title: const Text('Randevularım', style: TextStyle(color: wine, fontWeight: FontWeight.w800))),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: appointments,
      builder: (context, snapshot) => RefreshIndicator(
        color: wine,
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: [
            Wrap(spacing: 8, children: ['Aktif', 'Geçmiş', 'Tümü'].map((filter) => ChoiceChip(
              label: Text(filter),
              selected: selectedFilter == filter,
              onSelected: (_) => setState(() => selectedFilter = filter),
              selectedColor: blush,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(color: selectedFilter == filter ? wine : muted, fontWeight: FontWeight.w700, fontSize: 11),
              side: const BorderSide(color: blush),
            )).toList()),
            const SizedBox(height: 14),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: wine)))
            else if (snapshot.hasError)
              const _FeedMessage(icon: Icons.calendar_month_outlined, title: 'Randevular yüklenemedi', detail: 'Daha sonra tekrar deneyebilirsin.')
            else if (snapshot.data!.where(matchesFilter).isEmpty)
              const _FeedMessage(icon: Icons.event_available_outlined, title: 'Randevu bulunamadı', detail: 'Keşfet bölümünden bir salon seçerek randevu oluşturabilirsin.')
            else
              ...snapshot.data!.where(matchesFilter).map((row) {
                final business = row['businesses'];
                final service = row['services'];
                final employee = row['employees'];
                final businessName = business is Map<String, dynamic> ? business['name'] as String? ?? 'Kuaförüm' : 'Kuaförüm';
                final serviceName = service is Map<String, dynamic> ? service['name'] as String? ?? 'Hizmet' : 'Hizmet';
                final employeeName = employee is Map<String, dynamic> ? employee['display_name'] as String? ?? '' : '';
                final status = row['status'] as String? ?? 'pending';
                final date = _appointmentDateLabel(row['starts_at'] as String? ?? '');
                final price = service is Map<String, dynamic> ? service['price'] : null;
                return Card(
                  color: Colors.white,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: const BorderSide(color: blush)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(businessName, style: const TextStyle(color: wine, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Text(serviceName, style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
                      Text('${date}${employeeName.isEmpty ? '' : ' • $employeeName'}', style: const TextStyle(color: muted, fontSize: 11)),
                      if (price != null) Text('₺${(price as num).toStringAsFixed(0)}', style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: Text(
                          row['requires_business_approval'] == true && status == 'pending'
                              ? 'İşletme onayı bekleniyor'
                              : _appointmentStatusLabel(status),
                          style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w700),
                        )),
                        if (status == 'confirmed')
                          TextButton(
                            onPressed: () => cancel(row['id'] as String),
                            child: const Text('Randevuyu iptal et', style: TextStyle(color: wine)),
                          ),
                      ]),
                    ]),
                  ),
                );
              }),
          ],
        ),
      ),
    ),
  );
}

class AppointmentTile extends StatelessWidget {final String name,service,time,status;const AppointmentTile({super.key,required this.name,required this.service,required this.time,required this.status});@override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),border:Border.all(color:blush)),child:Row(children:[const CircleAvatar(radius:24,backgroundColor:blush,child:Icon(Icons.person,color:wine)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(name,style:const TextStyle(fontWeight:FontWeight.bold,color:ink)),Text(service,style:const TextStyle(color:muted,fontSize:12)),Text(time,style:const TextStyle(color:ink,fontSize:12))])),Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),decoration:BoxDecoration(color:const Color(0xFFE3F3E8),borderRadius:BorderRadius.circular(12)),child:Text(status,style:const TextStyle(color:Color(0xFF32734B),fontSize:10,fontWeight:FontWeight.bold))) ]));}
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final repository = KuaforumFeedRepository();
  late Future<List<Map<String, dynamic>>> conversations;

  @override
  void initState() {
    super.initState();
    conversations = repository.fetchConversations();
  }

  Future<void> refresh() async {
    final next = repository.fetchConversations();
    setState(() => conversations = next);
    await next;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: conversations,
    builder: (context, snapshot) => RefreshIndicator(
      color: wine,
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          const Text('Mesajlar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 5),
          const Text('Paylaşım yapan çalışanlarla sohbetlerin.', style: TextStyle(color: muted)),
          const SizedBox(height: 14),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Padding(
              padding: EdgeInsets.all(34),
              child: Center(child: CircularProgressIndicator(color: wine)),
            )
          else if (snapshot.hasError)
            _FeedMessage(
              icon: Icons.chat_bubble_outline,
              title: 'Mesajlar yüklenemedi',
              detail: 'Bağlantını kontrol edip tekrar dene.',
              action: 'Yeniden dene',
              onPressed: refresh,
            )
          else if ((snapshot.data ?? []).isEmpty)
            const _FeedMessage(
              icon: Icons.forum_outlined,
              title: 'Henüz sohbetin yok',
              detail: 'Keşfet bölümünde paylaşım yapan bir çalışanın profiline girip mesaj gönderebilirsin.',
            )
          else
            ...snapshot.data!.map((row) {
              final currentUserId = Supabase.instance.client.auth.currentUser?.id;
              final isCustomer = row['customer_id'] == currentUserId;
              final title = isCustomer
                  ? row['employee_name'] as String? ?? 'Çalışan'
                  : row['customer_name'] as String? ?? 'Müşteri';
              final avatarUrl = isCustomer
                  ? row['employee_avatar_url'] as String?
                  : row['customer_avatar_url'] as String?;
              final updated = DateTime.tryParse(row['updated_at'] as String? ?? '')?.toLocal();
              final time = updated == null
                  ? ''
                  : '${updated.day}.${updated.month} • ${updated.hour.toString().padLeft(2, '0')}:${updated.minute.toString().padLeft(2, '0')}';
              return Card(
                color: Colors.white,
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                  side: const BorderSide(color: blush),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: blush,
                    backgroundImage: avatarUrl == null || avatarUrl.isEmpty
                        ? null
                        : NetworkImage(avatarUrl),
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? const Icon(Icons.person, color: wine)
                        : null,
                  ),
                  title: Text(title, style: const TextStyle(color: ink, fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    row['business_name'] as String? ?? 'Kuaförüm',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                  trailing: Text(time, style: const TextStyle(color: muted, fontSize: 10)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ChatPage(
                      conversationId: row['id'] as String,
                      title: title,
                      subtitle: row['business_name'] as String? ?? 'Kuaförüm',
                    ),
                  )),
                ),
              );
            }),
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
    this.subtitle = 'Kuaförüm',
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final repository = KuaforumFeedRepository();
  final controller = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> messages;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    messages = repository.streamMessages(widget.conversationId);
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
    setState(() => sending = true);
    try {
      await repository.sendMessage(widget.conversationId, body);
      if (!mounted) return;
      controller.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mesaj gönderilemedi: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: cream,
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: const TextStyle(color: wine, fontWeight: FontWeight.w800, fontSize: 16)),
          Text(widget.subtitle, style: const TextStyle(color: muted, fontSize: 10)),
        ],
      ),
    ),
    body: SafeArea(
      child: Column(children: [
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: messages,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: wine));
              }
              if (snapshot.hasError) {
                return const Center(child: Text('Sohbet yüklenemedi.', style: TextStyle(color: muted)));
              }
              final rows = [...(snapshot.data ?? [])];
              rows.sort((a, b) => DateTime.parse(a['created_at'] as String)
                  .compareTo(DateTime.parse(b['created_at'] as String)));
              if (rows.isEmpty) {
                return const Center(child: Text('Sohbeti başlatmak için bir mesaj gönder.', style: TextStyle(color: muted)));
              }
              final currentUserId = Supabase.instance.client.auth.currentUser?.id;
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final message = rows[index];
                  final mine = message['sender_id'] == currentUserId;
                  final created = DateTime.tryParse(message['created_at'] as String? ?? '')?.toLocal();
                  final time = created == null
                      ? ''
                      : '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: mine ? wine : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(17),
                          topRight: const Radius.circular(17),
                          bottomLeft: Radius.circular(mine ? 17 : 4),
                          bottomRight: Radius.circular(mine ? 4 : 17),
                        ),
                        border: mine ? null : Border.all(color: blush),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            message['body'] as String? ?? '',
                            style: TextStyle(color: mine ? Colors.white : ink, height: 1.35),
                          ),
                          const SizedBox(height: 4),
                          Text(time, style: TextStyle(
                            color: mine ? Colors.white70 : muted,
                            fontSize: 9,
                          )),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: blush)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              maxLength: 4000,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => send(),
              decoration: InputDecoration(
                hintText: 'Mesajını yaz...',
                counterText: '',
                filled: true,
                fillColor: cream,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            )),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : send,
              style: IconButton.styleFrom(backgroundColor: wine, foregroundColor: Colors.white),
              icon: sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ))
                  : const Icon(Icons.send_rounded),
            ),
          ]),
        ),
      ]),
    ),
  );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return const _FeedMessage(
        icon: Icons.person_off_outlined,
        title: 'Oturum bulunamadı',
        detail: 'Profilini görmek için tekrar giriş yapmalısın.',
      );
    }
    return PublicUserProfilePage(userId: userId, isOwn: true);
  }
}

class _UserProfileData {
  final Map<String, dynamic> profile;
  final Map<String, int> stats;
  final List<KuaforumFeedPost> posts;
  final bool canMessage;
  const _UserProfileData(this.profile, this.stats, this.posts, this.canMessage);
}

class PublicUserProfilePage extends StatefulWidget {
  final String userId;
  final bool isOwn;
  const PublicUserProfilePage({
    super.key,
    required this.userId,
    this.isOwn = false,
  });

  @override
  State<PublicUserProfilePage> createState() => _PublicUserProfilePageState();
}

class _PublicUserProfilePageState extends State<PublicUserProfilePage> {
  final repository = KuaforumFeedRepository();
  late Future<_UserProfileData> data;
  bool following = false;
  bool followBusy = false;
  bool avatarBusy = false;

  bool get isOwnProfile =>
      widget.isOwn ||
      widget.userId == Supabase.instance.client.auth.currentUser?.id;

  Future<_UserProfileData> load() async {
    final values = await Future.wait([
      repository.fetchPublicProfile(widget.userId),
      repository.fetchSocialStats(userId: widget.userId),
      repository.fetchProfilePosts(userId: widget.userId),
      repository.canMessageEmployee(widget.userId),
    ]);
    return _UserProfileData(
      values[0] as Map<String, dynamic>,
      values[1] as Map<String, int>,
      values[2] as List<KuaforumFeedPost>,
      values[3] as bool,
    );
  }

  @override
  void initState() {
    super.initState();
    data = load();
    if (!isOwnProfile) loadFollowState();
  }

  Future<void> loadFollowState() async {
    try {
      final value = await repository.isFollowingUser(widget.userId);
      if (mounted) setState(() => following = value);
    } catch (_) {}
  }

  Future<void> toggleFollow() async {
    if (followBusy) return;
    setState(() {
      followBusy = true;
      following = !following;
    });
    try {
      if (following) {
        await repository.followUser(widget.userId);
      } else {
        await repository.unfollowUser(widget.userId);
      }
      if (mounted) setState(() => data = load());
    } catch (error) {
      if (mounted) {
        setState(() => following = !following);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Takip işlemi yapılamadı: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => followBusy = false);
    }
  }

  Future<void> openConversation(String employeeName) async {
    try {
      final conversationId =
          await repository.startEmployeeConversation(widget.userId);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: conversationId,
          title: employeeName,
        ),
      ));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sohbet başlatılamadı: $error')),
        );
      }
    }
  }

  void openList(String mode) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => FollowListPage(
        profileId: widget.userId,
        mode: mode,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_UserProfileData>(
    future: data,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator(color: wine));
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return const _FeedMessage(
          icon: Icons.person_search_outlined,
          title: 'Profil açılamadı',
          detail: 'Profil bilgileri şu anda yüklenemiyor.',
        );
      }
      final value = snapshot.data!;
      final name = (value.profile['full_name'] as String? ?? '').trim();
      final accountType = value.profile['account_type'] as String? ?? 'customer';
      final roleLabel = switch (accountType) {
        'business_owner' => 'İşletme sahibi',
        'employee' => 'Kuaför / Çalışan',
        _ => 'Kuaförüm üyesi',
      };
      return RefreshIndicator(
        color: wine,
        onRefresh: () async {
          final next = load();
          setState(() => data = next);
          await next;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            Center(child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: blush,
                  backgroundImage: (value.profile['avatar_url'] as String?)?.isNotEmpty == true
                      ? NetworkImage(value.profile['avatar_url'] as String)
                      : null,
                  child: (value.profile['avatar_url'] as String?)?.isNotEmpty == true
                      ? null
                      : Text(
                          name.isEmpty ? 'K' : name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: wine, fontSize: 30, fontWeight: FontWeight.w800),
                        ),
                ),
                if (isOwnProfile)
                  Positioned(
                    right: -5,
                    bottom: -5,
                    child: IconButton.filled(
                      onPressed: avatarBusy ? null : chooseAvatar,
                      style: IconButton.styleFrom(
                        backgroundColor: wine,
                        foregroundColor: Colors.white,
                        fixedSize: const Size(34, 34),
                        minimumSize: const Size(34, 34),
                        padding: EdgeInsets.zero,
                      ),
                      icon: avatarBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.camera_alt_rounded, size: 17),
                    ),
                  ),
              ],
            )),
            const SizedBox(height: 12),
            Text(
              name.isEmpty ? 'Kuaförüm kullanıcısı' : name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: ink),
            ),
            const SizedBox(height: 4),
            Text(roleLabel, textAlign: TextAlign.center, style: const TextStyle(color: muted)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _ProfileMetric(
                value.stats['posts'] ?? 0,
                'Gönderi',
                onTap: null,
              ),
              _ProfileMetric(
                value.stats['followers'] ?? 0,
                'Takipçi',
                onTap: () => openList('followers'),
              ),
              _ProfileMetric(
                value.stats['following'] ?? 0,
                'Takip',
                onTap: () => openList('following'),
              ),
            ]),
            if (isOwnProfile) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => Scaffold(
                    backgroundColor: cream,
                    appBar: AppBar(title: const Text('Bildirimler', style: TextStyle(color: wine, fontWeight: FontWeight.w800))),
                    body: const NotificationsPage(),
                  ),
                )),
                style: OutlinedButton.styleFrom(
                  foregroundColor: wine,
                  side: const BorderSide(color: blush),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('Bildirimler'),
              ),
            ],
            if (!isOwnProfile) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: followBusy ? null : toggleFollow,
                style: FilledButton.styleFrom(
                  backgroundColor: following ? blush : wine,
                  foregroundColor: following ? wine : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: Icon(following ? Icons.check : Icons.person_add_alt_1),
                label: Text(following ? 'Takip ediliyor' : 'Takip et'),
              ),
            ],
            if (!isOwnProfile && value.canMessage) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => openConversation(
                  name.isEmpty ? 'Çalışan' : name,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: wine,
                  side: const BorderSide(color: blush),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Mesaj gönder'),
              ),
            ],
            const SectionTitle('Paylaşımlar'),
            if (value.posts.isEmpty)
              const _FeedMessage(
                icon: Icons.photo_library_outlined,
                title: 'Henüz paylaşım yok',
                detail: 'Bu profilde görüntülenebilecek herkese açık paylaşım bulunmuyor.',
              )
            else
              ...value.posts.map((post) => LiveFeedPostCard(
                post: post,
                repository: repository,
              )),
            if (isOwnProfile) ...[
              const SectionTitle('Hesap'),
              Card(
                color: Colors.white,
                elevation: 0,
                child: ListTile(
                  leading: const Icon(Icons.logout, color: wine),
                  title: const Text('Çıkış yap', style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
                  onTap: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const RolePicker()),
                      (_) => false,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _ProfileMetric extends StatelessWidget {
  final int value;
  final String label;
  final VoidCallback? onTap;
  const _ProfileMetric(this.value, this.label, {this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(children: [
        Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: wine)),
        Text(label, style: const TextStyle(fontSize: 11, color: muted)),
      ]),
    ),
  );
}

class FollowListPage extends StatefulWidget {
  final String profileId;
  final String mode;
  final bool businessProfile;
  const FollowListPage({
    super.key,
    required this.profileId,
    required this.mode,
    this.businessProfile = false,
  });

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  final repository = KuaforumFeedRepository();
  late Future<List<Map<String, dynamic>>> people;

  @override
  void initState() {
    super.initState();
    people = load();
  }

  Future<List<Map<String, dynamic>>> load() {
    if (widget.businessProfile) {
      return repository.fetchBusinessFollowers(widget.profileId);
    }
    return widget.mode == 'followers'
        ? repository.fetchUserFollowers(widget.profileId)
        : repository.fetchUserFollowing(widget.profileId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: cream,
    appBar: AppBar(
      title: Text(
        widget.mode == 'followers' ? 'Takipçiler' : 'Takip Edilenler',
        style: const TextStyle(color: wine, fontWeight: FontWeight.w800),
      ),
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: people,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: wine));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Liste yüklenemedi.', style: TextStyle(color: muted)));
        }
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) {
          return const Center(child: Text('Henüz burada kimse yok.', style: TextStyle(color: muted)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(color: blush),
          itemBuilder: (context, index) {
            final row = rows[index];
            final isBusiness = row['kind'] == 'business';
            final id = row['id'] as String? ?? row['follower_user_id'] as String? ?? '';
            final name = row['name'] as String? ??
                row['full_name'] as String? ?? 'Kuaförüm kullanıcısı';
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              leading: CircleAvatar(
                backgroundColor: blush,
                backgroundImage: (row['avatar_url'] as String?)?.isNotEmpty == true
                    ? NetworkImage(row['avatar_url'] as String)
                    : null,
                child: (row['avatar_url'] as String?)?.isNotEmpty == true
                    ? null
                    : Icon(isBusiness ? Icons.storefront : Icons.person, color: wine),
              ),
              title: Text(name, style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
              subtitle: Text(isBusiness ? 'İşletme' : 'Kuaförüm üyesi', style: const TextStyle(color: muted)),
              trailing: const Icon(Icons.chevron_right, color: muted),
              onTap: id.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => isBusiness
                    ? BusinessProfilePage(businessId: id)
                    : PublicUserProfilePage(userId: id),
              )),
            );
          },
        );
      },
    ),
  );
}

class _BusinessProfileData {
  final Map<String, dynamic> business;
  final Map<String, int> stats;
  final List<KuaforumFeedPost> posts;
  final List<Map<String, dynamic>> services;
  final bool isMember;
  const _BusinessProfileData(this.business, this.stats, this.posts, this.services, this.isMember);
}

class BusinessProfilePage extends StatefulWidget {
  final String businessId;
  const BusinessProfilePage({super.key, required this.businessId});

  @override
  State<BusinessProfilePage> createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends State<BusinessProfilePage> {
  final repository = KuaforumFeedRepository();
  late Future<_BusinessProfileData> data;
  bool following = false;
  bool followBusy = false;

  Future<_BusinessProfileData> load() async {
    final values = await Future.wait([
      repository.fetchBusinessProfile(widget.businessId),
      repository.fetchSocialStats(businessId: widget.businessId),
      repository.fetchProfilePosts(businessId: widget.businessId),
      repository.fetchBusinessServices(widget.businessId),
      repository.fetchMyBusinessMembership(),
    ]);
    return _BusinessProfileData(
      values[0] as Map<String, dynamic>,
      values[1] as Map<String, int>,
      values[2] as List<KuaforumFeedPost>,
      values[3] as List<Map<String, dynamic>>,
      values[4] == widget.businessId,
    );
  }

  @override
  void initState() {
    super.initState();
    data = load();
    loadFollowState();
  }

  Future<void> loadFollowState() async {
    try {
      final value = await repository.isFollowingBusiness(widget.businessId);
      if (mounted) setState(() => following = value);
    } catch (_) {}
  }

  Future<void> toggleFollow() async {
    if (followBusy) return;
    setState(() {
      followBusy = true;
      following = !following;
    });
    try {
      if (following) {
        await repository.followBusiness(widget.businessId);
      } else {
        await repository.unfollowBusiness(widget.businessId);
      }
      if (mounted) setState(() => data = load());
    } catch (error) {
      if (mounted) {
        setState(() => following = !following);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İşletme takibi güncellenemedi: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => followBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: cream,
    appBar: AppBar(title: const Text('İşletme Profili', style: TextStyle(color: wine, fontWeight: FontWeight.w800))),
    body: FutureBuilder<_BusinessProfileData>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: wine));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const _FeedMessage(icon: Icons.store_mall_directory_outlined, title: 'İşletme profili açılamadı', detail: 'İşletme bilgileri şu anda yüklenemiyor.');
        }
        final value = snapshot.data!;
        final name = value.business['name'] as String? ?? 'Kuaförüm işletmesi';
        final address = value.business['address'] as String? ?? '';
        return RefreshIndicator(
          color: wine,
          onRefresh: () async => setState(() => data = load()),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              Center(child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: blush,
                  borderRadius: BorderRadius.circular(28),
                  image: (value.business['logo_url'] as String?)?.isNotEmpty == true
                      ? DecorationImage(
                          image: NetworkImage(value.business['logo_url'] as String),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (value.business['logo_url'] as String?)?.isNotEmpty == true
                    ? null
                    : const Icon(Icons.storefront_rounded, color: wine, size: 48),
              )),
              const SizedBox(height: 12),
              Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
              if (address.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(address, textAlign: TextAlign.center, style: const TextStyle(color: muted)),
              ],
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _ProfileMetric(value.stats['posts'] ?? 0, 'Gönderi'),
                _ProfileMetric(
                  value.stats['followers'] ?? 0,
                  'Takipçi',
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => FollowListPage(
                      profileId: widget.businessId,
                      mode: 'followers',
                      businessProfile: true,
                    ),
                  )),
                ),
              ]),
              const SizedBox(height: 14),
              if (value.business['owner_id'] !=
                  Supabase.instance.client.auth.currentUser?.id)
                FilledButton.icon(
                  onPressed: followBusy ? null : toggleFollow,
                  style: FilledButton.styleFrom(
                    backgroundColor: following ? blush : wine,
                    foregroundColor: following ? wine : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: Icon(following ? Icons.check : Icons.add),
                  label: Text(following ? 'Takip ediliyor' : 'İşletmeyi takip et'),
                ),
              if (value.isMember) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => BookingPage(
                      businessId: widget.businessId,
                      businessName: name,
                    ),
                  )),
                  style: FilledButton.styleFrom(
                    backgroundColor: wine,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Randevu al'),
                ),
              ] else if (value.business['owner_id'] !=
                  Supabase.instance.client.auth.currentUser?.id) ...[
                const SizedBox(height: 8),
                const Text(
                  'Randevu alabilmek için önce işletmenin katılım koduyla üye olmalısın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ],
              const SectionTitle('Hizmetler'),
              if (value.services.isEmpty)
                const Text('İşletmenin hizmet listesi henüz eklenmemiş.', style: TextStyle(color: muted, fontSize: 12))
              else
                ...value.services.where((service) => service['is_active'] == true).map((service) {
                  final price = service['price'] as num? ?? 0;
                  final duration = service['duration_minutes'] as int? ?? 30;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      radius: 18,
                      backgroundColor: blush,
                      child: Icon(Icons.content_cut, color: wine, size: 17),
                    ),
                    title: Text(service['name'] as String? ?? 'Hizmet', style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
                    subtitle: Text('$duration dakika', style: const TextStyle(color: muted, fontSize: 11)),
                    trailing: Text('${price.toStringAsFixed(0)} ₺', style: const TextStyle(color: wine, fontWeight: FontWeight.w800)),
                  );
                }),
              const SectionTitle('Salon paylaşımları'),
              if (value.posts.isEmpty)
                const _FeedMessage(icon: Icons.photo_library_outlined, title: 'Henüz paylaşım yok', detail: 'İşletmenin herkese açık paylaşımı bulunmuyor.')
              else
                ...value.posts.map((post) => LiveFeedPostCard(post: post, repository: repository)),
            ],
          ),
        );
      },
    ),
  );
}


class _Metric extends StatelessWidget {final String value,label;const _Metric(this.value,this.label);@override Widget build(BuildContext context)=>Column(children:[Text(value,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:wine)),Text(label,style:const TextStyle(fontSize:11,color:muted))]);}
class _EmployeeHomeData {
  final Map<String, dynamic> employee;
  final List<Map<String, dynamic>> appointments;
  const _EmployeeHomeData(this.employee, this.appointments);
}

class EmployeeHome extends StatefulWidget {
  const EmployeeHome({super.key});

  @override
  State<EmployeeHome> createState() => _EmployeeHomeState();
}

class _EmployeeHomeState extends State<EmployeeHome> {
  final repository = KuaforumFeedRepository();
  late Future<_EmployeeHomeData> data;

  @override
  void initState() {
    super.initState();
    data = load();
  }

  Future<_EmployeeHomeData> load() async {
    final employee = await repository.fetchMyEmployeeContext();
    final appointments = await repository.fetchBusinessAppointments(
      employee['business_id'] as String,
      mineOnly: true,
    );
    return _EmployeeHomeData(employee, appointments);
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => data = next);
    await next;
  }

  String appointmentTime(Map<String, dynamic> row) {
    final value = DateTime.tryParse(row['starts_at']?.toString() ?? '');
    if (value == null) return 'Saat bilgisi yok';
    final local = value.toLocal();
    final now = DateTime.now();
    final day = DateTime(local.year, local.month, local.day);
    final today = DateTime(now.year, now.month, now.day);
    final prefix = day == today
        ? 'Bugün'
        : day == today.add(const Duration(days: 1))
            ? 'Yarın'
            : '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}';
    return '$prefix • ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_EmployeeHomeData>(
    future: data,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator(color: wine));
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return PageBody(children: [
          const Text('Çalışan Paneli', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 12),
          _FeedMessage(
            icon: Icons.work_outline,
            title: 'Çalışan bilgileri yüklenemedi',
            detail: 'Aktif çalışan kaydını ve internet bağlantını kontrol et.',
            action: 'Yeniden dene',
            onPressed: refresh,
          ),
        ]);
      }

      final value = snapshot.data!;
      final now = DateTime.now();
      final todayCount = value.appointments.where((row) {
        final start = DateTime.tryParse(row['starts_at']?.toString() ?? '')?.toLocal();
        return start != null &&
            start.year == now.year &&
            start.month == now.month &&
            start.day == now.day &&
            row['status'] != 'cancelled';
      }).length;
      final upcoming = value.appointments.where((row) {
        final start = DateTime.tryParse(row['starts_at']?.toString() ?? '');
        final status = row['status']?.toString();
        return start != null &&
            start.isAfter(DateTime.now()) &&
            status != 'cancelled' &&
            status != 'completed' &&
            status != 'no_show';
      }).toList()
        ..sort((a, b) => DateTime.parse(a['starts_at'].toString())
            .compareTo(DateTime.parse(b['starts_at'].toString())));
      final name = value.employee['display_name']?.toString().trim();
      final greeting = name == null || name.isEmpty ? 'Merhaba' : 'Merhaba, $name';

      return RefreshIndicator(
        color: wine,
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          children: [
            Text(greeting, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 4),
            const Text('Bugünkü çalışmalarını ve randevularını buradan takip et.', style: TextStyle(color: muted)),
            const SizedBox(height: 16),
            Row(children: [
              _StatCard(todayCount.toString(), 'Bugünkü Randevu'),
              _StatCard(value.appointments.length.toString(), 'Toplam Randevu'),
              _StatCard(upcoming.length.toString(), 'Yaklaşan'),
            ]),
            const SizedBox(height: 16),
            HeroPanel(
              eyebrow: 'Portfolyonu büyüt',
              title: 'Çalışmalarını paylaş',
              subtitle: 'Yaptığın işleri paylaş, müşterilerine ilham ver ve portfolyonu büyüt.',
              icon: Icons.camera_alt,
              button: 'Paylaşım yap',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Yeni paylaşım', style: TextStyle(color: wine, fontWeight: FontWeight.w800))),
                  body: const SharePage(),
                ),
              )),
            ),
            const SectionTitle('Yaklaşan Randevular'),
            if (upcoming.isEmpty)
              const _FeedMessage(
                icon: Icons.event_available_outlined,
                title: 'Yaklaşan randevu yok',
                detail: 'Yeni randevuların burada görünecek.',
              )
            else
              ...upcoming.take(4).map((row) => AppointmentTile(
                name: row['customer_name']?.toString() ?? 'Müşteri',
                service: row['service_name']?.toString() ?? 'Hizmet',
                time: appointmentTime(row),
                status: row['status'] == 'pending'
                    ? 'Onay bekliyor'
                    : row['status'] == 'confirmed'
                        ? 'Onaylandı'
                        : row['status']?.toString() ?? 'Aktif',
              )),
          ],
        ),
      );
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
  final caption=TextEditingController(); final picker=ImagePicker(); XFile? selectedMedia; bool isVideo=false; String selectedCategory='Genel';
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
        category: selectedCategory,
      );
      if (!mounted) return;
      setState(() {
        caption.clear();
        selectedMedia = null;
        isVideo = false;
        selectedCategory = 'Genel';
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
      DropdownButtonFormField<String>(
        value: selectedCategory,
        decoration: InputDecoration(
          labelText: 'Paylaşım kategorisi',
          filled: true,
          fillColor: cream,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          prefixIcon: const Icon(Icons.category_outlined, color: wine),
        ),
        items: const ['Genel', 'Saç Kesimi', 'Boyama', 'Ombre', 'Topuz', 'Bakım']
            .map((category) => DropdownMenuItem(
              value: category,
              child: Text(category),
            ))
            .toList(),
        onChanged: (value) {
          if (value != null) setState(() => selectedCategory = value);
        },
      ),
      const SizedBox(height:12),
      TextField(
        controller:caption,
        maxLines:4,
        maxLength:500,
        decoration:InputDecoration(
          hintText:'Bu güzel çalışmayı anlat... ♡',
          filled:true,
          fillColor:cream,
          border:OutlineInputBorder(
            borderRadius:BorderRadius.circular(15),
            borderSide:BorderSide.none,
          ),
          prefixIcon:const Icon(Icons.edit_note,color:wine),
        ),
      ),
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
  final repository = KuaforumFeedRepository();
  late Future<_BusinessProfileData> data;
  late Future<String> joinCode;
  bool logoBusy = false;

  Future<_BusinessProfileData> load() async {
    final business = await repository.fetchOwnedBusinessProfile();
    final id = business['id'] as String;
    joinCode = repository.fetchMyBusinessJoinCode(id);
    final values = await Future.wait([
      repository.fetchSocialStats(businessId: id),
      repository.fetchProfilePosts(businessId: id),
    ]);
    return _BusinessProfileData(
      business,
      values[0] as Map<String, int>,
      values[1] as List<KuaforumFeedPost>,
    );
  }

  @override
  void initState() {
    super.initState();
    data = load();
  }

  Future<void> chooseLogo() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
    );
    if (picked == null || !mounted) return;
    setState(() => logoBusy = true);
    try {
      await repository.uploadBusinessLogo(File(picked.path));
      if (!mounted) return;
      final next = load();
      setState(() => data = next);
      await next;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İşletme fotoğrafı güncellendi.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İşletme fotoğrafı yüklenemedi: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => logoBusy = false);
    }
  }

  void open(BuildContext context, String section) {
    final page = switch (section) {
      'Randevu Yönetimi' => const OwnerAppointments(),
      'Müşterilerim' => const CustomersPage(),
      'Bildirimler' => const NotificationsPage(),
      _ => const SettingsPage(),
    };
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(section, style: const TextStyle(color: wine, fontWeight: FontWeight.bold))),
        body: page,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_BusinessProfileData>(
    future: data,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator(color: wine));
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return const _FeedMessage(
          icon: Icons.store_mall_directory_outlined,
          title: 'İşletme profili yüklenemedi',
          detail: 'İşletme bilgilerini şu anda görüntüleyemiyoruz.',
        );
      }
      final value = snapshot.data!;
      final businessId = value.business['id'] as String;
      final name = value.business['name'] as String? ?? 'İşletmem';
      final address = value.business['address'] as String? ?? '';
      return RefreshIndicator(
        color: wine,
        onRefresh: () async {
          final next = load();
          setState(() => data = next);
          await next;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            Center(child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: blush,
                    borderRadius: BorderRadius.circular(28),
                    image: (value.business['logo_url'] as String?)?.isNotEmpty == true
                        ? DecorationImage(
                            image: NetworkImage(value.business['logo_url'] as String),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (value.business['logo_url'] as String?)?.isNotEmpty == true
                      ? null
                      : const Icon(Icons.storefront, size: 48, color: wine),
                ),
                Positioned(
                  right: -5,
                  bottom: -5,
                  child: IconButton.filled(
                    onPressed: logoBusy ? null : chooseLogo,
                    style: IconButton.styleFrom(
                      backgroundColor: wine,
                      foregroundColor: Colors.white,
                      fixedSize: const Size(34, 34),
                      minimumSize: const Size(34, 34),
                      padding: EdgeInsets.zero,
                    ),
                    icon: logoBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.camera_alt_rounded, size: 17),
                  ),
                ),
              ],
            )),
            const SizedBox(height: 10),
            Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: ink)),
            Text(
              address.isEmpty ? 'İşletme hesabı' : address,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted),
            ),
            const SectionTitle('Müşteri Katılım Kodu'),
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: blush),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: FutureBuilder<String>(
                  future: joinCode,
                  builder: (context, codeSnapshot) {
                    if (codeSnapshot.connectionState == ConnectionState.waiting) {
                      return const Row(children: [
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: wine)),
                        SizedBox(width: 10),
                        Text('Katılım kodu yükleniyor...', style: TextStyle(color: muted)),
                      ]);
                    }
                    if (codeSnapshot.hasError || !codeSnapshot.hasData) {
                      return const Text(
                        'İşletmen onaylandıktan sonra müşterilerin kullanacağı kod burada görünecek.',
                        style: TextStyle(color: muted, fontSize: 12),
                      );
                    }
                    final code = codeSnapshot.data!;
                    return Row(children: [
                      const Icon(Icons.qr_code_2_rounded, color: wine, size: 28),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('İşletme kodun', style: TextStyle(color: muted, fontSize: 11)),
                          Text(code, style: const TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 2)),
                        ],
                      )),
                      IconButton(
                        tooltip: 'Kodu kopyala',
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: code));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Katılım kodu kopyalandı.')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, color: wine),
                      ),
                    ]);
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _ProfileMetric(value.stats['posts'] ?? 0, 'Gönderi'),
              _ProfileMetric(
                value.stats['followers'] ?? 0,
                'Takipçi',
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => FollowListPage(
                    profileId: businessId,
                    mode: 'followers',
                    businessProfile: true,
                  ),
                )),
              ),
            ]),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => BusinessProfilePage(businessId: businessId),
              )),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Müşterilerin gördüğü profili aç'),
              style: OutlinedButton.styleFrom(foregroundColor: wine),
            ),
            const SectionTitle('İşletme Yönetimi'),
            ...[
              'Randevu Yönetimi',
              'Müşterilerim',
              'İşletme Ayarları',
              'Bildirimler',
            ].map((section) => Card(
              color: Colors.white,
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.circle_outlined, color: wine),
                title: Text(section, style: const TextStyle(color: ink, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right, color: muted),
                onTap: () => open(context, section),
              ),
            )),
            const SectionTitle('Salon paylaşımları'),
            if (value.posts.isEmpty)
              const _FeedMessage(
                icon: Icons.photo_library_outlined,
                title: 'Henüz paylaşım yok',
                detail: 'Salonunun paylaşımları burada görünecek.',
              )
            else
              ...value.posts.map((post) => LiveFeedPostCard(
                post: post,
                repository: repository,
              )),
            const SectionTitle('Hesap'),
            Card(
              color: Colors.white,
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.logout, color: wine),
                title: const Text('Çıkış yap', style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
                onTap: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const RolePicker()),
                    (_) => false,
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
class _EmployeeManagementData {
  final String businessId;
  final List<Map<String, dynamic>> employees;
  const _EmployeeManagementData(this.businessId, this.employees);
}

class EmployeeManagementPage extends StatefulWidget {
  const EmployeeManagementPage({super.key});

  @override
  State<EmployeeManagementPage> createState() => _EmployeeManagementPageState();
}

class _EmployeeManagementPageState extends State<EmployeeManagementPage> {
  final repository = KuaforumFeedRepository();
  late Future<_EmployeeManagementData> data;

  @override
  void initState() {
    super.initState();
    data = load();
  }

  Future<_EmployeeManagementData> load() async {
    final business = await repository.fetchOwnedBusinessProfile();
    final businessId = business['id'] as String;
    final employees = await repository.fetchOwnedEmployees(businessId);
    return _EmployeeManagementData(businessId, employees);
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => data = next);
    await next;
  }

  Future<void> addEmployee(String businessId) async {
    final nameController = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Çalışan davet et'),
        content: TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Ad soyad',
            hintText: 'Örn. Elif Demir',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Davet oluştur')),
        ],
      ),
    );
    final name = nameController.text.trim();
    nameController.dispose();
    if (accepted != true || name.isEmpty || !mounted) return;
    try {
      final code = await repository.createEmployeeInvite(
        businessId: businessId,
        displayName: name,
      );
      if (!mounted) return;
      await refresh();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Çalışan daveti hazır'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Bu kodu çalışanına ilet. Çalışan kendi hesabında davet kodunu kullanarak işletmene bağlanabilir.'),
            const SizedBox(height: 14),
            SelectableText(
              code,
              style: const TextStyle(color: wine, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
              icon: const Icon(Icons.copy),
              label: const Text('Kodu kopyala'),
            ),
          ]),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Tamam')),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Davet oluşturulamadı: $error')),
        );
      }
    }
  }

  Future<void> toggleEmployee(Map<String, dynamic> employee) async {
    final active = employee['is_active'] == true;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(active ? 'Çalışanı pasifleştir?' : 'Çalışanı aktifleştir?'),
        content: Text(active
            ? 'Bu çalışan yeni randevu ve paylaşım işlemlerinde kullanılamaz.'
            : 'Bu çalışan tekrar aktif olacak.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: wine),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await repository.setEmployeeActive(employee['id'] as String, !active);
      await refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Çalışan durumu değiştirilemedi: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_EmployeeManagementData>(
    future: data,
    builder: (context, snapshot) => RefreshIndicator(
      color: wine,
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          const Text('Çalışanlar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 5),
          const Text('Çalışanlarını davet et ve hesap bağlantılarını yönet.', style: TextStyle(color: muted)),
          const SizedBox(height: 14),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Padding(padding: EdgeInsets.all(26), child: Center(child: CircularProgressIndicator(color: wine)))
          else if (snapshot.hasError)
            _FeedMessage(
              icon: Icons.groups_outlined,
              title: 'Çalışanlar yüklenemedi',
              detail: 'İşletme hesabının bağlantısını kontrol et.',
              action: 'Yeniden dene',
              onPressed: refresh,
            )
          else ...[
            FilledButton.icon(
              onPressed: () => addEmployee(snapshot.data!.businessId),
              style: FilledButton.styleFrom(backgroundColor: wine, padding: const EdgeInsets.symmetric(vertical: 13)),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Çalışan davet et'),
            ),
            const SizedBox(height: 12),
            if (snapshot.data!.employees.isEmpty)
              const _FeedMessage(
                icon: Icons.group_add_outlined,
                title: 'Henüz çalışan eklenmemiş',
                detail: 'Davet oluşturarak çalışanını işletmene bağlayabilirsin.',
              )
            else
              ...snapshot.data!.employees.map((employee) {
                final inviteRows = employee['employee_invites'];
                final invite = inviteRows is List && inviteRows.isNotEmpty
                    ? Map<String, dynamic>.from(inviteRows.first as Map)
                    : <String, dynamic>{};
                final claimed = employee['user_id'] != null;
                final active = employee['is_active'] == true;
                final code = invite['invite_code'] as String?;
                final expires = DateTime.tryParse(invite['expires_at'] as String? ?? '')?.toLocal();
                final expired = expires != null && expires.isBefore(DateTime.now());
                final subtitle = !active
                    ? 'Pasif çalışan'
                    : claimed
                        ? 'Hesap bağlandı'
                        : expired
                            ? 'Davet kodunun süresi dolmuş'
                            : 'Davet bekleniyor${code == null ? '' : ' • $code'}';
                return Card(
                  color: Colors.white,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: blush),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: blush,
                      child: Icon(Icons.person_outline, color: wine),
                    ),
                    title: Text(employee['display_name'] as String? ?? 'Çalışan', style: const TextStyle(color: ink, fontWeight: FontWeight.w800)),
                    subtitle: Text(subtitle, style: const TextStyle(color: muted, fontSize: 11)),
                    trailing: PopupMenuButton<String>(
                      onSelected: (_) => toggleEmployee(employee),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(active ? 'Pasifleştir' : 'Aktifleştir'),
                        ),
                      ],
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

class _ServicesData {
  final String businessId;
  final List<Map<String, dynamic>> services;
  const _ServicesData(this.businessId, this.services);
}

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  final repository = KuaforumFeedRepository();
  late Future<_ServicesData> data;

  @override
  void initState() {
    super.initState();
    data = load();
  }

  Future<_ServicesData> load() async {
    final business = await repository.fetchOwnedBusinessProfile();
    final businessId = business['id'] as String;
    final services = await repository.fetchBusinessServices(businessId);
    return _ServicesData(businessId, services);
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => data = next);
    await next;
  }

  Future<void> editService({Map<String, dynamic>? service}) async {
    final nameController = TextEditingController(text: service?['name'] as String? ?? '');
    final priceController = TextEditingController(
      text: service == null ? '' : (service['price'] as num).toStringAsFixed(0),
    );
    int duration = service?['duration_minutes'] as int? ?? 30;
    bool active = service?['is_active'] as bool? ?? true;
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(service == null ? 'Yeni hizmet ekle' : 'Hizmeti düzenle'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Hizmet adı'),
                validator: (value) => value == null || value.trim().isEmpty ? 'Hizmet adı gerekli' : null,
              ),
              TextFormField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Fiyat (₺)'),
                validator: (value) {
                  final price = double.tryParse((value ?? '').replaceAll(',', '.'));
                  return price == null || price < 0 ? 'Geçerli fiyat gir' : null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: duration,
                decoration: const InputDecoration(labelText: 'Süre'),
                items: const [15, 30, 45, 60, 90, 120].map((minutes) => DropdownMenuItem(
                  value: minutes,
                  child: Text('$minutes dakika'),
                )).toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => duration = value);
                },
              ),
              if (service != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hizmet aktif'),
                  value: active,
                  onChanged: (value) => setDialogState(() => active = value),
                ),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(dialogContext, true);
                }
              },
              style: FilledButton.styleFrom(backgroundColor: wine),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted) {
      nameController.dispose();
      priceController.dispose();
      return;
    }
    try {
      final price = double.parse(priceController.text.replaceAll(',', '.'));
      if (service == null) {
        final value = await data;
        await repository.createBusinessService(
          businessId: value.businessId,
          name: nameController.text,
          price: price,
          durationMinutes: duration,
        );
      } else {
        await repository.updateBusinessService(
          serviceId: service['id'] as String,
          name: nameController.text,
          price: price,
          durationMinutes: duration,
          isActive: active,
        );
      }
      await refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hizmet kaydedilemedi: $error')),
        );
      }
    } finally {
      nameController.dispose();
      priceController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_ServicesData>(
    future: data,
    builder: (context, snapshot) => RefreshIndicator(
      color: wine,
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          const Text('Hizmetler', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 5),
          const Text('Salonunda sunduğun hizmetleri, fiyatları ve süreleri düzenle.', style: TextStyle(color: muted)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: snapshot.hasData ? () => editService() : null,
            style: FilledButton.styleFrom(backgroundColor: wine, padding: const EdgeInsets.symmetric(vertical: 13)),
            icon: const Icon(Icons.add),
            label: const Text('Yeni hizmet ekle'),
          ),
          const SizedBox(height: 12),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: wine)))
          else if (snapshot.hasError)
            _FeedMessage(
              icon: Icons.content_cut,
              title: 'Hizmetler yüklenemedi',
              detail: 'İşletme hesabının bağlantısını kontrol et.',
              action: 'Yeniden dene',
              onPressed: refresh,
            )
          else if (snapshot.data!.services.isEmpty)
            const _FeedMessage(
              icon: Icons.add_business_outlined,
              title: 'Henüz hizmet eklenmemiş',
              detail: 'Müşterilerin randevu alabilmesi için önce hizmetlerini ekle.',
            )
          else
            ...snapshot.data!.services.map((service) {
              final active = service['is_active'] == true;
              final price = service['price'] as num? ?? 0;
              final duration = service['duration_minutes'] as int? ?? 30;
              return Card(
                color: Colors.white,
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: blush),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: blush,
                    child: Icon(Icons.content_cut, color: active ? wine : muted),
                  ),
                  title: Text(
                    service['name'] as String? ?? 'Hizmet',
                    style: TextStyle(color: active ? ink : muted, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('$duration dk • ${price.toStringAsFixed(0)} ₺', style: const TextStyle(color: muted)),
                  trailing: IconButton(
                    onPressed: () => editService(service: service),
                    icon: const Icon(Icons.edit_outlined, color: wine),
                  ),
                ),
              );
            }),
        ],
      ),
    ),
  );
}

class _OwnerHomeData {
  final Map<String, dynamic> business;
  final List<Map<String, dynamic>> appointments;
  final int customerCount;
  const _OwnerHomeData(this.business, this.appointments, this.customerCount);
}

class OwnerHome extends StatefulWidget {
  const OwnerHome({super.key});
  @override State<OwnerHome> createState() => _OwnerHomeState();
}

class _OwnerHomeState extends State<OwnerHome> {
  final repository = KuaforumFeedRepository();
  late Future<_OwnerHomeData> data;
  @override void initState() { super.initState(); data = load(); }
  Future<_OwnerHomeData> load() async {
    final business = await repository.fetchOwnedBusinessProfile();
    final id = business['id'] as String;
    final results = await Future.wait([repository.fetchBusinessAppointments(id, mineOnly: false), repository.fetchBusinessCustomers(id)]);
    return _OwnerHomeData(business, results[0] as List<Map<String, dynamic>>, (results[1] as List<Map<String, dynamic>>).length);
  }
  Future<void> refresh() async { final next = load(); setState(() => data = next); await next; }
  String appointmentTime(Map<String, dynamic> row) {
    final value = DateTime.tryParse(row['starts_at']?.toString() ?? '');
    if (value == null) return 'Saat bilgisi yok';
    final local = value.toLocal(); final now = DateTime.now();
    final day = DateTime(local.year, local.month, local.day); final today = DateTime(now.year, now.month, now.day);
    final prefix = day == today ? 'Bugün' : day == today.add(const Duration(days: 1)) ? 'Yarın' : local.day.toString().padLeft(2, '0') + '.' + local.month.toString().padLeft(2, '0');
    return prefix + ' • ' + local.hour.toString().padLeft(2, '0') + ':' + local.minute.toString().padLeft(2, '0');
  }
  @override Widget build(BuildContext context) => FutureBuilder<_OwnerHomeData>(
    future: data,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: wine));
      if (snapshot.hasError) return PageBody(children: [const Text('İşletme Yönetimi', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 12), _FeedMessage(icon: Icons.storefront_outlined, title: 'İşletme bilgileri yüklenemedi', detail: 'İşletme hesabını ve bağlantını kontrol et.', action: 'Yeniden dene', onPressed: refresh)]);
      final value = snapshot.data!; final now = DateTime.now();
      final todayCount = value.appointments.where((row) { final start = DateTime.tryParse(row['starts_at']?.toString() ?? '')?.toLocal(); return start != null && start.year == now.year && start.month == now.month && start.day == now.day && row['status'] != 'cancelled'; }).length;
      final upcoming = value.appointments.where((row) { final start = DateTime.tryParse(row['starts_at']?.toString() ?? ''); return start != null && start.isAfter(DateTime.now()) && row['status'] != 'cancelled' && row['status'] != 'completed' && row['status'] != 'no_show'; }).toList()..sort((a,b) => DateTime.parse(a['starts_at'].toString()).compareTo(DateTime.parse(b['starts_at'].toString())));
      final businessName = value.business['name'] as String? ?? 'İşletmem'; final address = value.business['address'] as String? ?? 'İşletme bilgilerini yönet';
      return RefreshIndicator(color: wine, onRefresh: refresh, child: ListView(padding: const EdgeInsets.fromLTRB(18,10,18,24), children: [
        const Text('İşletme Yönetimi', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 14),
        HeroPanel(
          eyebrow: 'İşletme paneli',
          title: businessName,
          subtitle: address.isEmpty ? 'İşletmeni, ekibini ve müşteri deneyimini yönet.' : address,
          icon: Icons.storefront,
          button: 'Ayarları aç',
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('İşletme Ayarları', style: TextStyle(color: wine, fontWeight: FontWeight.w800))),
              body: const SettingsPage(),
            ),
          )),
        ),
        const SizedBox(height: 14), Row(children: [_StatCard(todayCount.toString(), 'Bugünkü Randevu'), _StatCard(value.appointments.length.toString(), 'Toplam Randevu'), _StatCard(value.customerCount.toString(), 'Müşteri')]),
        const SectionTitle('Yaklaşan Randevular'),
        if (upcoming.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Yaklaşan randevu bulunmuyor.', style: TextStyle(color: muted)))
        else ...upcoming.take(3).map((row) => AppointmentTile(name: row['customer_name']?.toString() ?? 'Müşteri', service: row['service_name']?.toString() ?? 'Hizmet', time: appointmentTime(row), status: row['status'] == 'pending' ? 'Onay bekliyor' : row['status'] == 'confirmed' ? 'Onaylandı' : row['status']?.toString() ?? 'Aktif')),
        const SectionTitle('Hızlı Yönetim'), const QuickTiles(ownerMode: true),
      ]));
    },
  );
}
class _OwnerAppointmentData {
  final String businessId;
  final String? ownerEmployeeId;
  final List<Map<String, dynamic>> appointments;
  const _OwnerAppointmentData(this.businessId, this.ownerEmployeeId, this.appointments);
}

class OwnerAppointments extends StatefulWidget {
  const OwnerAppointments({super.key});

  @override
  State<OwnerAppointments> createState() => _OwnerAppointmentsState();
}

class _OwnerAppointmentsState extends State<OwnerAppointments> {
  final repository = KuaforumFeedRepository();
  late Future<_OwnerAppointmentData> data;
  String selectedFilter = 'Tümü';

  @override
  void initState() {
    super.initState();
    data = load();
  }

  Future<_OwnerAppointmentData> load() async {
    final business = await repository.fetchOwnedBusinessProfile();
    final businessId = business['id'] as String;
    String? ownerEmployeeId;
    try {
      final employee = await repository.fetchMyEmployeeContext();
      if (employee['business_id'] == businessId) {
        ownerEmployeeId = employee['id'] as String;
      }
    } catch (_) {}
    final appointments = await repository.fetchBusinessAppointments(
      businessId,
      mineOnly: false,
    );
    return _OwnerAppointmentData(businessId, ownerEmployeeId, appointments);
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => data = next);
    await next;
  }

  bool matchesFilter(Map<String, dynamic> row) {
    final status = row['status'] as String? ?? '';
    if (selectedFilter == 'Bekleyen') return status == 'pending';
    if (selectedFilter == 'Onaylanan') return status == 'confirmed';
    if (selectedFilter == 'Tamamlanan') return status == 'completed';
    return true;
  }

  Future<void> performAction(String id, String action) async {
    try {
      if (action == 'approve' || action == 'reject') {
        await repository.reviewAppointmentRequest(id, approve: action == 'approve');
      } else if (action == 'complete' || action == 'no_show') {
        await repository.updateAppointmentStatus(id, status: action == 'complete' ? 'completed' : 'no_show');
      } else if (action == 'cancel') {
        await repository.cancelAppointment(id);
      }
      await refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Randevu işlemi tamamlanamadı: $error')),
        );
      }
    }
  }

  Widget appointmentCard(Map<String, dynamic> row) => _BusinessAppointmentCard(
    appointment: row,
    ownerMode: true,
    onComplete: () => performAction(row['appointment_id'] as String, 'complete'),
    onNoShow: () => performAction(row['appointment_id'] as String, 'no_show'),
    onCancel: () => performAction(row['appointment_id'] as String, 'cancel'),
    onApprove: () => performAction(row['appointment_id'] as String, 'approve'),
    onReject: () => performAction(row['appointment_id'] as String, 'reject'),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<_OwnerAppointmentData>(
    future: data,
    builder: (context, snapshot) => RefreshIndicator(
      color: wine,
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          const Text('Randevu Yönetimi', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 12),
          Wrap(spacing: 7, children: ['Tümü', 'Bekleyen', 'Onaylanan', 'Tamamlanan'].map((filter) => ChoiceChip(
            label: Text(filter),
            selected: selectedFilter == filter,
            onSelected: (_) => setState(() => selectedFilter = filter),
            selectedColor: blush,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(color: selectedFilter == filter ? wine : muted, fontWeight: FontWeight.w700, fontSize: 11),
            side: const BorderSide(color: blush),
          )).toList()),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: wine)))
          else if (snapshot.hasError)
            _FeedMessage(
              icon: Icons.calendar_month_outlined,
              title: 'Randevular yüklenemedi',
              detail: 'İşletme hesabının bağlantısını kontrol et.',
              action: 'Yeniden dene',
              onPressed: refresh,
            )
          else ...[
            Builder(builder: (context) {
              final value = snapshot.data!;
              final visible = value.appointments.where(matchesFilter).toList();
              final mine = value.ownerEmployeeId == null
                  ? <Map<String, dynamic>>[]
                  : visible.where((row) => row['employee_id'] == value.ownerEmployeeId).toList();
              final employeeAppointments = value.ownerEmployeeId == null
                  ? visible
                  : visible.where((row) => row['employee_id'] != value.ownerEmployeeId).toList();
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionTitle('Benim Randevularım'),
                if (mine.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text('Henüz sana atanmış randevu yok.', style: TextStyle(color: muted, fontSize: 12)),
                  )
                else
                  ...mine.map(appointmentCard),
                const SectionTitle('Çalışan Randevuları'),
                if (employeeAppointments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text('Bu filtrede çalışan randevusu bulunmuyor.', style: TextStyle(color: muted, fontSize: 12)),
                  )
                else
                  ...employeeAppointments.map(appointmentCard),
              ]);
            }),
          ],
        ],
      ),
    ),
  );
}

class _CustomersData {
  final String businessId;
  final List<Map<String, dynamic>> customers;
  const _CustomersData(this.businessId, this.customers);
}

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final repository = KuaforumFeedRepository();
  final searchController = TextEditingController();
  late Future<_CustomersData> data;

  @override
  void initState() {
    super.initState();
    data = load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<_CustomersData> load() async {
    final business = await repository.fetchOwnedBusinessProfile();
    final businessId = business['id'] as String;
    final customers = await repository.fetchBusinessCustomers(businessId);
    return _CustomersData(businessId, customers);
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => data = next);
    await next;
  }

  Future<void> toggleBlacklist(
    String businessId,
    Map<String, dynamic> customer,
  ) async {
    final currentlyBlocked = customer['is_blacklisted'] == true;
    final reasonController = TextEditingController(
      text: customer['blacklist_reason'] as String? ?? '',
    );
    bool? accepted;
    if (!currentlyBlocked) {
      accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Müşteriyi kara listeye al'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Not (isteğe bağlı)',
              hintText: 'Örn. tekrarlanan randevuya gelmeme',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: wine),
              child: const Text('Kara listeye al'),
            ),
          ],
        ),
      );
    } else {
      accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Kara listeden çıkar?'),
          content: const Text('Bu müşteri yeni randevu taleplerinde tekrar normal şekilde işlem yapabilir.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: wine),
              child: const Text('Listeden çıkar'),
            ),
          ],
        ),
      );
    }
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (accepted != true || !mounted) return;
    try {
      await repository.setCustomerBlacklist(
        businessId: businessId,
        customerId: customer['customer_id'] as String,
        blocked: !currentlyBlocked,
        reason: reason,
      );
      await refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kara liste güncellenemedi: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_CustomersData>(
    future: data,
    builder: (context, snapshot) => RefreshIndicator(
      color: wine,
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          const Text('Müşterilerim', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 5),
          const Text('İşletmene katılan müşterileri ve randevu geçmişlerini yönet.', style: TextStyle(color: muted)),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Müşteri adı veya telefon ara...',
              prefixIcon: const Icon(Icons.search, color: wine),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: blush)),
            ),
          ),
          const SectionTitle('Müşteri Listesi'),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator(color: wine)))
          else if (snapshot.hasError)
            _FeedMessage(
              icon: Icons.people_outline,
              title: 'Müşteriler yüklenemedi',
              detail: 'İşletme hesabının bağlantısını kontrol et.',
              action: 'Yeniden dene',
              onPressed: refresh,
            )
          else ...[
            Builder(builder: (context) {
              final query = searchController.text.trim().toLowerCase();
              final rows = snapshot.data!.customers.where((customer) {
                final name = (customer['full_name'] as String? ?? '').toLowerCase();
                final phone = (customer['phone'] as String? ?? '').toLowerCase();
                return query.isEmpty || name.contains(query) || phone.contains(query);
              }).toList();
              if (rows.isEmpty) {
                return const _FeedMessage(
                  icon: Icons.person_search_outlined,
                  title: 'Müşteri bulunamadı',
                  detail: 'İşletmene katılan müşteriler burada listelenir.',
                );
              }
              return Column(children: rows.map((customer) {
                final name = customer['full_name'] as String? ?? 'Kuaförüm kullanıcısı';
                final phone = customer['phone'] as String? ?? 'Telefon eklenmemiş';
                final count = customer['appointment_count'] as int? ?? 0;
                final noShows = customer['no_show_count'] as int? ?? 0;
                final blocked = customer['is_blacklisted'] == true;
                final lastAppointment = customer['last_appointment_at'] as String?;
                return Card(
                  color: Colors.white,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: blocked ? wine.withOpacity(.45) : blush),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      Row(children: [
                        const CircleAvatar(
                          backgroundColor: blush,
                          child: Icon(Icons.person_outline, color: wine),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(color: ink, fontWeight: FontWeight.w800)),
                            Text(phone, style: const TextStyle(color: muted, fontSize: 11)),
                          ],
                        )),
                        if (blocked)
                          const Badge(label: Text('Kara listede'), backgroundColor: wine),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: Text('Randevu: $count', style: const TextStyle(color: muted, fontSize: 11))),
                        Expanded(child: Text('Gelmedi: $noShows', style: TextStyle(
                          color: noShows >= 3 ? wine : muted,
                          fontWeight: noShows >= 3 ? FontWeight.w800 : FontWeight.normal,
                          fontSize: 11,
                        ))),
                      ]),
                      if (lastAppointment != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Son randevu: ${_appointmentDateLabel(lastAppointment)}', style: const TextStyle(color: muted, fontSize: 10)),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => toggleBlacklist(snapshot.data!.businessId, customer),
                          icon: Icon(blocked ? Icons.remove_circle_outline : Icons.block, size: 17),
                          label: Text(blocked ? 'Kara listeden çıkar' : 'Kara listeye al'),
                          style: TextButton.styleFrom(foregroundColor: wine),
                        ),
                      ),
                    ]),
                  ),
                );
              }).toList());
            }),
          ],
        ],
      ),
    ),
  );
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final repository = KuaforumFeedRepository();
  late Future<List<Map<String, dynamic>>> notifications;

  @override
  void initState() {
    super.initState();
    notifications = repository.fetchNotifications();
  }

  Future<void> refresh() async {
    final next = repository.fetchNotifications();
    setState(() => notifications = next);
    await next;
  }

  Future<void> markRead(String id) async {
    try {
      await repository.markNotificationRead(id);
      if (!mounted) return;
      await refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bildirim güncellenemedi: $error')),
        );
      }
    }
  }

  Future<void> markAllRead() async {
    try {
      await repository.markAllNotificationsRead();
      if (!mounted) return;
      await refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bildirimler güncellenemedi: $error')),
        );
      }
    }
  }

  String dateLabel(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: notifications,
    builder: (context, snapshot) => RefreshIndicator(
      color: wine,
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          Row(children: [
            const Expanded(child: Text('Bildirimler', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink))),
            if ((snapshot.data ?? []).any((row) => row['read_at'] == null))
              TextButton(
                onPressed: markAllRead,
                child: const Text('Tümünü okundu işaretle', style: TextStyle(color: wine, fontSize: 11)),
              ),
          ]),
          const SizedBox(height: 10),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator(color: wine)))
          else if (snapshot.hasError)
            _FeedMessage(
              icon: Icons.notifications_off_outlined,
              title: 'Bildirimler yüklenemedi',
              detail: 'Bağlantını kontrol edip tekrar dene.',
              action: 'Yeniden dene',
              onPressed: refresh,
            )
          else if ((snapshot.data ?? []).isEmpty)
            const _FeedMessage(
              icon: Icons.notifications_none,
              title: 'Henüz bildirimin yok',
              detail: 'Randevu ve hesap hareketlerin burada görünecek.',
            )
          else
            ...snapshot.data!.map((row) {
              final unread = row['read_at'] == null;
              return Card(
                color: unread ? const Color(0xFFFFF7F7) : Colors.white,
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: blush),
                ),
                child: ListTile(
                  onTap: () async {
                    await showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: Text(row['title'] as String? ?? 'Bildirim'),
                        content: Text(row['body'] as String? ?? ''),
                        actions: [
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: FilledButton.styleFrom(backgroundColor: wine),
                            child: const Text('Tamam'),
                          ),
                        ],
                      ),
                    );
                    if (unread && mounted) await markRead(row['id'] as String);
                  },
                  leading: CircleAvatar(
                    backgroundColor: blush,
                    child: Icon(
                      unread ? Icons.notifications_active_outlined : Icons.notifications_none,
                      color: wine,
                    ),
                  ),
                  title: Text(
                    row['title'] as String? ?? 'Bildirim',
                    style: TextStyle(color: ink, fontWeight: unread ? FontWeight.w800 : FontWeight.w600),
                  ),
                  subtitle: Text(
                    row['body'] as String? ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                  trailing: unread
                      ? const CircleAvatar(radius: 4, backgroundColor: wine)
                      : null,
                  isThreeLine: true,
                ),
              );
            }),
        ],
      ),
    ),
  );
}

class _WorkHoursData {
  final String businessId;
  final List<Map<String, dynamic>> hours;
  const _WorkHoursData(this.businessId, this.hours);
}

class WorkHoursPage extends StatefulWidget {
  const WorkHoursPage({super.key});

  @override
  State<WorkHoursPage> createState() => _WorkHoursPageState();
}

class _WorkHoursPageState extends State<WorkHoursPage> {
  final repository = KuaforumFeedRepository();
  late Future<_WorkHoursData> data;
  final Set<int> savingDays = {};

  static const weekdays = [
    'Pazar',
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
  ];

  List<String> get timeOptions => List.generate(35, (index) {
    final totalMinutes = 6 * 60 + index * 30;
    final hour = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minute = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  });

  @override
  void initState() {
    super.initState();
    data = load();
  }

  Future<_WorkHoursData> load() async {
    final business = await repository.fetchOwnedBusinessProfile();
    final businessId = business['id'] as String;
    final hours = await repository.fetchBusinessHours(businessId);
    return _WorkHoursData(businessId, hours);
  }

  Future<void> saveDay(
    String businessId,
    Map<String, dynamic> row, {
    String? opensAt,
    String? closesAt,
    bool? isClosed,
  }) async {
    final weekday = row['weekday'] as int;
    if (savingDays.contains(weekday)) return;
    setState(() => savingDays.add(weekday));
    try {
      await repository.saveBusinessHours(
        businessId: businessId,
        weekday: weekday,
        opensAt: opensAt ?? (row['opens_at'] as String).substring(0, 5) + ':00',
        closesAt: closesAt ?? (row['closes_at'] as String).substring(0, 5) + ':00',
        isClosed: isClosed ?? row['is_closed'] == true,
      );
      if (mounted) setState(() => data = load());
    } catch (error) {
      if (mounted) {
        setState(() => data = load());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Çalışma saati kaydedilemedi: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => savingDays.remove(weekday));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_WorkHoursData>(
    future: data,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator(color: wine));
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return const _FeedMessage(
          icon: Icons.schedule,
          title: 'Çalışma saatleri yüklenemedi',
          detail: 'İşletme bağlantısını kontrol edip tekrar dene.',
        );
      }
      final value = snapshot.data!;
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          const Text('Çalışma Saatleri', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 5),
          const Text('Salonunun haftalık açık olduğu saatleri belirle.', style: TextStyle(color: muted)),
          const SizedBox(height: 14),
          ...value.hours.map((row) {
            final weekday = row['weekday'] as int;
            final closed = row['is_closed'] == true;
            final opens = (row['opens_at'] as String).substring(0, 5);
            final closes = (row['closes_at'] as String).substring(0, 5);
            final busy = savingDays.contains(weekday);
            return Card(
              color: Colors.white,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: blush),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 8, 13, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(weekdays[weekday], style: const TextStyle(color: ink, fontWeight: FontWeight.w800)),
                    subtitle: Text(closed ? 'Kapalı' : 'Açık', style: const TextStyle(color: muted, fontSize: 11)),
                    value: !closed,
                    activeThumbColor: wine,
                    onChanged: busy ? null : (open) => saveDay(value.businessId, row, isClosed: !open),
                  ),
                  if (!closed) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(child: DropdownButtonFormField<String>(
                        value: opens,
                        decoration: const InputDecoration(
                          labelText: 'Açılış',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: timeOptions.map((time) => DropdownMenuItem(value: time, child: Text(time))).toList(),
                        onChanged: busy ? null : (time) {
                          if (time != null) saveDay(value.businessId, row, opensAt: '$time:00');
                        },
                      )),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('–', style: TextStyle(color: muted, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(child: DropdownButtonFormField<String>(
                        value: closes,
                        decoration: const InputDecoration(
                          labelText: 'Kapanış',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: timeOptions.map((time) => DropdownMenuItem(value: time, child: Text(time))).toList(),
                        onChanged: busy ? null : (time) {
                          if (time != null) saveDay(value.businessId, row, closesAt: '$time:00');
                        },
                      )),
                    ]),
                  ],
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(color: wine),
                    ),
                ]),
              ),
            );
          }),
        ],
      );
    },
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final repository = KuaforumFeedRepository();
  late Future<Map<String, dynamic>> business;
  int? savingInterval;
  bool savingBusinessProfile = false;

  @override
  void initState() {
    super.initState();
    business = repository.fetchOwnedBusinessProfile();
  }

  Future<void> editBusinessProfile(Map<String, dynamic> value) async {
    final nameController = TextEditingController(text: value['name']?.toString() ?? '');
    final addressController = TextEditingController(text: value['address']?.toString() ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('İşletme bilgilerini düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'İşletme adı'),
            ),
            TextField(
              controller: addressController,
              maxLength: 180,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Adres'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: wine),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    final name = nameController.text.trim();
    final address = addressController.text.trim();
    nameController.dispose();
    addressController.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => savingBusinessProfile = true);
    try {
      await repository.updateOwnedBusinessProfile(
        businessId: value['id'] as String,
        name: name,
        address: address,
      );
      if (!mounted) return;
      setState(() => business = repository.fetchOwnedBusinessProfile());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İşletme bilgileri güncellendi.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İşletme bilgileri kaydedilemedi: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => savingBusinessProfile = false);
    }
  }

  Future<void> updateInterval(String businessId, int minutes) async {
    setState(() => savingInterval = minutes);
    try {
      await repository.updateAppointmentInterval(businessId, minutes);
      if (mounted) {
        setState(() => business = repository.fetchOwnedBusinessProfile());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Randevu aralığı $minutes dakika olarak kaydedildi.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Randevu aralığı kaydedilemedi: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => savingInterval = null);
    }
  }

  void openPage(Widget page, String title) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: cream,
        appBar: AppBar(title: Text(title, style: const TextStyle(color: wine, fontWeight: FontWeight.w800))),
        body: page,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: business,
    builder: (context, snapshot) {
      final interval = snapshot.data?['appointment_interval_minutes'] as int? ?? 30;
      final businessId = snapshot.data?['id'] as String?;
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          const Text('Ayarlar', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 5),
          const Text('İşletme ve randevu tercihlerini yönet.', style: TextStyle(color: muted)),
          const SectionTitle('İşletme bilgileri'),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: blush),
            ),
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined, color: wine),
              title: Text(
                snapshot.data?['name']?.toString() ?? 'İşletmem',
                style: const TextStyle(color: ink, fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                snapshot.data?['address']?.toString().isNotEmpty == true
                    ? snapshot.data!['address'].toString()
                    : 'Adres eklenmemiş',
                style: const TextStyle(color: muted),
              ),
              trailing: savingBusinessProfile
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: wine),
                    )
                  : IconButton(
                      tooltip: 'İşletme bilgilerini düzenle',
                      onPressed: snapshot.hasData
                          ? () => editBusinessProfile(snapshot.data!)
                          : null,
                      icon: const Icon(Icons.edit_outlined, color: wine),
                    ),
            ),
          ),
          const SectionTitle('Randevu ayarları'),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: blush)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Randevu aralığı', style: TextStyle(color: ink, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Randevu başlangıç saatleri arasındaki süreyi belirle.', style: TextStyle(color: muted, fontSize: 11)),
                const SizedBox(height: 10),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator(color: wine)
                else if (snapshot.hasError)
                  const Text('İşletme ayarları yüklenemedi.', style: TextStyle(color: muted))
                else
                  Wrap(spacing: 7, runSpacing: 7, children: [10, 15, 20, 30, 45, 60].map((minutes) => ChoiceChip(
                    label: Text('$minutes dk'),
                    selected: interval == minutes,
                    onSelected: businessId == null || savingInterval != null
                        ? null
                        : (_) => updateInterval(businessId, minutes),
                    selectedColor: blush,
                    backgroundColor: cream,
                    labelStyle: TextStyle(color: interval == minutes ? wine : muted, fontWeight: FontWeight.w700),
                    side: const BorderSide(color: blush),
                  )).toList()),
                if (savingInterval != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Kaydediliyor...', style: TextStyle(color: muted, fontSize: 11)),
                  ),
              ]),
            ),
          ),
          const SectionTitle('İşletme yönetimi'),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.content_cut, color: wine),
                title: const Text('Hizmetler', style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
                subtitle: const Text('Hizmet adı, fiyat ve süreleri düzenle'),
                trailing: const Icon(Icons.chevron_right, color: muted),
                onTap: () => openPage(const ServicesPage(), 'Hizmetler'),
              ),
              const Divider(height: 1, color: blush),
              ListTile(
                leading: const Icon(Icons.groups_outlined, color: wine),
                title: const Text('Çalışanlar', style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
                subtitle: const Text('Çalışan hesaplarını ve davetleri yönet'),
                trailing: const Icon(Icons.chevron_right, color: muted),
                onTap: () => openPage(const EmployeeManagementPage(), 'Çalışanlar'),
              ),
              const Divider(height: 1, color: blush),
              ListTile(
                leading: const Icon(Icons.schedule, color: wine),
                title: const Text('Çalışma saatleri', style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
                subtitle: const Text('Haftalık çalışma saatlerini düzenle'),
                trailing: const Icon(Icons.chevron_right, color: muted),
                onTap: () => openPage(const WorkHoursPage(), 'Çalışma Saatleri'),
              ),
            ]),
          ),
          const SectionTitle('Diğer'),
          Card(
            color: Colors.white,
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined, color: wine),
              title: const Text('Bildirimler', style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right, color: muted),
              onTap: () => openPage(const NotificationsPage(), 'Bildirimler'),
            ),
          ),
        ],
      );
    },
  );
}

class _AdminDashboardStats {
  final int businesses;
  final int users;
  final int posts;
  const _AdminDashboardStats(this.businesses, this.users, this.posts);
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  late Future<_AdminDashboardStats> stats;

  @override
  void initState() {
    super.initState();
    stats = load();
  }

  Future<_AdminDashboardStats> load() async {
    final rows = await Supabase.instance.client.rpc('admin_dashboard_stats') as List;
    if (rows.isEmpty) {
      throw const PostgrestException(message: 'Yönetici istatistikleri alınamadı.');
    }
    final row = Map<String, dynamic>.from(rows.first as Map);
    return _AdminDashboardStats(
      (row['business_count'] as num).toInt(),
      (row['user_count'] as num).toInt(),
      (row['post_count'] as num).toInt(),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_AdminDashboardStats>(
    future: stats,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator(color: wine));
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return PageBody(children: [
          const Text('Ana Yönetici', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 12),
          _FeedMessage(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Yönetim verileri yüklenemedi',
            detail: 'Yönetici hesabını ve bağlantıyı kontrol et.',
            action: 'Yeniden dene',
            onPressed: () => setState(() => stats = load()),
          ),
        ]);
      }
      final value = snapshot.data!;
      return PageBody(children: [
        const Text('Ana Yönetici', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 14),
        HeroPanel(
          eyebrow: 'Platform kontrolü',
          title: 'Kuaförüm ekosistemini yönet',
          subtitle: 'İşletmeleri, kullanıcıları ve Keşfet erişimlerini kontrol et.',
          icon: Icons.admin_panel_settings,
          button: 'İşletmeleri yönet',
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('İşletme Yönetimi', style: TextStyle(color: wine, fontWeight: FontWeight.w800))),
              body: const AdminBusinesses(),
            ),
          )),
        ),
        const SizedBox(height: 14),
        Row(children: [
          _StatCard(value.businesses.toString(), 'İşletme'),
          _StatCard(value.users.toString(), 'Kullanıcı'),
          _StatCard(value.posts.toString(), 'Paylaşım'),
        ]),
        const SectionTitle('Yönetim araçları'),
        const Text(
          'İşletme onayları, kullanıcı güvenliği ve Keşfet erişimleri. Ana yönetici hesabında randevu alma veya müşteri ekranları bulunmaz.',
          style: TextStyle(color: muted, height: 1.5),
        ),
        const SectionTitle('Hesap'),
        Card(
          color: Colors.white,
          elevation: 0,
          child: ListTile(
            leading: const Icon(Icons.logout, color: wine),
            title: const Text('Çıkış yap', style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const RolePicker()),
                (_) => false,
              );
            },
          ),
        ),
      ]);
    },
  );
}
class AdminBusinesses extends StatefulWidget {
  const AdminBusinesses({super.key});
  @override
  State<AdminBusinesses> createState() => _AdminBusinessesState();
}

class _AdminBusinessesState extends State<AdminBusinesses> {
  final client = Supabase.instance.client;
  final search = TextEditingController();
  late Future<List<Map<String, dynamic>>> data;
  final Set<String> saving = {};

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

  Future<List<Map<String, dynamic>>> load() async {
    final rows = await client.rpc('admin_list_businesses') as List;
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> changeBusinessStatus(Map<String, dynamic> business) async {
    final id = business['id'] as String;
    final currentStatus = business['status']?.toString() ?? '';
    final activating = currentStatus != 'active';
    if (saving.contains(id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(activating ? 'İşletmeyi onayla?' : 'İşletmeyi askıya al?'),
        content: Text(activating
            ? 'İşletme aktif edilecek ve uygulama özelliklerine erişebilecek.'
            : 'İşletme pasife alınacak. Yeni randevu ve herkese açık akış erişimi durdurulacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: wine),
            child: Text(activating ? 'Onayla' : 'Askıya al'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => saving.add(id));
    try {
      await client.rpc('admin_set_business_status', params: {
        'p_business_id': id,
        'p_status': activating ? 'active' : 'inactive',
      });
      if (!mounted) return;
      setState(() {
        business['status'] = activating ? 'active' : 'inactive';
        saving.remove(id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(activating
            ? 'İşletme onaylandı ve aktif edildi.'
            : 'İşletme askıya alındı.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => saving.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşletme durumu değiştirilemedi: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: data,
    builder: (context, snapshot) => PageBody(children: [
      const Text('İşletme Yönetimi',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 12),
      TextField(
        controller: search,
        decoration: const InputDecoration(
          hintText: 'İşletme ara...',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SectionTitle('İşletmeler'),
      if (snapshot.connectionState == ConnectionState.waiting)
        const Center(child: CircularProgressIndicator(color: wine))
      else if (snapshot.hasError)
        _FeedMessage(
          icon: Icons.store_outlined,
          title: 'İşletmeler yüklenemedi',
          detail: 'Yönetici yetkisini ve bağlantıyı kontrol et.',
          action: 'Yeniden dene',
          onPressed: () => setState(() => data = load()),
        )
      else
        ...snapshot.data!.where((business) =>
          (business['name']?.toString().toLowerCase() ?? '')
              .contains(search.text.trim().toLowerCase())
        ).map((business) {
          final id = business['id'] as String;
          final active = business['status'] == 'active';
          final paid = business['discover_paid'] == true;
          final visible = business['discover_enabled'] == true;
          return Card(
            color: Colors.white,
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: const BorderSide(color: blush),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: blush,
                child: Icon(Icons.store, color: wine),
              ),
              title: Text(
                business['name']?.toString() ?? 'İsimsiz işletme',
                style: const TextStyle(fontWeight: FontWeight.bold, color: ink),
              ),
              subtitle: Text(
                '${business['status'] == 'pending' ? 'Onay bekliyor' : business['status'] == 'rejected' ? 'Reddedildi' : active ? 'Aktif' : 'Askıda'}'
                ' • ${paid ? 'Keşfet hakkı var' : 'Keşfet hakkı yok'}'
                ' • ${visible ? 'Keşfet açık' : 'Keşfet kapalı'}',
              ),
              trailing: saving.contains(id)
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: wine),
                    )
                  : IconButton(
                      tooltip: active ? 'İşletmeyi askıya al' : 'İşletmeyi onayla',
                      onPressed: () => changeBusinessStatus(business),
                      icon: Icon(
                        active ? Icons.pause_circle_outline : Icons.check_circle_outline,
                        color: active ? Colors.redAccent : Colors.green,
                      ),
                    ),
            ),
          );
        }),
    ]),
  );
}

class AdminUsers extends StatefulWidget {
  const AdminUsers({super.key});
  @override
  State<AdminUsers> createState() => _AdminUsersState();
}

class _AdminUsersState extends State<AdminUsers> {
  final client = Supabase.instance.client;
  final search = TextEditingController();
  late Future<List<Map<String, dynamic>>> data;
  final Set<String> saving = {};

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

  Future<List<Map<String, dynamic>>> load() async {
    final rows = await client.rpc('admin_list_users') as List;
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> setBlocked(Map<String, dynamic> user) async {
    final userId = user['id'] as String;
    final blocked = user['is_blocked'] == true;
    if (user['is_admin'] == true || saving.contains(userId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(blocked ? 'Kullanıcı kısıtlamasını kaldır?' : 'Kullanıcıyı kısıtla?'),
        content: Text(blocked
            ? 'Bu kullanıcı tekrar uygulamaya erişebilecek.'
            : 'Bu kullanıcı uygulamaya erişemeyecek. İşlem yönetici yetkisiyle kaydedilecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: wine),
            child: Text(blocked ? 'Kısıtlamayı kaldır' : 'Kısıtla'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => saving.add(userId));
    try {
      await client.rpc('admin_set_user_blocked', params: {
        'p_user_id': userId,
        'p_blocked': !blocked,
      });
      if (!mounted) return;
      setState(() {
        user['is_blocked'] = !blocked;
        saving.remove(userId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blocked
            ? 'Kullanıcı kısıtlaması kaldırıldı.'
            : 'Kullanıcı uygulamaya erişimden kısıtlandı.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => saving.remove(userId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kullanıcı durumu değiştirilemedi: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: data,
    builder: (context, snapshot) => PageBody(children: [
      const Text('Kullanıcı Yönetimi',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 12),
      TextField(
        controller: search,
        decoration: const InputDecoration(
          hintText: 'Ad veya e-posta ara...',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SectionTitle('Kullanıcılar'),
      if (snapshot.connectionState == ConnectionState.waiting)
        const Center(child: CircularProgressIndicator(color: wine))
      else if (snapshot.hasError)
        _FeedMessage(
          icon: Icons.people_outline,
          title: 'Kullanıcılar yüklenemedi',
          detail: 'Yönetici yetkisini ve bağlantıyı kontrol et.',
          action: 'Yeniden dene',
          onPressed: () => setState(() => data = load()),
        )
      else
        ...snapshot.data!.where((user) {
          final query = search.text.trim().toLowerCase();
          return (user['full_name']?.toString().toLowerCase() ?? '').contains(query) ||
              (user['email']?.toString().toLowerCase() ?? '').contains(query);
        }).map((user) {
          final blocked = user['is_blocked'] == true;
          final isAdmin = user['is_admin'] == true;
          final userId = user['id'] as String;
          return Card(
            color: Colors.white,
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: const BorderSide(color: blush),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: blush,
                child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person, color: wine),
              ),
              title: Text(
                user['full_name']?.toString().isNotEmpty == true
                    ? user['full_name'].toString()
                    : 'İsimsiz kullanıcı',
                style: const TextStyle(fontWeight: FontWeight.bold, color: ink),
              ),
              subtitle: Text(
                '${user['email'] ?? 'E-posta yok'} • ${user['account_type'] ?? 'rol yok'}'
                '${blocked ? ' • Kısıtlı' : ''}',
              ),
              trailing: isAdmin
                  ? const Icon(Icons.shield_outlined, color: muted)
                  : saving.contains(userId)
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: wine),
                        )
                      : IconButton(
                          tooltip: blocked ? 'Kısıtlamayı kaldır' : 'Kullanıcıyı kısıtla',
                          onPressed: () => setBlocked(user),
                          icon: Icon(
                            blocked ? Icons.lock_open_outlined : Icons.block_outlined,
                            color: blocked ? Colors.green : Colors.redAccent,
                          ),
                        ),
            ),
          );
        }),
    ]),
  );
}

class DiscoverControl extends StatefulWidget {
  const DiscoverControl({super.key});

  @override
  State<DiscoverControl> createState() => _DiscoverControlState();
}

class _DiscoverControlState extends State<DiscoverControl> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _businesses = [];
  bool _loading = true;
  String? _error;
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
  }

  Future<void> _loadBusinesses() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _client.rpc('admin_list_businesses') as List;
      if (!mounted) return;
      setState(() {
        _businesses = rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'İşletmeler yüklenemedi. Bağlantıyı ve yönetici yetkisini kontrol et.';
        _loading = false;
      });
    }
  }

  Future<void> _setVisibility(Map<String, dynamic> business, bool enabled) async {
    final id = business['id'] as String;
    if (business['discover_paid'] != true || _saving.contains(id)) return;
    setState(() => _saving.add(id));
    try {
      await _client.rpc('admin_set_discover_visibility', params: {
        'p_business_id': id,
        'p_enabled': enabled,
      });
      if (!mounted) return;
      setState(() {
        business['discover_enabled'] = enabled;
        _saving.remove(id);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keşfet ayarı kaydedilemedi. Tekrar dene.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(children: [
        const Text('Keşfet Görünürlüğü',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 8),
        const Text(
          'Yalnızca Keşfet erişim hakkı tanımlanmış işletmelerin herkese açık akış görünürlüğünü yönet.',
          style: TextStyle(color: muted),
        ),
        const SectionTitle('Erişim yönetimi'),
        if (_loading)
          const Center(child: Padding(
            padding: EdgeInsets.all(28),
            child: CircularProgressIndicator(color: wine),
          ))
        else if (_error != null)
          Column(children: [
            Text(_error!, style: const TextStyle(color: muted)),
            TextButton(onPressed: _loadBusinesses, child: const Text('Tekrar dene')),
          ])
        else if (_businesses.isEmpty)
          const Text('Henüz işletme bulunmuyor.', style: TextStyle(color: muted))
        else
          ..._businesses.map((business) {
            final paid = business['discover_paid'] == true;
            final enabled = business['discover_enabled'] == true;
            final id = business['id'] as String;
            return Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: blush),
              ),
              child: SwitchListTile(
                value: paid && enabled,
                onChanged: paid && business['status'] == 'active' && !_saving.contains(id)
                    ? (value) => _setVisibility(business, value)
                    : null,
                activeThumbColor: wine,
                secondary: const Icon(Icons.store, color: wine),
                title: Text(
                  business['name'] as String? ?? 'İsimsiz işletme',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: ink),
                ),
                subtitle: Text(
                  business['status'] != 'active'
                      ? 'İşletme aktif değil'
                      : !paid
                          ? 'Keşfet erişim hakkı tanımlı değil'
                          : _saving.contains(id)
                              ? 'Kaydediliyor…'
                              : enabled
                                  ? 'Keşfet görünürlüğü açık'
                                  : 'Keşfet görünürlüğü kapalı',
                  style: const TextStyle(color: muted),
                ),
              ),
            );
          }),
      ]);
}



class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _businessName = TextEditingController();
  final _businessAddress = TextEditingController();
  bool _registering = false;
  bool _businessAccount = false;
  bool _busy = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (Supabase.instance.client.auth.currentSession != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openCurrentAccount());
    }
  }

  @override
  void dispose() {
    _firstName.dispose(); _lastName.dispose(); _phone.dispose();
    _email.dispose(); _password.dispose(); _businessName.dispose();
    _businessAddress.dispose();
    super.dispose();
  }

  String _friendlyError(Object error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login credentials')) return 'E-posta veya şifre hatalı.';
      if (message.contains('email not confirmed')) return 'Devam etmek için e-posta adresini doğrulamalısın.';
      if (message.contains('already registered')) return 'Bu e-posta adresi zaten kayıtlı. Giriş yapmayı dene.';
      if (message.contains('password')) return 'Şifre en az 8 karakter olmalıdır.';
      return error.message;
    }
    if (error is PostgrestException) return error.message;
    return 'İşlem tamamlanamadı. İnternet bağlantını kontrol edip tekrar dene.';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final client = Supabase.instance.client;
    try {
      if (_registering) {
        final fullName = _firstName.text.trim() + ' ' + _lastName.text.trim();
        final metadata = <String, dynamic>{
          'full_name': fullName,
          'phone': _phone.text.trim(),
        };
        if (_businessAccount) {
          metadata['requested_business_name'] = _businessName.text.trim();
          metadata['requested_business_address'] = _businessAddress.text.trim();
        }
        final response = await client.auth.signUp(
          email: _email.text.trim(), password: _password.text, data: metadata,
        );
        if (response.session == null) {
          _notice('Hesabın oluşturuldu. E-posta doğrulamasını tamamla; ardından aynı bilgilerle giriş yap. İşletme kaydın girişte tamamlanacak.');
          return;
        }
        await _openCurrentAccount();
      } else {
        await client.auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
        await _openCurrentAccount();
      }
    } catch (error) {
      if (mounted) _notice(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openCurrentAccount() async {
    final client = Supabase.instance.client;
    try {
      final user = client.auth.currentUser;
      if (user == null) return;
      final metadata = user.userMetadata ?? const <String, dynamic>{};
      final requestedBusinessName = metadata['requested_business_name']?.toString().trim() ?? '';
      final requestedBusinessAddress = metadata['requested_business_address']?.toString().trim() ?? '';
      var rows = await client.rpc('get_my_account_status') as List;
      var profile = rows.isEmpty ? null : Map<String, dynamic>.from(rows.first as Map);
      if (profile == null) throw const AuthException('Hesap profili oluşturulamadı. Destek ekibiyle iletişime geç.');
      if (profile['is_blocked'] == true) {
        await client.auth.signOut();
        throw const AuthException('Bu hesap uygulamaya erişim için engellenmiş.');
      }

      // Metadata only resumes the user's requested pending registration.
      // The database RPC assigns the owner role and creates the pending business.
      if (profile['account_type'] == 'customer' &&
          requestedBusinessName.isNotEmpty && requestedBusinessAddress.isNotEmpty) {
        await client.rpc('register_business', params: {
          'p_name': requestedBusinessName, 'p_address': requestedBusinessAddress,
        });
        rows = await client.rpc('get_my_account_status') as List;
        profile = rows.isEmpty ? null : Map<String, dynamic>.from(rows.first as Map);
      }
      if (profile == null || profile['is_blocked'] == true) {
        await client.auth.signOut();
        throw const AuthException('Hesap bilgileri doğrulanamadı.');
      }

      final isAdmin = profile['is_admin'] == true;
      final accountType = profile['account_type']?.toString() ?? 'customer';
      AppRole role;
      if (isAdmin) {
        role = AppRole.admin;
      } else if (accountType == 'business_owner') {
        role = AppRole.owner;
      } else if (accountType == 'employee') {
        final employee = await client.from('employees').select('id')
            .eq('user_id', user.id).eq('is_active', true).limit(1);
        if (employee.isEmpty) {
          await client.auth.signOut();
          throw const AuthException('Aktif çalışan kaydın bulunamadı. İşletme sahibinden davetini kontrol etmesini iste.');
        }
        role = AppRole.employee;
      } else {
        role = AppRole.customer;
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => RoleShell(role: role)), (_) => false,
      );
    } catch (error) {
      if (mounted) _notice(_friendlyError(error));
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: wine, behavior: SnackBarBehavior.floating),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label, prefixIcon: Icon(icon, color: rose), filled: true, fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: blush)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: blush)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: rose, width: 1.5)),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: ListView(padding: const EdgeInsets.fromLTRB(24, 28, 24, 28), children: [
        Center(child: Container(width: 76, height: 76,
          decoration: BoxDecoration(color: blush, borderRadius: BorderRadius.circular(25)),
          child: const Icon(Icons.spa_rounded, color: wine, size: 44))),
        const SizedBox(height: 14),
        const Text('Kuaförüm', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: wine, letterSpacing: -1)),
        const Text('Güzelliğin Yeni Adresi ♡', textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 14, fontStyle: FontStyle.italic)),
        const SizedBox(height: 28),
        Container(padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: blush.withOpacity(.65), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Expanded(child: _modeButton('Giriş Yap', !_registering, () => setState(() => _registering = false))),
            Expanded(child: _modeButton('Kayıt Ol', _registering, () => setState(() => _registering = true))),
          ])),
        const SizedBox(height: 22),
        Text(_registering ? 'Aramıza hoş geldin' : 'Tekrar hoş geldin',
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 5),
        Text(_registering ? 'Hesabını oluştur, güzellik yolculuğuna başla.' : 'Randevuların ve salonların seni bekliyor.',
          style: const TextStyle(color: muted, fontSize: 13)),
        const SizedBox(height: 20),
        Form(key: _formKey, child: Column(children: [
          if (_registering) ...[
            Row(children: [
              Expanded(child: TextFormField(controller: _firstName, textCapitalization: TextCapitalization.words,
                decoration: _decoration('Ad', Icons.person_outline),
                validator: (v) => v == null || v.trim().isEmpty ? 'Adını gir.' : null)),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _lastName, textCapitalization: TextCapitalization.words,
                decoration: _decoration('Soyad', Icons.person_outline),
                validator: (v) => v == null || v.trim().isEmpty ? 'Soyadını gir.' : null)),
            ]),
            const SizedBox(height: 12),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone,
              decoration: _decoration('Telefon', Icons.phone_outlined),
              validator: (v) => v == null || v.trim().length < 10 ? 'Geçerli bir telefon numarası gir.' : null),
            const SizedBox(height: 14),
            Container(padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: blush), borderRadius: BorderRadius.circular(15)),
              child: Row(children: [
                Expanded(child: _modeButton('Müşteri', !_businessAccount, () => setState(() => _businessAccount = false))),
                Expanded(child: _modeButton('İşletme Sahibi', _businessAccount, () => setState(() => _businessAccount = true))),
              ])),
            if (_businessAccount) ...[
              const SizedBox(height: 12),
              TextFormField(controller: _businessName, textCapitalization: TextCapitalization.words,
                decoration: _decoration('Salon / işletme adı', Icons.storefront_outlined),
                validator: (v) => v == null || v.trim().length < 2 ? 'İşletme adı en az 2 karakter olmalı.' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _businessAddress, textCapitalization: TextCapitalization.sentences,
                decoration: _decoration('İşletme adresi', Icons.location_on_outlined),
                validator: (v) => v == null || v.trim().length < 3 ? 'İşletme adresini gir.' : null),
            ],
            const SizedBox(height: 12),
          ],
          TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false,
            decoration: _decoration('E-posta', Icons.email_outlined),
            validator: (v) => v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? 'Geçerli bir e-posta gir.' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _password, obscureText: _obscurePassword,
            decoration: _decoration('Şifre', Icons.lock_outline).copyWith(suffixIcon: IconButton(
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: muted))),
            validator: (v) => v == null || v.length < 8 ? 'Şifre en az 8 karakter olmalı.' : null),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 54, child: FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: wine, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_registering ? 'Hesabımı Oluştur' : 'Giriş Yap',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          )),
        ])),
        const SizedBox(height: 16),
        const Text('Çalışan hesabın varsa işletmenden aldığın davet kodunu kullanabilirsin.',
          textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12)),
        if (kDebugMode) ...[
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RolePicker())),
            icon: const Icon(Icons.developer_mode_rounded), label: const Text('Geliştirici test ekranı'),
          ),
        ],
      ]),
    ))),
  );

  Widget _modeButton(String label, bool selected, VoidCallback onTap) => Material(
    color: selected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(12),
    child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(color: selected ? wine : muted, fontWeight: FontWeight.w800, fontSize: 13)))),
  );
}
).hasMatch(v.trim()) ? 'Geçerli bir e-posta gir.' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _password, obscureText: _obscurePassword,
            decoration: _decoration('Şifre', Icons.lock_outline).copyWith(suffixIcon: IconButton(
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: muted))),
            validator: (v) => v == null || v.length < 8 ? 'Şifre en az 8 karakter olmalı.' : null),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 54, child: FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: wine, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_registering ? 'Hesabımı Oluştur' : 'Giriş Yap',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          )),
        ])),
        const SizedBox(height: 16),
        const Text('Çalışan hesabın varsa işletmenden aldığın davet kodunu kullanabilirsin.',
          textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12)),
        if (kDebugMode) ...[
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RolePicker())),
            icon: const Icon(Icons.developer_mode_rounded), label: const Text('Geliştirici test ekranı'),
          ),
        ],
      ]),
    ))),
  );

  Widget _modeButton(String label, bool selected, VoidCallback onTap) => Material(
    color: selected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(12),
    child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(color: selected ? wine : muted, fontWeight: FontWeight.w800, fontSize: 13)))),
  );
}

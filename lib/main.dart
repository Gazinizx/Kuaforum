import 'package:flutter/material.dart';

void main() => runApp(const KuaforumApp());

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
    home: const RolePicker(),
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
  Widget _role(BuildContext context, AppRole role, String title, String subtitle, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RoleShell(role: role))),
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
      case AppRole.employee:
        labels = ['Ana Sayfa','Randevular','Paylaşım','Mesajlar','Profil']; icons = [Icons.home_rounded,Icons.calendar_month,Icons.add_circle,Icons.chat_bubble_outline,Icons.person_outline];
        pages = [const EmployeeHome(),const AppointmentsPage(title:'Randevularım'),const SharePage(),const MessagesPage(),const ProfilePage()];
      case AppRole.owner:
        labels = ['Genel Bakış','Randevular','Müşteriler','Mesajlar','Ayarlar']; icons = [Icons.dashboard,Icons.calendar_month,Icons.groups,Icons.chat_bubble_outline,Icons.settings];
        pages = [const OwnerHome(),const OwnerAppointments(),const CustomersPage(),const MessagesPage(),const SettingsPage()];
      case AppRole.admin:
        labels = ['Genel Bakış','İşletmeler','Kullanıcılar','Keşfet','Ayarlar']; icons = [Icons.dashboard,Icons.store,Icons.people_alt,Icons.explore,Icons.settings];
        pages = [const AdminHome(),const AdminBusinesses(),const AdminUsers(),const DiscoverControl(),const SettingsPage()];
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
    const Text('Merhaba, Güzellik! ♡',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:4),const Text('Bugün kendine biraz zaman ayır.',style:TextStyle(color:muted)),
    const SizedBox(height:16),const HeroPanel(eyebrow:'Stilini keşfet',title:'Hayal ettiğin saç stili burada',subtitle:'İlham al, sana en yakın salonu bul ve kolayca randevu oluştur.',icon:Icons.auto_awesome,button:'Şimdi keşfet  →'),
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
class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});
  @override Widget build(BuildContext context)=>PageBody(children:[const Text('Keşfet',style:TextStyle(fontSize:24,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:5),const Text('Yeni stiller, yetenekli çalışanlar ve ilham veren salonlar.',style:TextStyle(color:muted)),const SizedBox(height:16),const SearchBarBox(hint:'Saç modeli, salon veya çalışan ara...'),const SizedBox(height:12),const Wrap(spacing:8,children:[_Chip('Tümü',true),_Chip('Saç Kesimi'),_Chip('Boyama'),_Chip('Ombre'),_Chip('Topuz')]),const SectionTitle('Trend paylaşımlar'),const PostCard(name:'Zeynep Kaya',caption:'Işıltılı dalgalar ✨',likes:'12.5K'),const PostCard(name:'Merve Demir',caption:'Yeni sezon renk geçişi ♡',likes:'8.7K'),const PostCard(name:'Ayşe Yılmaz',caption:'Özel gün topuzu',likes:'6.2K')]);
}
class _Chip extends StatelessWidget {final String text;final bool active;const _Chip(this.text,[this.active=false]);@override Widget build(BuildContext context)=>Chip(label:Text(text,style:TextStyle(color:active?Colors.white:ink,fontSize:11)),backgroundColor:active?wine:Colors.white,side:BorderSide(color:blush));}
class PostCard extends StatelessWidget {
  final String name,caption,likes;const PostCard({super.key,required this.name,required this.caption,required this.likes});
  @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:16),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),border:Border.all(color:blush)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const CircleAvatar(backgroundColor:blush,child:Icon(Icons.person,color:wine)),const SizedBox(width:9),Expanded(child:Text(name,style:const TextStyle(fontWeight:FontWeight.bold,color:ink))),const Icon(Icons.more_horiz,color:muted)]),const SizedBox(height:10),Container(height:185,width:double.infinity,decoration:BoxDecoration(borderRadius:BorderRadius.circular(15),gradient:const LinearGradient(colors:[Color(0xFFE9C5CC),Color(0xFFB66A7D)])),child:const Center(child:Icon(Icons.auto_awesome,size:55,color:Colors.white))),const SizedBox(height:10),Text(caption,style:const TextStyle(fontWeight:FontWeight.w600,color:ink)),const SizedBox(height:8),Row(children:[const Icon(Icons.favorite_border,color:rose),Text(' $likes',style:const TextStyle(color:muted)),const SizedBox(width:16),const Icon(Icons.mode_comment_outlined,color:muted),const Spacer(),const Icon(Icons.bookmark_border,color:muted)])]));
}
class FollowingPage extends StatelessWidget {const FollowingPage({super.key});@override Widget build(BuildContext context)=>PageBody(children:[const Text('Takip Edilen',style:TextStyle(fontSize:24,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:8),const Text('Takip ettiğin çalışanların ve kuaförlerin paylaşımları.',style:TextStyle(color:muted)),const SizedBox(height:12),const Wrap(spacing:8,children:[_Chip('Çalışanlar',true),_Chip('Kuaförler')]),const SectionTitle('Akışın'),const PostCard(name:'Zeynep Kaya • Luxe Beauty',caption:'Bugünkü dönüşümden bir kare ♡',likes:'8.4K'),const PostCard(name:'Merve Demir • Rose Hair',caption:'Yeni balayage çalışmam',likes:'5.1K')]);}
class AppointmentsPage extends StatelessWidget {final String title;const AppointmentsPage({super.key,required this.title});@override Widget build(BuildContext context)=>PageBody(children:[Text(title,style:const TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:12),const Wrap(spacing:8,children:[_Chip('Aktif Randevular',true),_Chip('Geçmiş')]),const SectionTitle('Yaklaşan'),const AppointmentTile(name:'Elif Demir',service:'Saç Boyama',time:'12 Kasım • 14:30',status:'Onaylandı'),const AppointmentTile(name:'Zeynep Kaya',service:'Saç Kesimi',time:'14 Kasım • 11:00',status:'Beklemede')]);}
class AppointmentTile extends StatelessWidget {final String name,service,time,status;const AppointmentTile({super.key,required this.name,required this.service,required this.time,required this.status});@override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),border:Border.all(color:blush)),child:Row(children:[const CircleAvatar(radius:24,backgroundColor:blush,child:Icon(Icons.person,color:wine)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(name,style:const TextStyle(fontWeight:FontWeight.bold,color:ink)),Text(service,style:const TextStyle(color:muted,fontSize:12)),Text(time,style:const TextStyle(color:ink,fontSize:12))])),Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),decoration:BoxDecoration(color:const Color(0xFFE3F3E8),borderRadius:BorderRadius.circular(12)),child:Text(status,style:const TextStyle(color:Color(0xFF32734B),fontSize:10,fontWeight:FontWeight.bold))) ]));}
class MessagesPage extends StatelessWidget {const MessagesPage({super.key});@override Widget build(BuildContext context)=>PageBody(children:[const Text('Mesajlar',style:TextStyle(fontSize:24,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:12),const SearchBarBox(hint:'Kişi veya sohbet ara...'),const SizedBox(height:12),...['Zeynep Kaya','Luxe Beauty Salon','Merve Demir','Ayşe Yılmaz','Elif Demir'].map((n)=>ListTile(contentPadding:const EdgeInsets.symmetric(vertical:5),leading:const CircleAvatar(backgroundColor:blush,child:Icon(Icons.person,color:wine)),title:Text(n,style:const TextStyle(fontWeight:FontWeight.bold,color:ink)),subtitle:const Text('Merhaba, randevu için bilgi alabilir miyim?'),trailing:const Text('14:20',style:TextStyle(color:muted,fontSize:11))))]);}
class ProfilePage extends StatelessWidget {const ProfilePage({super.key});@override Widget build(BuildContext context)=>PageBody(children:[const Center(child:CircleAvatar(radius:48,backgroundColor:blush,child:Icon(Icons.person,size:55,color:wine))),const SizedBox(height:10),const Text('Gizem Yılmaz ♡',textAlign:TextAlign.center,style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:ink)),const Text('@gizemyilmaz',textAlign:TextAlign.center,style:TextStyle(color:muted)),const SizedBox(height:18),const Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[_Metric('28','Takipçi'),_Metric('12','Takip'),_Metric('45','Paylaşım')]),const SizedBox(height:20),...['Profilimi Düzenle','Randevularım','Favorilerim','Takip Ettiklerim','Ayarlar','Çıkış Yap'].map((s)=>Card(color:Colors.white,elevation:0,child:ListTile(leading:const Icon(Icons.circle_outlined,color:wine),title:Text(s,style:const TextStyle(color:ink,fontWeight:FontWeight.w600)),trailing:const Icon(Icons.chevron_right,color:muted))))]);}
class _Metric extends StatelessWidget {final String value,label;const _Metric(this.value,this.label);@override Widget build(BuildContext context)=>Column(children:[Text(value,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:wine)),Text(label,style:const TextStyle(fontSize:11,color:muted))]);}
class EmployeeHome extends StatelessWidget {const EmployeeHome({super.key});@override Widget build(BuildContext context)=>PageBody(children:[const Text('Merhaba Ayşe 👋',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800,color:ink)),const Text('Harika işler çıkarmaya devam et!',style:TextStyle(color:muted)),const SizedBox(height:16),const Row(children:[_StatCard('12','Bugün Randevu'),_StatCard('28','Toplam Randevu'),_StatCard('4.9','Puan')]),const SizedBox(height:16),const HeroPanel(eyebrow:'Portfolyonu büyüt',title:'Çalışmalarını paylaş',subtitle:'Yaptığın işleri paylaş, müşterilerine ilham ver ve kariyerini büyüt.',icon:Icons.camera_alt,button:'Paylaşım yap →'),const SectionTitle('Bugünkü Randevular',action:'Tümünü Gör'),const AppointmentTile(name:'Elif Demir',service:'Saç Kesimi',time:'09:30',status:'Devam Ediyor'),const AppointmentTile(name:'Merve Aksoy',service:'Keratin Bakım',time:'11:00',status:'Onaylandı')]);}
class _StatCard extends StatelessWidget {final String v,l;const _StatCard(this.v,this.l);@override Widget build(BuildContext context)=>Expanded(child:Container(margin:const EdgeInsets.only(right:7),padding:const EdgeInsets.symmetric(vertical:15),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:blush)),child:Column(children:[Text(v,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:20,color:wine)),Text(l,textAlign:TextAlign.center,style:const TextStyle(fontSize:10,color:muted))])));}
class SharePage extends StatelessWidget {const SharePage({super.key});@override Widget build(BuildContext context)=>PageBody(children:[const Text('Yeni Paylaşım',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:16),Container(height:260,decoration:BoxDecoration(color:blush,borderRadius:BorderRadius.circular(22)),child:const Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.add_a_photo_outlined,size:48,color:wine),SizedBox(height:8),Text('Fotoğraf veya video ekle',style:TextStyle(color:wine,fontWeight:FontWeight.bold))]))),const SizedBox(height:14),const SearchBarBox(hint:'Paylaşım açıklaması yaz...'),const SizedBox(height:14),const ListTile(leading:Icon(Icons.public,color:wine),title:Text('Herkese Açık'),trailing:Icon(Icons.chevron_right)),const SizedBox(height:15),const _PrimaryButton('Paylaş')]);}
class OwnerHome extends StatelessWidget {const OwnerHome({super.key});@override Widget build(BuildContext context)=>PageBody(children:[const Text('İşletme Yönetimi',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:14),const HeroPanel(eyebrow:'Luxe Beauty Salon',title:'Güzelliğin profesyonel adresi',subtitle:'İşletmeni, ekibini ve müşteri deneyimini tek yerden yönet.',icon:Icons.storefront,button:'İşletme paneli'),const SizedBox(height:14),const Row(children:[_StatCard('12','Bugünkü Randevu'),_StatCard('1.248','Toplam Müşteri'),_StatCard('4.9','Puan')]),const SectionTitle('Son Randevular',action:'Tümünü Gör'),const AppointmentTile(name:'Ayşe Demir',service:'Saç Kesimi',time:'Bugün • 16:30',status:'Onaylandı'),const SectionTitle('Hızlı Yönetim'),const QuickTiles()]);}
class OwnerAppointments extends StatelessWidget {const OwnerAppointments({super.key});@override Widget build(BuildContext context)=>PageBody(children:[const Text('Randevu Yönetimi',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:12),const Wrap(spacing:8,children:[_Chip('Tümü',true),_Chip('Bekleyen'),_Chip('Onaylanan'),_Chip('Tamamlanan')]),const SectionTitle('Benim Randevularım'),const AppointmentTile(name:'Gizem Yılmaz',service:'Saç Kesimi',time:'Bugün • 14:00',status:'Onaylandı'),const SectionTitle('Çalışan Randevuları'),const AppointmentTile(name:'Zeynep Kaya • Elif Demir',service:'Saç Boyama',time:'Bugün • 15:30',status:'Beklemede'),const AppointmentTile(name:'Merve Aksoy • Ayşe Demir',service:'Keratin Bakım',time:'Yarın • 11:00',status:'Onaylandı')]);}
class CustomersPage extends StatelessWidget {const CustomersPage({super.key});@override Widget build(BuildContext context)=>PageBody(children:[const Text('Müşterilerim',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:12),const SearchBarBox(hint:'Müşteri ara...'),const SectionTitle('Müşteri Listesi'),...['Ayşe Demir','Elif Yılmaz','Merve Aksoy','Derya Şahin','Zeynep Kaya'].map((n)=>ListTile(leading:const CircleAvatar(backgroundColor:blush,child:Icon(Icons.person,color:wine)),title:Text(n,style:const TextStyle(fontWeight:FontWeight.bold,color:ink)),subtitle:const Text('+90 545 123 45 67'),trailing:const Icon(Icons.more_vert,color:muted)))]);}
class SettingsPage extends StatelessWidget {const SettingsPage({super.key});@override Widget build(BuildContext context)=>PageBody(children:[const Text('Ayarlar',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:12),...['İşletme Bilgileri','Çalışma Saatleri','Hizmetler','Çalışanlar','Çalışan Davet Et','Bildirim Ayarları','Güvenlik','Yardım ve Destek'].map((s)=>Card(color:Colors.white,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),child:ListTile(leading:const Icon(Icons.settings_outlined,color:wine),title:Text(s,style:const TextStyle(fontWeight:FontWeight.w600,color:ink)),trailing:const Icon(Icons.chevron_right,color:muted))))]);}
class AdminHome extends StatelessWidget {const AdminHome({super.key});@override Widget build(BuildContext context)=>PageBody(children:[const Text('Ana Yönetici',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:14),const HeroPanel(eyebrow:'Platform kontrolü',title:'Kuaförüm ekosistemini yönet',subtitle:'İşletmeleri, kullanıcıları ve Keşfet erişimlerini kontrol et.',icon:Icons.admin_panel_settings,button:'Yönetimi aç'),const SizedBox(height:14),const Row(children:[_StatCard('248','İşletme'),_StatCard('12.5K','Kullanıcı'),_StatCard('1.8K','Paylaşım')]),const SectionTitle('Yönetim araçları'),const QuickTiles()]);}
class AdminBusinesses extends StatelessWidget {const AdminBusinesses({super.key});@override Widget build(BuildContext context)=>PageBody(children:[const Text('İşletme Yönetimi',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:12),const SearchBarBox(hint:'İşletme ara...'),const SectionTitle('İşletmeler'),...['Luxe Beauty Salon','Rose Hair Studio','Tasarımhane Kuaför','Mira Güzellik'].map((n)=>ListTile(leading:const CircleAvatar(backgroundColor:blush,child:Icon(Icons.store,color:wine)),title:Text(n,style:const TextStyle(fontWeight:FontWeight.bold,color:ink)),subtitle:const Text('Aktif • Keşfet erişimi açık'),trailing:const Icon(Icons.more_vert,color:muted)))]);}
class AdminUsers extends StatelessWidget {const AdminUsers({super.key});@override Widget build(BuildContext context)=>PageBody(children:[const Text('Kullanıcı Yönetimi',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:12),const SearchBarBox(hint:'Kullanıcı ara...'),const SectionTitle('Son kayıtlar'),...['Gizem Yılmaz','Ayşe Demir','Zeynep Kaya','Merve Demir'].map((n)=>ListTile(leading:const CircleAvatar(backgroundColor:blush,child:Icon(Icons.person,color:wine)),title:Text(n,style:const TextStyle(fontWeight:FontWeight.bold,color:ink)),subtitle:const Text('Müşteri hesabı'),trailing:const Icon(Icons.more_vert,color:muted)))]);}
class DiscoverControl extends StatelessWidget {const DiscoverControl({super.key});@override Widget build(BuildContext context)=>PageBody(children:[const Text('Keşfet Görünürlüğü',style:TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:ink)),const SizedBox(height:8),const Text('İşletmelerin paylaşımlarının herkese açık Keşfet akışında görünmesini buradan yönet.',style:TextStyle(color:muted)),const SectionTitle('Erişim yönetimi'),...['Luxe Beauty Salon','Rose Hair Studio','Tasarımhane Kuaför'].map((n)=>SwitchListTile(value:true,onChanged:(_){},activeColor:wine,secondary:const Icon(Icons.store,color:wine),title:Text(n,style:const TextStyle(fontWeight:FontWeight.bold,color:ink)),subtitle:const Text('Keşfet görünürlüğü')))]);}

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

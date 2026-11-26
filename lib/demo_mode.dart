import 'package:flutter/material.dart';

const _demoWine = Color(0xFF8E2947);
const _demoBlush = Color(0xFFF7DDE3);
const _demoInk = Color(0xFF39252C);
const _demoMuted = Color(0xFF927B82);

class DemoIdentity {
  const DemoIdentity(this.name, this.handle, this.role, this.initials);
  final String name;
  final String handle;
  final String role;
  final String initials;
}

class DemoPost {
  DemoPost({required this.author, required this.business, required this.caption, required this.time, this.likes = 0, this.liked = false});
  final String author;
  final String business;
  final String caption;
  final String time;
  int likes;
  bool liked;
}

class DemoChat {
  DemoChat(this.name, this.preview, this.messages);
  final String name;
  String preview;
  final List<String> messages;
}

class KuaforumDemoStore {
  KuaforumDemoStore._();
  static final KuaforumDemoStore instance = KuaforumDemoStore._();

  final Map<String, List<DemoPost>> posts = {
    'customer': [
      DemoPost(author: 'Elif Kaya', business: 'Lale Hair Studio', caption: 'Yeni sezonun doğal ışıltılı saç tonları ✨', time: '12 dk önce', likes: 28),
      DemoPost(author: 'Zeynep Demir', business: 'Mira Beauty', caption: 'Soft katlı kesim ve fön ile küçük bir değişim ♡', time: '1 saat önce', likes: 16),
    ],
    'employee': [
      DemoPost(author: 'Ayşe Yılmaz', business: 'Lale Hair Studio', caption: 'Bugünkü balyaj çalışmamızdan sıcak karamel tonları 🤎', time: '8 dk önce', likes: 42),
      DemoPost(author: 'Selin Aras', business: 'Mira Beauty', caption: 'Doğal dalgalar ve parlak bitiş ✨', time: 'Dün', likes: 31),
    ],
    'owner': [
      DemoPost(author: 'Ayşe Yılmaz', business: 'Lale Hair Studio', caption: 'Ekibimizden günün dönüşümü. Randevu için bize ulaşın ♡', time: '20 dk önce', likes: 53),
      DemoPost(author: 'Lale Hair Studio', business: 'Lale Hair Studio', caption: 'Bu haftanın bakım paketleri yayında!', time: '3 saat önce', likes: 24),
    ],
    'admin': [
      DemoPost(author: 'Lale Hair Studio', business: 'Lale Hair Studio', caption: 'Keşfet görünürlüğü açık örnek işletme paylaşımı.', time: '15 dk önce', likes: 53),
      DemoPost(author: 'Mira Beauty', business: 'Mira Beauty', caption: 'Platform yönetimi için örnek içerik.', time: 'Dün', likes: 18),
    ],
  };

  final Map<String, List<DemoChat>> chats = {
    'customer': [
      DemoChat('Ayşe • Lale Hair Studio', 'Merhaba, randevunuz için yardımcı olayım.', ['Merhaba, cumartesi için boş saatiniz var mı?', 'Merhaba! 14.00 ve 16.30 saatlerimiz uygun 🌸']),
      DemoChat('Selin • Mira Beauty', 'Bakım paketimiz hakkında bilgi', ['Saç bakım paketinizin fiyatını öğrenebilir miyim?', 'Elbette, paketimiz 900 TL’den başlıyor.']),
    ],
    'employee': [
      DemoChat('Elif Kaya', 'Cumartesi 14.00 uygun mu?', ['Merhaba Ayşe Hanım, cumartesi 14.00 uygun mu?', 'Merhaba Elif, evet sizin için ayırabilirim.']),
      DemoChat('Zeynep Demir', 'Teşekkür ederim 🌸', ['Merhaba, saç kesimi için bilgi alabilir miyim?', 'Tabii, memnuniyetle yardımcı olurum.', 'Teşekkür ederim 🌸']),
    ],
    'owner': [
      DemoChat('Elif Kaya • Müşteri', 'Randevu saatini değiştirebilir miyiz?', ['Merhaba, cumartesi randevumu 16.00 yapabilir miyiz?', 'Kontrol edip size dönüş yapıyorum.']),
      DemoChat('Ayşe Yılmaz • Çalışan', 'Günlük randevu planı hazır.', ['Yarınki randevu planını hazırladım.', 'Teşekkürler, panelden kontrol ediyorum.']),
    ],
    'admin': [
      DemoChat('Lale Hair Studio • İşletme', 'Onay süreci hakkında bilgi', ['İşletme başvurumuzun durumu nedir?', 'Başvurunuz inceleme sırasındadır.']),
      DemoChat('Destek • Kullanıcı', 'Hesap desteği talebi', ['Hesabımla ilgili destek rica ediyorum.', 'Talebiniz alındı.']),
    ],
  };

  final List<String> appointments = [
    'Elif Kaya • Saç kesimi • Bugün 14.00 • Onaylandı',
    'Zeynep Demir • Balyaj • Yarın 11.30 • Onay bekliyor',
    'Merve Aydın • Fön • Cuma 16.00 • Onaylandı',
  ];
  bool discoverEnabled = true;
  bool ownerApproval = false;

  DemoIdentity identity(String role) => switch (role) {
    'customer' => const DemoIdentity('Elif Kaya', '@elifkaya', 'Müşteri hesabı', 'EK'),
    'employee' => const DemoIdentity('Ayşe Yılmaz', '@ayseyilmaz', 'Çalışan hesabı • Lale Hair Studio', 'AY'),
    'owner' => const DemoIdentity('Derya Akın', '@lalehairstudio', 'İşletme sahibi • Lale Hair Studio', 'DA'),
    _ => const DemoIdentity('Kuaförüm Yönetim', '@kuaforumadmin', 'Ana yönetici hesabı', 'KY'),
  };

  List<DemoPost> feed(String role) => posts[role]!;
  List<DemoChat> inbox(String role) => chats[role]!;
}

class DemoWorkspacePage extends StatefulWidget {
  const DemoWorkspacePage({super.key, required this.role, required this.section});
  final String role;
  final String section;

  @override
  State<DemoWorkspacePage> createState() => _DemoWorkspacePageState();
}

class _DemoWorkspacePageState extends State<DemoWorkspacePage> {
  final store = KuaforumDemoStore.instance;
  final composer = TextEditingController();

  @override
  void dispose() {
    composer.dispose();
    super.dispose();
  }

  String get roleName => switch (widget.role) {
    'customer' => 'Müşteri',
    'employee' => 'Çalışan',
    'owner' => 'İşletme Sahibi',
    _ => 'Ana Yönetici',
  };

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    if (section == 'Profil') return _profile();
    if (section == 'Bildirimler') return _notifications();
    if (section == 'Mesajlar') return _messages();
    if (section == 'Paylaşım' || section == 'Paylaş') return _share();
    if (section == 'Randevular' || section == 'Randevum') return _appointments();
    if (section == 'Kullanıcılar' || section == 'İşletmeler' || section == 'Keşfet Yönetimi') return _adminSection();
    if (section == 'Keşfet' || section == 'Takip') return _feed();
    if (section == 'Genel Bakış') return _adminDashboard();
    if (section == 'Ana Sayfa') return _home();
    return _home();
  }

  Widget _page(List<Widget> children) => ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: children);

  Widget _header(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _demoInk)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: _demoMuted, fontSize: 13)),
    ]),
  );

  Widget _panel({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _demoBlush)),
    child: child,
  );

  Widget _home() {
    final identity = store.identity(widget.role);
    return _page([
      _header('Merhaba, ${identity.name.split(' ').first} ♡', 'Bu, ${roleName.toLowerCase()} demo hesabının ana sayfası.'),
      _panel(child: Row(children: [
        const CircleAvatar(radius: 27, backgroundColor: _demoBlush, child: Icon(Icons.auto_awesome, color: _demoWine)),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Kuaförüm’e hoş geldin', style: TextStyle(fontWeight: FontWeight.w800, color: _demoInk)),
          Text('Örnek içerikler ve işlemlerle uygulamayı deneyebilirsin.', style: TextStyle(fontSize: 12, color: _demoMuted)),
        ])),
      ])),
      _header('Hesabına özel alan', 'Rolüne ait demo verileri burada.'),
      if (widget.role == 'customer') ...[
        _action('Salonları keşfet', 'Paylaşımları incele ve beğen.', Icons.explore, () => _goFeed()),
        _action('Randevu oluştur', 'Lale Hair Studio • Saç kesimi • 14.00', Icons.calendar_month, () => _notice('Demo randevu talebin oluşturuldu.')),
      ] else if (widget.role == 'employee') ...[
        _action('Bugünkü randevular', '3 örnek randevunu görüntüle.', Icons.event, () => _notice('Randevu listesi alt menüde.')),
        _action('Yeni paylaşım', 'Çalışmanı Keşfet’te paylaş.', Icons.add_a_photo, () => _compose()),
      ] else if (widget.role == 'owner') ...[
        _action('İşletme özeti', '12 randevu • 4 çalışan • 86 müşteri', Icons.store, () => _notice('İşletme özetin güncel.')),
        _action('Çalışan randevuları', 'Ekibinin randevu takvimini incele.', Icons.groups, () => _notice('Örnek çalışan randevuları hazır.')),
      ] else ...[
        _action('Platform özeti', '8 işletme • 126 kullanıcı • 34 paylaşım', Icons.dashboard, () => _notice('Demo yönetim verileri yüklendi.')),
        _action('Keşfet görünürlüğü', 'İşletmelerin yayın izinlerini yönet.', Icons.visibility, () => setState(() => store.discoverEnabled = !store.discoverEnabled)),
      ],
      _header('Son paylaşımlar', 'Demo akışından örnekler.'),
      ...store.feed(widget.role).take(2).map(_postCard),
    ]);
  }

  Widget _action(String title, String subtitle, IconData icon, VoidCallback onTap) => _panel(child: ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(backgroundColor: _demoBlush, child: Icon(icon, color: _demoWine)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: _demoInk)),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: _demoMuted)),
    trailing: const Icon(Icons.chevron_right, color: _demoWine),
    onTap: onTap,
  ));

  Widget _feed() => _page([
    _header(widget.section == 'Takip' ? 'Takip Ettiklerin' : 'Keşfet', widget.section == 'Takip' ? 'Takip ettiğin salon ve çalışanlardan.' : 'Tüm işletmelerden ve çalışanlardan ilham al.'),
    if (widget.section == 'Takip') _panel(child: const Text('Takip ettiğin hesaplardan yeni paylaşımlar burada görünür.', style: TextStyle(color: _demoMuted))),
    ...store.feed(widget.role).map(_postCard),
    _action('Lale Hair Studio', 'İşletme profili • 4 çalışan • 86 takipçi', Icons.storefront, () => _notice('Lale Hair Studio demo profili açıldı.')),
  ]);

  Widget _postCard(DemoPost post) => _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      const CircleAvatar(backgroundColor: _demoBlush, child: Icon(Icons.person, color: _demoWine)),
      const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(post.author, style: const TextStyle(fontWeight: FontWeight.w800, color: _demoInk)),
        Text('${post.business} • ${post.time}', style: const TextStyle(fontSize: 11, color: _demoMuted)),
      ])),
      const Icon(Icons.more_horiz, color: _demoMuted),
    ]),
    const SizedBox(height: 12),
    Container(height: 150, width: double.infinity, decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFF4D6DE), Color(0xFFE9C3B0)]),
      borderRadius: BorderRadius.circular(14),
    ), child: const Center(child: Icon(Icons.content_cut, size: 48, color: Colors.white))),
    const SizedBox(height: 10),
    Text(post.caption, style: const TextStyle(color: _demoInk)),
    Row(children: [
      IconButton(onPressed: () => setState(() { post.liked = !post.liked; post.likes += post.liked ? 1 : -1; }), icon: Icon(post.liked ? Icons.favorite : Icons.favorite_border, color: _demoWine)),
      Text('${post.likes}', style: const TextStyle(color: _demoMuted)),
      const SizedBox(width: 12),
      IconButton(onPressed: () => _notice('Yorum alanı demo olarak açıldı.'), icon: const Icon(Icons.chat_bubble_outline, color: _demoWine)),
      TextButton(onPressed: () => _notice('Paylaşım bağlantısı kopyalandı.'), child: const Text('Paylaş')),
    ]),
  ]));

  Widget _messages() => _page([
    _header('Mesajlar', 'Bu rolün kendi demo sohbetleri. Mesaj gönderme aktif.'),
    ...store.inbox(widget.role).map((chat) => _panel(child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: const CircleAvatar(backgroundColor: _demoBlush, child: Icon(Icons.person, color: _demoWine)),
      title: Text(chat.name, style: const TextStyle(fontWeight: FontWeight.w800, color: _demoInk)),
      subtitle: Text(chat.preview, maxLines: 1, overflow: TextOverflow.ellipsis),
      children: [
        ...chat.messages.map((message) => Align(
          alignment: message.startsWith('Merhaba') || message.startsWith('Tabii') || message.startsWith('Elbette') || message.startsWith('Kontrol') || message.startsWith('Başvurunuz') ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(10), constraints: const BoxConstraints(maxWidth: 260), decoration: BoxDecoration(color: _demoBlush.withOpacity(.65), borderRadius: BorderRadius.circular(12)), child: Text(message, style: const TextStyle(color: _demoInk))),
        )),
        _DemoSendMessage(onSend: (value) => setState(() { chat.messages.add(value); chat.preview = value; })),
      ],
    ))),
  ]);

  Widget _share() => _page([
    _header('Yeni paylaşım', 'Çalışmalarını demo akışında paylaş.'),
    _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(height: 170, width: double.infinity, decoration: BoxDecoration(color: _demoBlush, borderRadius: BorderRadius.circular(15)), child: const Center(child: Icon(Icons.add_photo_alternate_outlined, size: 54, color: _demoWine))),
      const SizedBox(height: 12),
      TextField(controller: composer, maxLines: 3, decoration: const InputDecoration(hintText: 'Bugünkü çalışmanı anlat...', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: _demoWine),
        onPressed: _compose,
        icon: const Icon(Icons.publish),
        label: const Text('Demo paylaşımı yayınla'),
      )),
      const SizedBox(height: 6),
      const Text('Test modunda gerçek fotoğraf yüklenmez; örnek görselle yerel paylaşım oluşturulur.', style: TextStyle(fontSize: 11, color: _demoMuted)),
    ])),
    _header('Senin paylaşımların', 'Oluşturduğun içerikler bu hesapta kalır.'),
    ...store.feed(widget.role).map(_postCard),
  ]);

  Future<void> _compose() async {
    if (composer.text.trim().isEmpty) {
      final controller = TextEditingController();
      final value = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Yeni demo paylaşımı'),
        content: TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(hintText: 'Paylaşım açıklaması')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Yayınla')),
        ],
      ));
      controller.dispose();
      if (value == null || value.trim().isEmpty) return;
      composer.text = value;
    }
    final identity = store.identity(widget.role);
    setState(() {
      store.feed(widget.role).insert(0, DemoPost(author: identity.name, business: 'Lale Hair Studio', caption: composer.text.trim(), time: 'Şimdi'));
      composer.clear();
    });
    _notice('Demo paylaşımın yayınlandı.');
  }

  Widget _appointments() => _page([
    _header('Randevularım', 'Örnek randevular üzerinde işlem yapabilirsin.'),
    ...store.appointments.map((item) => _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(item, style: const TextStyle(fontWeight: FontWeight.w700, color: _demoInk)),
      const SizedBox(height: 9),
      Wrap(spacing: 8, children: [
        OutlinedButton(onPressed: () => _notice('Randevu ayrıntıları açıldı.'), child: const Text('Detay')),
        if (widget.role != 'customer') FilledButton(onPressed: () => _notice('Demo randevu durumu güncellendi.'), style: FilledButton.styleFrom(backgroundColor: _demoWine), child: const Text('Onayla')),
        TextButton(onPressed: () => _notice('Demo randevu iptal edildi.'), child: const Text('İptal')),
      ]),
    ]))),
    if (widget.role == 'customer') FilledButton.icon(onPressed: () => _notice('Yeni demo randevu talebi oluşturuldu.'), icon: const Icon(Icons.add), label: const Text('Randevu oluştur'), style: FilledButton.styleFrom(backgroundColor: _demoWine)),
  ]);

  Widget _profile() {
    final identity = store.identity(widget.role);
    return _page([
      _header('Profilim', 'Bağımsız demo hesabı'),
      _panel(child: Column(children: [
        CircleAvatar(radius: 38, backgroundColor: _demoBlush, child: Text(identity.initials, style: const TextStyle(color: _demoWine, fontSize: 22, fontWeight: FontWeight.w900))),
        const SizedBox(height: 10),
        Text(identity.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: _demoInk)),
        Text(identity.handle, style: const TextStyle(color: _demoMuted)),
        const SizedBox(height: 5),
        Text(identity.role, textAlign: TextAlign.center, style: const TextStyle(color: _demoWine, fontWeight: FontWeight.w700)),
      ])),
      _action('Hesap bilgileri', 'Ad, telefon ve profil bilgileri', Icons.person_outline, () => _notice('Demo profil bilgileri düzenlemeye hazır.')),
      _action('Bildirim tercihleri', 'Uygulama içi bildirimler', Icons.notifications_none, () => _notice('Bildirim ayarları açıldı.')),
      _action('Gizlilik ve güvenlik', 'Hesap ve görünürlük seçenekleri', Icons.lock_outline, () => _notice('Gizlilik seçenekleri açıldı.')),
      _panel(child: const Text('Bu rol, test APK’sına ait yerel demo kimliğidir. Gerçek hesabına veya Supabase verilerine bağlı değildir.', style: TextStyle(fontSize: 12, color: _demoMuted))),
    ]);
  }

  Widget _notifications() => _page([
    _header('Bildirimler', 'Bu demo hesabına ait örnek bildirimler.'),
    ...[
      'Lale Hair Studio randevu talebini onayladı.',
      'Ayşe Yılmaz yeni bir saç tasarımı paylaştı.',
      'Mesaj kutunda okunmamış bir mesajın var.',
    ].map((item) => _panel(child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(backgroundColor: _demoBlush, child: Icon(Icons.notifications_active, color: _demoWine)),
      title: Text(item, style: const TextStyle(fontWeight: FontWeight.w700, color: _demoInk)),
      subtitle: const Text('Az önce • Demo bildirim', style: TextStyle(color: _demoMuted, fontSize: 11)),
      onTap: () => _notice('Bildirim açıldı.'),
    ))),
  ]);

  Widget _adminDashboard() => _page([
    _header('Yönetim Merkezi', 'Ana yönetici demo hesabı'),
    Wrap(spacing: 8, runSpacing: 8, children: [
      _metric('8', 'İşletme'), _metric('126', 'Kullanıcı'), _metric('34', 'Paylaşım'), _metric('5', 'Onay bekliyor'),
    ]),
    _action('İşletme başvuruları', 'Örnek başvuruları incele.', Icons.store, () => _notice('Örnek işletme başvurusu onaylandı.')),
    _action('Kullanıcı yönetimi', 'Kullanıcıları ve hesap durumlarını gör.', Icons.people, () => _notice('Demo kullanıcı listesi hazır.')),
    _action('Keşfet yayın izinleri', 'Ücretli hesapların görünürlüğünü yönet.', Icons.visibility, () => setState(() => store.discoverEnabled = !store.discoverEnabled)),
  ]);

  Widget _metric(String value, String label) => Container(width: 145, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _demoBlush)), child: Column(children: [Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _demoWine)), Text(label, style: const TextStyle(color: _demoMuted))]));

  Widget _adminSection() {
    if (widget.section == 'Keşfet Yönetimi') return _page([
      _header('Keşfet görünürlüğü', 'İşletmelerin keşfette yayın iznini yönet.'),
      _panel(child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: store.discoverEnabled,
        activeColor: _demoWine,
        title: const Text('Lale Hair Studio', style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(store.discoverEnabled ? 'Keşfet’te görünür' : 'Keşfet görünürlüğü kapalı'),
        onChanged: (value) => setState(() => store.discoverEnabled = value),
      )),
      _panel(child: const ListTile(title: Text('Mira Beauty'), subtitle: Text('Ücretli görünürlük • Onay bekliyor'), trailing: Icon(Icons.pending_actions, color: _demoWine))),
    ]);
    final title = widget.section;
    return _page([
      _header(title, 'Yönetici hesabına özel örnek kayıtlar.'),
      ...['Lale Hair Studio • Aktif', 'Mira Beauty • Onay bekliyor', 'Studio Rose • Aktif'].map((name) => _panel(child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(backgroundColor: _demoBlush, child: Icon(Icons.store, color: _demoWine)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: PopupMenuButton<String>(onSelected: (v) => _notice('$name: $v'), itemBuilder: (_) => const [PopupMenuItem(value: 'Onayla', child: Text('Onayla')), PopupMenuItem(value: 'Askıya al', child: Text('Askıya al'))]),
      ))),
    ]);
  }

  void _goFeed() => _notice('Keşfet sekmesinden tüm demo paylaşımlarını görebilirsin.');
  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, backgroundColor: _demoWine));
  }
}


class _DemoSendMessage extends StatefulWidget {
  const _DemoSendMessage({required this.onSend});
  final ValueChanged<String> onSend;

  @override
  State<_DemoSendMessage> createState() => _DemoSendMessageState();
}

class _DemoSendMessageState extends State<_DemoSendMessage> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
    child: Row(children: [
      Expanded(child: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Mesaj yaz...', isDense: true))),
      IconButton(
        onPressed: () {
          final value = controller.text.trim();
          if (value.isEmpty) return;
          widget.onSend(value);
          controller.clear();
        },
        icon: const Icon(Icons.send_rounded, color: _demoWine),
      ),
    ]),
  );
}

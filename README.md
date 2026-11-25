# Kuaförüm

Kadın kuaförleri için premium salon keşif, randevu ve sosyal paylaşım uygulaması.

## Test sürümü
- Login/kayıt ekranı yoktur. Hızlı test için rol seçimi ekranı korunur.
- Müşteri ve çalışan ekranları mevcut tasarım akışını kullanır.
- İşletme sahibi; Ana Sayfa, Keşfet, Takip, Paylaş, Mesajlar ve Profil sekmelerini kullanır.
- İşletme hesabı adına fotoğraf/video seçerek paylaşım oluşturabilir; paylaşım Keşfet ve Takip akışında görünür.
- Ana Yönetici yalnızca platform yönetimi, işletmeler, kullanıcılar ve Keşfet erişimini yönetir. Randevu alma sekmesi yoktur.
- Paylaşım ekranında galeri fotoğrafı/video seçimi, açıklama ve yayınlama akışı bulunur.

## Önemli test sınırı
Bu APK hızlı rol ve arayüz test sürümüdür. Rol seçimi demo amaçlıdır; oluşturulan paylaşımlar ve beğeniler uygulama belleğinde tutulur. Supabase üzerinde kalıcı kayıt, gerçek kullanıcı kimliği/yetkisi, randevu işlemleri ve gerçek zamanlı mesajlaşma henüz bu Flutter istemcisine bağlanmamıştır. Login ekranı eklenmediği için bu aşamada gerçek hesaplar arasında güvenli veri işlemi yapılmaz.

## Build
`flutter pub get`
`flutter test`
`flutter build apk --release`

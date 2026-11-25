# Kuaförüm

Kadın kuaförleri için salon keşif, randevu ve sosyal paylaşım uygulaması.

## Tamamlanan sosyal özellikler

- Müşteri, çalışan ve işletme profilleri; profil fotoğrafı ve salon logosu yükleme
- Keşfet ve Takip akışları; fotoğraf/video paylaşımı, beğeni ve yorum
- Çalışan ve işletme takip etme; takipçi/takip edilen listeleri
- Gönderi açıklaması düzenleme, paylaşım silme ve şikâyet gönderme
- Keşfet'te gönderi, aktif işletme ve aktif çalışan arama; kategori filtreleri
- Paylaşım yapan uygun çalışanlarla müşteri arasında gerçek zamanlı mesajlaşma
- Supabase RLS ve güvenli profil alanları; e-posta, telefon ve yönetici yetkileri herkese açık değildir

## Tamamlanan randevu ve işletme özellikleri

- Müşterinin aktif salonları araması ve işletme profillerini görüntülemesi
- İşletme katılım koduyla üyelik
- İşletme sahibinin hizmet, fiyat ve süre yönetimi
- Çalışan daveti oluşturma, davet kodu görüntüleme ve çalışanı aktif/pasif yapma
- Haftalık çalışma saatleri ve randevu aralığı ayarları
- Müşterinin uygun gün/saat seçerek randevu oluşturması
- Uygun saat hesabında hizmet süresi, çalışma saatleri, molalar ve mevcut randevuların dikkate alınması
- Müşteri randevu geçmişi; çalışan kendi randevuları; işletme sahibi tüm çalışan randevuları ve onay bekleyen talepler
- Üç veya daha fazla gelmeme kaydında müşterinin otomatik kara listeye alınması; işletme sahibinin listeden çıkarabilmesi
- Kara listedeki müşterinin yeni randevularının işletme onayına düşmesi
- İşletmenin müşteri listesi, randevu/gelmeme sayıları ve kara liste yönetimi
- Randevu bildirimlerinin uygulama içindeki Bildirimler ekranında görüntülenmesi ve okundu işaretlenmesi

## Henüz tamamlanmayan bölümler

- Normal kullanıcı kayıt/giriş ekranı ve çalışan davet kodunu giriş sırasında kullanma akışı son aşamada tamamlanacaktır.
- Ana yönetici ekranındaki Keşfet görünürlük kontrollerinin veritabanına bağlanması tamamlanmamıştır.
- Firebase Cloud Messaging ile gerçek push teslimi henüz Kuaförüm projesine bağlanmamıştır. Eski projeye giden hatalı push tetikleyicisi güvenlik için kaldırılmıştır.
- iOS derlemesi ve App Store hazırlığı tamamlanmamıştır.

## Android derleme

Android APK iş akışı yalnızca kullanıcı açıkça istediğinde GitHub Actions içinden manuel başlatılır. Kod güncellemeleri otomatik derleme başlatmaz.

Yerel derleme komutları:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Bu dalda henüz Flutter analizi, test veya APK derlemesi çalıştırılmadı.

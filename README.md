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

## Henüz tamamlanmayan bölümler

- Randevu, hizmet, çalışan yönetimi ve müşteri işlemlerinin bir bölümü hâlâ örnek veri/tasarım aşamasındadır.
- Ana yönetici ekranındaki Keşfet görünürlük kontrollerinin veritabanına bağlanması tamamlanmamıştır.
- Normal kullanıcı kayıt/giriş ekranı son aşamada eklenecektir.
- iOS derlemesi ve App Store hazırlığı tamamlanmamıştır.

## Android derleme

Android APK iş akışı artık otomatik çalışmaz. Yalnızca kullanıcı açıkça istediğinde GitHub Actions içinden manuel olarak başlatılır.

Yerel derleme komutları:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Bu dalda henüz Flutter analizi, test veya APK derlemesi çalıştırılmadı.

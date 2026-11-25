# Kuaförüm

Kadın kuaförleri için premium salon keşif, randevu ve sosyal paylaşım uygulaması.

## Mevcut uygulama durumu

- Hızlı test rol ekranı korunur; her rol için gerçek Supabase hesabıyla giriş yapılır ve hesap rolü doğrulanır.
- Müşteri, çalışan, işletme sahibi ve ana yönetici panellerinin tasarım akışı bulunur.
- İşletme sahibi ve aktif çalışan hesapları fotoğraf/video paylaşabilir.
- Keşfet ve Takip akışları, beğeniler, takip ilişkileri ve yorumlar Supabase üzerinden kalıcı olarak çalışır.
- Paylaşılan medya özel `salon-feed` Storage alanında saklanır; görüntüleme izinleri işletme ve Keşfet görünürlüğü kurallarına bağlıdır.
- Ana yönetici Keşfet erişim kurallarının sahibidir; test işletmesinin görünürlüğü kendiliğinden açılmaz.

## Henüz tamamlanmayan bölümler

- Randevu, hizmet, çalışan yönetimi ve müşteri işlemlerinin bir bölümü şu anda tasarım/örnek veri aşamasındadır.
- Mesajlaşma ekranı henüz gerçek sohbet altyapısına bağlı değildir.
- Profil sayfaları, takipçi/takip edilen listeleri, içerik arama ve gelişmiş moderasyon tamamlanmamıştır.
- Normal kullanıcı kayıt/giriş ekranı, hızlı test ekranının yerine son aşamada eklenecektir.

## Android test derlemesi

GitHub Actions, her `main` güncellemesinde Android platform dosyalarını oluşturur; bağımlılıkları indirir, analiz ve testleri çalıştırır ve başarılı olursa release APK çıktısını `kuaforum-release-apk` adlı artifact olarak yükler.

Yerel derleme komutları:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

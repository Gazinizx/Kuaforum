# Kuaförüm

Kadın kuaförleri için Flutter tabanlı salon keşif, randevu, sosyal paylaşım ve işletme yönetimi uygulaması.

## Tamamlanan uygulama akışları

- Herkese açık kayıt yalnızca müşteri hesabı oluşturur; ad, soyad, telefon, e-posta ve şifre zorunludur.
- İşletme hesapları ana yönetici tarafından yönetilir.
- İşletme sahibi çalışan hesabını ad, soyad, telefon, e-posta ve ilk şifreyle oluşturur; çalışana e-posta doğrulama bağlantısı gönderilir.
- İşletme sahibi çalışanı devre dışı bırakabilir veya kaldırabilir. Çalışan kendi isteğiyle işletmeden ayrılıp müşteri hesabına dönebilir.
- Müşteri işletme katılım koduyla işletmeye bağlanır; profilinden bağlantısını yönetebilir.
- Müşteri işletme profilinde işletme bilgilerini, hizmetleri, çalışanları, paylaşımları ve değerlendirmeleri görebilir; işletmeyi takip edebilir, mesaj gönderebilir ve randevu oluşturabilir.
- Randevu akışı hizmet, çalışan ve uygun saat seçimiyle çalışır. Çalışan seçimi isteğe bağlıdır.
- İşletme sahibi çalışanları, hizmetleri, çalışma saatlerini, randevu aralığını ve geçici kapanışı yönetebilir.
- Çalışan kendi randevularını, çalışma saatlerini ve izin taleplerini yönetir. İzin taleplerini işletme sahibi inceler.
- Müşteri randevusunu iptal edebilir; üç iptal/gelmeme ihlalinde işletme bazlı otomatik kara liste uygulanır.
- Tamamlanan randevu sonrası müşteri işletmeyi puanlayıp yorumlayabilir.
- Keşfet ve Takip akışları gerçek Supabase verisini kullanır; paylaşım, beğeni, yorum, kaydetme, takip ve silme işlemleri veritabanına bağlıdır.
- Mesajlaşma, kişi bazlı mesaj gizleme, işletme sohbeti ve paylaşım yapan çalışanla özel sohbet desteklenir.
- Bildirim merkezi, randevu, mesaj, takip, beğeni, yorum ve destek olaylarını gösterir; kullanıcı bildirim türlerini ayrı ayrı açıp kapatabilir.
- Destek talepleri müşteri ve ana yönetici arasında iki yönlü mesajlaşma ve durum takibi sağlar.
- Ana yönetici işletmeleri, kullanıcıları, Keşfet görünürlüğünü ve destek taleplerini yönetebilir.
- Profilde telefon düzenleme, şifre değiştirme, profil fotoğrafı, çıkış, mevcut şifreyle doğrulanan kalıcı müşteri hesabı silme ve aktif cihazları uzaktan kapatma bulunur.

## Tamamlanması gerekenler

- Firebase/FCM anlık push teslimatı.
- Yeni cihaz girişinde e-posta doğrulaması.
- Ana yönetici tarafından alt yönetici ekleme ve ayrıntılı yetki matrisi.
- Türkçe/İngilizce dil seçimi ve açık/koyu tema.
- Bağlantı kesilmesi uyarısı ve bağlantı gelince otomatik yenileme.
- Profil fotoğrafı için kare kırpma/önizleme arayüzü.
- iOS/App Store hazırlığı ve son cihaz testleri.

## Android derlemesi

Android APK, son kaynak commit'i için analiz, test ve release derlemesi tamamlandıktan sonra paylaşılmalıdır.

Yerel komutlar:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

APK iş akışı ana dala gönderimde veya GitHub Actions üzerinden manuel başlatıldığında çalışır.

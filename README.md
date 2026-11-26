# Kuaförüm

Kadın kuaförleri için Flutter tabanlı salon keşif, randevu, sosyal paylaşım ve işletme yönetimi uygulaması.

## Uygulama kapsamı

- Normal kayıt yalnızca müşteri hesabı oluşturur; e-posta, ad, soyad ve telefon zorunludur.
- Çalışan, işletme sahibinin oluşturduğu davet kodunu müşteri hesabıyla giriş sırasında kullanarak çalışan hesabına geçer.
- İşletmeler ana yönetici tarafından onaylanır.
- Müşteri işletmeye katılım koduyla bağlanabilir; profilinden bağlı işletmelerini ve takip ettiklerini yönetebilir.
- İşletme sahibi çalışan, hizmet, işletme profili, çalışma saatleri ve randevu aralığını yönetebilir.
- Çalışan kendi randevularını, çalışma saatlerini ve izin taleplerini yönetir. İzin taleplerini işletme sahibi onaylar/reddeder.
- Müşteri işletme, hizmet, çalışan ve uygun saat seçerek randevu talebi oluşturabilir. Kara liste/özel onay, randevu iptali ve gelmeme kuralları veritabanında uygulanır.
- İşletme geçici kapatıldığında yeni randevu alınamaz; mevcut randevular korunur.
- Keşfet ve Takip akışları gerçek Supabase verisiyle çalışır; paylaşım, beğeni, yorum, kaydetme, takip ve paylaşım silme işlemleri veritabanına bağlıdır.
- Aktif işletmelerin paylaşımları Keşfet'te herkese açıktır. Üst sıralama hakkı olan işletmeler yönetici kontrolüyle öne çıkar; sıralamada etkileşim ve işletme puanları dikkate alınır.
- Mesajlaşma, kişi bazlı gizleme, işletme sohbeti ve çalışanla özel sohbet desteklenir. İşletme sahibi çalışanların özel sohbetlerini okuyamaz.
- Bildirim merkezi, takip/beğeni/yorum/paylaşım/mesaj ve randevu bildirimlerini gösterir.
- Destek talepleri müşteri ve ana yönetici arasında iki yönlü mesajlaşma ve durum takibi sağlar.
- Ana yönetici işletmeleri, kullanıcıları, Keşfet öne çıkarma ve destek taleplerini yönetebilir.

## Bilinen tamamlanmamış işler

- Firebase/FCM anlık push bildirimi ve bildirim türü tercih ekranı henüz tamamlanmadı; mevcut bildirim merkezi uygulama içidir.
- Yeni cihaz girişinde e-posta doğrulaması ve aktif cihaz/oturum yönetimi henüz tamamlanmadı.
- Hesabı uygulama içinden kalıcı silme akışı ve ayrıntılı yetkili-alt yönetici izin matrisi henüz tamamlanmadı.
- App Store/iOS dağıtım ve son cihaz testleri yapılmadı.
- İşletme puanlaması yalnızca tamamlanan randevudan sonra yapılabilir; ana yönetici dışındaki kullanıcılar değerlendirmeyi düzenleyemez.

## Android derlemesi

GitHub Actions release APK üretir. Son APK, son kaynak commit'i için analiz, test ve release derlemesi tamamlandıktan sonra paylaşılmalıdır.

Yerel komutlar:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

# Kuaförüm — Test Kontrol Listesi

Bu liste Android cihaz üzerinde ilk kullanıcı testinden önce ve test sırasında kullanılacak. Gerçek müşteri verisi yerine test hesapları ve test işletmesi kullan.

## 0. Test öncesi hazırlık

- [ ] Supabase Auth > URL Configuration > Additional Redirect URLs alanına `com.gazinizx.kuaforum://reset-password` ekle.
- [ ] Supabase Auth e-posta sağlayıcısının test e-postaları gönderebildiğini doğrula.
- [ ] Bir müşteri, bir işletme sahibi, o işletmeye bağlı en az bir çalışan ve bir ana yönetici test hesabı hazırla.
- [ ] İşletme hesabında en az iki aktif hizmet, fiyat/süre bilgisi, bir çalışan ve çalışma saatleri tanımla.
- [ ] Test hesaplarının doğru hesap türüne sahip olduğunu doğrula. Rol seçme geliştirici ekranı rol yetkisi vermez; gerçek hesap rolü sunucudan doğrulanır.
- [ ] APK kurulumu ve cihaz testleri, kullanıcı açıkça derleme istediğinde yapılır.

## 1. Giriş, kayıt ve oturum

- [ ] Yeni müşteri hesabı ad, soyad, telefon, e-posta ve en az 8 karakter şifre ile oluşturulabiliyor.
- [ ] Eksik veya geçersiz alanlarda anlaşılır doğrulama mesajı gösteriliyor.
- [ ] E-posta doğrulaması açıksa doğrulama sonrası aynı hesapla giriş yapılabiliyor.
- [ ] İşletme kaydı işletme adı/adresiyle oluşturuluyor ve ilk durumda onay bekliyor.
- [ ] Uygulama kapatılıp açıldığında oturum korunuyor.
- [ ] Profilim > Çıkış Yap sonrasında giriş ekranına dönülüyor.
- [ ] Engellenmiş hesap uygulamaya alınmıyor.

## 2. Şifre sıfırlama

- [ ] Giriş ekranından Şifremi Unuttum açılıyor.
- [ ] Geçersiz e-posta biçimi reddediliyor.
- [ ] Kayıtlı e-posta adresine sıfırlama bağlantısı ulaşıyor.
- [ ] Bağlantı Kuaförüm uygulamasını açıyor.
- [ ] Yeni şifre ve tekrar alanları eşleşme/uzunluk kontrolünden geçiyor.
- [ ] Yeni şifreyle yeniden giriş yapılabiliyor.

## 3. Müşteri akışı

- [ ] Salon arama, salon profili ve hizmet bilgileri açılıyor.
- [ ] Müşteri işletme ve çalışan profillerini takip edebiliyor.
- [ ] Keşfet tüm uygun herkese açık paylaşımları; Takip akışı takip edilen hesapların paylaşımlarını gösteriyor.
- [ ] Hizmet, çalışan, tarih ve uygun saat seçilerek randevu talebi oluşturuluyor.
- [ ] Randevu müşteri ekranında doğru durumla görünüyor.
- [ ] Müşteri kendi randevusunu iptal edebiliyor.
- [ ] Müşteri başka müşterinin randevusunu veya özel işletme verisini göremiyor.

## 4. Çalışan akışı

- [ ] İşletme davet kodu çalışan hesabını doğru işletmeye bağlıyor.
- [ ] Çalışan yalnızca kendi randevularını görüyor.
- [ ] Çalışan paylaşım oluşturup kendi profilinde yayınlayabiliyor.
- [ ] Müşteri, paylaşım yapan çalışanla mesaj başlatabiliyor; mesajlaşma erişimi olmayan çalışanlara açılamıyor.
- [ ] Çalışan başka çalışanın randevusunu veya yönetim ayarlarını değiştiremiyor.

## 5. İşletme sahibi akışı

- [ ] İşletme sahibi kendi randevularını çalışan randevularından ayrı görüyor.
- [ ] Çalışan randevuları listesinde randevunun hangi çalışana ait olduğu doğru.
- [ ] Hizmet, fiyat, süre, çalışma saati ve randevu aralığı ayarları kaydediliyor.
- [ ] Çalışan ekleme/davet ve aktif-pasif işlemleri çalışıyor.
- [ ] Müşteri listesi ve ayrı Kara Liste ekranı açılıyor.
- [ ] İşletme sahibi müşteriyi kara listeye ekleyip çıkarabiliyor; gerekçe notu doğru görünüyor.
- [ ] Kara listedeki müşterinin yeni randevu talebi işletme onayına düşüyor.
- [ ] Üç gelmeme kaydından sonra otomatik kara liste davranışı doğrulanıyor.
- [ ] İşletme sahibi başka işletmenin müşterisini veya kara liste kayıtlarını değiştiremiyor.

## 6. Ana yönetici

- [ ] Ana yönetici olmayan hesap yönetim ekranına erişemiyor.
- [ ] Bekleyen işletme onaylanabiliyor veya askıya alınabiliyor.
- [ ] Kullanıcı kısıtlama ve kısıtlamayı kaldırma işlemleri çalışıyor.
- [ ] Ücretli erişim yetkisi olan işletmenin Keşfet görünürlüğü yönetilebiliyor.
- [ ] İşletme sahibi kendi onay veya ücretli Keşfet yetkisini değiştiremiyor.

## 7. Bildirim ve hata koşulları

- [ ] İnternet kesildiğinde uygulama çökmek yerine anlaşılır hata/yeniden dene durumu gösteriyor.
- [ ] Yetkisiz kayıt ve RPC çağrıları veritabanı tarafından reddediliyor.
- [ ] Uygulama içi bildirim merkezi kontrol ediliyor.
- [ ] Firebase Cloud Messaging gerçek push teslimi henüz tamamlanmadığından push bildirimi bu test turunda geçme kriteri değildir; ayrı entegrasyon testi gerekir.

## Test sonucu kaydı

Her senaryo için: **Geçti / Kaldı / Test edilemedi** olarak işaretle. Kalan senaryoda ekran görüntüsü, test hesabının rolü, yapılan adımlar ve hata metnini not et. Gerçek kullanıcı bilgilerini test notlarına yazma.

## Mevcut doğrulama sınırı

Bu dosya ve widget testleri test hazırlığıdır; Flutter analyze, flutter test, cihazda uçtan uca test veya APK derlemesi çalıştırıldığı anlamına gelmez. Bu kontroller ayrı olarak yürütülmelidir.

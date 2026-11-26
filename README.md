# Kuaförüm

Kadın kuaförleri için salon keşif, randevu ve sosyal paylaşım uygulaması.

## Uygulama özellikleri

### Sosyal alan
- Müşteri, çalışan ve işletme profilleri; profil fotoğrafı ve salon logosu
- Instagram benzeri ortak Keşfet akışı ve ayrı Takip akışı
- İşletme ve çalışan takip etme; takipçi/takip edilen listeleri
- Fotoğraf/video paylaşımı, beğeni, yorum, açıklama düzenleme, silme ve şikâyet
- Keşfet araması ve paylaşım kategorileri
- Paylaşım yapan uygun çalışanlarla müşteri arasında mesajlaşma

### Randevu ve işletme
- Aktif işletme arama, işletme profilleri ve katılım koduyla üyelik
- İşletme sahibine özel katılım kodu gösterimi ve kopyalama
- İşletme adı/adresi düzenleme; randevu aralığı ve çalışma saatleri yönetimi
- Hizmet, fiyat, süre ve çalışan yönetimi
- Çalışan daveti oluşturma, davet kodunu kullanma ekranı ve çalışanı aktif/pasif yapma
- Çalışan, mevcut müşteri hesabıyla giriş yapıp tek kullanımlık davet kodunu doğrulayınca otomatik olarak çalışan rolüne geçer
- Haftalık çalışma saatleri ve randevu aralığı ayarları
- Gerçek uygun saat hesabı ve randevu oluşturma
- Müşteri, çalışan ve işletme sahibi için ayrı randevu görünümleri
- Üç gelmeme kaydından sonra otomatik kara liste; işletme sahibi manuel ekleme/çıkarma yapabilir.
- Kara listedeki müşterinin yeni randevu talepleri işletme onayına düşer.
- Kara listedeki müşterinin yeni randevularında işletme onayı
- İşletme panelinde ayrı Kara Liste menüsü ve Müşterilerim içinden filtre; işletme sahibi müşteri ekleyebilir/çıkarabilir, gerekçe notu görebilir ve randevu/gelmeme kayıtlarını inceleyebilir

### Ana yönetici
- İşletmeleri listeleme, onaylama ve askıya alma
- Kullanıcıları listeleme, kısıtlama ve kısıtlamayı kaldırma
- Ücretli erişim hakkı olan işletmelerin Keşfet görünürlüğünü açıp kapatma
- Yeni işletmeler varsayılan olarak onay bekler; işletme sahibi kendi durumunu veya ücretli Keşfet yetkisini değiştiremez
- Yetki kontrolleri istemci arayüzüne bırakılmaz; veritabanı tarafında da doğrulanır

### Hesap ve oturum
- Supabase oturumu cihazda saklanır; kullanıcı Profilim / Hesap bölümünden Çıkış Yap demedikçe giriş açık kalır.
- Giriş ekranında e-posta ile Şifremi Unuttum akışı ve uygulama içinde yeni şifre belirleme ekranı bulunur.

### Güvenlik
- Profil tablosunda e-posta, telefon ve yetki alanları doğrudan istemci okumasına kapalıdır
- İşletme katılım kodu ve Keşfet ödeme/yayın yetkileri doğrudan istemci erişimine kapalıdır; sahip/yönetici işlemleri doğrulamalı RPC ile yapılır
- Yönetici kullanıcı listesi, yönetici yetkisini doğrulayan ayrı RPC üzerinden gelir
- Herkese açık profil görünümleri güvenlik invoker ve RLS kurallarıyla çalışır
- Fotoğraf/video depolama izinleri ve mesajlaşma erişimi RLS ile korunur

## Auth veritabanı migration'ı
- `supabase/migrations/20261126140000_auth_signup_and_business_registration.sql`
- `supabase/migrations/20261126150000_restrict_auth_trigger_function_execution.sql`

## Henüz tamamlanması gerekenler
- Supabase Auth panelinde `com.gazinizx.kuaforum://reset-password` adresinin Additional Redirect URLs listesine eklenmesi gerekiyor.
- iOS uygulama projesi oluşturulduğunda aynı şifre sıfırlama bağlantısı için URL scheme kaydı yapılacak.
- Şifre sıfırlama bağlantısının gerçek cihazda e-posta üzerinden uçtan uca testi.
- Firebase Cloud Messaging ile gerçek push bildirim teslimi. Uygulama içi bildirim merkezi vardır; push teslimi henüz bağlanmamıştır.
- iOS yapılandırması, imzalama ve App Store hazırlığı.
- Son cihaz testleri, Flutter analiz/test ve yayın derlemesi.

## Android derleme
Android APK iş akışı yalnızca kullanıcı açıkça istediğinde GitHub Actions içinden manuel başlatılır. Kod güncellemeleri otomatik derleme başlatmaz.

Yerel komutlar:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

İşletme kayıt RPC'si ve profil rol/yönetici/engelli alanlarının kullanıcı tarafından değiştirilememesi SQL transaction içinde test edildi; test verisi rollback ile geri alındı. Auth kullanıcı oluşturma trigger'ı kuruldu ve veritabanında doğrulandı. Gerçek e-posta kayıt/doğrulama akışı cihaz testi aşamasında doğrulanacak.

Bu dalda henüz Flutter analizi, test veya APK derlemesi çalıştırılmadı.


## Geliştirici test APK'sı
- `KUAFORUM_TEST_MODE=true` ile açıldığında dört ayrı yerel demo kimliği sunulur: müşteri, çalışan, işletme sahibi ve ana yönetici.
- Demo profilleri, akış gönderileri, beğeniler, sohbetler, yerel mesaj gönderimi, randevu örnekleri, bildirimler ve ana yönetici Keşfet görünürlüğü kontrolü Supabase'e yazmadan çalışır.
- Rol menüsünden geçiş, seçilen rolün ayrı demo kimliğine ve kendi örnek içeriklerine geçer.
- Test modunda gerçek davet kodu/Auth işlemleri açılmaz. Üretim derlemesinde `AuthGate` ve mevcut Supabase tabanlı ekranlar korunur.
- Demo mesajları ve gönderileri yalnızca uygulama belleğinde tutulur; uygulama kapatılınca sıfırlanır. Fotoğraf yükleme, gerçek rezervasyon, gerçek bildirim teslimi ve canlı mesajlaşma bu yerel demo kapsamına dahil değildir.

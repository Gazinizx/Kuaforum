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
- Çalışan daveti ve çalışanı aktif/pasif yapma
- Haftalık çalışma saatleri ve randevu aralığı ayarları
- Gerçek uygun saat hesabı ve randevu oluşturma
- Müşteri, çalışan ve işletme sahibi için ayrı randevu görünümleri
- Üç gelmeme kaydından sonra otomatik kara liste; işletme sahibinin yönetimi
- Kara listedeki müşterinin yeni randevularında işletme onayı
- İşletme müşteri listesi, randevu ve gelmeme kayıtları

### Ana yönetici
- İşletmeleri listeleme, onaylama ve askıya alma
- Kullanıcıları listeleme, kısıtlama ve kısıtlamayı kaldırma
- Ücretli erişim hakkı olan işletmelerin Keşfet görünürlüğünü açıp kapatma
- Yetki kontrolleri istemci arayüzüne bırakılmaz; veritabanı tarafında da doğrulanır

### Güvenlik
- Profil tablosunda e-posta, telefon ve yetki alanları doğrudan istemci okumasına kapalıdır
- İşletme katılım kodu ve Keşfet ödeme/yayın yetkileri doğrudan istemci erişimine kapalıdır; sahip/yönetici işlemleri doğrulamalı RPC ile yapılır
- Yönetici kullanıcı listesi, yönetici yetkisini doğrulayan ayrı RPC üzerinden gelir
- Herkese açık profil görünümleri güvenlik invoker ve RLS kurallarıyla çalışır
- Fotoğraf/video depolama izinleri ve mesajlaşma erişimi RLS ile korunur

## Henüz tamamlanması gerekenler
- Normal müşteri/işletme kayıt ve giriş akışı ile çalışan davet kodu üzerinden hesap aktivasyonu. Hızlı rol/test ekranı yalnızca geliştirme testi içindir; normal giriş akışı son aşamada yapılacaktır.
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

Bu dalda henüz Flutter analizi, test veya APK derlemesi çalıştırılmadı.

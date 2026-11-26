# Kuaförüm – Uygulama Denetimi ve Test Planı

Bu plan Android müşteri, çalışan, işletme sahibi ve ana yönetici akışlarını kapsar. CI'daki Flutter testleri gerçek Supabase hesabı/cihaz uçtan uca testinin yerine geçmez.

## Bu denetimde ele alınan düzeltmeler
- Ana sayfa ve işletme paneli kısayolları gerçek sayfa geçişlerine bağlandı.
- Randevu oluşturma ve uygun saat sorgularındaki işletme üyeliği zorunluluğu kaldırıldı. Aktif hesap, aktif işletme, hizmet, çalışan, çalışma saati, mola, çakışma ve kara liste onayı kontrolleri korunuyor.
- İşletme sahiplerinin başka aktif işletmelerle sohbet başlatması etkinleştirildi. Gönderen işletme veritabanında saklanıyor ve sunucu tarafında sahiplik doğrulanıyor.
- Yorum düzenleme penceresi alt panel olarak yenilendi.
- Paylaşım fotoğraflarına kırpma/düzenleme ve seçilen medyayı kaldırma eklendi.
- Herkese açık işletme profilinin üst alanı yeniden tasarlandı.
- Profilde ad-soyad ve telefon güncelleme alanları eklendi/iyileştirildi.

## Android manuel kabul testleri

### 1. Kayıt ve oturum
- [ ] Müşteri kaydı: ad, soyad, telefon, e-posta ve şifre doğrulaması.
- [ ] Mevcut müşteri hesabıyla e-posta/şifre girişi.
- [ ] Yeni cihazda uygulama içi OTP sorulmaması.
- [ ] Oturumu kapatma ve uygulamayı yeniden açma.
- [ ] Şifre sıfırlama ve şifre değiştirme.
- [ ] Engellenmiş hesabın uygulamaya erişememesi.

### 2. Müşteri profili
- [ ] Ad-soyad düzenleme ve kalıcılık.
- [ ] Telefon numarası: 05xxxxxxxxx, +905xxxxxxxxx ve hatalı numara kontrolleri.
- [ ] Profil fotoğrafı seçme, kırpma, yükleme ve görüntülenme.
- [ ] İşletmeye katılma/ayrılma (katılım kodu yalnızca üyelik için).
- [ ] Aktif cihazları görme ve diğer oturumu kapatma.

### 3. Ana sayfa ve keşif
- [ ] Arama alanı işletme/çalışan dizinini açmalı.
- [ ] Hero kartı işletme keşfini açmalı.
- [ ] Randevu Al, Keşfet, Takip Edilen kısayolları çalışmalı.
- [ ] İşletme kartı doğru işletme profiline gitmeli.
- [ ] Tümünü Gör işletme dizinini açmalı.
- [ ] Keşfet ve Takip akışları yenileme, boş durum ve hata durumlarını göstermeli.

### 4. Randevu
- [ ] Üye olmayan müşteri işletme profilinden randevu oluşturabilmeli.
- [ ] Hizmet/çalışan/tarih seçimi ve uygun saatler doğru gelmeli.
- [ ] Çalışma saatleri, izinler, işletme molaları ve mevcut randevular slotları filtrelemeli.
- [ ] Randevu oluşturma ve dolu saati reddetme.
- [ ] Kara listedeki müşteri için işletme onayı gerektiren akış.
- [ ] Müşteri randevu iptali.
- [ ] İşletme sahibi kendi randevuları ile çalışan randevularını ayrı görmeli.
- [ ] Çalışan yalnızca kendi randevularını görmeli.
- [ ] Tamamlanan randevuda değerlendirme ekleme/düzenleme/silme.

### 5. Sosyal akış ve paylaşım
- [ ] Fotoğraf seçme, kırpma, önizleme ve seçimi kaldırma.
- [ ] Video seçme ve paylaşma.
- [ ] Açıklama zorunluluğu ve 500 karakter sınırı.
- [ ] Paylaşımın doğru işletme/çalışan kimliğiyle yayınlanması.
- [ ] Beğeni, yorum ekleme/düzenleme/silme, kaydetme ve kendi gönderisini silme.
- [ ] Keşfet ve Takip akışlarında gönderi görünürlüğü.
- [ ] Paylaşım yapan çalışanla müşteri sohbeti.
- [ ] İşletme keşfet görünürlüğü ve yönetici kontrolü.

### 6. Mesajlaşma
- [ ] Müşteri-işletme mesajlaşması.
- [ ] Müşteri-paylaşım yapan çalışan mesajlaşması.
- [ ] İşletme sahibi başka işletme arayıp sohbet başlatabilmeli.
- [ ] Alıcı işletme sohbeti görüp yanıtlayabilmeli.
- [ ] Sohbet listesinde doğru işletme adı görünmeli.
- [ ] Mesaj gönderme, yenileme, kişi bazlı gizleme ve oturum yetkileri.

### 7. İşletme ve çalışan yönetimi
- [ ] İşletme profili, logo ve iletişim bilgileri.
- [ ] Hizmet ekleme/düzenleme/aktif-pasif.
- [ ] Çalışan daveti, ilk giriş, devre dışı bırakma ve kaldırma.
- [ ] İşletme/çalışan çalışma saatleri ve izin talepleri.
- [ ] Randevu aralığı ve geçici kapanış.
- [ ] Müşteri listesi ve kara liste ekleme/çıkarma.

### 8. Destek ve yönetim
- [ ] Destek talebi oluşturma ve ilk mesaj.
- [ ] Müşteri-ana yönetici destek mesajları.
- [ ] Alt yöneticinin yalnızca destek izni varsa taleplere erişmesi.
- [ ] Ana yönetici işletme/kullanıcı/Keşfet/alt yönetici işlemleri.
- [ ] Alt yönetici yetkilerini verme, değiştirme ve kaldırma.
- [ ] Engelli/izinsiz hesabın yönetim fonksiyonlarına erişememesi.

### 9. Genel cihaz kontrolü
- [ ] Android geri tuşu ve sayfa geçişleri.
- [ ] Yavaş internet, internet kesilmesi ve yeniden bağlanma.
- [ ] Fotoğraf/video yükleme ve büyük dosya hataları.
- [ ] Uygulamanın arka plana alınıp geri açılması.
- [ ] Küçük ekran ve klavye açıkken taşma/örtüşme.
- [ ] Bildirim merkezi tercihleri; gerçek FCM push ayrı test edilir.

## Açık işler / doğrulanması gerekenler
- Firebase FCM gerçek cihaz token kaydı ve push teslimatı tamamlanmadı.
- Supabase e-posta şablonu / kayıt e-posta onayı gerçek e-posta ile kontrol edilmeli.
- Türkçe/İngilizce dil seçimi, açık/koyu tema ve çevrimdışı otomatik yenileme henüz tamamlanmadı.
- Test klasöründe yalnızca temel widget testi bulunuyor; kritik iş akışları için entegrasyon ve regresyon testleri eklenmeli.
- iOS derlemesi ve App Store hazırlığı Android kabulünden sonra yapılmalı.

## Yayın kapısı
Son kaynak değişiklikleri için flutter analyze, flutter test ve flutter build apk --release başarılı olmalı. CI yeşil olsa bile gerçek Supabase hesaplarıyla manuel cihaz testleri tamamlanmadan uygulama yayın adayı sayılmamalı.

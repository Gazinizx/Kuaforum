# Kuaförüm

Kadın kuaförleri için Flutter tabanlı randevu, sosyal akış ve çalışan-müşteri mesajlaşma uygulaması.

## Modüller
- Müşteri, işletme sahibi ve çalışan hesapları
- İşletme ve çalışan randevu yönetimi
- Çalışanların fotoğraf/video paylaşabildiği **Takip Edilen** ve **Keşfet** akışları
- Müşterinin paylaşım yapan çalışanla birebir sohbeti
- Ana yönetici tarafından işletme bazında ücret ve Keşfet yetkilendirmesi
- Supabase Auth, PostgreSQL, RLS, Storage ve Realtime

## Backend
Kuaförüm kendi Supabase projesini kullanır: `zhvfudtdnvgsqywojjrz` (Frankfurt).
Berberim'in Supabase projesiyle veri paylaşmaz. İstemciye yalnızca publishable key verilir; service-role anahtarı uygulamaya konmaz.

## Android APK
GitHub Actions → **Build Kuaforum Android APK** → son başarılı çalışmanın Artifacts alanı → `kuaforum-release-apk`.

## Apple
**Build Kuaforum iOS (unsigned)** iş akışı imzasız iOS uygulaması üretir. TestFlight/App Store dağıtımı için Apple Developer üyeliği, signing certificate, provisioning profile ve App Store Connect yapılandırması gerekir.

## Bildirimler
Kuaförüm'e ait ayrı Firebase Android/iOS yapılandırmaları henüz eklenmedi. Bu nedenle push bildirimleri Firebase kurulumu tamamlanana kadar etkin değildir.

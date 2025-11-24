# Dynamic Notch

Dynamic Notch, macOS çentiğinin hemen altında çalışan ve Control Center tarzı kontrolleri tek panelde toplayan hafif bir yardımcı uygulamadır. Pencere, fare çentiğe yaklaştığında açılır ve uzaklaştığında kapanır; Dock’ta görünmez ve sistemin en üstünde konumlanır.

## Özellikler

- NSPanel tabanlı, dinamik açılıp kapanan pencere
- CPU / RAM / Disk / GPU / İnternet göstergeleri
- Ekran kaydı kısayolu, dosya tutabilen pano kutusu
- Pomodoro sayacı (çalışma–mola döngüsü)
- Google Gemini destekli AI sohbeti
- Koyu tema uyumlu, cam efektiyle tasarlanmış arayüz

## Gereksinimler

- macOS Sonoma veya üzeri
- Xcode 15+
- (Opsiyonel) `/usr/local/bin/brightness` CLI’si parlaklık kontrolü için

## Kurulum

1. Depoyu klonla:
   ```bash
   git clone https://github.com/k4gan/dynamic-notch
   cd dynamicnotch
   ```
2. `NotchViewModel.swift` içerisindeki `geminiAPIKey` değerini Google AI Studio’dan aldığın anahtarla değiştir.
3. Derle ve çalıştır:
   ```bash
   swift build
   swift run DynamicNotch
   ```

## İlk Çalıştırma

Uygulama ilk açıldığında macOS şu izinleri isteyecektir:

- **Erişilebilirlik**: parlaklık/ekran kaydı kısayolları için
- **Ekran Kaydı**: Cmd+Shift+5 entegrasyonu için

Sistem Ayarları > Güvenlik ve Gizlilik bölümünden izin vererek devam edebilirsin.

## Kullanım

- Fareyi çentik bölgesine getir ince gizli panel açılır; uzaklaşınca kapanır.
- Pano kartına dosya sürükleyip bırakarak saklayabilir, listedeki öğeleri tekrar sürükleyebilirsin.
- Pomodoro butonuna tıklayarak çalışma/mola sayacını başlat, sağ tıkla “Sıfırla” diyebilirsin.
- AI Chat bölümünde Gemini API’si üzerinden hızlı yanıtlar alabilirsin.

Herhangi bir sorun durumunda `/tmp/dynamicnotch.log` kayıtlarını kontrol edip bizimle paylaşabilirsin.


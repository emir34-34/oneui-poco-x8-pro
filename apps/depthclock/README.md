# Derinlik Saati (LSPosed)

HyperOS 4 kilit ekranı düzenleyicisinin "Saat belirsiz. Derinlik efekti kullanılamıyor."
kontrolünü kapatan LSPosed modülü. Duvar kağıdındaki nesne saatin ne kadarını kapatırsa
kapatsın derinlik efekti açık kalır.

## Nasıl çalışıyor

Düzenleyici `com.miui.aod` paketinin içinde (`com.miui.keyguard.editor`).
`CalculateWorker.calculateUnAlphaPercent()` saat dikdörtgeninde nesnenin kapattığı
pikselleri sayar ve şu sınırlarla karşılaştırır:

| Duvar kağıdı | Sınır (`*_AVOID_RATE`) |
|---|---|
| Resim | 0.2 (%20) |
| Derinlik videosu | 0.5 (%50) |

Sınır aşılırsa `false` döner, efekt kapanır ve `kg_dialog_too_much_time_blocking`
uyarısı gösterilir. Modül hesap bittiğinde sonucu `true` yapar. `null` (görüntü hazır değil)
sonucuna dokunmaz. Efekti elle kapatma düğmesi ayrı bir bayrak olduğu için çalışmaya devam eder.

Çift saat (dual clock) açıkken düzenleyici kontrolü hiç yapmadan efekti kapatıyor.
Bu modül o durumu değiştirmez.

İncelenen sürüm: MIUIAod `DEV-2455.2.0.1-10230949`, HyperOS `OS4.0.5.0.XPJCNXM`.
Sınıf adları başka bir sürümde değişirse LSPosed günlüğünde `DepthClock: hook failed` yazar.

## Kurulum

1. `DepthClock.apk` dosyasını normal bir uygulama gibi kur.
2. LSPosed → Modüller → Derinlik Saati → etkinleştir. Kapsamda `com.miui.aod` seçili olsun.
3. Düzenleyiciyi yeniden başlat: `su -c am force-stop com.miui.aod`
4. Kilit ekranı düzenleyicisini aç ve derinlik efektini yeniden aç.

## Derleme

`./build.sh` (Android SDK: build-tools 35.0.0, platform android-35). Xposed API için
yalnızca derlemede kullanılan taslak sınıflar `stubs/` klasöründe. Bunlar APK'ya girmez,
gerçeklerini LSPosed sağlıyor.

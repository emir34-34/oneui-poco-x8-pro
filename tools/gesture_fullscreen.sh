#!/bin/bash
# Kullanım: gesture_fullscreen.sh [apply|revert|status]
# Hareket çubuğunu (gesture hint) gizler, uygulamalar ekranın en altına kadar çizilir; alt kenara basılı
# tutunca Circle to Search (ve onun yerine geçen asistan) açılmaz. Kaydırma hareketleri çalışmaya devam eder.
# Root gerekmez: adb shell "settings" kullanır, ayarlar /data'da kalır (yeniden başlatmada silinmez).
S=${ADB_SERIAL:+-s $ADB_SERIAL}
A="adb $S shell"
case "${1:-apply}" in
apply)
  $A '
    # Samsung: kaydırma hareketleri modu (1) + ipucu çubuğu kapalı (0). İpucu kapalıyken One UI alt boşluğu
    # (gesture inset) uygulamalara bırakır: içerik çubuğun durduğu yere kadar uzanır.
    settings put global navigation_bar_gesture_while_hidden 1
    settings put global navigation_bar_gesture_hint 0
    # Circle to Search: alt kenara / tutamağa basılı tutma ve ana sayfaya basılı tutma girişleri kapalı.
    settings put secure search_press_hold_nav_handle_enabled 0
    settings put secure search_long_press_home_enabled 0
    # CTS kapalıyken uzun basma asistanı (Gemini) açar; o da kapalı -> alt kenara basılı tutmak hiçbir şey yapmaz.
    settings put secure assist_long_press_home_enabled 0
    echo "uygulandi"'
  ;;
revert)
  $A '
    settings put global navigation_bar_gesture_hint 1
    settings put secure search_press_hold_nav_handle_enabled 1
    settings put secure search_long_press_home_enabled 1
    settings put secure assist_long_press_home_enabled 1
    echo "geri alindi"'
  ;;
status) ;;
*) echo "kullanim: $0 [apply|revert|status]"; exit 1 ;;
esac
# Durum: ilgili tüm anahtarlar + gerçek alt boşluk (navigationBars / mandatorySystemGestures inset).
$A '
  for k in navigation_bar_gesture_while_hidden navigation_bar_gesture_hint; do echo "global $k=$(settings get global $k)"; done
  for k in navigation_mode search_press_hold_nav_handle_enabled search_long_press_home_enabled assist_long_press_home_enabled; do
    echo "secure $k=$(settings get secure $k)"; done
  echo "-- diger navigation/search anahtarlari:"
  { settings list global; settings list secure; } | grep -iE "navigation_bar|navigationbar|circle|contextual|search_.*(press|entry)" | sort -u
  echo "-- WindowManager inset (navigationBars yuksekligi 0 olmali):"
  dumpsys window | grep -iE "navigationBars|NavigationBar.*frame" | head -6'

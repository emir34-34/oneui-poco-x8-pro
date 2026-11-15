#!/system/bin/sh
# kleeledd: KleeToys komutlarini kamera halkasi LED'lerine (AW21024) yazar.
# Komut dosyasi (uygulama yazar, satir satir):
#   q RRGGBB RRGGBB RRGGBB RRGGBB   -> ust sol, ust sag, alt sag, alt sol
#   off                             -> hepsini kapat
# Fiziksel eslesme (2026-11-15 dogrulandi): grup 3=ust sol, 5=ust sag, 4=alt sag, 6=alt sol; 0,1,2,7 bos.
D=/sys/class/leds/aw21024_led
F=${1:-/data/user/0/com.klee.toys/files/led.cmd}

init_led() {
  echo 1 > $D/effect
  for j in 0 1 2 7; do echo "$j 000000" > $D/rgbcolor; done
}
off() { for j in 3 5 4 6; do echo "$j 000000" > $D/rgbcolor; done; echo 0 > $D/effect; }

while [ ! -f "$F" ]; do sleep 2; done
ON=
tail -n0 -F "$F" 2>/dev/null | while read c a b x y; do
  case "$c" in
    q) [ -n "$ON" ] || { init_led; ON=1; }
       echo "3 $a" > $D/rgbcolor; echo "5 $b" > $D/rgbcolor
       echo "4 $x" > $D/rgbcolor; echo "6 $y" > $D/rgbcolor ;;
    off) off; ON= ;;
  esac
done

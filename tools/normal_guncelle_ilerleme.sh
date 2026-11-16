#!/bin/bash
# One UI normal kurulum GUNCELLEME (slot B) — VERI KORUNUR: yalniz super + vbmeta_b, format YOK. Yuzde cubuklu.
# userdata/metadata/IMEI/boot bolumlerine dokunulmaz.
# Kullanim: normal_kur_ilerleme.sh work/normal_super/super_oneui_o9-N.img
set -e
cd "${KLEE_ROOT:-.}"
S="${KLEE_SERIAL:?set KLEE_SERIAL to the phone serial}"; Y="$(ls -d backups/ix-tam-yedek-* | tail -1)"; SUPER="$(realpath "${1:?super imaji}")"
FB(){ python3 -I tools/fastboot_ilerleme.py "$@"; }
adim(){ printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
trap 'printf "\n\033[1;31mHATA — durdu. Bu pencereyi kapatmadan Claude'"'"'a haber ver.\033[0m\n"; read -r' ERR

adim "1/5 Telefon bootloader'a alınıyor"
if adb -s $S get-state >/dev/null 2>&1; then
  adb -s $S shell getprop ro.build.display.id | grep -q A066B || { echo "Telefon One UI'da değil, durdu"; read -r; exit 1; }
  adb -s $S reboot bootloader
fi
printf 'fastboot bekleniyor'; until fastboot devices | grep -q $S; do printf .; sleep 1; done; echo " ✓"
[ "$(fastboot getvar is-userspace 2>&1 | grep -o 'is-userspace: [a-z]*' | cut -d' ' -f2)" = no ] || { echo "Bootloader fastboot değil (fastbootd?), durdu"; read -r; exit 1; }

adim "2/5 One UI super yazılıyor ($(basename "$SUPER"))"
FB super fastboot flash super "$SUPER"
adim "3/5 vbmeta_b (doğrulama kapalı)"
FB vbmeta_b fastboot --disable-verity --disable-verification flash vbmeta_b "$Y/vbmeta_b.img"
adim "4/5 Aktif slot b"
fastboot set_active b
adim "5/5 Yeniden başlatılıyor"
fastboot reboot
printf '\n\033[1;32mKurulum bitti ✓  One UI ilk açılış birkaç dakika sürebilir. Bu pencereyi kapatabilirsin.\033[0m\n'
read -r -t 600 || true

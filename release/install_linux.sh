#!/bin/sh
# One UI 9 for POCO X8 Pro (klee) - o9-65 TEST BUILD - clean install (WIPES DATA)
# Writes to the CURRENT active slot only. Never runs set_active. Never touches
# preloader, lk or IMEI partitions (nvram, nvdata, nvcfg, persist, protect1/2, md_sec, proinfo, seccfg).
cd "$(dirname "$0")" || exit 1
FB=fastboot
command -v $FB >/dev/null 2>&1 || { echo "fastboot not found. Install Android platform-tools first."; exit 1; }

echo "Checking files..."
sha256sum -c --quiet SHA256SUMS || { echo "Checksum FAILED. Download again."; exit 1; }

echo "Waiting for device in bootloader (fastboot) mode..."
prod=$($FB getvar product 2>&1 | awk '/^product:/{print $2}')
[ "$prod" = "klee" ] || { echo "This is not a POCO X8 Pro / klee (product: '$prod'). Stopped."; exit 1; }
us=$($FB getvar is-userspace 2>&1 | awk '/^is-userspace:/{print $2}')
[ "$us" = "yes" ] && { echo "You are in fastbootd. Run: fastboot reboot bootloader  and start again."; exit 1; }
slot=$($FB getvar current-slot 2>&1 | awk '/^current-slot:/{print $2}'); slot=${slot#_}
case "$slot" in a|b) ;; *) echo "Could not read the current slot ('$slot'). Stopped."; exit 1;; esac

echo
echo "Device: klee   Active slot: $slot   (the slot will NOT be changed)"
echo "This TEST build will be flashed to slot $slot and userdata + metadata will be ERASED."
echo "Make sure you have a full backup of all partitions and Fenrir lk + preloader installed."
printf "Type YES to continue: "
read -r ok
[ "$ok" = "YES" ] || { echo "Cancelled."; exit 0; }

set -e
PARTS="apusys audio_dsp ccu connsys_bt connsys_gnss connsys_wifi dpm gpueb gz mcupm modem mvpu_algo
       pi_img scp spmfw sspm tee vcp boot init_boot vendor_boot dtbo vbmeta_system vbmeta_vendor"
# Progress is weighted by bytes, so super (most of the data) moves the bar the most.
TOTAL=0; DONE=0
for p in $PARTS vbmeta super; do TOTAL=$((TOTAL + $(stat -c%s images/$p.img))); done
[ "$slot" = "a" ] && TOTAL=$((TOTAL + $(stat -c%s images/super_slot_a_meta.img)))
bar(){ pct=$((DONE * 100 / TOTAL)); n=$((pct * 40 / 100))
  printf '\n\033[1;36m[%s%s] %3d%%\033[0m  %s\n' "$(printf '%*s' $n '' | tr ' ' '#')" \
         "$(printf '%*s' $((40 - n)) '' | tr ' ' '.')" "$pct" "$1"; }
RCF=$(mktemp)
step(){ # step <label> <image or -> fastboot args...   (super moves the bar chunk by chunk)
  label=$1; img=$2; shift 2; bar "$label"
  size=0; [ "$img" != "-" ] && size=$(stat -c%s "$img")
  echo 1 > "$RCF"
  { $FB "$@" 2>&1 && echo 0 > "$RCF"; } | while IFS= read -r line; do
    echo "$line"
    case "$line" in
      Writing\ sparse*/*OKAY*)
        nm=$(echo "$line" | grep -oE '[0-9]+/[0-9]+' | head -1)
        n=${nm%/*}; m=${nm#*/}
        DONE_SAVE=$DONE; DONE=$((DONE + size * n / m)); bar "$label  (part $n/$m)"; DONE=$DONE_SAVE ;;
    esac
  done
  [ "$(cat "$RCF")" = 0 ] || { printf "\n\033[1;31mFAILED: %s. Do NOT reboot. Ask for help with this output.\033[0m\n" "$label"; exit 1; }
  DONE=$((DONE + size))
  return 0; }

for p in $PARTS; do step "${p}_$slot" images/$p.img flash ${p}_$slot images/$p.img; done
step "vbmeta_$slot (verification off)" images/vbmeta.img --disable-verity --disable-verification flash vbmeta_$slot images/vbmeta.img
step "super (big, takes a few minutes)" images/super.img flash super images/super.img
[ "$slot" = "a" ] && step "super slot A metadata" images/super_slot_a_meta.img flash super images/super_slot_a_meta.img
step "erase metadata" - erase metadata
step "wipe userdata" - -w
DONE=$TOTAL; bar "rebooting"
$FB reboot
echo
echo "Done. First boot takes a few minutes. Finish setup and wait 3+ minutes before the first reboot."

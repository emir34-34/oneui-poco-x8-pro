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
for p in apusys audio_dsp ccu connsys_bt connsys_gnss connsys_wifi dpm gpueb gz mcupm modem mvpu_algo \
         pi_img scp spmfw sspm tee vcp boot init_boot vendor_boot dtbo vbmeta_system vbmeta_vendor; do
  $FB flash ${p}_$slot images/$p.img
done
$FB --disable-verity --disable-verification flash vbmeta_$slot images/vbmeta.img
$FB flash super images/super.img
[ "$slot" = "a" ] && $FB flash super images/super_slot_a_meta.img
$FB erase metadata
$FB -w
$FB reboot
echo
echo "Done. First boot takes a few minutes. Finish setup and wait 3+ minutes before the first reboot."

One UI 9 for POCO X8 Pro (klee) - o9-65 TEST BUILD
====================================================

NOT FOR DAILY USE. Experimental port, for testing only. It has bugs.
Best for people who can use adb/logcat, ideally with an AI coding assistant.

What it is
- One UI 9 (Galaxy A06 SM-A066B base + some S26 Ultra parts), Android 17
- Kernel, vendor and firmware from Infinity X 4.1 (18.10.2026), SELinux Enforcing
- Installs to the CURRENT active slot. The scripts never switch slots.
- Tested on slot B only. Slot A uses the same image plus a 1 MiB partition-table
  patch (images/super_slot_a_meta.img) and is UNTESTED.

Requirements
- Fenrir lk + preloader (writes must work from the bootloader)
- Android platform-tools (fastboot) on your PC
- A FULL backup of all partitions. Keep it safe.
- NEVER flash or erase IMEI partitions: nvram, nvdata, nvcfg, persist,
  protect1/2, md_sec, proinfo, seccfg

Install (wipes userdata + metadata)
Recommended: let an AI assistant (Claude Code etc.) guide the install.
Open AI_INSTALL_PROMPT.txt and follow it.

Manual:
1. Reboot to the bootloader (fastboot mode, NOT fastbootd).
2. Linux: sh install_linux.sh     Windows: install_windows.bat
3. Type YES when asked.
4. First boot takes a few minutes. Finish setup, then wait 3+ minutes before
   the first reboot.

What the script writes (active slot only)
apusys audio_dsp ccu connsys_bt connsys_gnss connsys_wifi dpm gpueb gz mcupm
modem mvpu_algo pi_img scp spmfw sspm tee vcp boot init_boot vendor_boot dtbo
vbmeta (verity/verification disabled) vbmeta_system vbmeta_vendor super
Then: erase metadata, fastboot -w, reboot.
NOT written: preloader, lk, IMEI partitions. init_boot is stock (no root).

Known bugs
- After a reboot, unlock with PIN/pattern FIRST. Fingerprint can dismiss the
  lockscreen while storage stays locked (stuck on "Phone is starting").
  Fix: screen off/on, draw your pattern/PIN.
- Bluetooth audio routing: audio may stay on the speaker.
- Samsung IMS (imsd) crash loop, VoLTE/IMS not working properly.
- Play Integrity: BASIC only, DEVICE fails.
- DSU PIN workarounds still inside.
- Debug build ON PURPOSE: ADB is on from the first boot with NO authorization
  prompt (ro.adb.secure=0, ro.debuggable=1). Anyone with a USB cable can access
  the phone. Don't keep personal data on it.
- Shutdown is not fully clean (no data loss seen).

Reporting bugs: steps + logcat (adb logcat -b all -d > log.txt).
Can you fix bugs? DM me on Telegram: @Pearto_tech

Source, tools & notes: https://github.com/emir34-34/oneui-poco-x8-pro

Flash at your own risk. The author is not responsible for bricked devices.

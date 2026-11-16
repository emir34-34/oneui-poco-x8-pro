# One UI 9 on klee — notes (2026-11-08 → 2026-11-17)

Developed as a **DSU** image (the installed ROM is never touched). Since 2026-11-16 it also runs
as a **normal install** in place of Infinity X on slot B, with SELinux Enforcing:
see [docs/NORMAL_INSTALL.md](docs/NORMAL_INSTALL.md).

## Base

- **System:** Galaxy A06 5G (SM-A066B) One UI 9 `system` + `system_ext` + `product`, as one EROFS
  image with an AVB hashtree footer (`tools/build_image.sh`).
- **From the Galaxy S26 Ultra:** SystemUI, AODService, Galaxy AI / Now Brief / Gallery search /
  text recognition apps, PhotoEditor AI libraries, floating-feature values.
- **From klee:** kernel, vendor, odm (Infinity X, vendor API 202604). Samsung's sepolicy is
  extended with the types the 202604 vendor policy refers to.
- Build log: about 45 base images (`o9-01` … `o9-45`) plus small add-on modules (`m1` … `m13`).

## Status (o9-48, 2026-11-14)

| Area | Status |
|---|---|
| Boot, S26 Ultra SystemUI, ADB, Wi-Fi, Google/Samsung sign-in | ✅ |
| Boot time | ✅ screen at ~50–63 s (was 109 s), see *Boot logo wait* |
| PIN lock | ✅ correct PIN unlocks, wrong PIN is rejected (DSU workaround) |
| Fingerprint enrol / unlock / LockStar animation | ✅ |
| Always On Display (S26U AODService) | ✅ |
| Adaptive brightness | ✅ |
| Flashlight strength levels | ✅ |
| Xiaomi camera | ✅ photos saved |
| Bluetooth A2DP offload | ✅ |
| SIM, mobile data, SMS in/out, calls in/out | ✅ incoming calls arrive late (open) |
| 5G | 🟡 menu shown, modem reports NR restricted |
| VoLTE / VoWiFi, MMS | ❌ |

o9-48 is the first image meant to work on a **clean install** (no add-on module, setup wizard run
normally); it is not tested yet.

## Test loop

1. `tools/build_image.sh work/o9-NN` → `system.img` (~6.5 GB).
2. `tools/auto_install.sh o9-NN <log>` waits for the phone, runs `tools/dsu_cycle.sh`
   (`gsi_tool install` with a 32 GiB userdata), skips the setup wizard, sets a test PIN and
   collects a diagnosis with `tools/diag_oneui.sh`. Set `ADB_SERIAL` first.
3. Small changes go into a **module** instead of a new 6 GB image:
   - `tools/build_module.sh <dir> work/o9-NN` packs `<dir>/{mod.list,mod.prop,system/…,product/…}`
     into an EROFS image labelled with the base image's `file_contexts`.
   - `tools/push_module.sh <img>` copies it to `/data/local/tmp/klee_mod/` and reboots into DSU
     (`--disable` switches it off).
   - `tools/kleemod/klee_modmount.{sh,rc}` (part of the base image) mounts each folder listed in
     `mod.list` as a read-only overlayfs on top of the original, in `post-fs-data`, before zygote.
     If a boot with the module never reaches `sys.boot_completed`, the next boot skips it.
   - Example: [`module-example/`](module-example/).
   - `gsi_tool install` recreates userdata even without `--wipe`, so a new base image always means
     a fresh setup; modules keep the data.

`tools/build_services_mod.sh services|secinputdev-service` rebuilds a framework jar from apktool
smali and replaces only the dex files of the base jar (zip-aligned), for use in a module.

**All of this is development tooling** (loader, `klee_fpfs`, debug log service, the permissive
`oneuidbg` domain). It has to be removed before any permanent install.

## Fixes

Smali diffs against the stock One UI 9 `services.jar` and `secinputdev-service.jar` are in
[`patches/`](patches/). The `framework.jar` and sepolicy changes are only described here.

### Boot logo wait (o9-41)
Samsung's init waits for `security.fbe.global_de` before every `/data` mkdir; vold could not set it
(SELinux, `exported_system_prop`), so 59 mkdirs × 0.9 s were lost. Labelling `security.fbe.` as
`vold_prop` in `plat_property_contexts` fixed it: zygote 69 → 21 s, screen 109 → 63 s.

### PIN lock (o9-30, o9-31)
Samsung's `gatekeeperd` cannot verify with the klee TEE inside DSU (`verifyChallenge` returns
ERROR). `SyntheticPasswordManager.unlockLskfBasedProtector`: on gatekeeper ERROR, the decision is
made by `unwrapSyntheticPasswordBlob` (AES-GCM with the key derived from the PIN), so a wrong PIN is
still rejected. `createSyntheticPasswordBlob`: SID 0, so the Keystore key is not bound to the
gatekeeper SID (otherwise SystemUI fails with `UserNotAuthenticatedException`).

### Fingerprint
- `KleeFodTouch` (new class): an input monitor that sends `onPointerDown/Up` to the Xiaomi
  fingerprint HAL when the finger is on the sensor area (Samsung expects its own touch firmware to
  do this).
- `SemFingerprintEnrollClient.onEnrollResult`: Xiaomi reports remaining steps, Samsung computes
  `100 − remaining`; enrolment now starts at 0 %.
- `framework.jar FingerprintManager.semGetSensorPosition()` 4 → 2 (the A06 has a side sensor).
- Lock screen / AOD read the sensor position from `/sys/class/fingerprint/fingerprint/position`,
  which the Xiaomi kernel does not have. `tools/kleemod/klee_fpfs.c` builds a tmpfs copy of
  `/sys/class` (each class bind-mounted from the real sysfs) and adds that file, before zygote.
  Fields used: `[0]` bottom margin, `[3]` area height, `[7]` icon size (mm). Current value
  `6.25,0,0,11.59,0,0,0,14.0`.
  *Do not test this with toybox `unshare -m`: it does not make mounts private, the tmpfs leaks into
  the global namespace and healthd loses the battery.* `klee_fpfs test` does it properly.
- **Unlock animation (m12):** BiometricSetting starts the effect on HAL acquired events
  `(6, 10002/10003/10004)` (capture start / complete / finger up), which the Xiaomi HAL does not
  send; `KleeFodTouch` now sends them through `SemFpSysUiImpl.handleOnAcquired`. The effect is also
  drawn from Samsung's touch-screen "FOD touch map" (`SemInputDeviceManager.getFodInfo/getFodPosition`,
  `"NA"` here). `secinputdev-service.jar` now returns `"17,14,60"` and a fixed 17×14 finger-sized
  disc bitmap (hex, 8 cells per byte, LSB first).
- The icon/animation picker comes from LockStar, which SystemUI only enables when
  `com.samsung.android.goodlock` is installed. Galaxy Store does not offer Good Lock to this device,
  so it has to be installed by hand.

### Always On Display
- S26U AODService; the A06 floating feature `CLOCKPACK_ITEM` made it crash (IndexOutOfBounds).
- `KleeFramework` overlay: `config_aodBrightnessValues`, `config_screenBrightnessDozeFloat` 0.0067.
- `DisplayBrightnessStrategySelector`: DOZE strategy is chosen even when the doze brightness is -1.
- **From the home screen (OFF → DOZE)** the klee panel ignores backlight writes in DOZE, so the AOD
  stayed black. `LocalDisplayAdapter$LocalDisplayDevice$1.run()`: on OFF → DOZE, go ON first with
  brightness 0.0067, wait 300 ms, then DOZE.
- Lock screen clock missing: two `PLUGIN_FACE_WIDGET` plugins (AODService and the old
  `ClockPack_v80`); disabling ClockPack fixes it.

### Adaptive brightness
The under-display light sensor needs the MTK hardware composer to send it screen colour data
(CWB). `hwcomposer.mtk_common.so` only turns that on when `ro.product.product.name` contains
`rodin/dali/klimt/goya/klee/dash`; One UI's `a06xxx` gave a constant 0 lux. Fix: product
`build.prop` `ro.product.product.name=a06xxx_klee`.

### Flashlight
Samsung SystemUI sends torch levels 1–5; the klee camera HAL's maximum is 100. `framework.jar`
`CameraManager` (SystemUI process only) maps 1–5 to `level*max/5` and back, and ignores
`CAMERA_IN_USE` instead of crashing the quick-settings slider (`patches/framework.jar-torch.patch`;
the matching reverse mapping lives in `CameraManager$CameraManagerGlobal`).

### Xiaomi camera
The final JPEG comes from `vendor.xiaomi.hardware.aidlbgservice.IBGService` in `camerahalserver`.
servicemanager refused `platform_app` → `hal_camera_service` (`find`), so every photo waited 24 s
and was dropped. `sepolicy/camera-bgservice.cil`. Samsung's own camera app is removed (it does not
work with this hardware).

### Telephony (Infinity X vendor RIL with Samsung's framework)
Patched vendor libraries, bound over `/vendor/lib64` before `rild` (`tools/kleevendor/`):
- `libmtkmipc-ril.so`: incoming SMS were queued forever ("SMS framework isn't ready") because
  Samsung never sends MTK's `SET_SMS_FWK_READY`; the check is skipped. SMSC is returned as
  `"num",145` (Samsung's format), otherwise outgoing SMS used a broken SMSC. MMS profile id and
  PDN protocol mapped to MTK values.
- `librilfusion.so`: unsolicited responses (including call state) were held until an MTK-only
  "client connected" flag; now passed on directly → incoming calls ring.
- `services.jar`: Samsung RealTimeTokenService blocked system_server for 5 s on every network
  change (a missing Samsung HAL), which delayed incoming calls.
- SIM presence: Samsung Settings reads `ril.ICC_TYPE<n>`, which the MTK RIL does not write; a boot
  script mirrors `vendor.gsm.ril.uicctype`.
- 5G menu: TelephonyUI reads `persist.radio.def_network`; set to `26,26` in `build.prop`.

### Lock screen root cause (DSU only)
The Xiaomi gatekeeper TA adds 1000000 to user ids inside DSU; verifying uid 1200000 fails with
"can't find uid". The o9-30/o9-31 workarounds weaken PIN-bound keys and **must be removed for a
normal install**, where the TA should behave like on Infinity X.

### Clean install
Some fixes were first done with live commands and were lost when DSU data was reset. Everything
is now in the image: ClockPack removed (lock screen / AOD clock), 5G property, vendor RIL
libraries, product name. Rule from now on: a live fix is only a test, the image gets the real one.

### Other
- `EngineeringModeManager` native check now also requires the Samsung engmode HAL to be declared
  (removed a 5 s system_server stall on every screen on/off).
- ePDG / cidmanager crashes fixed with SELinux labels (o9-44); VoLTE itself does not work yet.
- Gallery AI: S26U PhotoEditor libraries added; it then stops in `libPetDetector` (needs Samsung's
  `snap` HAL and models).

## Since o9-56 (2026-11-16 → 2026-11-17)

### Normal install (o9-63 → o9-65)
Full `super.img` with the phone's own vendor, flashed from the bootloader; details, the first-boot
rule and the open points are in [docs/NORMAL_INSTALL.md](docs/NORMAL_INSTALL.md). Enforcing needed
`sepolicy/normal_install_enforcing.cil` (o9-64).

### Changing a system APK without re-signing
For packages on the system partition the package manager reads the certificate from the APK
Signing Block but does not compare the content digests. So a file inside the APK can change, even
its size, as long as the original signing block sits right before the central directory and the
EOCD points to the new offset (`tools/apk_swap_entry.py`). The platform certificate,
`sharedUserId` and the SELinux `seinfo` stay the same. To add new resources the APK is rebuilt
with apktool, aligned, and the original block is put back (`tools/apk_graft_sig.py`).

### 120 Hz (o9-63)
Samsung Settings on the A06 offers only Adaptive and Standard. The fragment's read/write calls go
through two small helpers: "High" stores `refresh_rate_mode` 1 plus `min_refresh_rate` 120,
Adaptive/Standard reset the minimum to 0 (`patches/SecSettings-120hz.patch`).

### Infinity video wallpapers (o9-65)
`wallpaper-res` comes from the S26 Ultra (One UI 8.5 animated graphical wallpapers, e.g. the
basketball court, served by `GraphicalWallpaperService`). Its S26U videos were replaced with the
four Galaxy S24 Ultra Infinity videos and eight still images. The pack shrank from 852 MB to
413 MB so it fits in `super`.

Lesson: `InfinityWallpaper` does not just play the video. On unlock or touch it seeks back and
forth to frame numbers (`newMotionAnimator 1206 700 1500`). Re-encoded videos must therefore be
**all-intra** (x265 `keyint=1`) and keep the **original frame rate and frame count** (S24U:
120 fps, 2953 frames). Videos encoded with a 60–90 frame GOP stuttered badly; all-intra at
1272×2756 Main10 CRF 22 (~85–95 MB each) plays smoothly.

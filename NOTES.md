# One UI 9 on klee — notes (2026-11-08 → 2026-11-12)

A **DSU** image: the installed ROM (Infinity X, Android 17, slot `_b`) is never touched,
and nothing is written outside `/data/gsi` and `/data/local/tmp`.

## Base

- **System:** Galaxy A06 5G (SM-A066B) One UI 9 `system` + `system_ext` + `product`, as one EROFS
  image with an AVB hashtree footer (`tools/build_image.sh`).
- **From the Galaxy S26 Ultra:** SystemUI, AODService, Galaxy AI / Now Brief / Gallery search /
  text recognition apps, PhotoEditor AI libraries, floating-feature values.
- **From klee:** kernel, vendor, odm (Infinity X, vendor API 202604). Samsung's sepolicy is
  extended with the types the 202604 vendor policy refers to.
- Build log: about 45 base images (`o9-01` … `o9-45`) plus small add-on modules (`m1` … `m13`).

## Status (o9-45 + m13, 2026-11-12)

| Area | Status |
|---|---|
| Boot, S26 Ultra SystemUI, ADB, Wi-Fi, Google/Samsung sign-in | ✅ |
| Boot time | ✅ screen at ~50–63 s (was 109 s), see *Boot logo wait* |
| PIN lock | ✅ correct PIN unlocks, wrong PIN is rejected |
| Fingerprint enrol / unlock | ✅ |
| Fingerprint unlock animation (Good Lock / LockStar) | ✅ with a synthetic touch map |
| Always On Display (S26U AODService) | ✅ from lock screen and from home screen |
| Lock screen elements around the sensor | ✅ text moved, icon size being tuned |
| Adaptive brightness | ❌ light sensor reports an almost constant lux |
| SMS, VoLTE, SIM manager, Theme Store, Gallery AI | ❌ |
| Camera, Bluetooth, GPS, calls, mobile data | not tested |

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

### Brightness
`KleeFramework` overlay adds the S26U lux → nit curve and a matching backlight array
(`config_autoBrightnessLcdBacklightValues`) and a narrower hysteresis. The mapping is now built,
but the Xiaomi `tsl2522_als` sensor reports 71–80 lux while its raw value moves between 4000 and
11000, so the screen does not follow the light. Still open.

### Other
- `EngineeringModeManager` native check now also requires the Samsung engmode HAL to be declared
  (removed a 5 s system_server stall on every screen on/off).
- ePDG / cidmanager crashes fixed with SELinux labels (o9-44); VoLTE itself does not work yet.
- Gallery AI: S26U PhotoEditor libraries added; it then stops in `libPetDetector` (needs Samsung's
  `snap` HAL and models).

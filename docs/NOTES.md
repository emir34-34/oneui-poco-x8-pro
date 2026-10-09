# One UI on klee — notes (2026-10-06 → 2026-10-08)

## Base

- **Firmware:** Galaxy A06 5G **SM-A066B** (Dimensity 6300, also MediaTek), region **XME**,
  version **A066BXXS8CZI1** (One UI 8.5 / Android 16).
  - A066B is not offered for TUR/EUX. The A06 sold in Turkey is the 4G SM-A065F.
  - Download with [samloader-rs](https://github.com/topjohnwu/samloader-rs). The old Python
    samloader 0.4 no longer works, because of the new SmartDownload protocol.
- **Phone:** Poco X8 Pro (`klee`), AxionAOSP v2.8 (Android 16), KernelSU, active slot `_b`.
  The Xiaomi vendor uses the `nlmsg` SELinux permission.
  - Android 16 r1 GSIs (June 2025, e.g. ponces/TrebleDroid 16.0 r1) therefore fail to compile
    the split policy: init reboots into recovery.
  - Google's Android 17 QPR1 `aosp_arm64` GSI (CP3A.260905.010) boots fine.
  - One UI's policy contains `nlmsg` too and passes `tools/secil_test_pc.sh`.

## Why DSU

DSU installs a second system image into `/data/gsi` and boots it once (or until disabled):
```
gsi_tool install --gsi-size <bytes> --userdata-size 8589934592 < image
```
After a failed boot the phone returns to the installed ROM by itself.

On this phone, after `gsi_tool install`, it rebooted straight into the DSU. A failed One UI boot
went like this:
1. About 100 s after boot, the phone reset.
2. For about 2 minutes it looped between preloader and BROM (on USB, `0e8d:2000` /
   `0e8d:0003`).
3. It came back to Axion on its own, and DSU was then disabled.

**Do not press any buttons during the loop; just wait.**

## Building the image

These steps were done by hand. `tools/build_oneui.sh` automates the last part.

1. **Extract the Samsung images.** Take `super.img` from the AP tarball, then `system`,
   `system_ext` and `product` from it (all EROFS).
   - Extract them without root, using `fsck.erofs --extract` from erofs-utils with
     `tools/erofs-utils-fsck.patch`, inside `unshare --map-auto --map-root-user`.
   - The patch skips `security.selinux`, which cannot be set in a user namespace. The files are
     relabelled later from `file_contexts`.
   - The patch logs `security.capability` to `$EROFS_CAPS_LOG` (e.g. `run-as`,
     `simpleperf_app_runner`), so the capabilities can be re-applied.
2. **Layout: root = system.img's root.**
   - `system_ext` and `product` must be **real directories at the image root**, with
     `/system/system_ext -> /system_ext` and `/system/product -> /product` as symlinks. This is
     Samsung's layout.
   - The GSI-style layout (real `/system/system_ext`) kills zygote with
     `Not allowlisted: /system/system_ext/framework/mediatek-common.jar`.
3. **Add `skip_mount.cfg`.** Put `patches/skip_mount.cfg` in `/system/etc/init/config/` and
   `/system_ext/etc/init/config/`.
   - Without it, first-stage init tries to mount the device's own `system_ext`/`product` and
     reboots to the bootloader.
   - On this phone the kernel drops userspace kmsg writes, so init's log is invisible. This was
     found from the ramoops timing plus the AOSP source.
4. **Apply the prop and sepolicy changes.**
   - `patches/system-build.prop.patch`
   - `patches/plat_file_contexts.patch`
   - append `sepolicy/oneui_fixes.cil` and `sepolicy/oneuidbg.cil` to
     `/system/etc/selinux/plat_sepolicy.cil`
   - Check with `tools/secil_test_pc.sh` against the phone's vendor/odm policy, pulled with adb.
5. **Add the debug log service.**
   - `debuglog/oneui_debuglog.rc` → `/system/etc/init/`
   - `debuglog/oneui_debuglog.sh` → `/system/bin/`
   - If `/metadata/oneui_dbg/run.sh` exists (e.g. `debuglog/run.sh`, written from Axion as
     root), the service runs it, so logging can change without rebuilding the image.
   - Logs land in `/metadata/oneui_debug/`. Read them back from Axion.
   - With `ro.debuggable=1`, `pmsg-ramoops` (pstore) also keeps Samsung's `!@` boot log lines.
6. **Add the Xiaomi audio parameter parser** (see below).
7. **Patch `services.jar`.**
   - Decompile it with apktool into `fw/jars/services`.
   - Apply `patches/services.jar.patch` (`patch -p1` inside the apktool folder).
   - Run `tools/build_oneui.sh --jar services`. It repacks only the dex files, aligns them and
     removes the old `oat/arm64/services.{odex,vdex,art}`.
8. **Build the image.** `build_oneui.sh` runs `mkfs.erofs` with `--file-contexts`, then
   `avbtool add_hashtree_footer`.
   - The footer is **required**. Without it the phone reboots with "dm-verity device corrupted",
     because the device fstab mounts system with `avb=vbmeta_system`.
   - Use the AOSP test key, `--do_not_generate_fec`, and partition size = image + 48 MiB.

## Problems solved

### Zygote loop (napproxyd)
Samsung's `netd.rc` declares `socket napproxyd` and `onrestart restart zygote`. The
`/dev/socket/napproxyd` label lives in Samsung's vendor policy, so it is missing on Xiaomi.
- init's socket creation is denied (the avc shows in dmesg).
- netd exits, and zygote is killed.

**Fix:** the `napproxyd_socket` type (`sepolicy/oneui_fixes.cil`) and its `plat_file_contexts`
line.

### system_server crash in the vibrator service
`libvibratorservice` calls Samsung's vibrator HAL extension (`getExtension`). That extension
does not exist on Xiaomi, so the call segfaults on null.

**Fix:** 20 Samsung-specific methods of `VibratorController$NativeWrapper` (`supports*`,
`hasFeature`, `seh*`, `setIntensity`, …) are stubbed to no-op/false.

### AudioPolicy not available
`audioserver` waited forever for `android.media.audio.IHalAdapterVendorExtension/default`. On
Axion this service comes from the Xiaomi `system_ext`, which One UI does not have.

**Fix:** copy these from the stock/Axion `system_ext`:
- `/system_ext/bin/hw/android.hardware.audio.parameter_parser.service`
- its `.rc` (`patches/…service.rc`)
- `android.hardware.audio.core-V3-ndk.so` and `av-audio-types-aidl-V3-ndk.so` into
  `/system/lib64`

Use `root:shell 0755/0644`. `tools/resolve.py` lists the missing libraries and symbols. One UI's
`system_ext` policy already has the needed types. After this, AudioPolicy loaded.

## Current blocker: battery info

`system_server` dies in the `JobSchedulerService` constructor:
```
NullPointerException: Attempt to read from field 'int android.hardware.health.HealthInfo.batteryLevel'
on a null object reference … BatteryService$LocalService.getBatteryLevel … JobSchedulerService.<init>
```

**Why:**
- Samsung's `BatteryService` only gets health info through Samsung's own HAL extension
  (`ISehHealth` → `ISehHealthInfoCallback` → `SehHealthInfo`, which carries an `aospHealthInfo`
  field).
- The Xiaomi vendor only has the plain AOSP `android.hardware.health.IHealth`.
- The earlier patch skips registration when `ISehHealth` is missing (to avoid a crash), so no
  battery info ever arrives.

**The fix, written but NOT hooked up and NOT tested:** the new class
`com.android.server.health.KleeAospHealthCallback` (in the patch):
- It is a Binder that implements `android.hardware.health.IHealthInfoCallback` and calls
  `markVintfStability()`.
- `register(HealthRegCallbackAidl)` does the following:
  1. waits for `android.hardware.health.IHealth/default`
  2. calls `registerCallback` (transaction 1)
  3. calls `update` (3)
- `healthInfoChanged` (1) wraps the `HealthInfo` in a new `SehHealthInfo` (`aospHealthInfo`) and
  passes it to `HealthRegCallbackAidl.mServiceInfoCallback.update(...)`. That is the same path
  Samsung's callback uses.

**Next step:** in `HealthRegCallbackAidl.onRegistration`, inside the `if-nez p2` null branch
(before its `return-void`), add:
```
invoke-static {p0}, Lcom/android/server/health/KleeAospHealthCallback;->register(Lcom/android/server/health/HealthRegCallbackAidl;)V
```
Then rebuild with `tools/build_oneui.sh --jar services`, test-boot it and read
`/metadata/oneui_debug`.

**AOSP IHealth AIDL codes:** registerCallback=1, unregisterCallback=2, update=3,
getHealthInfo=12. IHealthInfoCallback: healthInfoChanged=1.

## Other known problems

- **USB/adb does not work in One UI.** It fails to enumerate about every 32 s. Samsung's USB
  config does not match the Xiaomi gadget HAL. That is why the debug log service exists.
- **imsd socket label** is missing, the same kind of problem as napproxyd.
- **The phone resets ~100 s into a failed boot** and loops through preloader/BROM before
  returning. This did not happen in the last test, after the system_server loop had been fixed.

## Safety notes from testing

- Check the IMEI after every test boot (`*#06#` in Android).
- The DSU never touches the installed system. A failed boot recovers by itself in about 2
  minutes; do not press buttons during the loop.
- To boot a DSU that is installed but disabled: `gsi_tool enable --single-boot`.

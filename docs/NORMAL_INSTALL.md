# Normal install (slot B, in place of Infinity X) — 2026-11-17

Status: **working**, the author's daily phone 2026-11-16 → 2026-11-20 (o9-63 → o9-65); o9-65 released as a public test build.
SELinux is **Enforcing**. DSU is still used for trying new images first.

## Layout
One `super.img` built with `lpmake` (`tools/build_normal_super.sh work/o9-N`):

| Partition (group `mediatek_dynamic_partitions_b`) | Source |
|---|---|
| `system_b`, `system_ext_b`, `product_b` | One UI tree, split with `tools/build_split.sh` |
| `vendor_b`, `odm_b`, `vendor_dlkm_b`, `odm_dlkm_b`, `system_dlkm_b` | copied 1:1 from the installed Infinity X slot B |

`--device super:12884901888 --group mediatek_dynamic_partitions_b:9121562624 --virtual-ab
--metadata-slots 3`. o9-65 uses 6541 + 2125 MiB of the 8699 MiB group, **33 MiB free**.
Slot A is not used (One UI + a second vendor copy does not fit, and slot A's metadata overlaps
slot B's extents on this phone).

## Install (from the bootloader, not fastbootd)
`tools/normal_kur_ilerleme.sh super_oneui_o9-N.img` — progress bar per step
(`tools/fastboot_ilerleme.py`):
1. `fastboot flash super super_oneui_o9-N.img`
2. `fastboot --disable-verity --disable-verification flash vbmeta_b vbmeta_b.img` (the phone's own)
3. **First install only:** `fastboot -w` **and** `fastboot erase metadata`. Without erasing
   `/metadata` the old encryption keys stay and the first boot fails.
4. `fastboot set_active b`, `fastboot reboot`

**Updates keep data:** `tools/normal_guncelle_ilerleme.sh` writes only `super` + `vbmeta_b`.

### First boot: leave it alone for a few minutes
On the first attempt the phone was restarted about one minute after the first boot. User 0's
device-encrypted data (`/data/user_de/0`, the lock-screen `spblob`) was gone afterwards, Rescue
Party sent the phone to recovery. On the second attempt (format again, then waited 3+ minutes
before the first restart) everything stayed. Root cause not proven; the rule is: finish setup,
wait, then restart.

## Enforcing fixes
Samsung's system side needs rules that the Xiaomi vendor policy does not have:
`sepolicy/normal_install_enforcing.cil` (vold shutdown flag and Samsung directories, radio OMC
property, Samsung `/data/log`). Without them `com.android.phone` crashed and `dumpstate` looped.

## Test before calling an image ready
Reboot → unlock with the PIN/pattern → reboot again → unlock. Passed on o9-64 and o9-65.

## Public test package (2026-11-24)
`release/` scripts, package built in `work/release_o9-65`:
- `super.img` = the installed o9-65 (slot B names). For slot A the script also flashes
  `super_slot_a_meta.img`: lpmake output for `_a` and `_b` differs only in the first MiB, so a
  sparse image with that MiB as RAW and the rest DONT_CARE switches the metadata. Slot A untested.
- boot, vendor_boot, dtbo and firmware (apusys … vcp) are the ones o9-65 was tested with;
  init_boot and vbmeta* are stock from the Infinity X 4.1 payload.
- Writes only the active slot, no `set_active`, no preloader/lk/IMEI partitions.

## Still open
- The DSU-only PIN workarounds o9-30 / o9-31 are still in the image. In a normal install the
  gatekeeper TA does not need them and they weaken PIN-bound keys; removing them needs a separate
  test with a backup.
- vold is still killed during shutdown, so `/data` is shut down with an F2FS full sync instead of
  a clean unmount. No data loss seen.
- Works only on the Infinity X vendor it was built against. No Samsung or Xiaomi files here.

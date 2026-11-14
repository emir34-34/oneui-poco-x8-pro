# Leaving DSU: plan for a normal install (2026-11-14)

Status: **preparation only**. Testing continues in DSU until the open issues are solved. Nothing
here has been done on the phone.

## Partitions the phone mounts
The first-stage `fstab.mt6899` (vendor_boot) mounts `system, system_ext, product, vendor, odm,
vendor_dlkm, odm_dlkm, system_dlkm`, all `slotselect,logical`, none optional. In DSU the single
image carries its own `/product` and `/system_ext`; a normal install needs three images:
`tools/build_split.sh work/o9-N` → `split/{system,system_ext,product}.img`.

## Space in `super` (12 GiB)

| | MiB |
|---|---|
| One UI o9-48: system / system_ext / product | 4471 / 202 / 1514 = **6187** |
| Infinity X slot B: system / system_ext / product | 924 / 1435 / 1854 = 4213 |
| Infinity X slot B: vendor / odm / dlkm | 953 / 1146 / 26 |
| Free space after slot B | ~5950 |

- **Slot A:** One UI + its own vendor/odm copy needs ~8.3 GiB, so ~2.3 GiB short. The slot A
  metadata on this phone also overlaps slot B's live extents, and `/data` is shared between slots.
- **In place of Infinity X (slot B):** +1974 MiB, fits (super ~8.3 / 12 GiB). Needs a data format.

## Must be reverted for a normal install
- PIN workarounds o9-30 / o9-31 (gatekeeper TA uid offset is DSU-only). They weaken PIN-bound
  keys.
- Development tools: module loader, root command runner, forced ADB, logger, `ro.debuggable=1`,
  `ro.adb.secure=0`, permissive `oneuidbg` domain. The functional parts of the boot script
  (audio/Bluetooth binds, `ril.ICC_TYPE`, fingerprint position, vendor RIL binds) need an enforcing
  domain with their own rules.
- AVB: DSU key → vbmeta with verification disabled, or own signing key.

## Release requirements
- Works only on the Infinity X vendor (sepolicy 202604) it was built against.
- Install: fastbootd → flash `system`, `system_ext`, `product` (+ vbmeta) → format data, or one
  `super.img` built with `lpmake`.
- No Samsung or Xiaomi files in this repository.

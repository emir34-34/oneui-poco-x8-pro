#!/bin/bash
# Kullanım: secil_test.sh <root> <ref> : init'in split-policy derlemesini taklit eder
R="$1"; D="$2/dev"; V=$(cat "$D/vendor/plat_sepolicy_vers.txt"); S="/home/administrator/Desktop/one ui port new*/tools/port/secilc"
A=("$R/system/etc/selinux/plat_sepolicy.cil" "$R/system/etc/selinux/mapping/$V.cil")
for f in "$R/system/etc/selinux/mapping/$V.compat.cil" "$R/system/etc/selinux/plat_sepolicy_genfs_$V.cil" "$R/system_ext/etc/selinux/system_ext_sepolicy.cil" "$R/system_ext/etc/selinux/mapping/$V.cil" "$R/product/etc/selinux/product_sepolicy.cil" "$R/product/etc/selinux/mapping/$V.cil" "$D/vendor/plat_pub_versioned.cil" "$D/vendor/vendor_sepolicy.cil"; do [ -f "$f" ] && A+=("$f"); done
"$S" -m -M true -G -N -c "$(cat "$D/pv")" "${A[@]}" -o "${3:-/dev/null}" -f /dev/null; echo "SECILC_EXIT=$?"

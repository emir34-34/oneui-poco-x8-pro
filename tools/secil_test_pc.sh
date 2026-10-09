#!/bin/bash
# Emulates init's split-policy compilation on the PC.
# Usage: secil_test_pc.sh <sel_folder>
#   <sel_folder> contains: _system_etc_selinux, _system_system_ext_etc_selinux, _system_product_etc_selinux
# The device's vendor/odm policy is read from device_sel/ (pulled with adb).
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D="$ROOT/device_sel"
S="$1"
V=$(cat "$D/vendor/plat_sepolicy_vers.txt")
B=$(cat "$D/board_api")
PV=$(cat "$D/policyvers")

A=("$S/_system_etc_selinux/plat_sepolicy.cil" "$S/_system_etc_selinux/mapping/$V.cil")
for f in "$S/_system_etc_selinux/mapping/$V.compat.cil" \
         "$S/_system_etc_selinux/plat_sepolicy_genfs_$B.cil" \
         "$S/_system_system_ext_etc_selinux/system_ext_sepolicy.cil" \
         "$S/_system_system_ext_etc_selinux/mapping/$V.cil" \
         "$S/_system_system_ext_etc_selinux/mapping/$V.compat.cil" \
         "$S/_system_product_etc_selinux/product_sepolicy.cil" \
         "$S/_system_product_etc_selinux/mapping/$V.cil" \
         "$D/vendor/plat_pub_versioned.cil" \
         "$D/vendor/vendor_sepolicy.cil" \
         "$D/odm/odm_sepolicy.cil"; do
  [ -f "$f" ] && A+=("$f")
done

echo "vendor=$V board=$B policyvers=$PV"
"$ROOT/tools/secilc" -m -M true -G -N -c "$PV" "${A[@]}" -o /tmp/secil_out_policy.$$ -f /dev/null
rc=$?
rm -f /tmp/secil_out_policy.$$
echo "SECILC_EXIT=$rc"
exit $rc

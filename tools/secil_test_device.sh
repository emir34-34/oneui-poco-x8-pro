#!/system/bin/sh
# Emulates init's split-policy compilation on the device: $1 = GSI selinux folder
S=$1; V=$(cat /vendor/etc/selinux/plat_sepolicy_vers.txt); B=$(getprop ro.board.api_level)
A="$S/_system_etc_selinux/plat_sepolicy.cil $S/_system_etc_selinux/mapping/$V.cil"
for f in $S/_system_etc_selinux/mapping/$V.compat.cil $S/_system_etc_selinux/plat_sepolicy_genfs_$B.cil \
         $S/_system_system_ext_etc_selinux/system_ext_sepolicy.cil $S/_system_system_ext_etc_selinux/mapping/$V.cil \
         $S/_system_system_ext_etc_selinux/mapping/$V.compat.cil \
         $S/_system_product_etc_selinux/product_sepolicy.cil $S/_system_product_etc_selinux/mapping/$V.cil \
         /vendor/etc/selinux/plat_pub_versioned.cil /vendor/etc/selinux/vendor_sepolicy.cil /odm/etc/selinux/odm_sepolicy.cil; do
  [ -f "$f" ] && A="$A $f"
done
echo "vendor=$V board=$B"; echo "$A" | tr ' ' '\n'
secilc -m -M true -G -N -c $(cat /sys/fs/selinux/policyvers) $A -o $S/out_policy -f /dev/null
echo SECILC_EXIT=$?

#!/bin/bash
# o9-N agacindan NORMAL KURULUM super.img uretir (slot B duzeni): One UI system/system_ext/product + IX vendor/odm/dlkm (work/normal_super/ix_b).
# Kullanim: build_normal_super.sh work/o9-N   -> work/normal_super/super_oneui_o9-N.img
set -e
cd "${KLEE_ROOT:-.}"
O="${1:?o9 dizini}"; N=$(basename "$O")
bash tools/build_split.sh "$O" > "$O/split.log" 2>&1 || { echo "SPLIT HATA"; tail -3 "$O/split.log"; exit 1; }
I=work/normal_super/ix_b; S="$O/split"; G=mediatek_dynamic_partitions_b; OUT=work/normal_super/super_oneui_$N.img
args=(); add(){ args+=(--partition $1:readonly:$(stat -c %s $2):$G --image $1=$2); }
add odm_b $I/odm_b.img; add odm_dlkm_b $I/odm_dlkm_b.img; add product_b $S/product.img; add system_b $S/system.img; add system_dlkm_b $I/system_dlkm_b.img; add system_ext_b $S/system_ext.img; add vendor_b $I/vendor_b.img; add vendor_dlkm_b $I/vendor_dlkm_b.img
lpmake --metadata-size 65536 --super-name super --metadata-slots 3 --virtual-ab --device super:12884901888 --group $G:9121562624 "${args[@]}" --sparse --output "$OUT" 2>&1 | grep -v "sparse file format" | tail -1
echo "SUPER $OUT $(stat -c %s "$OUT") $(sha256sum "$OUT" | cut -d' ' -f1)"

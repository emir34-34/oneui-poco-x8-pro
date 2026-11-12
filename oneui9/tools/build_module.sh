#!/bin/bash
# Kullanım: build_module.sh <modul_dizini> <taban_iter> : <modul_dizini>/{mod.list,mod.prop,system/...,product/...} -> <modul_dizini>.img (erofs, tabanın file_contexts etiketleriyle)
ROOT="${ROOT:-$(dirname "$(realpath "$0")")/..}"  # proje kökü: tools/port (apktool, erofs, avbtool) burada
set -e
M="$(realpath "$1")"; B="$(realpath "$2")"; T="$ROOT/tools/port"; O="$M.img"
[ -f "$M/mod.list" ] || { echo "mod.list yok"; exit 1; }
while read -r p; do case "$p" in ''|\#*) continue;; esac; [ -d "$M/$p" ] || { echo "listede olup dizinde olmayan: $p"; exit 1; }; [ -d "$B/root/$p" ] || { echo "tabanda olmayan hedef: $p"; exit 1; }; done < "$M/mod.list"
rm -f "$O"
unshare --map-auto --map-root-user sh -c "chown -R 0:0 '$M' && '$T/erofs/bin/mkfs.erofs' -zlz4hc,9 --file-contexts='$B/file_contexts' --mount-point=/ -T 1640995200 '$O' '$M'" | tail -2
ls -la "$O"; sha256sum "$O" | cut -c1-16

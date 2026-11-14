#!/bin/bash
# Kullanım: build_module.sh <modul_dizini> <taban_iter> : <modul_dizini>/{mod.list,mod.prop,system/...,product/...} -> <modul_dizini>.img (erofs, tabanın file_contexts etiketleriyle)
set -e
M="$(realpath "$1")"; B="$(realpath "$2")"; T="/home/administrator/Desktop/one ui port new*/tools/port"; O="$M.img"
[ -f "$M/mod.list" ] || { echo "mod.list yok"; exit 1; }
while read -r p; do case "$p" in ''|\#*) continue;; esac; [ -d "$M/$p" ] || { echo "listede olup dizinde olmayan: $p"; exit 1; }; case "$p" in vendor/*) ;; *) [ -d "$B/root/$p" ] || { echo "tabanda olmayan hedef: $p"; exit 1; };; esac; done < "$M/mod.list"
rm -f "$O"
# vendor/ hedefleri için tabanın file_contexts'ine vendor_file satırı eklenir (DSU sistem imajında /vendor etiketi yok).
FC="$(mktemp)"; cp "$B/file_contexts" "$FC"; echo "/vendor(/.*)?  u:object_r:vendor_file:s0" >> "$FC"
unshare --map-auto --map-root-user sh -c "chown -R 0:0 '$M' && '$T/erofs/bin/mkfs.erofs' -zlz4hc,9 --file-contexts='$FC' --mount-point=/ -T 1640995200 '$O' '$M'" | tail -2
ls -la "$O"; sha256sum "$O" | cut -c1-16

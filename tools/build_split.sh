#!/bin/bash
# Kullanım: build_split.sh <iter_dizini> : NORMAL KURULUM hazırlığı (DSU değil). Tek DSU ağacını
# system / system_ext / product bölüm imajlarına ayırır (erofs). Telefona hiçbir şey yazmaz.
set -e
I="$(realpath "$1")"; T="/home/administrator/Desktop/one ui port new*/tools/port"; O="$I/split"; mkdir -p "$O"
ST=$(mktemp -d -p "$O"); trap 'unshare --map-auto --map-root-user rm -rf "$ST"' EXIT
mk(){ # $1 ad, $2 kaynak, $3 bağlama noktası
  unshare --map-auto --map-root-user "$T/erofs/bin/mkfs.erofs" -zlz4hc,9 --file-contexts="$I/file_contexts" --mount-point=$3 -T 1640995200 "$O/$1.img" "$2" 2>&1 | tail -1
  stat -c "%s $1.img" "$O/$1.img"; }
# system: kök ağaç, product ve system_ext içerikleri hariç (boş bağlama noktaları kalır)
unshare --map-auto --map-root-user sh -c "mkdir -p '$ST/root' && cd '$I/root' && find . -mindepth 1 -maxdepth 1 ! -name product ! -name system_ext -exec cp -a --reflink=auto {} '$ST/root/' \; && mkdir -p '$ST/root/product' '$ST/root/system_ext' && chmod 755 '$ST/root/product' '$ST/root/system_ext'"
mk system "$ST/root" /
mk product "$I/root/product" /product
mk system_ext "$I/root/system_ext" /system_ext
ls -la "$O"; du -ch "$O"/*.img | tail -1

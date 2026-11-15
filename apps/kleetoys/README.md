# KleeToys

Rear camera-ring LED controller for the POCO X8 Pro ("klee") One UI port.

- Hardware: Awinic AW21024 (`/sys/class/leds/aw21024_led`), 4 physical RGB LEDs on driver groups 3 (top-left), 5 (top-right), 4 (bottom-right), 6 (bottom-left).
- `daemon/kleeledd.c`: tiny init service (`/dev/socket/kleeledd`, line protocol `q RRGGBB x4` / `off`), own SELinux domain (`sepolicy/klee_o954.cil`).
- App: presets, per-corner colors, 7 animations, music sync ("Klee" mode: bass red / treble blue, Visualizer FFT).
- Optional "HyperOS" music mode loads a vendor audio-LED analysis library at runtime via `jni/xled.c`. That library and its config are **not** part of this repository; place them in `xiaomi/` locally to build with it.

Build: `./build.sh` (Android SDK build-tools 35, platform 36, NDK r27; no Gradle).

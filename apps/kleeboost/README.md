# KleeBoost

Vector / LSPosed module that raises media volume above 100 % (default **150 %**). Works on HyperOS 4,
AOSP-based ROMs and this One UI port (Android 13+).

## How it works

The system's own media volume bar is extended, as if HyperOS had a 150 % option built in:
volume keys, the HyperOS volume panel and Settings > Sound all go past the old maximum.

- Scope: **System Framework** (`android`, i.e. `system_server`).
- `AudioService$VolumeStreamState` (STREAM_MUSIC): after the constructor, `mIndexMax` is raised by
  the chosen percentage (e.g. 15 → 23 steps for 150 %). `AudioManager.getStreamMaxVolume()` reports
  the new range, so every volume UI picks it up.
- The audio policy still gets the original range: `AudioSystem.initStreamVolume` receives the old
  max, and `setStreamVolumeIndexAS` / `setVolumeIndexForAttributes` / `getStreamVolumeDB` clamp
  music indexes to it. The old top step keeps its old loudness (= 100 %).
- Bluetooth AVRCP absolute volume and LE Audio are rescaled so headphones reach full device volume
  at 100 %.
- Steps above 100 % become gain: `system_server` attaches a `LoudnessEnhancer` to every player's
  audio session (real session IDs from `AudioPlaybackCallback`, `system_server` holds
  `MODIFY_AUDIO_ROUTING`). Gain grows linearly from 0 at 100 % to `20·log10(top/100)` dB at the top
  (150 % = +3.5 dB, 200 % = +6 dB). The effect has a limiter, so it does not clip.
- Media / game / unknown usages only (ringtone, notifications, calls have their own streams).
  On headphones/Bluetooth the boost is off unless the switch is on: there the steps above 100 %
  act as 100 %.
- If the bar cannot be extended (unknown ROM internals), it falls back to a constant gain at any
  volume and logs `ses cubugu uzatilamadi`.
- Bar length is read at boot (reboot after changing the top value); gain changes apply live
  (`com.klee.boost.RELOAD` broadcast, `xposedsharedprefs`).

## Install

1. `./build.sh` (Android SDK build-tools 35, platform 36; no Gradle). Output: `build/KleeBoost.apk`.
   Override paths with `ANDROID_SDK=…`, `BT=…`, `AJ=…`.
2. `adb install build/KleeBoost.apk`
3. Vector (LSPosed) → Modules → KleeBoost → enable, scope **System Framework** → reboot.
4. Open KleeBoost and set the top of the bar (100–300 %, step 5), then reboot once more.

Check: `adb logcat | grep KleeBoost` (Vector log) should show `system_server'a yuklendi` and
`muzik cubugu 15 -> 23 adim (%150)` and `hazir, enabled=true en_ust=%150 cubuk=15->23`.

## Limits

- Apps that play with session 0 (output mix) are skipped.
- If an app attaches its own LoudnessEnhancer with higher priority, that app's setting wins.
- `stubs/` holds minimal Xposed API stubs for compiling only; they are not packaged.

# KleeBoost

Vector / LSPosed module that raises media volume above 100 % (default **150 %**). Works on HyperOS 4,
AOSP-based ROMs and this One UI port (Android 13+).

## How it works

- Scope: **System Framework** (`android`, i.e. `system_server`). Hooks only
  `ActivityManagerService.systemReady()` to start itself.
- Inside `system_server` it registers an `AudioPlaybackCallback`. Because `system_server` holds
  `MODIFY_AUDIO_ROUTING`, the callback gets the real audio session IDs of every player
  (AudioTrack, MediaPlayer, ExoPlayer, AAudio/OpenSL).
- On every session it attaches a `LoudnessEnhancer` with gain `20·log10(percent/100)` dB:
  150 % amplitude = **+3.5 dB**, 200 % = +6 dB, 300 % = +9.5 dB. The effect has a built-in limiter,
  so it does not clip.
- Default: only media / game / unknown usages, only on the built-in speaker. Headphones/Bluetooth
  and "all sounds" (ringtone, notifications, calls) are opt-in switches.
- Settings are stored with `xposedsharedprefs` and pushed live (`com.klee.boost.RELOAD` broadcast),
  no reboot needed after the first activation.

## Install

1. `./build.sh` (Android SDK build-tools 35, platform 36; no Gradle). Output: `build/KleeBoost.apk`.
   Override paths with `ANDROID_SDK=…`, `BT=…`, `AJ=…`.
2. `adb install build/KleeBoost.apk`
3. Vector (LSPosed) → Modules → KleeBoost → enable, scope **System Framework** → reboot.
4. Open KleeBoost and set the level (100–300 %, step 5).

Check: `adb logcat | grep KleeBoost` (Vector log) should show `system_server'a yuklendi` and
`hazir, enabled=true gain=352mB`.

## Limits

- Apps that play with session 0 (output mix) are skipped.
- If an app attaches its own LoudnessEnhancer with higher priority, that app's setting wins.
- `stubs/` holds minimal Xposed API stubs for compiling only; they are not packaged.

# Klee NavFull (Vector / LSPosed module)

Works on **HyperOS 4** (stock Poco X8 Pro ROM) and on the One UI port.

Hides the gesture bar, lets apps use the bottom strip where it was, and stops Circle to Search
(and the assistant fallback) from opening on a long-press at the bottom edge. Swipe gestures keep
working.

| Scope | What it does |
|---|---|
| `android` (system_server) | In gesture mode the nav bar window reports no `navigationBars` / `tappableElement` insets (`InsetsFrameProvider.getInsetsSize` → `Insets.NONE`), so apps lay out to the bottom edge. `ContextualSearchManagerService.startContextualSearch` refuses the nav-handle and home long-press entry points. |
| `com.android.systemui` | The `home_handle` view is not drawn. On start it sets `global hide_gesture_line 1` (HyperOS), `global navigation_bar_gesture_hint 0` (One UI) and `secure search_press_hold_nav_handle_enabled / search_long_press_home_enabled / assist_long_press_home_enabled` to 0. `AssistManager.startAssist` from a long-press is dropped. |
| `com.miui.home`, `com.mi.android.globallauncher` (POCO Launcher), `com.sec.android.app.launcher` | `ContextualSearchManager.startContextualSearch` from the nav handle / home is dropped; `home_handle` hidden there too. |

Gesture mode is read from `secure navigation_mode` (2), HyperOS `global force_fsg_nav_bar` (1) or
Samsung's `global navigation_bar_gesture_while_hidden` (1); in 3-button mode the insets are left alone.
The Circle to Search entry-point numbers are read from the framework's own constants.

Needs root (Magisk/KernelSU) with Zygisk and Vector. Install, enable the module, keep the
suggested scopes (HyperOS: System Framework, System UI, System Launcher), reboot. Logs: Vector's log view, lines starting with `KleeNavFull:`.

Build (no Gradle): `./build.sh` → `build/KleeNavFull.apk`. Needs build-tools and
`platforms/android-36` under `~/Android/Sdk` (or `ANDROID_HOME`); the Xposed API 82 jar is
downloaded for compiling only and is not packed into the APK.

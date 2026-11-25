package com.klee.navfull;

import android.app.Application;
import android.content.ContentResolver;
import android.content.Context;
import android.database.ContentObserver;
import android.graphics.Canvas;
import android.graphics.Insets;
import android.os.Bundle;
import android.os.Handler;
import android.os.HandlerThread;
import android.provider.Settings;
import android.view.View;
import android.view.WindowInsets;

import java.lang.reflect.Method;
import java.util.HashSet;
import java.util.Set;

import de.robv.android.xposed.IXposedHookLoadPackage;
import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XposedBridge;
import de.robv.android.xposed.XposedHelpers;
import de.robv.android.xposed.callbacks.XC_LoadPackage.LoadPackageParam;

/**
 * Klee NavFull (Vector / LSPosed module).
 *
 * android (system_server): in gesture navigation the navigation bar window reports no
 *   navigationBars / tappableElement insets, so apps lay out down to the bottom edge.
 *   Swipe gestures are unaffected (they come from the launcher's input monitor, and the
 *   mandatory/system gesture insets are kept). Circle to Search from the nav handle and
 *   home long-press is refused in ContextualSearchManagerService.
 * com.android.systemui: the gesture handle (id home_handle) is not drawn; Samsung's
 *   "gesture hint" is turned off and the long-press search/assistant settings are set to 0;
 *   assistant calls coming from a nav handle / home long-press are dropped.
 * launcher (com.miui.home, POCO Launcher, One UI Home): ContextualSearchManager calls from the
 *   nav handle are dropped.
 * Works on HyperOS (hide_gesture_line / force_fsg_nav_bar) and One UI (Samsung keys).
 */
public class Hook implements IXposedHookLoadPackage {
    private static final String TAG = "KleeNavFull: ";

    private static void log(String s) { XposedBridge.log(TAG + s); }

    @Override
    public void handleLoadPackage(LoadPackageParam lp) {
        switch (lp.packageName) {
            case "android":
                if ("android".equals(lp.processName)) {
                    hookInsets(lp.classLoader);
                    hookCtsService(lp.classLoader);
                }
                break;
            case "com.android.systemui":
                if ("com.android.systemui".equals(lp.processName)) {
                    hookHandle();
                    hookCtsClient(lp.classLoader);
                    hookAssist(lp.classLoader);
                    hookSettingsWrite();
                }
                break;
            default: // launcher (HyperOS'ta tutamak launcher penceresinde de olabilir)
                hookHandle();
                hookCtsClient(lp.classLoader);
                break;
        }
    }

    // ---------------------------------------------------------------- system_server: insets

    private static volatile boolean sGestural = false;

    private static boolean readGestural(ContentResolver cr) {
        int aosp = Settings.Secure.getInt(cr, "navigation_mode", -1);
        int sec = Settings.Global.getInt(cr, "navigation_bar_gesture_while_hidden", -1); // Samsung
        int mi = Settings.Global.getInt(cr, "force_fsg_nav_bar", -1); // HyperOS/MIUI tam ekran hareketleri
        return aosp == 2 || sec == 1 || mi == 1;
    }

    private void hookInsets(ClassLoader cl) {
        // Navigation mode is read off the WM lock: once at systemReady, then via an observer.
        try {
            XposedHelpers.findAndHookMethod("com.android.server.wm.WindowManagerService", cl, "systemReady",
                    new XC_MethodHook() {
                        @Override protected void afterHookedMethod(MethodHookParam p) {
                            final Context ctx = (Context) XposedHelpers.getObjectField(p.thisObject, "mContext");
                            HandlerThread t = new HandlerThread("KleeNavFull");
                            t.start();
                            final Handler h = new Handler(t.getLooper());
                            h.post(() -> {
                                final ContentResolver cr = ctx.getContentResolver();
                                ContentObserver o = new ContentObserver(h) {
                                    @Override public void onChange(boolean self) {
                                        sGestural = readGestural(cr);
                                        log("gestural=" + sGestural);
                                    }
                                };
                                cr.registerContentObserver(Settings.Secure.getUriFor("navigation_mode"), false, o);
                                cr.registerContentObserver(Settings.Global.getUriFor("navigation_bar_gesture_while_hidden"), false, o);
                                cr.registerContentObserver(Settings.Global.getUriFor("force_fsg_nav_bar"), false, o);
                                o.onChange(false);
                            });
                        }
                    });
        } catch (Throwable e) { log("systemReady hook: " + e); }

        final int hide = WindowInsets.Type.navigationBars() | WindowInsets.Type.tappableElement();
        try {
            Class<?> fp = XposedHelpers.findClass("android.view.InsetsFrameProvider", cl);
            XposedHelpers.findAndHookMethod(fp, "getInsetsSize", new XC_MethodHook() {
                @Override protected void beforeHookedMethod(MethodHookParam p) {
                    if (sGestural && ((int) XposedHelpers.callMethod(p.thisObject, "getType") & hide) != 0) p.setResult(Insets.NONE);
                }
            });
            XposedHelpers.findAndHookMethod(fp, "getInsetsSizeOverrides", new XC_MethodHook() {
                @Override protected void beforeHookedMethod(MethodHookParam p) {
                    if (sGestural && ((int) XposedHelpers.callMethod(p.thisObject, "getType") & hide) != 0) p.setResult(null);
                }
            });
            log("insets hooks ok");
        } catch (Throwable e) { log("insets hook: " + e); }
    }

    // ---------------------------------------------------------------- Circle to Search

    /** Entry points to refuse; read from the framework so the numbers are not guessed. */
    private static Set<Integer> ctsEntries(ClassLoader cl) {
        Set<Integer> s = new HashSet<>();
        try {
            Class<?> m = XposedHelpers.findClass("android.app.contextualsearch.ContextualSearchManager", cl);
            for (String f : new String[]{"ENTRYPOINT_LONG_PRESS_NAV_HANDLE", "ENTRYPOINT_LONG_PRESS_HOME"}) {
                try { s.add(XposedHelpers.getStaticIntField(m, f)); } catch (Throwable ignored) { }
            }
        } catch (Throwable ignored) { }
        return s;
    }

    private static XC_MethodHook ctsBlocker(final Set<Integer> entries, final String where) {
        return new XC_MethodHook() {
            @Override protected void beforeHookedMethod(MethodHookParam p) {
                if (p.args.length > 0 && p.args[0] instanceof Integer && entries.contains(p.args[0])) {
                    log(where + ": Circle to Search engellendi (entrypoint " + p.args[0] + ")");
                    p.setResult(null);
                }
            }
        };
    }

    private void hookCtsService(ClassLoader cl) {
        Set<Integer> e = ctsEntries(cl);
        if (e.isEmpty()) { log("CTS entrypoint sabitleri yok"); return; }
        for (String c : new String[]{
                "com.android.server.contextualsearch.ContextualSearchManagerService$ContextualSearchManagerStub",
                "com.android.server.contextualsearch.ContextualSearchManagerService"}) {
            try {
                int n = XposedBridge.hookAllMethods(XposedHelpers.findClass(c, cl), "startContextualSearch",
                        ctsBlocker(e, "system_server")).size();
                log(c + " startContextualSearch x" + n);
            } catch (Throwable t) { log("CTS service " + c + ": " + t); }
        }
    }

    private void hookCtsClient(ClassLoader cl) {
        Set<Integer> e = ctsEntries(cl);
        if (e.isEmpty()) return;
        try {
            XposedBridge.hookAllMethods(XposedHelpers.findClass("android.app.contextualsearch.ContextualSearchManager", cl),
                    "startContextualSearch", ctsBlocker(e, "client"));
        } catch (Throwable t) { log("CTS client: " + t); }
    }

    // ---------------------------------------------------------------- SystemUI

    private static int sHandleId = -1;
    private static final Set<Class<?>> sHooked = new HashSet<>();

    private void hookHandle() {
        XposedHelpers.findAndHookMethod(View.class, "onAttachedToWindow", new XC_MethodHook() {
            @Override protected void afterHookedMethod(MethodHookParam p) {
                View v = (View) p.thisObject;
                if (sHandleId == -1) sHandleId = v.getResources().getIdentifier("home_handle", "id", v.getContext().getPackageName());
                if (sHandleId == 0 || v.getId() != sHandleId) return;
                hideHandle(v);
            }
        });
    }

    private static void hideHandle(View v) {
        Class<?> cls = v.getClass();
        synchronized (sHooked) {
            if (!sHooked.contains(cls)) {
                sHooked.add(cls);
                Method m = null;
                for (Class<?> c = cls; c != null && c != View.class && m == null; c = c.getSuperclass()) {
                    try { m = c.getDeclaredMethod("onDraw", Canvas.class); } catch (NoSuchMethodException ignored) { }
                }
                if (m != null) {
                    XposedBridge.hookMethod(m, new XC_MethodHook() {
                        @Override protected void beforeHookedMethod(MethodHookParam p) {
                            if (((View) p.thisObject).getId() == sHandleId) p.setResult(null);
                        }
                    });
                    log("handle gizlendi: " + m);
                } else {
                    log("handle onDraw yok (" + cls.getName() + "), alpha 0");
                }
            }
        }
        v.setAlpha(0f);
        v.invalidate();
    }

    /** Assistant fallback for nav-handle / home long-press (Gemini instead of CTS). */
    private void hookAssist(ClassLoader cl) {
        final Set<Integer> types = new HashSet<>();
        try {
            Class<?> au = XposedHelpers.findClass("com.android.internal.app.AssistUtils", cl);
            for (String f : new String[]{"INVOCATION_TYPE_HOME_BUTTON_LONG_PRESS", "INVOCATION_TYPE_NAV_HANDLE_LONG_PRESS"}) {
                try { types.add(XposedHelpers.getStaticIntField(au, f)); } catch (Throwable ignored) { }
            }
        } catch (Throwable ignored) { }
        try {
            XposedBridge.hookAllMethods(XposedHelpers.findClass("com.android.systemui.assist.AssistManager", cl), "startAssist",
                    new XC_MethodHook() {
                        @Override protected void beforeHookedMethod(MethodHookParam p) {
                            for (Object a : p.args) {
                                if (!(a instanceof Bundle)) continue;
                                Bundle b = (Bundle) a;
                                boolean omni = b.containsKey("omni.entry_point");
                                int type = b.getInt("invocation_type", -1);
                                if (omni || types.contains(type)) {
                                    log("asistan engellendi (type " + type + ", omni " + omni + ")");
                                    p.setResult(null);
                                }
                                return;
                            }
                        }
                    });
        } catch (Throwable t) { log("AssistManager: " + t); }
    }

    /** Samsung gesture hint off + long-press search/assistant settings off, at every SystemUI start. */
    private void hookSettingsWrite() {
        XposedHelpers.findAndHookMethod(Application.class, "onCreate", new XC_MethodHook() {
            @Override protected void afterHookedMethod(MethodHookParam p) {
                ContentResolver cr = ((Application) p.thisObject).getContentResolver();
                try {
                    Settings.Global.putInt(cr, "hide_gesture_line", 1);            // HyperOS: hareket çizgisini gizle
                    Settings.Global.putInt(cr, "navigation_bar_gesture_hint", 0);  // One UI karşılığı
                    Settings.Secure.putInt(cr, "search_press_hold_nav_handle_enabled", 0);
                    Settings.Secure.putInt(cr, "search_long_press_home_enabled", 0);
                    Settings.Secure.putInt(cr, "assist_long_press_home_enabled", 0);
                    log("ayarlar yazildi");
                } catch (Throwable t) { log("ayar yazilamadi: " + t); }
            }
        });
    }
}

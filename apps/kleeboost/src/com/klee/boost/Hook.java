package com.klee.boost;

import de.robv.android.xposed.IXposedHookLoadPackage;
import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XposedBridge;
import de.robv.android.xposed.XposedHelpers;
import de.robv.android.xposed.callbacks.XC_LoadPackage;

/**
 * Vector / LSPosed girisi. Kapsam: "android" (System Framework = system_server).
 *
 * Ses akislarina dokunan tek sey Booster; burada sadece system_server hazir oldugunda
 * onu baslatiyoruz. ActivityManagerService.systemReady() AOSP, HyperOS ve One UI'da ayni.
 */
public class Hook implements IXposedHookLoadPackage {
    static final String TAG = "KleeBoost: ";

    @Override
    public void handleLoadPackage(XC_LoadPackage.LoadPackageParam lpparam) throws Throwable {
        if (!"android".equals(lpparam.packageName)) return;

        Class<?> ams = XposedHelpers.findClassIfExists(
                "com.android.server.am.ActivityManagerService", lpparam.classLoader);
        if (ams == null) {
            XposedBridge.log(TAG + "ActivityManagerService bulunamadi");
            return;
        }
        XposedBridge.hookAllMethods(ams, "systemReady", new XC_MethodHook() {
            @Override
            protected void afterHookedMethod(MethodHookParam param) {
                try {
                    Booster.start();
                } catch (Throwable t) {
                    XposedBridge.log(TAG + "baslatilamadi");
                    XposedBridge.log(t);
                }
            }
        });
        XposedBridge.log(TAG + "system_server'a yuklendi");
    }
}

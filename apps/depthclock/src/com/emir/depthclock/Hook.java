package com.emir.depthclock;

import de.robv.android.xposed.IXposedHookLoadPackage;
import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XposedBridge;
import de.robv.android.xposed.XposedHelpers;
import de.robv.android.xposed.callbacks.XC_LoadPackage;

/**
 * HyperOS kilit ekranı düzenleyicisi (com.miui.aod) derinlik efektini, saat dikdörtgeninin
 * belli bir oranı (resimde %20, videoda %50) nesne tarafından kapatılınca kapatıyor.
 *
 * Karar: com.miui.keyguard.editor.utils.CalculateWorker#calculateUnAlphaPercent()
 *   null  -> görüntü henüz hazır değil, kontrol atlanıyor (dokunmuyoruz)
 *   true  -> saat yeterince görünür, derinlik efekti açık kalır
 *   false -> "Saat belirsiz. Derinlik efekti kullanılamıyor." ve efekt kapanır
 *
 * Hesap bittiğinde sonucu her zaman true yapıyoruz. Kullanıcının efekti kendisi kapatması
 * (isUserOpenHierarchy) ayrı bir bayrak olduğu için etkilenmiyor.
 * Kaynak sürüm: MIUIAod DEV-2455.2.0.1-10230949 (OS4.0.5.0.XPJCNXM).
 */
public class Hook implements IXposedHookLoadPackage {
    private static final String TAG = "DepthClock: ";
    private static final String WORKER = "com.miui.keyguard.editor.utils.CalculateWorker";

    @Override
    public void handleLoadPackage(XC_LoadPackage.LoadPackageParam lpparam) {
        if (!"com.miui.aod".equals(lpparam.packageName)) return;
        try {
            XposedHelpers.findAndHookMethod(WORKER, lpparam.classLoader, "calculateUnAlphaPercent",
                    new XC_MethodHook() {
                        @Override
                        protected void afterHookedMethod(MethodHookParam param) {
                            Object r = param.getResult();
                            if (r != null && !Boolean.TRUE.equals(r)) {
                                param.setResult(Boolean.TRUE);
                            }
                        }
                    });
            XposedBridge.log(TAG + "hooked " + WORKER + ".calculateUnAlphaPercent");
        } catch (Throwable t) {
            XposedBridge.log(TAG + "hook failed (com.miui.aod surumu degismis olabilir): " + t);
        }
    }
}

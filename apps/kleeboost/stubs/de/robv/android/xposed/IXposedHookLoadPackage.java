package de.robv.android.xposed;
import de.robv.android.xposed.callbacks.XC_LoadPackage;
// Derleme icin stub. APK'ya girmez; gercegi Vector/LSPosed saglar.
public interface IXposedHookLoadPackage {
    void handleLoadPackage(XC_LoadPackage.LoadPackageParam lpparam) throws Throwable;
}

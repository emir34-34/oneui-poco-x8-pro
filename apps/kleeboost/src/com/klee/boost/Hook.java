package com.klee.boost;

import android.media.AudioAttributes;
import android.media.AudioManager;

import de.robv.android.xposed.IXposedHookLoadPackage;
import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XSharedPreferences;
import de.robv.android.xposed.XposedBridge;
import de.robv.android.xposed.XposedHelpers;
import de.robv.android.xposed.callbacks.XC_LoadPackage;

import java.lang.reflect.Field;

/**
 * Vector / LSPosed girisi. Kapsam: "android" (System Framework = system_server).
 *
 * Sistemin kendi muzik ses cubugunu uzatir: AudioService'teki STREAM_MUSIC en yuksek
 * seviyesi %150'ye denk gelecek sekilde artirilir (ornek: 15 adim -> 23 adim). Ses tuslari,
 * HyperOS ses paneli ve Ayarlar > Ses ayni cubugu kullandigi icin hepsi %150'ye kadar gider.
 *
 * Ses sistemine (audio policy) ise eski en yuksek seviye bildirilir ve %100'un ustundeki
 * seviyeler %100'e sabitlenir; ustteki kisim Booster'in LoudnessEnhancer kazancina cevrilir.
 */
public class Hook implements IXposedHookLoadPackage {
    static final String TAG = "KleeBoost: ";

    /** Gercek (orijinal) en yuksek muzik seviyesi, adim cinsinden. 0 = uzatma yapilmadi. */
    static volatile int origMaxSteps;
    /** Uzatilmis en yuksek muzik seviyesi (cubugun %150 noktasi), adim cinsinden. */
    static volatile int newMaxSteps;

    @Override
    public void handleLoadPackage(XC_LoadPackage.LoadPackageParam lpparam) throws Throwable {
        if (!"android".equals(lpparam.packageName)) return;
        ClassLoader cl = lpparam.classLoader;

        try {
            hookVolumeRange(cl);
        } catch (Throwable t) {
            XposedBridge.log(TAG + "ses cubugu uzatilamadi, sabit kazanc moduna geciliyor");
            XposedBridge.log(t);
        }

        Class<?> ams = XposedHelpers.findClassIfExists(
                "com.android.server.am.ActivityManagerService", cl);
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

    private static void hookVolumeRange(ClassLoader cl) throws Throwable {
        Class<?> vss = XposedHelpers.findClassIfExists(
                "com.android.server.audio.AudioService$VolumeStreamState", cl);
        if (vss == null) throw new ClassNotFoundException("AudioService$VolumeStreamState");
        final Field fStream = field(vss, "mStreamType");
        final Field fMax = field(vss, "mIndexMax");

        XSharedPreferences prefs = new XSharedPreferences(Prefs.PKG, Prefs.FILE);
        final int pct = Math.max(Prefs.MIN_PERCENT, Math.min(Prefs.MAX_PERCENT,
                prefs.getInt(Prefs.PERCENT, Prefs.DEF_PERCENT)));
        if (pct <= 100) return;

        // 1) Muzik cubugunu uzat. mIndexMax onda bir adim cinsinden (15 adim = 150).
        XposedBridge.hookAllConstructors(vss, new XC_MethodHook() {
            @Override
            protected void afterHookedMethod(MethodHookParam param) throws Throwable {
                if (fStream.getInt(param.thisObject) != AudioManager.STREAM_MUSIC) return;
                int max = fMax.getInt(param.thisObject);
                int orig = (max + 5) / 10;
                if (orig <= 0) return;
                int ext = (orig * pct + 50) / 100;
                if (ext <= orig) return;
                origMaxSteps = orig;
                newMaxSteps = ext;
                fMax.setInt(param.thisObject, ext * 10);
                XposedBridge.log(TAG + "muzik cubugu " + orig + " -> " + ext + " adim (%" + pct + ")");
            }
        });

        // 2) Ses sistemine giden seviyeleri gercek araliga sabitle.
        Class<?> as = Class.forName("android.media.AudioSystem");
        XposedBridge.hookAllMethods(as, "initStreamVolume", new XC_MethodHook() {
            @Override
            protected void beforeHookedMethod(MethodHookParam p) {
                // initStreamVolume(stream, indexMin, indexMax): audio policy eski araligi bilsin
                if (origMaxSteps > 0 && p.args.length == 3 && isMusic(p.args[0])) {
                    p.args[2] = origMaxSteps;
                }
            }
        });
        XC_MethodHook clampStreamIndex = new XC_MethodHook() {
            @Override
            protected void beforeHookedMethod(MethodHookParam p) {
                // setStreamVolumeIndexAS / getStreamVolumeDB (stream, index, device)
                if (origMaxSteps > 0 && p.args.length >= 2 && isMusic(p.args[0])) clampArg(p.args, 1);
            }
        };
        XposedBridge.hookAllMethods(as, "setStreamVolumeIndexAS", clampStreamIndex);
        XposedBridge.hookAllMethods(as, "getStreamVolumeDB", clampStreamIndex);
        XposedBridge.hookAllMethods(as, "setVolumeIndexForAttributes", new XC_MethodHook() {
            @Override
            protected void beforeHookedMethod(MethodHookParam p) {
                // setVolumeIndexForAttributes(AudioAttributes, index, device)
                if (origMaxSteps > 0 && p.args.length >= 2 && p.args[0] instanceof AudioAttributes
                        && ((AudioAttributes) p.args[0]).getVolumeControlStream()
                           == AudioManager.STREAM_MUSIC) {
                    clampArg(p.args, 1);
                }
            }
        });

        // 3) Bluetooth / LE Audio mutlak ses: kulaklik eski %100'unde tam sese ulassin.
        Class<?> broker = XposedHelpers.findClassIfExists(
                "com.android.server.audio.AudioDeviceBroker", cl);
        if (broker != null) {
            XposedBridge.hookAllMethods(broker, "postSetAvrcpAbsoluteVolumeIndex", new XC_MethodHook() {
                @Override
                protected void beforeHookedMethod(MethodHookParam p) {
                    // index / getStreamMaxVolume() ile olceklenir; yeni maks'a gore yeniden olcekle
                    if (origMaxSteps > 0 && p.args.length == 1 && p.args[0] instanceof Integer) {
                        int i = Math.min((Integer) p.args[0], origMaxSteps);
                        p.args[0] = (i * newMaxSteps + origMaxSteps / 2) / origMaxSteps;
                    }
                }
            });
            XposedBridge.hookAllMethods(broker, "postSetLeAudioVolumeIndex", new XC_MethodHook() {
                @Override
                protected void beforeHookedMethod(MethodHookParam p) {
                    // (index*10, maxIndex*10, streamType): eski araligi gonder
                    if (origMaxSteps > 0 && p.args.length == 3 && isMusic(p.args[2])
                            && p.args[0] instanceof Integer && p.args[1] instanceof Integer) {
                        p.args[0] = Math.min((Integer) p.args[0], origMaxSteps * 10);
                        p.args[1] = origMaxSteps * 10;
                    }
                }
            });
        }
    }

    private static boolean isMusic(Object stream) {
        return stream instanceof Integer && (Integer) stream == AudioManager.STREAM_MUSIC;
    }

    private static void clampArg(Object[] args, int i) {
        if (args[i] instanceof Integer && (Integer) args[i] > origMaxSteps) args[i] = origMaxSteps;
    }

    private static Field field(Class<?> c, String name) throws NoSuchFieldException {
        Field f = c.getDeclaredField(name);
        f.setAccessible(true);
        return f;
    }
}

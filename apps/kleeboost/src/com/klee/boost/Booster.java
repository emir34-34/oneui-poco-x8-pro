package com.klee.boost;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.media.AudioAttributes;
import android.media.AudioDeviceInfo;
import android.media.AudioManager;
import android.media.AudioPlaybackConfiguration;
import android.media.audiofx.LoudnessEnhancer;
import android.os.Handler;
import android.os.HandlerThread;

import de.robv.android.xposed.XSharedPreferences;
import de.robv.android.xposed.XposedBridge;

import java.lang.reflect.Method;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * system_server icinde calisir. Her calan oynaticinin (AudioTrack, MediaPlayer, ExoPlayer,
 * AAudio/OpenSL) ses oturumuna bir LoudnessEnhancer takar. Boylece %100 ses seviyesinin
 * ustune, sinirlayicili (clip yapmayan) ek kazanc gelir: %150 = +3.5 dB.
 *
 * system_server MODIFY_AUDIO_ROUTING iznine sahip oldugu icin AudioPlaybackCallback ona
 * gercek oturum kimliklerini verir (normal uygulamalar anonimlestirilmis liste alir).
 */
final class Booster {
    private static final String TAG = Hook.TAG;

    private static boolean started;

    private final Context context;
    private final AudioManager audio;
    private final Handler handler;
    private final XSharedPreferences prefs;

    /** oturum kimligi -> takili efekt */
    private final Map<Integer, LoudnessEnhancer> effects = new HashMap<>();
    /** efekt takilamayan oturumlar (tekrar tekrar denememek icin) */
    private final Set<Integer> failed = new HashSet<>();

    private boolean enabled;
    private int gainMb;
    private boolean headphones;
    private boolean allUsages;

    private Method getSessionId;
    private Method getPlayerState;
    private Method getDeviceInfo;

    static synchronized void start() throws Exception {
        if (started) return;
        started = true;
        Object at = Class.forName("android.app.ActivityThread")
                .getMethod("currentActivityThread").invoke(null);
        Context ctx = (Context) at.getClass().getMethod("getSystemContext").invoke(at);
        HandlerThread thread = new HandlerThread("KleeBoost");
        thread.start();
        final Booster b = new Booster(ctx, new Handler(thread.getLooper()));
        b.handler.post(b::init);
    }

    private Booster(Context context, Handler handler) {
        this.context = context;
        this.handler = handler;
        this.audio = context.getSystemService(AudioManager.class);
        this.prefs = new XSharedPreferences(Prefs.PKG, Prefs.FILE);
    }

    private void init() {
        try {
            getSessionId = AudioPlaybackConfiguration.class.getMethod("getSessionId");
        } catch (NoSuchMethodException e) {
            XposedBridge.log(TAG + "getSessionId yok, modul calisamaz");
            return;
        }
        getPlayerState = optMethod("getPlayerState");
        getDeviceInfo = optMethod("getAudioDeviceInfo");

        loadPrefs();

        audio.registerAudioPlaybackCallback(new AudioManager.AudioPlaybackCallback() {
            @Override
            public void onPlaybackConfigChanged(List<AudioPlaybackConfiguration> configs) {
                if (prefs.hasFileChanged()) loadPrefs();
                apply(configs);
            }
        }, handler);

        // Uygulamadaki ayar degisikligini yeniden baslatmadan uygula.
        context.registerReceiver(new BroadcastReceiver() {
            @Override
            public void onReceive(Context c, Intent i) {
                loadPrefs();
                apply(audio.getActivePlaybackConfigurations());
            }
        }, new IntentFilter(Prefs.ACTION_RELOAD), null, handler, Context.RECEIVER_EXPORTED);

        apply(audio.getActivePlaybackConfigurations());
        XposedBridge.log(TAG + "hazir, enabled=" + enabled + " gain=" + gainMb + "mB");
    }

    private void loadPrefs() {
        prefs.reload();
        enabled = prefs.getBoolean(Prefs.ENABLED, Prefs.DEF_ENABLED);
        int pct = prefs.getInt(Prefs.PERCENT, Prefs.DEF_PERCENT);
        pct = Math.max(Prefs.MIN_PERCENT, Math.min(Prefs.MAX_PERCENT, pct));
        gainMb = Prefs.percentToMb(pct);
        headphones = prefs.getBoolean(Prefs.HEADPHONES, Prefs.DEF_HEADPHONES);
        allUsages = prefs.getBoolean(Prefs.ALL_USAGES, Prefs.DEF_ALL_USAGES);
        failed.clear();
    }

    private void apply(List<AudioPlaybackConfiguration> configs) {
        if (!enabled || gainMb <= 0) {
            releaseAll();
            return;
        }

        // Bir oturumda birden fazla oynatici olabilir: biri uygunsa efekt acik.
        Map<Integer, Boolean> wanted = new HashMap<>();
        boolean headsetConnected = !headphones && headsetConnected();
        for (AudioPlaybackConfiguration c : configs) {
            int session = intCall(getSessionId, c, 0);
            if (session <= 0) continue; // 0 = cikis karisimi, dokunma
            if (intCall(getPlayerState, c, -1) == 0 /* RELEASED */) continue;
            boolean ok = usageAllowed(c.getAudioAttributes()) && routeAllowed(c, headsetConnected);
            Boolean prev = wanted.get(session);
            wanted.put(session, ok || (prev != null && prev));
        }

        // Kapanan oturumlarin efektlerini birak.
        Iterator<Map.Entry<Integer, LoudnessEnhancer>> it = effects.entrySet().iterator();
        while (it.hasNext()) {
            Map.Entry<Integer, LoudnessEnhancer> e = it.next();
            if (!wanted.containsKey(e.getKey())) {
                safeRelease(e.getValue());
                it.remove();
            }
        }
        failed.retainAll(wanted.keySet());

        for (Map.Entry<Integer, Boolean> w : wanted.entrySet()) {
            int session = w.getKey();
            boolean on = w.getValue();
            LoudnessEnhancer le = effects.get(session);
            if (le == null) {
                if (!on || failed.contains(session)) continue;
                try {
                    le = new LoudnessEnhancer(session);
                    effects.put(session, le);
                } catch (Throwable t) {
                    failed.add(session);
                    XposedBridge.log(TAG + "oturum " + session + " icin efekt yok: " + t);
                    continue;
                }
            }
            try {
                le.setTargetGain(gainMb);
                le.setEnabled(on);
            } catch (Throwable t) {
                XposedBridge.log(TAG + "oturum " + session + " ayarlanamadi: " + t);
            }
        }
    }

    /** Varsayilan: sadece medya, oyun ve bilinmeyen kullanim. Bildirim, zil, arama haric. */
    private boolean usageAllowed(AudioAttributes aa) {
        if (allUsages) return true;
        if (aa == null) return true;
        int u = aa.getUsage();
        return u == AudioAttributes.USAGE_MEDIA
                || u == AudioAttributes.USAGE_GAME
                || u == AudioAttributes.USAGE_UNKNOWN;
    }

    /** Kulaklik secenegi kapaliyken sadece dahili hoparlorde artir (isitme saglidi). */
    private boolean routeAllowed(AudioPlaybackConfiguration c, boolean headsetConnected) {
        if (headphones) return true;
        AudioDeviceInfo dev = null;
        if (getDeviceInfo != null) {
            try {
                dev = (AudioDeviceInfo) getDeviceInfo.invoke(c);
            } catch (Throwable ignored) {
            }
        }
        if (dev == null) return !headsetConnected;
        return !isHeadphoneLike(dev.getType());
    }

    private boolean headsetConnected() {
        for (AudioDeviceInfo d : audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS)) {
            if (isHeadphoneLike(d.getType())) return true;
        }
        return false;
    }

    private static boolean isHeadphoneLike(int type) {
        switch (type) {
            case AudioDeviceInfo.TYPE_WIRED_HEADSET:
            case AudioDeviceInfo.TYPE_WIRED_HEADPHONES:
            case AudioDeviceInfo.TYPE_BLUETOOTH_A2DP:
            case AudioDeviceInfo.TYPE_BLUETOOTH_SCO:
            case AudioDeviceInfo.TYPE_USB_HEADSET:
            case AudioDeviceInfo.TYPE_HEARING_AID:
            case AudioDeviceInfo.TYPE_BLE_HEADSET:
                return true;
            default:
                return false;
        }
    }

    private void releaseAll() {
        for (LoudnessEnhancer le : effects.values()) safeRelease(le);
        effects.clear();
    }

    private static void safeRelease(LoudnessEnhancer le) {
        try {
            le.setEnabled(false);
        } catch (Throwable ignored) {
        }
        try {
            le.release();
        } catch (Throwable ignored) {
        }
    }

    private static Method optMethod(String name) {
        try {
            return AudioPlaybackConfiguration.class.getMethod(name);
        } catch (NoSuchMethodException e) {
            return null;
        }
    }

    private static int intCall(Method m, Object o, int def) {
        if (m == null) return def;
        try {
            return (Integer) m.invoke(o);
        } catch (Throwable t) {
            return def;
        }
    }
}

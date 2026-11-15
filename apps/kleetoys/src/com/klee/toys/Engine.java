package com.klee.toys;

import android.content.Context;
import android.media.audiofx.Visualizer;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;

/** Tum efektleri calistiran tek is parcacigi. Kose sirasi saat yonu: 0 ust sol, 1 ust sag, 2 alt sag, 3 alt sol. */
final class Engine {
    static final int OFF = 0, STATIC = 1, ANIM = 2, MUSIC_HYPER = 3, MUSIC_KLEE = 4;
    static final String[] ANIMS = {"Kuyruklu yıldız", "Gökkuşağı dönüşü", "Nefes", "Polis", "Şarj", "Kalp atışı", "Renk akışı"};

    final LedOut led;
    private final Context ctx;
    private Thread th;
    private volatile int mode = OFF, anim;
    volatile int[] colors = {0xff0000, 0x0000ff, 0x00ff00, 0xffff00};
    volatile int accent = 0x00ffff;
    volatile String status = "";

    Engine(Context c) { ctx = c; led = new LedOut(c); }

    int mode() { return mode; }
    int anim() { return anim; }

    synchronized void setStatic(int[] c) { colors = c.clone(); start(STATIC, 0); }
    synchronized void setAnim(int a) { start(ANIM, a); }
    synchronized void setMusic(boolean hyper) { start(hyper ? MUSIC_HYPER : MUSIC_KLEE, 0); }
    synchronized void stop() { start(OFF, 0); }

    private void start(int m, int a) {
        mode = m; anim = a;
        if (th != null) { th.interrupt(); try { th.join(500); } catch (InterruptedException ignored) { } }
        th = null;
        if (m == OFF) { led.off(); status = "Kapalı"; return; }
        final int my = m;
        th = new Thread(() -> {
            try {
                if (my == STATIC) runStatic();
                else if (my == ANIM) runAnim(a);
                else runMusic(my == MUSIC_HYPER);
            } catch (InterruptedException ignored) {
            } catch (Throwable t) { status = "Hata: " + t.getMessage(); }
        }, "klee-led");
        th.start();
    }

    private boolean alive() { return !Thread.currentThread().isInterrupted(); }
    private static void nap(long ms) throws InterruptedException { Thread.sleep(ms); }

    private void runStatic() throws InterruptedException {
        status = "Sabit renk";
        while (alive()) { led.set(colors); nap(250); }
    }

    // ---------------- Animasyonlar ----------------
    private static int mix(int a, int b, float t) {
        int r = (int) (((a >> 16) & 255) * (1 - t) + ((b >> 16) & 255) * t);
        int g = (int) (((a >> 8) & 255) * (1 - t) + ((b >> 8) & 255) * t);
        int bl = (int) ((a & 255) * (1 - t) + (b & 255) * t);
        return (r << 16) | (g << 8) | bl;
    }
    private static int dim(int c, float t) { return mix(0, c, Math.max(0, Math.min(1, t))); }
    static int hsv(float h, float s, float v) { return android.graphics.Color.HSVToColor(new float[]{h, s, v}) & 0xffffff; }

    private void runAnim(int a) throws InterruptedException {
        status = ANIMS[a];
        long t0 = System.currentTimeMillis();
        int[] f = new int[4];
        while (alive()) {
            float t = (System.currentTimeMillis() - t0) / 1000f;
            switch (a) {
                case 0: { // kuyruklu yildiz: saat yonunde, arkasinda sonen iz
                    float p = (t * 1.6f) % 4f;
                    for (int i = 0; i < 4; i++) {
                        float d = (p - i + 4f) % 4f;           // basin arkasindaki mesafe
                        f[i] = dim(accent, d < 1f ? 1f : (float) Math.pow(0.25, d));
                    }
                    break;
                }
                case 1: { // gokkusagi donusu: renk tekerlegi yumusakca doner
                    for (int i = 0; i < 4; i++) f[i] = hsv((t * 90f + i * 90f) % 360f, 1f, 1f);
                    break;
                }
                case 2: { // nefes
                    float v = (float) (0.5 - 0.5 * Math.cos(t * 2 * Math.PI / 3.2));
                    for (int i = 0; i < 4; i++) f[i] = dim(accent, v * v);
                    break;
                }
                case 3: { // polis: sol kirmizi / sag mavi uclu cakar
                    float c = t % 0.72f; boolean left = c < 0.36f; float k = (c % 0.36f) % 0.12f;
                    boolean on = k < 0.06f;
                    f[0] = f[3] = (left && on) ? 0xff0000 : 0;
                    f[1] = f[2] = (!left && on) ? 0x0000ff : 0;
                    break;
                }
                case 4: { // sarj: koseler sirayla dolar, sonra 3 kez yanip soner
                    float c = t % 3.6f;
                    if (c < 2.4f) { int n = (int) (c / 0.6f) + 1; for (int i = 0; i < 4; i++) f[i] = i < n ? 0x00ff00 : 0; }
                    else { boolean on = ((int) ((c - 2.4f) / 0.2f)) % 2 == 1; for (int i = 0; i < 4; i++) f[i] = on ? 0x00ff00 : 0; }
                    break;
                }
                case 5: { // kalp atisi: cift vurus
                    float c = t % 1.2f;
                    float v = c < 0.1f ? 1f : c < 0.22f ? 0f : c < 0.32f ? 1f : Math.max(0f, 1f - (c - 0.32f) * 4f) * 0.25f;
                    for (int i = 0; i < 4; i++) f[i] = dim(0xff0000, v);
                    break;
                }
                default: { // renk akisi: tum halka ayni renk, yavas gokkusagi
                    int c = hsv((t * 30f) % 360f, 1f, 1f);
                    for (int i = 0; i < 4; i++) f[i] = c;
                }
            }
            led.set(f);
            nap(30);
        }
    }

    // ---------------- Muzik ----------------
    private void runMusic(boolean hyper) throws InterruptedException {
        boolean xi = hyper && initHyper();
        if (hyper && !xi) status = "HyperOS modu yok, Klee moduna geçildi";
        else status = xi ? "Müzik: HyperOS" : "Müzik: Klee";
        Visualizer v = null;
        try {
            v = new Visualizer(0);
            v.setEnabled(false);
            int cs = Visualizer.getCaptureSizeRange()[1];
            v.setCaptureSize(cs);
            v.setScalingMode(Visualizer.SCALING_MODE_NORMALIZED);
            v.setEnabled(true);
            double binHz = v.getSamplingRate() / 1000.0 / cs;
            byte[] buf = new byte[cs];
            short[] sm = new short[cs];
            double bri = 0, red = 0, maxE = 1e-3, maxB = 1e-3, maxH = 1e-3;
            long quietSince = 0;
            while (alive()) {
                if (xi) {
                    if (v.getWaveForm(buf) != Visualizer.SUCCESS) { nap(20); continue; }
                    int pk = 0;
                    for (int k = 0; k < cs; k++) { sm[k] = (short) (((buf[k] & 0xff) - 128) << 8); pk = Math.max(pk, Math.abs(sm[k])); }
                    int col = Xled.xproc(sm, cs) & 0xffffff;
                    if (pk < 300) { if (quietSince == 0) quietSince = System.currentTimeMillis(); } else quietSince = 0;
                    if (quietSince != 0 && System.currentTimeMillis() - quietSince > 400) col = 0;
                    led.all(col);
                    nap(20);
                    continue;
                }
                if (v.getFft(buf) != Visualizer.SUCCESS) { nap(25); continue; }
                double bass = 0, high = 0;
                for (int k = 1; k < cs / 2; k++) {
                    double fz = k * binHz, re = buf[2 * k], im = buf[2 * k + 1], m = Math.sqrt(re * re + im * im);
                    if (fz < 40) continue;
                    if (fz <= 160) bass += m * 2.0; else if (fz <= 6000) high += m;
                }
                double e = bass + high;
                maxE = Math.max(maxE * 0.995, e);
                double lvl = e < 8 ? 0 : e / maxE;
                bri = lvl > bri ? lvl : bri * 0.88 + lvl * 0.12;
                maxB = Math.max(maxB * 0.997, bass); maxH = Math.max(maxH * 0.997, high);
                double bN = bass / maxB, hN = high / maxH;
                double tr = Math.min(1, Math.max(0, (bN - 0.55) / 0.3 + (bN - hN) * 0.8));
                red = tr > red ? red * 0.3 + tr * 0.7 : red * 0.85 + tr * 0.15;
                int B = (int) Math.round(255 * Math.min(1, bri));
                led.all(((int) (B * red) << 16) | (int) (B * (1 - red)));
                nap(25);
            }
        } finally {
            if (v != null) { try { v.setEnabled(false); } catch (Throwable ignored) { } v.release(); }
        }
    }

    private boolean hyperReady;
    private boolean initHyper() {
        if (hyperReady) return true;
        if (!Xled.loaded) return false;
        String lib = libPath(ctx);
        if (lib == null) return false;
        File bin = new File(ctx.getFilesDir(), "mis_audioled_configs.bin");
        if (!bin.exists()) {
            try (InputStream in = ctx.getAssets().open("mis_audioled_configs.bin"); FileOutputStream o = new FileOutputStream(bin)) {
                byte[] b = new byte[4096]; int n; while ((n = in.read(b)) > 0) o.write(b, 0, n);
            } catch (Exception e) {
                bin = new File("/vendor/etc/audio_param/mis_audioled_configs.bin");
            }
        }
        hyperReady = Xled.xinit(lib, bin.getPath(), 48000, 1) == 0;
        return hyperReady;
    }

    /** Cikarilmis dosya varsa onun yolu, yoksa APK icinden ada gore yukleme (extractNativeLibs=false). */
    static String libPath(Context c) {
        if (!Xled.loaded) return null;
        File f = new File(c.getApplicationInfo().nativeLibraryDir, "libmis_audioled.so");
        if (f.exists()) return f.getPath();
        try { return Xled.xhas("libmis_audioled.so") ? "libmis_audioled.so" : null; } catch (Throwable t) { return null; }
    }

    static boolean hyperAvailable(Context c) { return libPath(c) != null; }
}

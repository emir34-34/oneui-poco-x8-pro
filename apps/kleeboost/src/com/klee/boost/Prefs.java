package com.klee.boost;

/** Ayar anahtarlari: hem uygulama (MainActivity) hem system_server (Booster) kullanir. */
final class Prefs {
    static final String PKG = "com.klee.boost";
    static final String FILE = "boost";
    static final String ACTION_RELOAD = "com.klee.boost.RELOAD";

    static final String ENABLED = "enabled";
    static final String PERCENT = "percent";        // ses cubugunun en ustu, 100..300
    static final String HEADPHONES = "headphones";  // kulaklik / Bluetooth'ta da uygula

    static final boolean DEF_ENABLED = true;
    static final int DEF_PERCENT = 150;
    static final boolean DEF_HEADPHONES = false;

    static final int MIN_PERCENT = 100;
    static final int MAX_PERCENT = 300;

    /** Genlik yuzdesini LoudnessEnhancer kazancina (milibel) cevirir. %150 -> 352 mB (+3.5 dB). */
    static int percentToMb(int percent) {
        if (percent <= 100) return 0;
        return (int) Math.round(2000.0 * Math.log10(percent / 100.0));
    }

    private Prefs() {}
}

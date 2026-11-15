package com.klee.toys;

/** HyperOS muzik isigi algoritmasina (libmis_audioled) JNI koprusu. Kutuphane yoksa kullanilamaz. */
final class Xled {
    static boolean loaded;
    static {
        try { System.loadLibrary("xled"); loaded = true; } catch (Throwable t) { loaded = false; }
    }
    static native int xinit(String lib, String bin, int sampleRate, int channels);
    static native int xproc(short[] samples, int n);
    static native boolean xhas(String lib);
}

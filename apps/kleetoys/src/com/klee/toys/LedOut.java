package com.klee.toys;

import android.content.Context;
import android.net.LocalSocket;
import android.net.LocalSocketAddress;
import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;

/**
 * kleeledd'e komut yazar. Kose sirasi: 0 ust sol, 1 ust sag, 2 alt sag, 3 alt sol.
 * Once /dev/socket/kleeledd (imajdaki servis), o yoksa @kleeledd (gelistirme), en son files/led.cmd (eski betik).
 */
final class LedOut {
    private final File file;
    private LocalSocket sock;
    private OutputStream out;
    private boolean fileMode;
    private String last = "";
    private int lines;
    private long nextTry;
    volatile float brightness = 1f;

    LedOut(Context c) { file = new File(c.getFilesDir(), "led.cmd"); }

    synchronized void set(int[] rgb) {
        StringBuilder sb = new StringBuilder("q");
        for (int i = 0; i < 4; i++) sb.append(' ').append(String.format("%06x", scale(rgb[i]) & 0xffffff));
        write(sb.toString());
    }

    void all(int rgb) { set(new int[]{rgb, rgb, rgb, rgb}); }

    synchronized void off() { write("off"); }

    /** Servis yasiyor mu (arayuzde gostermek icin). */
    synchronized String transport() { return out == null ? "bağlı değil" : fileMode ? "dosya (geliştirme)" : "kleeledd"; }

    private int scale(int c) {
        float b = brightness;
        int r = (int) (((c >> 16) & 0xff) * b), g = (int) (((c >> 8) & 0xff) * b), bl = (int) ((c & 0xff) * b);
        return (r << 16) | (g << 8) | bl;
    }

    private boolean connect() {
        if (out != null) return true;
        if (System.currentTimeMillis() < nextTry) return false;
        for (LocalSocketAddress a : new LocalSocketAddress[]{
                new LocalSocketAddress("kleeledd", LocalSocketAddress.Namespace.RESERVED),
                new LocalSocketAddress("kleeledd", LocalSocketAddress.Namespace.ABSTRACT)}) {
            try {
                LocalSocket s = new LocalSocket();
                s.connect(a);
                sock = s; out = s.getOutputStream(); fileMode = false;
                return true;
            } catch (Exception ignored) { }
        }
        try {
            file.getParentFile().setExecutable(true, false);
            out = new FileOutputStream(file, false);
            file.setReadable(true, false);
            fileMode = true; lines = 0;
            return true;
        } catch (Exception e) {
            nextTry = System.currentTimeMillis() + 2000;
            return false;
        }
    }

    private void drop() {
        try { if (out != null) out.close(); } catch (Exception ignored) { }
        try { if (sock != null) sock.close(); } catch (Exception ignored) { }
        out = null; sock = null; last = "";
        nextTry = System.currentTimeMillis() + 1000;
    }

    private void write(String s) {
        if (s.equals(last)) return;
        if (!connect()) return;
        try {
            if (fileMode && lines > 20000) { drop(); if (!connect()) return; }
            out.write((s + "\n").getBytes());
            out.flush();
            last = s;
            lines++;
        } catch (Exception e) { drop(); }
    }

    /** Efekt bitince baglantiyi kapat; kleeledd son istemci gidince isiklari zaten sondurur. */
    synchronized void close() { drop(); }
}

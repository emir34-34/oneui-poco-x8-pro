package de.robv.android.xposed;
import java.io.File;
public final class XSharedPreferences {
    public XSharedPreferences(String packageName, String prefFileName) {}
    public File getFile() { return null; }
    public synchronized void reload() {}
    public synchronized boolean hasFileChanged() { return false; }
    public int getInt(String key, int defValue) { return defValue; }
    public boolean getBoolean(String key, boolean defValue) { return defValue; }
}

package com.klee.boost;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.LinearLayout;
import android.widget.SeekBar;
import android.widget.Switch;
import android.widget.TextView;

import java.util.Locale;

/** Ayar ekrani. Degisiklikler aninda system_server'a iletilir (yeniden baslatma gerekmez). */
public class MainActivity extends Activity {
    private static final int STEP = 5;

    private SharedPreferences prefs;
    private boolean moduleActive = true;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        try {
            // Vector/LSPosed, xposedsharedprefs ile bu modu destekler ve dosyayi
            // system_server'in okuyabilecegi yere koyar. Modul etkin degilse hata verir.
            //noinspection deprecation
            prefs = getSharedPreferences(Prefs.FILE, Context.MODE_WORLD_READABLE);
        } catch (SecurityException e) {
            moduleActive = false;
            prefs = getSharedPreferences(Prefs.FILE, Context.MODE_PRIVATE);
        }

        int pad = dp(20);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(pad, pad * 2, pad, pad);

        TextView title = new TextView(this);
        title.setText("KleeBoost — ses yükseltici");
        title.setTextSize(22);
        root.addView(title);

        TextView status = new TextView(this);
        status.setText(moduleActive
                ? "Modül etkin. Ayarlar hemen uygulanır."
                : "Modül Vector/LSPosed'da etkin değil. Etkinleştirin, kapsamda \"System Framework\" "
                  + "seçili olsun ve telefonu yeniden başlatın.");
        status.setPadding(0, dp(8), 0, dp(16));
        root.addView(status);

        Switch enabled = new Switch(this);
        enabled.setText("Ses yükseltme açık");
        enabled.setChecked(prefs.getBoolean(Prefs.ENABLED, Prefs.DEF_ENABLED));
        enabled.setOnCheckedChangeListener((v, on) -> save(Prefs.ENABLED, on));
        root.addView(enabled);

        final TextView level = new TextView(this);
        level.setTextSize(18);
        level.setGravity(Gravity.CENTER_HORIZONTAL);
        level.setPadding(0, dp(24), 0, dp(4));
        TextView barTitle = new TextView(this);
        barTitle.setText("Ses çubuğunun en üstü");
        barTitle.setPadding(0, dp(24), 0, 0);
        root.addView(barTitle);
        root.addView(level);

        SeekBar bar = new SeekBar(this);
        bar.setMax((Prefs.MAX_PERCENT - Prefs.MIN_PERCENT) / STEP);
        int pct = prefs.getInt(Prefs.PERCENT, Prefs.DEF_PERCENT);
        bar.setProgress((pct - Prefs.MIN_PERCENT) / STEP);
        showLevel(level, pct);
        bar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar s, int p, boolean user) {
                showLevel(level, Prefs.MIN_PERCENT + p * STEP);
            }
            @Override public void onStartTrackingTouch(SeekBar s) {}
            @Override public void onStopTrackingTouch(SeekBar s) {
                save(Prefs.PERCENT, Prefs.MIN_PERCENT + s.getProgress() * STEP);
            }
        });
        root.addView(bar);

        Switch hp = new Switch(this);
        hp.setText("Kulaklık ve Bluetooth'ta da uygula (işitme sağlığına dikkat)");
        hp.setChecked(prefs.getBoolean(Prefs.HEADPHONES, Prefs.DEF_HEADPHONES));
        hp.setOnCheckedChangeListener((v, on) -> save(Prefs.HEADPHONES, on));
        hp.setPadding(0, dp(24), 0, 0);
        root.addView(hp);

        TextView note = new TextView(this);
        note.setText("Medya ses çubuğu (ses tuşları, ses paneli, Ayarlar > Ses) %100'ü geçip bu "
                + "değere kadar uzar. Eski en üst nokta artık %100; üstündeki her adım sesi "
                + "biraz daha yükseltir. Çubuğun uzunluğu yeniden başlatınca değişir, "
                + "en üstteki kazanç hemen. Sınırlayıcı sayesinde ses patlamaz.\n\n"
                + "Kulaklık seçeneği kapalıyken kulaklıkta %100'ün üstü %100 gibi davranır.");
        note.setPadding(0, dp(24), 0, 0);
        note.setAlpha(0.7f);
        root.addView(note);

        setContentView(root);
    }

    private void showLevel(TextView tv, int pct) {
        tv.setText(String.format(Locale.ROOT, "%%%d  (+%.1f dB)", pct, Prefs.percentToMb(pct) / 100.0));
    }

    private void save(String key, Object value) {
        SharedPreferences.Editor e = prefs.edit();
        if (value instanceof Boolean) e.putBoolean(key, (Boolean) value);
        else e.putInt(key, (Integer) value);
        e.commit(); // system_server'in okuyacagi dosya yayindan once yazilmis olsun
        sendBroadcast(new Intent(Prefs.ACTION_RELOAD));
    }

    private int dp(int v) {
        return Math.round(v * getResources().getDisplayMetrics().density);
    }
}

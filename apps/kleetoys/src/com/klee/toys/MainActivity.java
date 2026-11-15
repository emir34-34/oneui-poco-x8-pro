package com.klee.toys;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.GridLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.TextView;
import android.widget.Toast;

public class MainActivity extends Activity {
    private Engine eng;
    private SharedPreferences sp;
    private TextView status;
    private final View[] cornerViews = new View[4];
    private int[] corners;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private Runnable pendingMusic;

    static final int[][] PRESETS = {
            {0xffff00, 0xff00ff, 0x00ffff, 0xffffff}, // Gokkusagi (ilk renk denemesi; kullanici cok begendi)
            {0xff0000, 0x0000ff, 0x00ff00, 0xffff00}, // Dort Renk
            {0xff0000, 0x0000ff, 0x0000ff, 0xff0000}, // Ayna: ust renkler alta (sol kirmizi, sag mavi)
    };
    static final String[] PRESET_NAMES = {"Gökkuşağı", "Dört Renk", "Ayna"};
    static final int[] SWATCH = {0xff0000, 0xff6000, 0xffff00, 0x00ff00, 0x00ffff, 0x0000ff, 0xff00ff, 0xffffff};

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        if (getActionBar() != null) getActionBar().hide();
        eng = LedService.engine(this);
        sp = getSharedPreferences("klee", MODE_PRIVATE);
        corners = new int[4];
        for (int i = 0; i < 4; i++) corners[i] = sp.getInt("c" + i, PRESETS[1][i]);
        eng.accent = sp.getInt("accent", 0x00ffff);
        eng.led.brightness = sp.getInt("bri", 100) / 100f;
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED)
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 2);
        setContentView(build());
        tick();
    }

    private int dp(int v) { return (int) (v * getResources().getDisplayMetrics().density); }

    private TextView title(LinearLayout p, String s) {
        TextView t = new TextView(this);
        t.setText(s); t.setTextSize(18); t.setPadding(0, dp(22), 0, dp(8));
        t.setTypeface(t.getTypeface(), android.graphics.Typeface.BOLD);
        p.addView(t);
        return t;
    }

    private Button btn(String s, View.OnClickListener l) {
        Button x = new Button(this);
        x.setText(s); x.setAllCaps(false); x.setOnClickListener(l);
        return x;
    }

    private LinearLayout row(LinearLayout p) {
        LinearLayout r = new LinearLayout(this);
        r.setOrientation(LinearLayout.HORIZONTAL);
        p.addView(r);
        return r;
    }

    private void addW(LinearLayout r, View v) {
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1);
        lp.setMargins(dp(3), dp(3), dp(3), dp(3));
        r.addView(v, lp);
    }

    private View build() {
        ScrollView sv = new ScrollView(this);
        LinearLayout p = new LinearLayout(this);
        p.setOrientation(LinearLayout.VERTICAL);
        p.setPadding(dp(18), dp(28), dp(18), dp(40));
        sv.addView(p);

        TextView h = new TextView(this);
        h.setText("KleeToys"); h.setTextSize(30);
        h.setTypeface(h.getTypeface(), android.graphics.Typeface.BOLD);
        p.addView(h);
        status = new TextView(this);
        status.setTextSize(14); status.setAlpha(0.7f);
        p.addView(status);

        // Parlaklik + kapat
        title(p, "Parlaklık");
        SeekBar br = new SeekBar(this);
        br.setMax(100); br.setProgress(Math.round(eng.led.brightness * 100));
        br.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            public void onProgressChanged(SeekBar s, int v, boolean u) { eng.led.brightness = Math.max(0.03f, v / 100f); sp.edit().putInt("bri", v).apply(); }
            public void onStartTrackingTouch(SeekBar s) { }
            public void onStopTrackingTouch(SeekBar s) { }
        });
        p.addView(br);
        LinearLayout r0 = row(p);
        addW(r0, btn("Işıkları kapat", v -> { eng.stop(); stopService(new android.content.Intent(this, LedService.class)); }));

        // Muzik
        title(p, "Müzikle senkron");
        LinearLayout rm = row(p);
        Button hyper = btn("HyperOS", v -> music(true));
        if (!Engine.hyperAvailable(this)) { hyper.setEnabled(false); hyper.setText("HyperOS (yok)"); }
        addW(rm, hyper);
        addW(rm, btn("Klee (bas kırmızı)", v -> music(false)));

        // Hazir renkler
        title(p, "Hazır renkler");
        LinearLayout rp = row(p);
        for (int i = 0; i < PRESETS.length; i++) {
            final int k = i;
            addW(rp, btn(PRESET_NAMES[i], v -> { corners = PRESETS[k].clone(); saveCorners(); refreshCorners(); go(() -> eng.setStatic(corners)); }));
        }

        // Koseler
        title(p, "Köşeler (dokun, rengi seç)");
        GridLayout g = new GridLayout(this);
        g.setColumnCount(2);
        int[] order = {0, 1, 3, 2}; // ekranda: ust sol, ust sag / alt sol, alt sag
        String[] names = {"Üst sol", "Üst sağ", "Alt sağ", "Alt sol"};
        for (int idx : order) {
            View sw = new View(this);
            GridLayout.LayoutParams lp = new GridLayout.LayoutParams();
            lp.width = 0; lp.height = dp(64);
            lp.columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f);
            lp.setMargins(dp(6), dp(6), dp(6), dp(6));
            sw.setContentDescription(names[idx]);
            sw.setOnClickListener(v -> pick(names[idx], corners[idx], c -> { corners[idx] = c; saveCorners(); refreshCorners(); go(() -> eng.setStatic(corners)); }));
            cornerViews[idx] = sw;
            g.addView(sw, lp);
        }
        p.addView(g);
        refreshCorners();
        LinearLayout rc = row(p);
        addW(rc, btn("Köşeleri yak", v -> go(() -> eng.setStatic(corners))));

        // Animasyonlar
        title(p, "Animasyonlar");
        for (int i = 0; i < Engine.ANIMS.length; i += 2) {
            LinearLayout ra = row(p);
            for (int j = i; j < Math.min(i + 2, Engine.ANIMS.length); j++) {
                final int k = j;
                addW(ra, btn(Engine.ANIMS[j], v -> go(() -> eng.setAnim(k))));
            }
        }
        LinearLayout racc = row(p);
        addW(racc, btn("Yıldız/nefes rengi", v -> pick("Animasyon rengi", eng.accent, c -> { eng.accent = c; sp.edit().putInt("accent", c).apply(); })));

        TextView foot = new TextView(this);
        foot.setText("\nPOCO X8 Pro kamera halkası · 4 LED\nOne UI klee portu için");
        foot.setAlpha(0.5f); foot.setGravity(Gravity.CENTER);
        p.addView(foot);
        return sv;
    }

    private void go(Runnable r) { LedService.ensure(this); r.run(); }

    private void music(boolean hyper) {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            pendingMusic = () -> go(() -> eng.setMusic(hyper));
            requestPermissions(new String[]{Manifest.permission.RECORD_AUDIO}, 1);
            return;
        }
        go(() -> eng.setMusic(hyper));
    }

    @Override public void onRequestPermissionsResult(int code, String[] p, int[] r) {
        if (code == 1) {
            if (r.length > 0 && r[0] == PackageManager.PERMISSION_GRANTED && pendingMusic != null) pendingMusic.run();
            else Toast.makeText(this, "Müzik için ses izni gerekli (yalnız ses seviyesi okunur, kayıt yapılmaz)", Toast.LENGTH_LONG).show();
            pendingMusic = null;
        }
    }

    private void saveCorners() {
        SharedPreferences.Editor e = sp.edit();
        for (int i = 0; i < 4; i++) e.putInt("c" + i, corners[i]);
        e.apply();
    }

    private void refreshCorners() {
        for (int i = 0; i < 4; i++) {
            if (cornerViews[i] == null) continue;
            GradientDrawable d = new GradientDrawable();
            d.setCornerRadius(dp(16));
            d.setColor(0xff000000 | corners[i]);
            d.setStroke(dp(1), 0x40888888);
            cornerViews[i].setBackground(d);
        }
    }

    interface ColorCb { void on(int c); }

    private void pick(String what, int cur, ColorCb cb) {
        LinearLayout l = new LinearLayout(this);
        l.setOrientation(LinearLayout.VERTICAL);
        l.setPadding(dp(20), dp(10), dp(20), dp(0));
        View prev = new View(this);
        GradientDrawable pd = new GradientDrawable(); pd.setCornerRadius(dp(14));
        prev.setBackground(pd);
        l.addView(prev, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(56)));
        float[] hsv = new float[3];
        Color.colorToHSV(0xff000000 | cur, hsv);
        final int[] val = {cur};
        SeekBar hue = new SeekBar(this), sat = new SeekBar(this);
        hue.setMax(359); hue.setProgress((int) hsv[0]);
        sat.setMax(100); sat.setProgress((int) (hsv[1] * 100));
        Runnable upd = () -> { val[0] = Engine.hsv(hue.getProgress(), sat.getProgress() / 100f, 1f); pd.setColor(0xff000000 | val[0]); };
        SeekBar.OnSeekBarChangeListener ls = new SeekBar.OnSeekBarChangeListener() {
            public void onProgressChanged(SeekBar s, int v, boolean u) { upd.run(); }
            public void onStartTrackingTouch(SeekBar s) { }
            public void onStopTrackingTouch(SeekBar s) { }
        };
        hue.setOnSeekBarChangeListener(ls); sat.setOnSeekBarChangeListener(ls);
        TextView th = new TextView(this); th.setText("Renk tonu"); th.setPadding(0, dp(12), 0, 0);
        TextView ts = new TextView(this); ts.setText("Doygunluk");
        l.addView(th); l.addView(hue); l.addView(ts); l.addView(sat);
        LinearLayout sw = new LinearLayout(this);
        sw.setPadding(0, dp(10), 0, dp(6));
        for (int c : SWATCH) {
            View v = new View(this);
            GradientDrawable d = new GradientDrawable(); d.setShape(GradientDrawable.OVAL); d.setColor(0xff000000 | c); d.setStroke(dp(1), 0x40888888);
            v.setBackground(d);
            v.setOnClickListener(x -> {
                float[] q = new float[3]; Color.colorToHSV(0xff000000 | c, q);
                hue.setProgress((int) q[0]); sat.setProgress((int) (q[1] * 100));
                val[0] = c; pd.setColor(0xff000000 | c);
            });
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, dp(32), 1);
            lp.setMargins(dp(3), 0, dp(3), 0);
            sw.addView(v, lp);
        }
        l.addView(sw);
        pd.setColor(0xff000000 | cur);
        new AlertDialog.Builder(this)
                .setTitle(what)
                .setView(l)
                .setPositiveButton("Tamam", (d, w) -> cb.on(val[0]))
                .setNegativeButton("Vazgeç", null)
                .show();
    }

    private void tick() {
        String m;
        switch (eng.mode()) {
            case Engine.OFF: m = "Kapalı"; break;
            default: m = eng.status;
        }
        status.setText("Durum: " + m + "\nLED servisi: " + eng.led.transport());
        ui.postDelayed(this::tick, 500);
    }

    @Override protected void onDestroy() { ui.removeCallbacksAndMessages(null); super.onDestroy(); }
}

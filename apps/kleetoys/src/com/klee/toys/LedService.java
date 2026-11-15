package com.klee.toys;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.os.IBinder;

/** Efektler ekran kapaliyken de surebilsin diye on plan servisi. */
public class LedService extends Service {
    static Engine engine;
    static final String STOP = "com.klee.toys.STOP";

    static Engine engine(Context c) {
        if (engine == null) engine = new Engine(c.getApplicationContext());
        return engine;
    }

    static void ensure(Context c) {
        Intent i = new Intent(c, LedService.class);
        c.startForegroundService(i);
    }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && STOP.equals(intent.getAction())) {
            engine(this).stop();
            stopForeground(STOP_FOREGROUND_REMOVE);
            stopSelf();
            return START_NOT_STICKY;
        }
        NotificationManager nm = getSystemService(NotificationManager.class);
        nm.createNotificationChannel(new NotificationChannel("led", "Işık efektleri", NotificationManager.IMPORTANCE_LOW));
        PendingIntent open = PendingIntent.getActivity(this, 0, new Intent(this, MainActivity.class), PendingIntent.FLAG_IMMUTABLE);
        PendingIntent stop = PendingIntent.getService(this, 1, new Intent(this, LedService.class).setAction(STOP), PendingIntent.FLAG_IMMUTABLE);
        Notification n = new Notification.Builder(this, "led")
                .setSmallIcon(android.R.drawable.ic_menu_view)
                .setContentTitle("KleeToys")
                .setContentText("Kamera ışıkları çalışıyor")
                .setContentIntent(open)
                .addAction(new Notification.Action.Builder(null, "Kapat", stop).build())
                .setOngoing(true)
                .build();
        startForeground(7, n);
        return START_STICKY;
    }

    @Override public void onDestroy() { if (engine != null) engine.stop(); super.onDestroy(); }
    @Override public IBinder onBind(Intent intent) { return null; }
}

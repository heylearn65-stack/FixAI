#!/bin/bash
set -e
cat > build.gradle <<'FIXAI_EOF'
plugins {
    id 'com.android.application' version '8.5.2' apply false
}
FIXAI_EOF
cat > settings.gradle <<'FIXAI_EOF'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "FIXAI"
include ':app'
FIXAI_EOF
mkdir -p app
cat > app/build.gradle <<'FIXAI_EOF'
plugins {
    id 'com.android.application'
}

android {
    namespace 'com.fixai.app'
    compileSdk 34

    defaultConfig {
        applicationId "com.fixai.app"
        minSdk 24
        targetSdk 34
        versionCode 1
        versionName "0.1"
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
}
FIXAI_EOF
mkdir -p app/src/main
cat > app/src/main/AndroidManifest.xml <<'FIXAI_EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="@string/app_name"
        android:allowBackup="false"
        android:theme="@android:style/Theme.DeviceDefault.NoActionBar">

        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
FIXAI_EOF
mkdir -p app/src/main/java/com/fixai/app
cat > app/src/main/java/com/fixai/app/MainActivity.java <<'FIXAI_EOF'
package com.fixai.app;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Typeface;
import android.os.Bundle;
import android.provider.Settings;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

public class MainActivity extends Activity {
    TextView status;

    int dp(int v) {
        return (int) (v * getResources().getDisplayMetrics().density);
    }

    TextView tv(String s, int size, boolean bold, int color) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextSize(size);
        t.setTextColor(color);
        if (bold) t.setTypeface(Typeface.DEFAULT_BOLD);
        t.setPadding(0, dp(8), 0, dp(8));
        return t;
    }

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        LinearLayout l = new LinearLayout(this);
        l.setOrientation(LinearLayout.VERTICAL);
        l.setBackgroundColor(0xFF0D1220);
        l.setPadding(dp(20), dp(48), dp(20), dp(24));

        l.addView(tv("FIXAI", 34, true, 0xFF818CF8));
        l.addView(tv("Ask. Allow. Done.", 14, false, 0xFF9AA5BD));
        l.addView(tv("ফোনের সমস্যায় FIXAI শুধু দেখিয়ে দেয় কোথায় ট্যাপ করবেন। ট্যাপ আপনি নিজে করবেন।", 16, false, 0xFFEEF1F8));
        l.addView(tv("গোপনীয়তা: FIXAI শুধু সেটিংস অ্যাপের স্ক্রিনে বোতাম খোঁজে। পাসওয়ার্ড বা OTP পড়ে না, নিজে ট্যাপ করে না, কিছু সংরক্ষণ বা পাঠায় না।", 13, false, 0xFF9AA5BD));

        status = tv("", 15, true, 0xFFFFFFFF);
        l.addView(status);

        Button b1 = new Button(this);
        b1.setText("১) Accessibility চালু করুন");
        b1.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                Toast.makeText(MainActivity.this, "তালিকা থেকে FIXAI বেছে চালু করুন", Toast.LENGTH_LONG).show();
                startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS));
            }
        });
        l.addView(b1);

        Button b2 = new Button(this);
        b2.setText("২) Wi‑Fi গাইড শুরু করুন");
        b2.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                if (FixaiService.inst == null) {
                    Toast.makeText(MainActivity.this, "আগে ১ নম্বর ধাপ করুন", Toast.LENGTH_LONG).show();
                    return;
                }
                FixaiService.start();
                startActivity(new Intent(Settings.ACTION_SETTINGS));
            }
        });
        l.addView(b2);

        Button b3 = new Button(this);
        b3.setText("গাইড বন্ধ করুন");
        b3.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                FixaiService.stop();
            }
        });
        l.addView(b3);

        ScrollView sv = new ScrollView(this);
        sv.setBackgroundColor(0xFF0D1220);
        sv.addView(l);
        setContentView(sv);
    }

    @Override
    protected void onResume() {
        super.onResume();
        status.setText(FixaiService.inst != null ? "✅ Accessibility চালু আছে" : "⚠️ Accessibility এখনও চালু নেই");
    }
}
FIXAI_EOF
mkdir -p app/src/main/java/com/fixai/app
cat > app/src/main/java/com/fixai/app/FixaiService.java <<'FIXAI_EOF'
package com.fixai.app;

import android.accessibilityservice.AccessibilityService;
import android.content.Context;
import android.content.Intent;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PixelFormat;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.drawable.GradientDrawable;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import android.widget.FrameLayout;
import android.widget.TextView;

import java.util.Locale;

public class FixaiService extends AccessibilityService {
    static FixaiService inst;
    static int step = -1;
    static int clicks = 0;

    static final String[][] KEYS = {
        {"network & internet", "network and internet", "connection", "নেটওয়ার্ক", "সংযোগ"},
        {"wi-fi", "wi\u2011fi", "wifi", "wlan", "internet", "ওয়াই", "ইন্টারনেট"}
    };
    static final String[] MSG = {
        "ধাপ ১/৩: \"নেটওয়ার্ক ও ইন্টারনেট\" (বা \"Connections\") এ ট্যাপ করুন",
        "ধাপ ২/৩: \"Wi‑Fi\" (বা \"Internet\") এ ট্যাপ করুন",
        "ধাপ ৩/৩: Wi‑Fi সুইচটি বন্ধ করুন, তারপর আবার চালু করুন"
    };

    WindowManager wm;
    FrameLayout root;
    Ring ring;
    TextView msg;
    boolean shown = false;
    Handler handler = new Handler(Looper.getMainLooper());

    static class Ring extends View {
        Rect r;
        Paint stroke = new Paint(Paint.ANTI_ALIAS_FLAG);
        Paint glow = new Paint(Paint.ANTI_ALIAS_FLAG);

        Ring(Context c) {
            super(c);
            stroke.setStyle(Paint.Style.STROKE);
            stroke.setStrokeWidth(8);
            stroke.setColor(0xFF4F46E5);
            glow.setStyle(Paint.Style.STROKE);
            glow.setStrokeWidth(24);
            glow.setColor(0x554F46E5);
        }

        void set(Rect x) {
            r = x == null ? null : new Rect(x);
            invalidate();
        }

        @Override
        protected void onDraw(Canvas c) {
            if (r == null) return;
            int[] l = new int[2];
            getLocationOnScreen(l);
            RectF f = new RectF(r.left - l[0] - 8, r.top - l[1] - 8, r.right - l[0] + 8, r.bottom - l[1] + 8);
            c.drawRoundRect(f, 24, 24, glow);
            c.drawRoundRect(f, 24, 24, stroke);
        }
    }

    static void start() {
        step = 0;
        clicks = 0;
        if (inst != null) inst.refresh();
    }

    static void stop() {
        step = -1;
        if (inst != null) inst.hide();
    }

    @Override
    protected void onServiceConnected() {
        inst = this;
        wm = (WindowManager) getSystemService(WINDOW_SERVICE);
    }

    @Override
    public boolean onUnbind(Intent i) {
        hide();
        inst = null;
        return super.onUnbind(i);
    }

    @Override
    public void onInterrupt() {
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent e) {
        if (step < 0 || e == null) return;
        CharSequence p = e.getPackageName();
        if (p != null && p.toString().equals(getPackageName())) return;
        if (e.getEventType() == AccessibilityEvent.TYPE_VIEW_CLICKED && isSettings(p)) {
            click(e.getSource());
        }
        refresh();
    }

    boolean isSettings(CharSequence p) {
        return p != null && p.toString().toLowerCase(Locale.ROOT).contains("settings");
    }

    void click(AccessibilityNodeInfo n) {
        if (n == null) return;
        if (step < 2) {
            String s = txt(n, 3);
            if (step == 0 && matches(s, KEYS[0])) step = 1;
            else if (matches(s, KEYS[1])) step = 2;
        } else if (step == 2 && hasSwitch(n, 2)) {
            clicks++;
            if (clicks >= 2) step = 3;
        }
    }

    void refresh() {
        AccessibilityNodeInfo r = getRootInActiveWindow();
        if (r == null) return;
        if (!isSettings(r.getPackageName())) {
            hide();
            return;
        }
        if (step >= 3) {
            show(null, "✅ হয়ে গেছে! এবার ইন্টারনেট চলছে কি না দেখুন।");
            step = -1;
            handler.postDelayed(new Runnable() {
                public void run() {
                    hide();
                }
            }, 5000);
            return;
        }
        Rect rect = null;
        String m = MSG[step];
        if (step < 2) {
            rect = findByText(r, KEYS[step]);
            if (rect == null && step == 0) {
                rect = findByText(r, KEYS[1]);
                if (rect != null) m = MSG[1];
            }
        } else {
            rect = findSwitch(r);
        }
        show(rect, rect == null ? m + "\n(এই স্ক্রিনে খুঁজে পাচ্ছি না, নিজে খুঁজে দেখুন বা নিচে স্ক্রল করুন)" : m);
    }

    String txt(AccessibilityNodeInfo n, int depth) {
        if (n == null || n.isPassword() || n.isEditable()) return "";
        StringBuilder s = new StringBuilder();
        CharSequence t = n.getText();
        CharSequence c = n.getContentDescription();
        if (t != null) s.append(t).append(' ');
        if (c != null) s.append(c).append(' ');
        if (depth > 0) {
            for (int i = 0; i < n.getChildCount(); i++) s.append(txt(n.getChild(i), depth - 1));
        }
        return s.toString().toLowerCase(Locale.ROOT);
    }

    boolean matches(String s, String[] keys) {
        for (String k : keys) if (s.contains(k)) return true;
        return false;
    }

    boolean hasSwitch(AccessibilityNodeInfo n, int depth) {
        if (n == null) return false;
        if (n.isCheckable()) return true;
        if (depth > 0) {
            for (int i = 0; i < n.getChildCount(); i++) if (hasSwitch(n.getChild(i), depth - 1)) return true;
        }
        return false;
    }

    Rect findByText(AccessibilityNodeInfo n, String[] keys) {
        if (n == null || !n.isVisibleToUser()) return null;
        String s = txt(n, 0);
        if (!s.isEmpty() && matches(s, keys)) {
            AccessibilityNodeInfo a = n;
            for (int i = 0; i < 6 && a != null && !a.isClickable(); i++) a = a.getParent();
            if (a != null && a.isClickable()) {
                Rect r = new Rect();
                a.getBoundsInScreen(r);
                return r;
            }
        }
        for (int i = 0; i < n.getChildCount(); i++) {
            Rect r = findByText(n.getChild(i), keys);
            if (r != null) return r;
        }
        return null;
    }

    Rect findSwitch(AccessibilityNodeInfo n) {
        if (n == null || !n.isVisibleToUser()) return null;
        if (n.isCheckable()) {
            Rect r = new Rect();
            n.getBoundsInScreen(r);
            return r;
        }
        for (int i = 0; i < n.getChildCount(); i++) {
            Rect r = findSwitch(n.getChild(i));
            if (r != null) return r;
        }
        return null;
    }

    void show(Rect r, String text) {
        if (wm == null) return;
        if (!shown) {
            int d = (int) (getResources().getDisplayMetrics().density * 16);
            root = new FrameLayout(this);
            ring = new Ring(this);
            root.addView(ring, new FrameLayout.LayoutParams(-1, -1));
            msg = new TextView(this);
            msg.setTextColor(Color.WHITE);
            msg.setTextSize(16);
            msg.setPadding(d, d, d, d);
            GradientDrawable bg = new GradientDrawable();
            bg.setColor(0xF2111827);
            bg.setCornerRadius(d * 1.5f);
            msg.setBackground(bg);
            FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM);
            lp.setMargins(d, d, d, d * 4);
            root.addView(msg, lp);
            WindowManager.LayoutParams wl = new WindowManager.LayoutParams(
                -1, -1,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                    | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                    | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                    | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT);
            wm.addView(root, wl);
            shown = true;
        }
        ring.set(r);
        msg.setText(text);
    }

    void hide() {
        if (shown) {
            try {
                wm.removeView(root);
            } catch (Exception ignored) {
            }
            shown = false;
        }
    }
}
FIXAI_EOF
mkdir -p app/src/main/res/values
cat > app/src/main/res/values/strings.xml <<'FIXAI_EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">FIXAI Test</string>
    <string name="svc_desc">FIXAI শুধু ফোনের সেটিংস অ্যাপে কোন বোতামে ট্যাপ করবেন তা হাইলাইট করে দেখায়। এটি নিজে ট্যাপ করে না, পাসওয়ার্ড বা OTP পড়ে না।</string>
</resources>
FIXAI_EOF

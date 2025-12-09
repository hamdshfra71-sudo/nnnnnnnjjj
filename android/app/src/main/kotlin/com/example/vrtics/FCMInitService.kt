package com.example.vrtics

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader

/**
 * FCM Initialization Service
 * يعمل في الخلفية بعد تشغيل الجهاز لتهيئة Flutter و FCM
 */
class FCMInitService : Service() {
    companion object {
        private const val TAG = "FCMInitService"
    }

    private var flutterEngine: FlutterEngine? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "📱 FCM Init Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "🚀 Starting FCM initialization...")
        
        try {
            // تهيئة Flutter Engine
            initFlutterEngine()
            Log.d(TAG, "✅ Flutter Engine initialized for FCM")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error initializing Flutter Engine: ${e.message}")
        }
        
        // إيقاف الخدمة بعد التهيئة (سيقوم Flutter بالباقي)
        stopSelf()
        
        return START_NOT_STICKY
    }

    private fun initFlutterEngine() {
        if (flutterEngine != null) {
            Log.d(TAG, "Flutter Engine already exists")
            return
        }

        // تحميل FlutterLoader
        val flutterLoader = FlutterLoader()
        flutterLoader.startInitialization(applicationContext)
        flutterLoader.ensureInitializationComplete(applicationContext, null)

        // إنشاء Flutter Engine جديد
        flutterEngine = FlutterEngine(applicationContext)
        
        // تشغيل Dart entry point
        flutterEngine?.dartExecutor?.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        
        Log.d(TAG, "✅ Dart entry point executed - FCM handlers should be registered now")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.d(TAG, "FCM Init Service destroyed")
        super.onDestroy()
    }
}

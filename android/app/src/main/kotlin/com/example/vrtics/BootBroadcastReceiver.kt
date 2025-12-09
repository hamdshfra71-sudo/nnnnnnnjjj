package com.example.vrtics

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Boot Receiver - يبدأ عند تشغيل الجهاز
 * يقوم بتشغيل التطبيق في الخلفية لتسجيل FCM handlers
 */
class BootBroadcastReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON" ||
            intent.action == "com.htc.intent.action.QUICKBOOT_POWERON") {
            
            Log.d(TAG, "📱 Device boot completed - Starting FCM initialization...")
            
            // تشغيل الخدمة الخلفية
            try {
                val serviceIntent = Intent(context, FCMInitService::class.java)
                context.startService(serviceIntent)
                Log.d(TAG, "✅ FCM Init Service started successfully")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error starting FCM Init Service: ${e.message}")
            }
        }
    }
}

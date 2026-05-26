package com.example.first

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var smsChannel: MethodChannel? = null
    private var smsReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        smsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SMS_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingSmsEvents" -> result.success(SmsEventStore.pending(this))
                    "ackSmsEvent" -> {
                        val id = call.argument<String>("id")
                        if (id != null) {
                            SmsEventStore.ack(this, id)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        registerSmsEventReceiver()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        smsReceiver?.let { receiver ->
            unregisterReceiver(receiver)
        }
        smsReceiver = null
        smsChannel?.setMethodCallHandler(null)
        smsChannel = null

        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun registerSmsEventReceiver() {
        if (smsReceiver != null) return

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val event = SmsReceiver.eventFromIntent(intent) ?: return
                smsChannel?.invokeMethod("smsReceived", event)
            }
        }
        val filter = IntentFilter(SmsReceiver.ACTION_SMS_EVENT)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(receiver, filter)
        }
        smsReceiver = receiver
    }

    companion object {
        private const val SMS_CHANNEL = "com.example.first/sms_events"
    }
}

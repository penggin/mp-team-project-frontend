package com.example.first

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isEmpty()) return

        val sender = messages.firstOrNull()?.displayOriginatingAddress.orEmpty()
        val body = messages.joinToString(separator = "") { message ->
            message.displayMessageBody.orEmpty()
        }.trim()
        if (body.isEmpty()) return

        val receivedAt = messages.minOfOrNull { message ->
            message.timestampMillis
        } ?: System.currentTimeMillis()
        val event = mapOf(
            "id" to eventId(sender, body, receivedAt),
            "sender" to sender,
            "body" to body,
            "receivedAt" to receivedAt,
        )

        SmsEventStore.append(context, event)

        val eventIntent = Intent(ACTION_SMS_EVENT)
            .setPackage(context.packageName)
            .putExtra("id", event["id"] as String)
            .putExtra("sender", sender)
            .putExtra("body", body)
            .putExtra("receivedAt", receivedAt)
        context.sendBroadcast(eventIntent)
    }

    companion object {
        const val ACTION_SMS_EVENT = "com.example.first.SMS_EVENT"

        fun eventFromIntent(intent: Intent): Map<String, Any>? {
            val id = intent.getStringExtra("id") ?: return null
            val sender = intent.getStringExtra("sender").orEmpty()
            val body = intent.getStringExtra("body").orEmpty()
            val receivedAt = intent.getLongExtra("receivedAt", 0L)
            if (body.isEmpty()) return null

            return mapOf(
                "id" to id,
                "sender" to sender,
                "body" to body,
                "receivedAt" to receivedAt,
            )
        }

        private fun eventId(sender: String, body: String, receivedAt: Long): String {
            return "$receivedAt:${sender.hashCode()}:${body.hashCode()}"
        }
    }
}

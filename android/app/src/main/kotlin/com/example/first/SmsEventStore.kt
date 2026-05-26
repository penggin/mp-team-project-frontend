package com.example.first

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object SmsEventStore {
    private const val PREFS_NAME = "sms_events"
    private const val KEY_PENDING_EVENTS = "pending_events"
    private const val MAX_PENDING_EVENTS = 50

    fun append(context: Context, event: Map<String, Any>) {
        val events = readArray(context)
        events.put(JSONObject(event))

        while (events.length() > MAX_PENDING_EVENTS) {
            events.remove(0)
        }

        writeArray(context, events)
    }

    fun pending(context: Context): List<Map<String, Any>> {
        val events = readArray(context)
        val result = mutableListOf<Map<String, Any>>()

        for (index in 0 until events.length()) {
            val item = events.optJSONObject(index) ?: continue
            result.add(item.toMap())
        }

        return result
    }

    fun ack(context: Context, id: String) {
        val events = readArray(context)
        val remaining = JSONArray()

        for (index in 0 until events.length()) {
            val item = events.optJSONObject(index) ?: continue
            if (item.optString("id") != id) {
                remaining.put(item)
            }
        }

        writeArray(context, remaining)
    }

    private fun readArray(context: Context): JSONArray {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_PENDING_EVENTS, "[]") ?: "[]"
        return try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
    }

    private fun writeArray(context: Context, events: JSONArray) {
        context
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PENDING_EVENTS, events.toString())
            .apply()
    }

    private fun JSONObject.toMap(): Map<String, Any> {
        val result = mutableMapOf<String, Any>()
        val keys = keys()

        while (keys.hasNext()) {
            val key = keys.next()
            result[key] = get(key)
        }

        return result
    }
}

package com.omnirush.dayforge.data

import android.content.Context
import com.omnirush.dayforge.model.AppData
import kotlinx.serialization.json.Json
import kotlinx.serialization.encodeToString

class DayforgeStore(context: Context) {
    private val preferences = context.getSharedPreferences("dayforge", Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    fun load(): AppData {
        val raw = preferences.getString(KEY_DATA, null) ?: return AppData()
        return runCatching { json.decodeFromString<AppData>(raw) }.getOrDefault(AppData())
    }

    fun save(data: AppData) {
        preferences.edit().putString(KEY_DATA, json.encodeToString(data)).apply()
    }

    var token: String?
        get() = preferences.getString(KEY_TOKEN, null)
        set(value) { preferences.edit().putStringOrRemove(KEY_TOKEN, value).apply() }

    var email: String?
        get() = preferences.getString(KEY_EMAIL, null)
        set(value) { preferences.edit().putStringOrRemove(KEY_EMAIL, value).apply() }

    var accountName: String?
        get() = preferences.getString(KEY_ACCOUNT_NAME, null)
        set(value) { preferences.edit().putStringOrRemove(KEY_ACCOUNT_NAME, value).apply() }

    private fun android.content.SharedPreferences.Editor.putStringOrRemove(key: String, value: String?): android.content.SharedPreferences.Editor {
        if (value == null) remove(key) else putString(key, value)
        return this
    }

    private companion object {
        const val KEY_DATA = "data"
        const val KEY_TOKEN = "token"
        const val KEY_EMAIL = "email"
        const val KEY_ACCOUNT_NAME = "accountName"
    }
}

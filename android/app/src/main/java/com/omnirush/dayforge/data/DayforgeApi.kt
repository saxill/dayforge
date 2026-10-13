package com.omnirush.dayforge.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class DayforgeApi(
    private val baseUrl: String = "https://dayforge-sync.sahilchanna344.workers.dev",
) {
    suspend fun register(email: String, password: String, name: String): JSONObject =
        request("POST", "/auth/register", JSONObject().put("email", email).put("password", password).put("name", name))

    suspend fun login(email: String, password: String): JSONObject =
        request("POST", "/auth/login", JSONObject().put("email", email).put("password", password))

    suspend fun logout(token: String) { runCatching { request("POST", "/auth/logout", null, token) } }

    suspend fun invite(token: String): JSONObject = request("POST", "/pair/invite", null, token)

    suspend fun getPair(token: String): JSONObject = request("GET", "/pair", null, token)

    suspend fun join(code: String, token: String): JSONObject =
        request("POST", "/pair/join", JSONObject().put("code", code), token)

    suspend fun updateMotivation(payload: JSONObject, token: String): JSONObject =
        request("PUT", "/pair/motivation", payload, token)

    suspend fun nudge(message: String, token: String): JSONObject =
        request("POST", "/pair/nudge", JSONObject().put("message", message), token)

    suspend fun leave(token: String): JSONObject = request("POST", "/pair/leave", null, token)

    suspend fun pull(token: String): JSONObject = request("GET", "/data", null, token)

    suspend fun push(data: JSONObject, token: String): JSONObject =
        request("PUT", "/data", JSONObject().put("data", data), token)

    private suspend fun request(method: String, path: String, body: JSONObject?, token: String? = null): JSONObject = withContext(Dispatchers.IO) {
        val connection = (URL(baseUrl + path).openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = 15_000
            readTimeout = 15_000
            setRequestProperty("Accept", "application/json")
            if (body != null) {
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
            }
            if (token != null) setRequestProperty("Authorization", "Bearer $token")
        }

        try {
            if (body != null) connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            val text = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
            val result = if (text.isBlank()) JSONObject() else JSONObject(text)
            if (code !in 200..299) throw ApiException(result.optString("error", "The server said no ($code)."), code)
            result
        } finally {
            connection.disconnect()
        }
    }
}

class ApiException(message: String, val statusCode: Int) : Exception(message)

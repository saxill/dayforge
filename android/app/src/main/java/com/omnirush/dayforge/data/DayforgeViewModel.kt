package com.omnirush.dayforge.data

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.omnirush.dayforge.model.AlarmSettings
import com.omnirush.dayforge.model.AppData
import com.omnirush.dayforge.model.Expense
import com.omnirush.dayforge.model.Habit
import com.omnirush.dayforge.model.LatestNudge
import com.omnirush.dayforge.model.MotivationHistoryEntry
import com.omnirush.dayforge.model.MotivationSummary
import com.omnirush.dayforge.model.PairPayload
import com.omnirush.dayforge.model.PairState
import com.omnirush.dayforge.model.ProfileSettings
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.UUID
import kotlin.math.roundToInt

enum class FocusPhase { IDLE, RUNNING, PAUSED, FINISHED }

class DayforgeViewModel(application: Application) : AndroidViewModel(application) {
    private val store = DayforgeStore(application)
    private val api = DayforgeApi()
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    var data by mutableStateOf(store.load())
        private set
    var accountEmail by mutableStateOf(store.email)
        private set
    var accountName by mutableStateOf(store.accountName)
        private set
    var pairState by mutableStateOf<PairState?>(null)
        private set
    var busy by mutableStateOf(false)
        private set
    var errorMessage by mutableStateOf<String?>(null)
        private set
    var noticeMessage by mutableStateOf<String?>(null)
        private set
    var focusPhase by mutableStateOf(FocusPhase.IDLE)
        private set
    var remainingSeconds by mutableIntStateOf(data.focusDurationMinutes * 60)
        private set

    private var timerJob: Job? = null

    val isSignedIn: Boolean get() = !store.token.isNullOrBlank() && !accountEmail.isNullOrBlank()
    val habitsDone: Int get() = data.habits.count { it.isDone }
    val habitProgress: Float get() = if (data.habits.isEmpty()) 0f else habitsDone.toFloat() / data.habits.size
    val pulse: Int get() = (habitProgress * 55 + (data.focusMinutesToday.coerceAtMost(100) * 0.35) + if (data.alarm.isOn) 10 else 0).roundToInt()
    val motivationPulse: Int get() = (habitProgress * 65 + (data.focusMinutesToday.coerceAtMost(100) * 0.35)).roundToInt()
    val monthlySpend: Double get() = data.expenses.sumOf { it.amount }
    val budgetProgress: Float get() = if (data.monthlyBudget <= 0) 0f else (monthlySpend / data.monthlyBudget).coerceIn(0.0, 1.0).toFloat()
    val timerProgress: Float get() {
        val total = data.focusDurationMinutes * 60
        return if (total <= 0) 0f else 1f - (remainingSeconds.toFloat() / total.toFloat()).coerceIn(0f, 1f)
    }

    fun toggleHabit(id: String) {
        data = data.copy(habits = data.habits.map { if (it.id == id) it.copy(isDone = !it.isDone) else it })
        persistAndPublish()
    }

    fun updateProfileName(name: String) {
        data = data.copy(profile = data.profile.copy(name = name.take(40)))
        persistAndPublish()
    }

    fun setTheme(theme: String) {
        data = data.copy(profile = data.profile.copy(theme = theme))
        persistAndPublish()
    }

    fun setSectionVisible(section: String, visible: Boolean) {
        val profile = when (section) {
            "habits" -> data.profile.copy(showHabits = visible)
            "alarm" -> data.profile.copy(showAlarm = visible)
            "spending" -> data.profile.copy(showSpending = visible)
            "brain" -> data.profile.copy(showBrain = visible)
            else -> data.profile.copy(showBrief = visible)
        }
        data = data.copy(profile = profile)
        persistAndPublish()
    }

    fun addExpense(amount: Double, category: String, note: String) {
        if (!amount.isFinite() || amount <= 0) {
            errorMessage = "Enter an amount greater than zero."
            return
        }
        data = data.copy(expenses = data.expenses + Expense(UUID.randomUUID().toString(), amount, category, note.take(100), System.currentTimeMillis()))
        persistAndPublish()
        noticeMessage = "Spending logged."
    }

    fun setMonthlyBudget(value: Double) {
        if (value <= 0 || value > 1_000_000) {
            errorMessage = "Choose a budget between 1 and 1,000,000."
            return
        }
        data = data.copy(monthlyBudget = value)
        persistAndPublish()
    }

    fun setAlarm(enabled: Boolean) {
        data = data.copy(alarm = data.alarm.copy(isOn = enabled))
        persistAndPublish()
    }

    fun updateManga(updated: List<com.omnirush.dayforge.model.Manga>) {
        data = data.copy(manga = updated)
        persistAndPublish()
    }

    fun setFocusDuration(minutes: Int) {
        val safe = minutes.coerceIn(5, 120)
        data = data.copy(focusDurationMinutes = safe)
        if (focusPhase == FocusPhase.IDLE || focusPhase == FocusPhase.FINISHED) remainingSeconds = safe * 60
        persistAndPublish()
    }

    fun startFocus() {
        if (focusPhase == FocusPhase.FINISHED || focusPhase == FocusPhase.IDLE) remainingSeconds = data.focusDurationMinutes * 60
        focusPhase = FocusPhase.RUNNING
        timerJob?.cancel()
        timerJob = viewModelScope.launch {
            while (isActive && remainingSeconds > 0) {
                delay(1_000)
                remainingSeconds -= 1
            }
            if (remainingSeconds == 0) completeFocus()
        }
    }

    fun pauseFocus() {
        timerJob?.cancel()
        timerJob = null
        focusPhase = FocusPhase.PAUSED
    }

    fun resetFocus() {
        timerJob?.cancel()
        timerJob = null
        remainingSeconds = data.focusDurationMinutes * 60
        focusPhase = FocusPhase.IDLE
    }

    private fun completeFocus() {
        timerJob = null
        focusPhase = FocusPhase.FINISHED
        data = data.copy(
            focusSessionsToday = data.focusSessionsToday + 1,
            focusMinutesToday = data.focusMinutesToday + data.focusDurationMinutes,
            focusStreakDays = if (data.focusSessionsToday == 0) data.focusStreakDays + 1 else data.focusStreakDays,
        )
        persistAndPublish()
        noticeMessage = "Focus complete. Nice work."
    }

    fun clearMessages() {
        errorMessage = null
        noticeMessage = null
    }

    fun register(email: String, password: String, name: String) = authenticate(register = true, email, password, name)

    fun signIn(email: String, password: String) = authenticate(register = false, email, password, "")

    private fun authenticate(register: Boolean, email: String, password: String, name: String) {
        if (email.isBlank() || password.length < 8 || (register && name.isBlank())) {
            errorMessage = if (register) "Add a name, email, and an 8-character password." else "Enter your email and an 8-character password."
            return
        }
        viewModelScope.launch {
            busy = true
            errorMessage = null
            try {
                val response = if (register) api.register(email.trim(), password, name.trim()) else api.login(email.trim(), password)
                completeAuth(response)
                if (!register) pullFromCloud()
                refreshPair()
                publishMotivation()
                noticeMessage = if (register) "Account created." else "Welcome back."
            } catch (exception: Exception) {
                errorMessage = exception.message ?: "Could not reach Dayforge sync."
            } finally {
                busy = false
            }
        }
    }

    private fun completeAuth(response: JSONObject) {
        val user = response.optJSONObject("user") ?: JSONObject()
        store.token = response.optString("token").takeIf { it.isNotBlank() }
        store.email = user.optString("email").takeIf { it.isNotBlank() }
        store.accountName = user.optString("name").takeIf { it.isNotBlank() }
        accountEmail = store.email
        accountName = store.accountName
        if (data.profile.name.isBlank() && !accountName.isNullOrBlank()) updateProfileName(accountName.orEmpty())
    }

    fun signOut() {
        val token = store.token
        if (token != null) viewModelScope.launch { api.logout(token) }
        store.token = null
        store.email = null
        store.accountName = null
        accountEmail = null
        accountName = null
        pairState = null
        noticeMessage = "Signed out."
    }

    fun createPairInvite() = pairRequest { api.invite(it) }

    fun refreshPair() = pairRequest { api.getPair(it) }

    fun joinPair(code: String) {
        val normalized = code.trim().uppercase()
        if (!PairCode.isValid(normalized)) {
            errorMessage = "Enter the 6-character team code."
            return
        }
        pairRequest { api.join(normalized, it) }
    }

    fun leavePair() {
        val token = store.token ?: return
        viewModelScope.launch {
            busy = true
            try {
                api.leave(token)
                pairState = null
                noticeMessage = "You left the team."
            } catch (exception: Exception) {
                errorMessage = exception.message ?: "Could not leave the team."
            } finally {
                busy = false
            }
        }
    }

    fun sendNudge(message: String) {
        val token = store.token ?: return
        val cleaned = message.trim()
        if (cleaned.isEmpty()) {
            errorMessage = "Write a short message first."
            return
        }
        viewModelScope.launch {
            busy = true
            try {
                api.nudge(cleaned.take(120), token)
                refreshPair()
                noticeMessage = "Encouragement sent."
            } catch (exception: Exception) {
                errorMessage = exception.message ?: "Could not send encouragement."
            } finally {
                busy = false
            }
        }
    }

    private fun pairRequest(operation: suspend (String) -> JSONObject) {
        val token = store.token
        if (token.isNullOrBlank()) {
            errorMessage = "Sign in before setting up a team."
            return
        }
        viewModelScope.launch {
            busy = true
            errorMessage = null
            try {
                applyPairResponse(operation(token))
                publishMotivation()
            } catch (exception: Exception) {
                errorMessage = exception.message ?: "Could not update your team."
            } finally {
                busy = false
            }
        }
    }

    private fun applyPairResponse(response: JSONObject) {
        val pairObject = response.optJSONObject("pair")
        val pair = pairObject?.let {
            PairPayload(
                id = it.optString("id"),
                status = it.optString("status"),
                code = it.optString("code").takeIf(String::isNotBlank),
                partnerName = it.optString("partnerName").takeIf(String::isNotBlank),
                partnerUserId = it.optString("partnerUserId").takeIf(String::isNotBlank),
                createdAt = it.optDouble("createdAt"),
            )
        }
        val own = summaryFromJson(response.optJSONObject("summary"), accountName ?: "You")
        val summaries = response.optJSONArray("summaries")
        val partner = summaries?.let { if (it.length() > 0) summaryFromJson(it.optJSONObject(0), pair?.partnerName ?: "Partner") else null }
        val nudgeObject = response.optJSONObject("latestNudge")
        val nudge = nudgeObject?.let { LatestNudge(it.optString("fromName"), it.optString("message"), it.optDouble("createdAt")) }
        pairState = PairState(pair, own, partner, nudge)
    }

    private fun summaryFromJson(value: JSONObject?, fallbackName: String): MotivationSummary {
        if (value == null) return localMotivationSummary(fallbackName)
        val history = value.optJSONArray("history")?.let(::historyFromJson).orEmpty()
        return MotivationSummary(
            userId = value.optString("userId", "unknown"),
            name = value.optString("name", fallbackName),
            pulse = value.optInt("pulse"),
            habitsDone = value.optInt("habitsDone"),
            habitsTotal = value.optInt("habitsTotal"),
            focusMinutes = value.optInt("focusMinutes"),
            focusStreakDays = value.optInt("focusStreakDays"),
            checkedInDate = value.optString("checkedInDate").takeIf(String::isNotBlank),
            updatedAt = value.optDouble("updatedAt"),
            history = history,
        )
    }

    private fun historyFromJson(array: JSONArray): List<MotivationHistoryEntry> = buildList {
        for (index in 0 until array.length()) {
            val item = array.optJSONObject(index) ?: continue
            add(MotivationHistoryEntry(item.optString("date"), item.optInt("pulse"), item.optInt("habitsDone"), item.optInt("habitsTotal"), item.optInt("focusMinutes"), item.optInt("focusStreakDays")))
        }
    }

    private fun localMotivationSummary(name: String): MotivationSummary = MotivationSummary(
        userId = "local",
        name = name,
        pulse = motivationPulse,
        habitsDone = habitsDone,
        habitsTotal = data.habits.size,
        focusMinutes = data.focusMinutesToday,
        focusStreakDays = data.focusStreakDays,
        checkedInDate = todayString(),
        updatedAt = System.currentTimeMillis().toDouble(),
        history = data.motivationHistory,
    )

    private fun recordMotivationSnapshot(): MotivationHistoryEntry {
        val entry = MotivationHistoryEntry(todayString(), motivationPulse, habitsDone, data.habits.size, data.focusMinutesToday, data.focusStreakDays)
        val history = (data.motivationHistory.filterNot { it.date == entry.date } + entry).sortedByDescending { it.date }.take(30)
        data = data.copy(motivationHistory = history)
        store.save(data)
        return entry
    }

    private fun publishMotivation() {
        val token = store.token ?: return
        if (pairState?.pair == null) return
        viewModelScope.launch {
            runCatching {
                val summary = localMotivationSummary(accountName ?: "You")
                val history = JSONArray().apply { summary.history.forEach { put(JSONObject().put("date", it.date).put("pulse", it.pulse).put("habitsDone", it.habitsDone).put("habitsTotal", it.habitsTotal).put("focusMinutes", it.focusMinutes).put("focusStreakDays", it.focusStreakDays)) } }
                api.updateMotivation(JSONObject().put("pulse", summary.pulse).put("habitsDone", summary.habitsDone).put("habitsTotal", summary.habitsTotal).put("focusMinutes", summary.focusMinutes).put("focusStreakDays", summary.focusStreakDays).put("checkedInDate", summary.checkedInDate).put("history", history), token)
            }
        }
    }

    private fun pullFromCloud() {
        val token = store.token ?: return
        viewModelScope.launch {
            runCatching {
                val dataObject = api.pull(token).optJSONObject("data") ?: return@runCatching
                val remote = json.decodeFromString<AppData>(dataObject.toString())
                data = remote
                store.save(remote)
            }
        }
    }

    private fun persistAndPublish() {
        recordMotivationSnapshot()
        store.save(data)
        val token = store.token ?: return
        viewModelScope.launch {
            runCatching { api.push(JSONObject(json.encodeToString(data)), token) }
            publishMotivation()
        }
    }

    private fun todayString(): String = LocalDate.now().format(DateTimeFormatter.ISO_DATE)

    override fun onCleared() {
        timerJob?.cancel()
        super.onCleared()
    }
}

object PairCode {
    private val allowed = "ACDEFGHJKMNPQRTUVWXYZ23479".toSet()
    fun isValid(code: String): Boolean = code.length == 6 && code.all { it in allowed }
}

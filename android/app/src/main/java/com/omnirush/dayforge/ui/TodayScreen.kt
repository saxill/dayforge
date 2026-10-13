package com.omnirush.dayforge.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.EditNote
import androidx.compose.material.icons.filled.LocalCafe
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Person2
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.omnirush.dayforge.data.DayforgeViewModel
import com.omnirush.dayforge.model.Article
import com.omnirush.dayforge.ui.DayforgeTheme
import java.text.NumberFormat
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable
fun TodayScreen(viewModel: DayforgeViewModel, padding: PaddingValues, onFocus: () -> Unit, onProfile: () -> Unit) {
    var showExpense by remember { mutableStateOf(false) }
    var showBrain by remember { mutableStateOf(false) }
    var showArticle by remember { mutableStateOf<Article?>(null) }
    val data = viewModel.data
    val greeting = when (java.time.LocalTime.now().hour) {
        in 5..11 -> "Good morning"
        in 12..16 -> "Good afternoon"
        in 17..21 -> "Good evening"
        else -> "Still up?"
    }
    val name = data.profile.name.substringBefore(" ").takeIf { it.isNotBlank() }

    Column(
        modifier = Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Spacer(Modifier.size(6.dp))
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.weight(1f)) {
                Text("${greeting}${name?.let { ", $it" } ?: ""}", style = MaterialTheme.typography.headlineMedium)
                Text(LocalDate.now().format(DateTimeFormatter.ofPattern("EEEE, MMM d", Locale.getDefault())), color = InkSoft)
            }
            IconButton(onClick = onProfile) { Icon(Icons.Default.Person2, "Open profile", tint = Moss) }
        }

        DayCard {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(contentAlignment = Alignment.Center, modifier = Modifier.size(106.dp)) {
                    CircularProgressIndicator(progress = { viewModel.pulse / 100f }, modifier = Modifier.fillMaxSize(), strokeWidth = 10.dp, color = Moss, trackColor = Moss.copy(alpha = 0.12f))
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("${viewModel.pulse}", style = MaterialTheme.typography.headlineLarge, color = Moss, fontWeight = FontWeight.Bold)
                        Text("PULSE", style = MaterialTheme.typography.labelSmall, color = InkSoft)
                    }
                }
                Spacer(Modifier.size(18.dp))
                Column(Modifier.weight(1f)) {
                    Text("Your day has a shape", style = MaterialTheme.typography.titleLarge)
                    Text("A little progress is still a direction. Keep one promise to yourself today.", color = InkSoft)
                    Spacer(Modifier.size(10.dp))
                    FilledTonalButton(onClick = onFocus) { Icon(Icons.Default.Timer, null); Spacer(Modifier.size(6.dp)); Text("Focus now") }
                }
            }
        }

        if (viewModel.isSignedIn) {
            DayCard(Modifier.clickable { onProfile() }) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    AccentIcon("↗", Blue)
                    Spacer(Modifier.size(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(viewModel.pairState?.pair?.partnerName ?: "Motivation partner", style = MaterialTheme.typography.titleMedium)
                        Text(
                            when {
                                viewModel.pairState?.pair?.status == "connected" -> "Connected · aggregate status ready"
                                viewModel.pairState?.pair?.status == "waiting" -> "Team code ready · waiting to connect"
                                else -> "Set up a private two-person team"
                            },
                            color = InkSoft,
                        )
                    }
                    Icon(Icons.Default.ChevronRight, null, tint = InkSoft)
                }
            }
        }

        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            QuickAction("Focus", "◷", Blue, onFocus, Modifier.weight(1f))
            QuickAction("Habits", "✓", Moss, {}, Modifier.weight(1f))
            QuickAction("Spend", "$", Clay, { showExpense = true }, Modifier.weight(1f))
            QuickAction("Brain", "✦", Gold, { showBrain = true }, Modifier.weight(1f))
        }

        if (data.profile.showHabits) {
            DayCard {
                SectionHeader("Daily rituals", "${viewModel.habitsDone}/${data.habits.size}")
                Spacer(Modifier.size(8.dp))
                data.habits.forEach { habit ->
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().padding(vertical = 5.dp)) {
                        Checkbox(checked = habit.isDone, onCheckedChange = { viewModel.toggleHabit(habit.id) })
                        Column(Modifier.weight(1f)) {
                            Text(habit.title, fontWeight = FontWeight.SemiBold)
                            Text(habit.detail, style = MaterialTheme.typography.bodySmall, color = InkSoft)
                        }
                        Text("${habit.streak}d", style = MaterialTheme.typography.labelMedium, color = Moss)
                    }
                }
                Spacer(Modifier.size(6.dp))
                ProgressBar(viewModel.habitProgress)
            }
        }

        if (data.profile.showAlarm) {
            DayCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    AccentIcon("◴", Clay)
                    Spacer(Modifier.size(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text("${data.alarm.hour.toString().padStart(2, '0')}:${data.alarm.minute.toString().padStart(2, '0')}", style = MaterialTheme.typography.headlineMedium)
                        Text("${data.alarm.label} · ${data.alarm.repeatText}", color = InkSoft)
                    }
                    Switch(checked = data.alarm.isOn, onCheckedChange = viewModel::setAlarm)
                }
            }
        }

        if (data.profile.showSpending) {
            DayCard {
                SectionHeader("Spending", "This month")
                Spacer(Modifier.size(8.dp))
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(currency(viewModel.monthlySpend), style = MaterialTheme.typography.headlineMedium)
                    Spacer(Modifier.size(8.dp))
                    Text("of ${currency(data.monthlyBudget)}", color = InkSoft, modifier = Modifier.padding(bottom = 4.dp))
                    Spacer(Modifier.weight(1f))
                    IconButton(onClick = { showExpense = true }) { Icon(Icons.Default.Add, "Add spending", tint = Clay) }
                }
                ProgressBar(viewModel.budgetProgress, Clay)
            }
        }

        if (data.profile.showBrain) {
            DayCard(Modifier.clickable { showBrain = true }) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    AccentIcon("✦", Gold)
                    Spacer(Modifier.size(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text("Brain training", style = MaterialTheme.typography.titleMedium)
                        Text("A tiny sprint keeps the gears warm.", color = InkSoft)
                    }
                    Icon(Icons.Default.PlayArrow, "Start brain training", tint = Gold)
                }
            }
        }

        if (data.profile.showBrief) {
            val article = com.omnirush.dayforge.model.SampleData.articles.first()
            DayCard(Modifier.clickable { showArticle = article }) {
                TinyTag(article.tag, Blue)
                Spacer(Modifier.size(8.dp))
                Text(article.title, style = MaterialTheme.typography.titleLarge)
                Spacer(Modifier.size(4.dp))
                Text(article.summary, color = InkSoft)
            }
        }
        Spacer(Modifier.size(18.dp))
    }

    if (showExpense) ExpenseDialog(viewModel, onDismiss = { showExpense = false })
    if (showBrain) BrainDialog(onDismiss = { showBrain = false })
    showArticle?.let { article -> ArticleDialog(article, onDismiss = { showArticle = null }) }
}

@Composable
private fun QuickAction(label: String, glyph: String, tint: Color, onClick: () -> Unit, modifier: Modifier) {
    Surface(onClick = onClick, modifier = modifier, color = tint.copy(alpha = 0.12f), shape = RoundedCornerShape(16.dp)) {
        Column(Modifier.padding(vertical = 12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(glyph, color = tint, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text(label, style = MaterialTheme.typography.labelSmall, color = InkSoft)
        }
    }
}

@Composable
private fun ExpenseDialog(viewModel: DayforgeViewModel, onDismiss: () -> Unit) {
    var amount by remember { mutableStateOf("") }
    var category by remember { mutableStateOf("Food") }
    var note by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add spending") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(amount, { amount = it }, label = { Text("Amount") }, singleLine = true)
                OutlinedTextField(category, { category = it }, label = { Text("Category") }, singleLine = true)
                OutlinedTextField(note, { note = it }, label = { Text("Note") }, singleLine = true)
            }
        },
        confirmButton = {
            Button(onClick = { viewModel.addExpense(amount.toDoubleOrNull() ?: 0.0, category, note); onDismiss() }) { Text("Save") }
        },
        dismissButton = { OutlinedButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

@Composable
private fun BrainDialog(onDismiss: () -> Unit) {
    var answer by remember { mutableStateOf("") }
    var checked by remember { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Daily sprint") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("What is 7 × 8?", style = MaterialTheme.typography.titleLarge)
                OutlinedTextField(answer, { answer = it }, label = { Text("Your answer") }, singleLine = true)
                if (checked) Text(if (answer.trim() == "56") "Correct — keep the momentum." else "Not quite. The answer is 56.", color = if (answer.trim() == "56") Moss else Clay)
            }
        },
        confirmButton = { Button(onClick = { checked = true }) { Text(if (checked) "Try again" else "Check") } },
        dismissButton = { OutlinedButton(onClick = onDismiss) { Text("Done") } },
    )
}

@Composable
private fun ArticleDialog(article: Article, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(article.title) },
        text = { Column(verticalArrangement = Arrangement.spacedBy(10.dp)) { TinyTag("${article.tag} · ${article.minutes} min", Blue); Text(article.body) } },
        confirmButton = { Button(onClick = onDismiss) { Text("Close") } },
    )
}

private fun currency(value: Double): String = NumberFormat.getCurrencyInstance(Locale.getDefault()).format(value)

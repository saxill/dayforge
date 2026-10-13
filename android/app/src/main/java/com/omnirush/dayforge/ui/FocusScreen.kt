package com.omnirush.dayforge.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.omnirush.dayforge.data.DayforgeViewModel
import com.omnirush.dayforge.data.FocusPhase

@Composable
fun FocusScreen(viewModel: DayforgeViewModel, padding: PaddingValues) {
    var showSettings by remember { mutableStateOf(false) }
    Column(
        Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Spacer(Modifier.size(6.dp))
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.weight(1f)) {
                Text("FOCUS", style = MaterialTheme.typography.labelLarge, color = InkSoft, fontWeight = FontWeight.Bold)
                Text("One thing, ${viewModel.data.focusDurationMinutes} minutes", style = MaterialTheme.typography.headlineMedium)
            }
            IconButton(onClick = { showSettings = true }) { Icon(Icons.Default.Settings, "Focus timer settings", tint = Blue) }
        }

        DayCard {
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                Spacer(Modifier.size(8.dp))
                CircularProgressIndicator(
                    progress = { viewModel.timerProgress },
                    modifier = Modifier.size(250.dp),
                    strokeWidth = 18.dp,
                    color = if (viewModel.focusPhase == FocusPhase.FINISHED) Moss else Blue,
                    trackColor = Blue.copy(alpha = 0.12f),
                )
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(top = 16.dp)) {
                    Text(formatSeconds(viewModel.remainingSeconds), style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
                    Text(
                        when (viewModel.focusPhase) {
                            FocusPhase.IDLE -> "Ready when you are"
                            FocusPhase.RUNNING -> "Stay with the next small step"
                            FocusPhase.PAUSED -> "Paused"
                            FocusPhase.FINISHED -> "Focus complete"
                        },
                        color = if (viewModel.focusPhase == FocusPhase.FINISHED) Moss else InkSoft,
                    )
                }
            }
        }

        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Button(onClick = { if (viewModel.focusPhase == FocusPhase.RUNNING) viewModel.pauseFocus() else viewModel.startFocus() }, modifier = Modifier.weight(1f)) {
                Icon(if (viewModel.focusPhase == FocusPhase.RUNNING) Icons.Default.Pause else Icons.Default.PlayArrow, null)
                Spacer(Modifier.size(7.dp))
                Text(if (viewModel.focusPhase == FocusPhase.PAUSED) "Resume" else if (viewModel.focusPhase == FocusPhase.FINISHED) "Go again" else if (viewModel.focusPhase == FocusPhase.RUNNING) "Pause" else "Start")
            }
            OutlinedButton(onClick = viewModel::resetFocus, modifier = Modifier.weight(1f), enabled = viewModel.focusPhase != FocusPhase.IDLE) {
                Icon(Icons.Default.Refresh, null)
                Spacer(Modifier.size(7.dp))
                Text("Reset")
            }
        }

        DayCard {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Lock, null, tint = Moss, modifier = Modifier.size(28.dp))
                Spacer(Modifier.size(12.dp))
                Column(Modifier.weight(1f)) {
                    Text("Ongoing timer state", style = MaterialTheme.typography.titleMedium)
                    Text("Android keeps your current focus state visible here while you work. iOS uses a Live Activity.", color = InkSoft)
                }
            }
        }

        DayCard {
            SectionHeader("Today", "Focus stats")
            Spacer(Modifier.size(12.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                MetricPill("Sessions", viewModel.data.focusSessionsToday.toString(), Moss)
                MetricPill("Minutes", viewModel.data.focusMinutesToday.toString(), Blue)
                MetricPill("Day streak", viewModel.data.focusStreakDays.toString(), Clay)
            }
        }
        Spacer(Modifier.size(18.dp))
    }

    if (showSettings) FocusSettingsDialog(viewModel, onDismiss = { showSettings = false })
}

@Composable
private fun FocusSettingsDialog(viewModel: DayforgeViewModel, onDismiss: () -> Unit) {
    var minutes by remember { mutableStateOf(viewModel.data.focusDurationMinutes.toString()) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Focus duration") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Choose a calm block between 5 and 120 minutes.", color = InkSoft)
                OutlinedTextField(minutes, { minutes = it.filter(Char::isDigit) }, label = { Text("Minutes") }, singleLine = true)
            }
        },
        confirmButton = { Button(onClick = { viewModel.setFocusDuration(minutes.toIntOrNull() ?: 25); onDismiss() }) { Text("Save") } },
        dismissButton = { OutlinedButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

private fun formatSeconds(seconds: Int): String = "%02d:%02d".format(seconds / 60, seconds % 60)

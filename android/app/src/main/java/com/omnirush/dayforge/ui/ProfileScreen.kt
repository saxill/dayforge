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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.omnirush.dayforge.data.DayforgeViewModel

@Composable
fun ProfileScreen(viewModel: DayforgeViewModel, padding: PaddingValues) {
    var showAuth by remember { mutableStateOf(false) }
    var showTeam by remember { mutableStateOf(false) }
    LaunchedEffect(viewModel.isSignedIn) { if (viewModel.isSignedIn) viewModel.refreshPair() }

    Column(
        Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Spacer(Modifier.size(6.dp))
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
            Text("D", style = MaterialTheme.typography.headlineLarge, color = ColorWhite, modifier = Modifier.padding(14.dp))
            Text(viewModel.data.profile.name.ifBlank { "Your profile" }, style = MaterialTheme.typography.headlineMedium)
            Text(viewModel.accountEmail ?: "Not signed in", color = InkSoft)
        }

        DayCard {
            SectionHeader("Account", if (viewModel.isSignedIn) "connected" else "offline")
            Spacer(Modifier.size(8.dp))
            if (viewModel.isSignedIn) {
                Text("${viewModel.accountName ?: "Dayforge account"} · ${viewModel.accountEmail}", color = InkSoft)
                Spacer(Modifier.size(10.dp))
                OutlinedButton(onClick = viewModel::signOut) { Text("Sign out") }
            } else {
                Text("Sign in to sync your Dayforge data and pair with one trusted person.", color = InkSoft)
                Spacer(Modifier.size(10.dp))
                Button(onClick = { showAuth = true }) { Text("Sign in or create account") }
            }
        }

        if (viewModel.isSignedIn) {
            DayCard {
                SectionHeader("Team", viewModel.pairState?.pair?.status ?: "not set up")
                Spacer(Modifier.size(8.dp))
                Text("Share Pulse, daily ritual totals, focus momentum and aggregate history. Habit names, expenses, alarms, manga files and notes stay private.", color = InkSoft)
                Spacer(Modifier.size(10.dp))
                Button(onClick = { showTeam = true }) { Text(if (viewModel.pairState?.pair == null) "Set up a motivation partner" else "Open motivation team") }
            }
        }

        DayCard {
            SectionHeader("Appearance")
            Spacer(Modifier.size(8.dp))
            OutlinedTextField(
                value = viewModel.data.profile.name,
                onValueChange = viewModel::updateProfileName,
                label = { Text("Your name") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.size(10.dp))
            Text("Theme", style = MaterialTheme.typography.titleSmall)
            Spacer(Modifier.size(6.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("linen", "moss", "blue").forEach { theme ->
                    FilterChip(selected = viewModel.data.profile.theme == theme, onClick = { viewModel.setTheme(theme) }, label = { Text(theme.replaceFirstChar(Char::uppercase)) })
                }
            }
        }

        DayCard {
            SectionHeader("Today cards")
            Spacer(Modifier.size(4.dp))
            SettingToggle("Habits", viewModel.data.profile.showHabits) { viewModel.setSectionVisible("habits", it) }
            SettingToggle("Alarm", viewModel.data.profile.showAlarm) { viewModel.setSectionVisible("alarm", it) }
            SettingToggle("Spending", viewModel.data.profile.showSpending) { viewModel.setSectionVisible("spending", it) }
            SettingToggle("Brain training", viewModel.data.profile.showBrain) { viewModel.setSectionVisible("brain", it) }
            SettingToggle("AI brief", viewModel.data.profile.showBrief) { viewModel.setSectionVisible("brief", it) }
        }
        Spacer(Modifier.size(18.dp))
    }

    if (showAuth) AuthDialog(viewModel, onDismiss = { showAuth = false })
    if (showTeam) TeamDialog(viewModel, onDismiss = { showTeam = false })
}

@Composable
private fun SettingToggle(title: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(title, modifier = Modifier.weight(1f))
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Composable
private fun AuthDialog(viewModel: DayforgeViewModel, onDismiss: () -> Unit) {
    var register by remember { mutableStateOf(false) }
    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (register) "Create your Dayforge account" else "Welcome back") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(9.dp)) {
                if (register) OutlinedTextField(name, { name = it }, label = { Text("Name") }, singleLine = true)
                OutlinedTextField(email, { email = it }, label = { Text("Email") }, singleLine = true)
                OutlinedTextField(password, { password = it }, label = { Text("Password") }, singleLine = true)
                Text(if (register) "Already have an account? Sign in instead." else "New here? Create an account.", color = InkSoft, modifier = Modifier.padding(top = 4.dp))
                OutlinedButton(onClick = { register = !register }) { Text(if (register) "Use sign in" else "Create account") }
            }
        },
        confirmButton = {
            Button(onClick = { if (register) viewModel.register(email, password, name) else viewModel.signIn(email, password); onDismiss() }, enabled = !viewModel.busy) {
                if (viewModel.busy) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp) else Text(if (register) "Create" else "Sign in")
            }
        },
        dismissButton = { OutlinedButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

@Composable
private fun TeamDialog(viewModel: DayforgeViewModel, onDismiss: () -> Unit) {
    var joinCode by remember { mutableStateOf("") }
    var nudge by remember { mutableStateOf("") }
    val pair = viewModel.pairState?.pair
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Motivation partner") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Share daily aggregate momentum without sharing the habits themselves.", color = InkSoft)
                if (pair == null) {
                    Button(onClick = viewModel::createPairInvite, enabled = !viewModel.busy) { Text("Create team code") }
                    OutlinedTextField(joinCode, { joinCode = it.uppercase().filter { char -> char.isLetterOrDigit() }.take(6) }, label = { Text("6-character code") }, singleLine = true)
                    Button(onClick = { viewModel.joinPair(joinCode) }, enabled = !viewModel.busy && joinCode.length == 6) { Text("Join with code") }
                } else {
                    Text(if (pair.status == "waiting") "Your team code" else "Connected to ${pair.partnerName ?: "your partner"}", style = MaterialTheme.typography.titleLarge)
                    if (pair.status == "waiting") {
                        Text(pair.code ?: "—", style = MaterialTheme.typography.headlineLarge, color = Moss, fontWeight = FontWeight.Bold)
                        Text("Send this code to someone you trust. Refresh checks whether they joined; it does not rotate the code.", color = InkSoft)
                    } else {
                        val partner = viewModel.pairState?.partner
                        Text("Partner Pulse: ${partner?.pulse ?: "—"}", color = Blue)
                        Text("Rituals: ${partner?.habitsDone ?: 0}/${partner?.habitsTotal ?: 0} · Focus: ${partner?.focusMinutes ?: 0} min", color = InkSoft)
                        OutlinedTextField(nudge, { nudge = it.take(120) }, label = { Text("Send encouragement") }, singleLine = true)
                        Button(onClick = { viewModel.sendNudge(nudge); nudge = "" }, enabled = nudge.isNotBlank() && !viewModel.busy) { Text("Send") }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = viewModel::refreshPair, enabled = !viewModel.busy) { Text("Refresh") }
                        OutlinedButton(onClick = viewModel::leavePair, enabled = !viewModel.busy) { Text("Leave") }
                    }
                }
            }
        },
        confirmButton = { Button(onClick = onDismiss) { Text("Done") } },
    )
}

private val ColorWhite = androidx.compose.ui.graphics.Color.White

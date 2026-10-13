package com.omnirush.dayforge.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.omnirush.dayforge.data.DayforgeViewModel

private enum class MainTab(val title: String) {
    TODAY("Today"), FOCUS("Focus"), DISCOVER("Discover"), PROFILE("Profile")
}

@Composable
fun DayforgeApp(viewModel: DayforgeViewModel) {
    var tab by rememberSaveable { mutableStateOf(MainTab.TODAY) }
    val snackbar = remember { SnackbarHostState() }

    LaunchedEffect(viewModel.errorMessage, viewModel.noticeMessage) {
        val message = viewModel.errorMessage ?: viewModel.noticeMessage
        if (message != null) {
            snackbar.showSnackbar(message)
            viewModel.clearMessages()
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        bottomBar = {
            NavigationBar(modifier = Modifier.navigationBarsPadding(), containerColor = Card) {
                MainTab.entries.forEach { item ->
                    NavigationBarItem(
                        selected = tab == item,
                        onClick = { tab = item },
                        icon = {
                            Icon(
                                imageVector = when (item) {
                                    MainTab.TODAY -> Icons.Default.WbSunny
                                    MainTab.FOCUS -> Icons.Default.Timer
                                    MainTab.DISCOVER -> Icons.Default.AutoAwesome
                                    MainTab.PROFILE -> Icons.Default.Person
                                },
                                contentDescription = item.title,
                            )
                        },
                        label = { Text(item.title) },
                    )
                }
            }
        },
    ) { padding ->
        when (tab) {
            MainTab.TODAY -> TodayScreen(viewModel, padding, onFocus = { tab = MainTab.FOCUS }, onProfile = { tab = MainTab.PROFILE })
            MainTab.FOCUS -> FocusScreen(viewModel, padding)
            MainTab.DISCOVER -> DiscoverScreen(viewModel, padding)
            MainTab.PROFILE -> ProfileScreen(viewModel, padding)
        }
    }
}

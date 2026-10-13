package com.omnirush.dayforge

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import com.omnirush.dayforge.data.DayforgeViewModel
import com.omnirush.dayforge.ui.DayforgeApp
import com.omnirush.dayforge.ui.DayforgeTheme

class MainActivity : ComponentActivity() {
    private val viewModel by viewModels<DayforgeViewModel>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { DayforgeTheme { DayforgeApp(viewModel) } }
    }
}

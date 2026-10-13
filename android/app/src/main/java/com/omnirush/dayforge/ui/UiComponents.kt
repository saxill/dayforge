package com.omnirush.dayforge.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

@Composable
fun DayCard(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(containerColor = Card),
        border = androidx.compose.foundation.BorderStroke(1.dp, Hairline),
    ) { Column(Modifier.padding(16.dp), content = { content() }) }
}

@Composable
fun SectionHeader(title: String, trailing: String? = null) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        Spacer(Modifier.weight(1f))
        if (trailing != null) Text(trailing, style = MaterialTheme.typography.labelMedium, color = InkSoft)
    }
}

@Composable
fun MetricPill(label: String, value: String, tint: Color = Moss) {
    Surface(color = tint.copy(alpha = 0.12f), shape = RoundedCornerShape(16.dp)) {
        Column(Modifier.padding(horizontal = 14.dp, vertical = 12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = tint)
            Text(label, style = MaterialTheme.typography.labelSmall, color = InkSoft)
        }
    }
}

@Composable
fun ProgressBar(progress: Float, tint: Color = Moss) {
    LinearProgressIndicator(
        progress = { progress.coerceIn(0f, 1f) },
        modifier = Modifier.fillMaxWidth().height(8.dp).clip(RoundedCornerShape(8.dp)),
        color = tint,
        trackColor = tint.copy(alpha = 0.12f),
    )
}

@Composable
fun AccentIcon(symbol: String, tint: Color = Moss, modifier: Modifier = Modifier) {
    Box(
        modifier.size(46.dp).clip(RoundedCornerShape(14.dp)).background(tint.copy(alpha = 0.13f)),
        contentAlignment = Alignment.Center,
    ) { Text(symbol, style = MaterialTheme.typography.titleLarge, color = tint) }
}

@Composable
fun TinyTag(text: String, tint: Color = Moss) {
    Surface(color = tint.copy(alpha = 0.13f), contentColor = tint, shape = RoundedCornerShape(99.dp)) {
        Text(text.uppercase(), modifier = Modifier.padding(horizontal = 9.dp, vertical = 5.dp), style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold)
    }
}

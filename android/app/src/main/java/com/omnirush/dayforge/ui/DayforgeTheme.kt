package com.omnirush.dayforge.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

val Linen = Color(0xFFF7F3EC)
val Ink = Color(0xFF202623)
val InkSoft = Color(0xFF6F7771)
val Card = Color(0xFFFFFCF7)
val Moss = Color(0xFF52735F)
val MossSoft = Color(0xFFDDE9DD)
val Blue = Color(0xFF4D738A)
val BlueSoft = Color(0xFFDCEBF1)
val Clay = Color(0xFFB6654F)
val ClaySoft = Color(0xFFF6DDD2)
val Gold = Color(0xFFC79643)
val GoldSoft = Color(0xFFF5E8BD)
val Hairline = Color(0xFFE6DED2)

private val LightColors = lightColorScheme(
    primary = Moss,
    onPrimary = Color.White,
    secondary = Blue,
    background = Linen,
    onBackground = Ink,
    surface = Card,
    onSurface = Ink,
    surfaceVariant = Linen,
    onSurfaceVariant = InkSoft,
    error = Clay,
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFFB7D0B9),
    onPrimary = Color(0xFF183521),
    secondary = Color(0xFFB5D2E0),
    background = Color(0xFF17201B),
    onBackground = Color(0xFFE7EEE7),
    surface = Color(0xFF202B24),
    onSurface = Color(0xFFE7EEE7),
)

private val DayforgeTypography = Typography().let { base ->
    base.copy(
        headlineLarge = base.headlineLarge.copy(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Bold, fontSize = 30.sp),
        headlineMedium = base.headlineMedium.copy(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Bold, fontSize = 24.sp),
        titleLarge = base.titleLarge.copy(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Bold),
        titleMedium = base.titleMedium.copy(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.SemiBold),
        bodyLarge = base.bodyLarge.copy(fontFamily = FontFamily.SansSerif, lineHeight = 22.sp),
        bodyMedium = base.bodyMedium.copy(fontFamily = FontFamily.SansSerif, lineHeight = 20.sp),
    )
}

@Composable
fun DayforgeTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (isSystemInDarkTheme()) DarkColors else LightColors,
        typography = DayforgeTypography,
        content = content,
    )
}

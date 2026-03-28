// DesignTokens.kt
// GreenRead AR — Design System (Android)
// Port of DesignTokens.swift — PRD §5.2
//
// All 12 color tokens with exact hex values from PRD color palette.

package com.greenreadar.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Design tokens for GreenRead AR.
 * Port of DesignTokens.swift — all colors per PRD §5.2.
 */
object DesignTokens {

    // MARK: - Colors (PRD §5.2)

    val BackgroundDeep = Color(0xFF0D1F14)
    val BackgroundSurface = Color(0xFF122A1A)
    val BackgroundCard = Color(0xFF183322)

    val Primary = Color(0xFF1A7A4A)
    val PrimaryLight = Color(0xFF22A55E)

    val Downhill = Color(0xFF3B82F6)     // Blue — downhill slopes
    val Uphill = Color(0xFFEF4444)       // Red — uphill slopes
    val Flat = Color(0xFF22C55E)         // Green — flat areas

    val Ball = Color(0xFFFFFFFF)         // White golf ball
    val BreakLine = Color(0xFFFACC15)    // Yellow break curve

    val TextPrimary = Color(0xFFF0FDF4)
    val TextSecondary = Color(0xFFA7C4B8)
    val TextDim = Color(0xFF5A7D6C)

    val Border = Color(0x331A7A4A)       // Primary with ~20% alpha

    // MARK: - Typography

    val FontTitle = FontFamily.Default
    val FontBody = FontFamily.Default

    val TitleSize = 28.sp
    val SubtitleSize = 18.sp
    val BodySize = 14.sp
    val CaptionSize = 12.sp
    val HudValueSize = 32.sp

    // MARK: - Spacing

    val PaddingSmall = 8.dp
    val PaddingMedium = 16.dp
    val PaddingLarge = 24.dp

    val CornerRadiusSmall = 8.dp
    val CornerRadiusMedium = 12.dp
    val CornerRadiusLarge = 20.dp

    // MARK: - Opacity

    const val GlassOpacity = 0.85f
    const val OverlayOpacity = 0.7f
}

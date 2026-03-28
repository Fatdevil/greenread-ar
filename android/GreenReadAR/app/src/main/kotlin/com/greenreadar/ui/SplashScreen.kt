// SplashScreen.kt
// GreenRead AR — Splash Screen (Android)
// Port of SplashView.swift — PRD §5.1
//
// Jetpack Compose implementation with ARCore availability check.
// Uses DesignTokens for all colors per PRD §5.2.

package com.greenreadar.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.*
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.google.ar.core.ArCoreApk
import com.greenreadar.ui.theme.DesignTokens
import kotlinx.coroutines.delay

/**
 * Splash screen with branding and ARCore availability check.
 * Port of SplashView.swift — identical layout and functionality.
 */
@Composable
fun SplashScreen(
    onStartScanning: () -> Unit,
    onARNotSupported: () -> Unit
) {
    val context = LocalContext.current

    // ARCore availability state
    var arAvailable by remember { mutableStateOf<Boolean?>(null) }
    var showContent by remember { mutableStateOf(false) }
    var showButton by remember { mutableStateOf(false) }

    // Check ARCore availability
    LaunchedEffect(Unit) {
        delay(300) // Brief delay for splash feel
        showContent = true

        val availability = ArCoreApk.getInstance().checkAvailability(context)
        arAvailable = when (availability) {
            ArCoreApk.Availability.SUPPORTED_INSTALLED,
            ArCoreApk.Availability.SUPPORTED_APK_TOO_OLD,
            ArCoreApk.Availability.SUPPORTED_NOT_INSTALLED -> true
            else -> false
        }

        delay(600)
        showButton = true
    }

    // Pulse animation for the golf icon
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.08f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = EaseInOutSine),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse_scale"
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        DesignTokens.BackgroundDeep,
                        DesignTokens.BackgroundSurface
                    )
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.padding(DesignTokens.PaddingLarge)
        ) {
            // App icon — pulsing golf flag
            AnimatedVisibility(
                visible = showContent,
                enter = fadeIn(tween(800)) + slideInVertically(tween(800))
            ) {
                Text(
                    text = "⛳",
                    fontSize = DesignTokens.HudValueSize * 2,
                    modifier = Modifier
                        .scale(pulseScale)
                        .padding(bottom = 24.dp)
                )
            }

            // App name
            AnimatedVisibility(
                visible = showContent,
                enter = fadeIn(tween(800, delayMillis = 200))
            ) {
                Text(
                    text = "GreenRead AR",
                    color = DesignTokens.TextPrimary,
                    fontSize = DesignTokens.TitleSize,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Subtitle
            AnimatedVisibility(
                visible = showContent,
                enter = fadeIn(tween(800, delayMillis = 400))
            ) {
                Text(
                    text = "Läs greenen med AR",
                    color = DesignTokens.TextSecondary,
                    fontSize = DesignTokens.SubtitleSize,
                    textAlign = TextAlign.Center
                )
            }

            Spacer(modifier = Modifier.height(48.dp))

            // Start button or error message
            AnimatedVisibility(
                visible = showButton,
                enter = fadeIn(tween(600))
            ) {
                when (arAvailable) {
                    true -> {
                        Button(
                            onClick = onStartScanning,
                            colors = ButtonDefaults.buttonColors(
                                containerColor = DesignTokens.Primary
                            ),
                            shape = RoundedCornerShape(DesignTokens.CornerRadiusMedium),
                            modifier = Modifier
                                .fillMaxWidth(0.7f)
                                .height(56.dp)
                        ) {
                            Text(
                                text = "Börja scanna",
                                color = DesignTokens.TextPrimary,
                                fontSize = DesignTokens.SubtitleSize,
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                    }
                    false -> {
                        // ARCore not supported
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = "⚠️",
                                fontSize = DesignTokens.TitleSize
                            )
                            Spacer(modifier = Modifier.height(12.dp))
                            Text(
                                text = "ARCore krävs",
                                color = DesignTokens.Uphill,
                                fontSize = DesignTokens.SubtitleSize,
                                fontWeight = FontWeight.Bold
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = "Din enhet stöder inte ARCore Depth API.\nGreenRead AR kräver en kompatibel enhet\nmed djupsensor.",
                                color = DesignTokens.TextSecondary,
                                fontSize = DesignTokens.BodySize,
                                textAlign = TextAlign.Center
                            )
                        }
                    }
                    null -> {
                        // Still checking
                        CircularProgressIndicator(
                            color = DesignTokens.Primary,
                            modifier = Modifier.size(32.dp)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(48.dp))

            // Version info
            AnimatedVisibility(
                visible = showContent,
                enter = fadeIn(tween(800, delayMillis = 600))
            ) {
                Text(
                    text = "v1.0  ·  Android",
                    color = DesignTokens.TextDim,
                    fontSize = DesignTokens.CaptionSize
                )
            }
        }
    }
}

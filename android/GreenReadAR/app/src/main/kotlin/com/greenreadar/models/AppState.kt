// AppState.kt
// GreenRead AR — Global Application State (Android)
// Port of AppState.swift — PRD §2.2
//
// Uses Android ViewModel + StateFlow instead of Swift @Published + ObservableObject.
// Identical screen states and interaction modes.

package com.greenreadar.models

import androidx.lifecycle.ViewModel
import com.greenreadar.ar.Float3
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlin.math.sqrt

// MARK: - Screen & Interaction State

enum class AppScreen {
    SPLASH, CAMERA, SETTINGS
}

enum class InteractionMode {
    SCANNING, PLACE_HOLE, PLACE_BALL, READY, ROLLING, RESULT
}

// MARK: - Settings

data class GreenReadSettings(
    val stimpmeter: Float = 10.0f,         // 7.0 – 13.0
    val useMetric: Boolean = true,          // metric vs imperial
    val breakInCm: Boolean = true,          // cm vs inches
    val numberOfBalls: Int = 1,             // 1, 3, or 5
    val theme: AppTheme = AppTheme.DARK
) {
    enum class AppTheme { DARK, LIGHT }

    /** Friction coefficient derived from Stimpmeter */
    val frictionCoefficient: Float
        get() = 1.0f / (stimpmeter * 0.38f)
}

// MARK: - Putt Result

data class PuttResult(
    val distance: Double,           // meters
    val breakAmount: Double,        // centimeters
    val breakDirection: String,     // "Vänster" / "Höger" / "Rak putt"
    val slopePercent: Double,
    val slopeType: String,          // "Uppförsbacke" / "Nedförsbacke" / "Plant"
    val speedRecommendation: String,
    val speedPercent: Double         // 0–100 for UI bar
)

// MARK: - App State ViewModel

/**
 * Global application state using ViewModel + StateFlow.
 * Port of AppState.swift — identical state machine and transitions.
 */
class AppState : ViewModel() {

    // Screen navigation
    private val _currentScreen = MutableStateFlow(AppScreen.SPLASH)
    val currentScreen: StateFlow<AppScreen> = _currentScreen.asStateFlow()

    private val _interactionMode = MutableStateFlow(InteractionMode.SCANNING)
    val interactionMode: StateFlow<InteractionMode> = _interactionMode.asStateFlow()

    // Settings
    private val _settings = MutableStateFlow(GreenReadSettings())
    val settings: StateFlow<GreenReadSettings> = _settings.asStateFlow()

    private val _isPremium = MutableStateFlow(false)
    val isPremium: StateFlow<Boolean> = _isPremium.asStateFlow()

    // LiDAR / ARCore
    private val _arSupported = MutableStateFlow(true)
    val arSupported: StateFlow<Boolean> = _arSupported.asStateFlow()

    private val _scanProgress = MutableStateFlow(0.0)
    val scanProgress: StateFlow<Double> = _scanProgress.asStateFlow()

    private val _greenDetected = MutableStateFlow(false)
    val greenDetected: StateFlow<Boolean> = _greenDetected.asStateFlow()

    // Placement
    private val _holePosition = MutableStateFlow<Float3?>(null)
    val holePosition: StateFlow<Float3?> = _holePosition.asStateFlow()

    private val _ballPosition = MutableStateFlow<Float3?>(null)
    val ballPosition: StateFlow<Float3?> = _ballPosition.asStateFlow()

    private val _puttDistance = MutableStateFlow(0.0)
    val puttDistance: StateFlow<Double> = _puttDistance.asStateFlow()

    // Slope HUD
    private val _slopeDegrees = MutableStateFlow(0.0)
    val slopeDegrees: StateFlow<Double> = _slopeDegrees.asStateFlow()

    private val _slopePercent = MutableStateFlow(0.0)
    val slopePercent: StateFlow<Double> = _slopePercent.asStateFlow()

    private val _slopeDirection = MutableStateFlow("—")
    val slopeDirection: StateFlow<String> = _slopeDirection.asStateFlow()

    // Results
    private val _puttResult = MutableStateFlow<PuttResult?>(null)
    val puttResult: StateFlow<PuttResult?> = _puttResult.asStateFlow()

    private val _showResultsPanel = MutableStateFlow(false)
    val showResultsPanel: StateFlow<Boolean> = _showResultsPanel.asStateFlow()

    // MARK: - ARCore Check

    fun setARSupported(supported: Boolean) {
        _arSupported.value = supported
    }

    // MARK: - State Transitions

    fun startScanning() {
        if (!_arSupported.value) return
        _currentScreen.value = AppScreen.CAMERA
        _interactionMode.value = InteractionMode.SCANNING
    }

    fun greenWasDetected() {
        _greenDetected.value = true
        _interactionMode.value = InteractionMode.PLACE_HOLE
    }

    fun holePlaced(position: Float3) {
        _holePosition.value = position
        _interactionMode.value = InteractionMode.PLACE_BALL
    }

    fun ballPlaced(position: Float3) {
        _ballPosition.value = position
        _interactionMode.value = InteractionMode.READY

        // Calculate distance
        _holePosition.value?.let { hole ->
            val diff = position - hole
            _puttDistance.value = sqrt(
                (diff.x * diff.x + diff.y * diff.y + diff.z * diff.z).toDouble()
            )
        }
    }

    fun startRolling() {
        if (!_isPremium.value && _interactionMode.value != InteractionMode.READY) return
        _interactionMode.value = InteractionMode.ROLLING
        _showResultsPanel.value = false
    }

    fun rollComplete(result: PuttResult) {
        _interactionMode.value = InteractionMode.RESULT
        _puttResult.value = result
        _showResultsPanel.value = true
    }

    fun resetPutt() {
        _holePosition.value = null
        _ballPosition.value = null
        _puttResult.value = null
        _showResultsPanel.value = false
        _puttDistance.value = 0.0
        _interactionMode.value = InteractionMode.PLACE_HOLE
    }

    fun openSettings() {
        _currentScreen.value = AppScreen.SETTINGS
    }

    fun closeSettings() {
        _currentScreen.value = AppScreen.CAMERA
    }

    fun updateSettings(settings: GreenReadSettings) {
        _settings.value = settings
    }

    fun setPremium(premium: Boolean) {
        _isPremium.value = premium
    }

    fun updateSlope(degrees: Double, percent: Double, direction: String) {
        _slopeDegrees.value = degrees
        _slopePercent.value = percent
        _slopeDirection.value = direction
    }

    // MARK: - Mode Text

    val modeText: String
        get() = when (_interactionMode.value) {
            InteractionMode.SCANNING -> "Scanning pågår..."
            InteractionMode.PLACE_HOLE -> "Tryck för att placera hål ⛳"
            InteractionMode.PLACE_BALL -> "Tryck för att placera boll 🏌️"
            InteractionMode.READY -> "Redo att rulla 🎯"
            InteractionMode.ROLLING -> "Bollen rullar..."
            InteractionMode.RESULT -> "Resultat"
        }
}

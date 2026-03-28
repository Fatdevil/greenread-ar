// GreenReadSession.kt
// GreenRead AR — Session Interface (Android)
// Port of GreenReadSession.swift — PRD §10.2-B
//
// Abstracts the AR session so that BallPhysicsEngine and SlopeAnalyzer
// depend only on this interface, enabling future alternative implementations
// (e.g. ARCore vs. test mock vs. replay session).

package com.greenreadar.ar

/**
 * 2D position on the green surface (x, z in world space).
 */
data class Float2(val x: Float, val y: Float)

/**
 * 3D position or vector in world space.
 */
data class Float3(val x: Float, val y: Float, val z: Float) {
    operator fun plus(other: Float3) = Float3(x + other.x, y + other.y, z + other.z)
    operator fun minus(other: Float3) = Float3(x - other.x, y - other.y, z - other.z)
    operator fun times(scalar: Float) = Float3(x * scalar, y * scalar, z * scalar)
    operator fun div(scalar: Float) = Float3(x / scalar, y / scalar, z / scalar)

    fun length(): Float = kotlin.math.sqrt(x * x + y * y + z * z)
    fun normalized(): Float3 {
        val len = length()
        return if (len > 0.0001f) Float3(x / len, y / len, z / len) else Float3(0f, 0f, 0f)
    }

    companion object {
        val zero = Float3(0f, 0f, 0f)
        fun dot(a: Float3, b: Float3): Float = a.x * b.x + a.y * b.y + a.z * b.z
        fun cross(a: Float3, b: Float3): Float3 = Float3(
            a.y * b.z - a.z * b.y,
            a.z * b.x - a.x * b.z,
            a.x * b.y - a.y * b.x
        )
    }
}

/**
 * Slope information for a point on the green.
 * Port of SlopeInfo struct from Swift.
 */
data class SlopeInfo(
    val degrees: Float,        // Angle from horizontal
    val percent: Float,        // Gradient as percentage
    val direction: String,     // Compass direction: "↑ N", "↘ SE", etc.
    val fallLine: Float3,      // Normalized fall direction vector
    val normal: Float3         // Surface normal
) {
    /** Color classification for the slope grid — PRD §5.3 */
    val colorCategory: SlopeColorCategory
        get() = when {
            degrees < 0.8f -> SlopeColorCategory.FLAT
            degrees < 2.5f -> if (fallLine.z > 0.1f) SlopeColorCategory.MODERATE_DOWNHILL
                              else SlopeColorCategory.MODERATE_UPHILL
            else -> if (fallLine.z > 0.1f) SlopeColorCategory.STEEP_DOWNHILL
                    else SlopeColorCategory.STEEP_UPHILL
        }
}

enum class SlopeColorCategory {
    FLAT,               // Green (#22C55E)
    MODERATE_DOWNHILL,  // Transitioning to blue
    MODERATE_UPHILL,    // Transitioning to red
    STEEP_DOWNHILL,     // Blue (#3B82F6)
    STEEP_UPHILL        // Red (#EF4444)
}

/**
 * Result from a completed ball roll simulation.
 * Port of BallRollResult struct from Swift.
 */
data class BallRollResult(
    val finalPosition: Float3,
    val trailPositions: List<Float3>,
    val totalDistance: Float,
    val maxBreak: Float,               // cm
    val breakDirection: BreakDirection,
    val avgSlopeAlongPath: Float,      // degrees
    val elevationChange: Float         // meters
) {
    enum class BreakDirection(val displayName: String) {
        LEFT("Vänster"),
        RIGHT("Höger"),
        STRAIGHT("Rak putt")
    }
}

/**
 * GreenReadSession — Core interface for AR session abstraction.
 * Port of GreenReadSession protocol from Swift — PRD §10.2-B.
 *
 * BallPhysicsEngine and SlopeAnalyzer depend ONLY on this interface,
 * not on the concrete ARCoreSession implementation.
 */
interface GreenReadSession {
    // Session Lifecycle
    fun startSession()
    fun pauseSession()
    fun stopSession()

    // Mesh & Scanning
    val scanProgress: Float
    val isGreenDetected: Boolean

    fun heightAt(position: Float2): Float?
    fun normalAt(position: Float2): Float3?
    fun slopeAt(position: Float2): SlopeInfo?

    // Entity Placement
    fun placeHole(at: Float3)
    fun placeBall(at: Float3)
    fun clearEntities()

    // Ball Simulation
    fun startBallRoll(stimpmeter: Float)
    val isBallRolling: Boolean

    // Rendering
    fun updateSlopeGrid()
    fun setBreakCurveVisible(visible: Boolean)
    fun configureBallTrail(fadeAfterSeconds: Double)

    // Callbacks
    var onGreenDetected: (() -> Unit)?
    var onBallStopped: ((BallRollResult) -> Unit)?
    var onSlopeUpdated: ((SlopeInfo) -> Unit)?
}

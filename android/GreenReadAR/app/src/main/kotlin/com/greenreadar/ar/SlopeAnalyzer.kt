// SlopeAnalyzer.kt
// GreenRead AR — Slope Calculation Engine (Android)
// Port of SlopeAnalyzer.swift — PRD §2.2
//
// Analyzes surface normals to compute slope angle, direction, and grade.
// Pure math — no platform dependencies. Used by ARCoreSession and BallPhysicsEngine.

package com.greenreadar.ar

import kotlin.math.acos
import kotlin.math.atan2
import kotlin.math.sqrt
import kotlin.math.tan
import kotlin.math.abs
import kotlin.math.PI

/**
 * Slope analysis engine — direct port of SlopeAnalyzer.swift.
 * All formulas identical to iOS version per PRD §2.2.
 */
object SlopeAnalyzer {

    private const val RAD_TO_DEG = (180.0 / PI).toFloat()

    /**
     * PRD §2.2 Formula:
     * slopeAngle = acos(dot(normal, upVector))
     * slopeDirection = atan2(normal.x, normal.z)
     * fallLine = normalize(Float3(normal.x, 0, normal.z))
     */
    fun calculateSlope(normal: Float3): SlopeInfo {
        val upVector = Float3(0f, 1f, 0f)

        // Slope angle from horizontal
        val dotProduct = Float3.dot(normal, upVector).coerceIn(-1f, 1f)
        val slopeAngle = acos(dotProduct) // radians
        val slopeDegrees = slopeAngle * RAD_TO_DEG
        val slopePercent = tan(slopeAngle) * 100f

        // Fall line direction (horizontal component of normal)
        val horizontalLength = sqrt(normal.x * normal.x + normal.z * normal.z)
        val fallLine = if (horizontalLength > 0.001f) {
            Float3(normal.x, 0f, normal.z).normalized()
        } else {
            Float3.zero
        }

        // Compass direction from fall line
        val direction = compassDirection(fallLine, slopeDegrees)

        return SlopeInfo(
            degrees = slopeDegrees,
            percent = slopePercent,
            direction = direction,
            fallLine = fallLine,
            normal = normal
        )
    }

    /**
     * Convert fall direction vector to compass string.
     * Identical logic to Swift version.
     */
    private fun compassDirection(fallDir: Float3, slopeDegrees: Float): String {
        if (slopeDegrees <= 0.3f) return "—"

        val angle = atan2(fallDir.x, fallDir.z) * RAD_TO_DEG

        return when {
            angle in -22.5f..22.5f    -> "↑ N"
            angle in 22.5f..67.5f     -> "↗ NE"
            angle in 67.5f..112.5f    -> "→ E"
            angle in 112.5f..157.5f   -> "↘ SE"
            angle in -67.5f..-22.5f   -> "↖ NW"
            angle in -112.5f..-67.5f  -> "← W"
            angle in -157.5f..-112.5f -> "↙ SW"
            else                      -> "↓ S"
        }
    }

    // MARK: - Grid Color Mapping

    /**
     * PRD §5.3: Map slope to grid cell color.
     * Flat (0-1°): green, Moderate (1-3°): gradient, Steep (3°+): red/blue
     */
    fun slopeColor(info: SlopeInfo): Triple<Float, Float, Float> {
        val d = info.degrees

        return when {
            d < 0.8f -> {
                // Flat — green (#22C55E)
                Triple(0.133f, 0.773f, 0.369f)
            }
            d < 3.0f -> {
                val t = (d - 0.8f) / 2.2f
                if (info.fallLine.z > 0.1f) {
                    // Transitioning to blue (downhill)
                    Triple(
                        0.133f + t * (0.231f - 0.133f),
                        0.773f + t * (0.510f - 0.773f),
                        0.369f + t * (0.965f - 0.369f)
                    )
                } else {
                    // Transitioning to red (uphill)
                    Triple(
                        0.133f + t * (0.937f - 0.133f),
                        0.773f + t * (0.267f - 0.773f),
                        0.369f + t * (0.267f - 0.369f)
                    )
                }
            }
            else -> {
                if (info.fallLine.z > 0.1f) {
                    // Steep downhill — blue (#3B82F6)
                    Triple(0.231f, 0.510f, 0.965f)
                } else {
                    // Steep uphill — red (#EF4444)
                    Triple(0.937f, 0.267f, 0.267f)
                }
            }
        }
    }

    // MARK: - Break Calculation

    /**
     * Calculate total break between two positions along a trail.
     * Identical to Swift SlopeAnalyzer.calculateBreak().
     */
    fun calculateBreak(
        trail: List<Float3>,
        startPosition: Float3,
        holePosition: Float3
    ): Pair<Float, BallRollResult.BreakDirection> {
        val lineDir = (holePosition - startPosition).normalized()
        var maxLateral = 0f
        var maxCross = 0f

        for (point in trail) {
            val toPoint = point - startPosition
            val projLen = Float3.dot(toPoint, lineDir)
            val projection = lineDir * projLen
            val lateral = toPoint - projection
            val lateralDist = lateral.length()

            if (lateralDist > abs(maxLateral)) {
                val crossProduct = Float3.cross(
                    Float3(lineDir.x, 0f, lineDir.z),
                    Float3(lateral.x, 0f, lateral.z)
                )
                maxLateral = lateralDist
                maxCross = crossProduct.y
            }
        }

        val breakCm = maxLateral * 100f // meters to cm

        return when {
            breakCm < 0.5f -> Pair(breakCm, BallRollResult.BreakDirection.STRAIGHT)
            maxCross > 0f  -> Pair(breakCm, BallRollResult.BreakDirection.LEFT)
            else           -> Pair(breakCm, BallRollResult.BreakDirection.RIGHT)
        }
    }
}

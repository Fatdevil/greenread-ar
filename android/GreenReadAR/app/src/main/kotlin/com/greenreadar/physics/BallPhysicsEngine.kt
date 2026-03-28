// BallPhysicsEngine.kt
// GreenRead AR — Golf Ball Physics Simulation (Android)
// Port of BallPhysicsEngine.swift — PRD §2.2
//
// ARCHITECTURE NOTE — Same as iOS:
// This engine uses custom Verlet integration for break prediction.
// It depends ONLY on GreenReadSession interface (not ARCoreSession).
// Same engine, same math, same results on both platforms.

package com.greenreadar.physics

import com.greenreadar.ar.Float2
import com.greenreadar.ar.Float3
import com.greenreadar.ar.GreenReadSession
import com.greenreadar.ar.SlopeAnalyzer
import com.greenreadar.ar.BallRollResult
import kotlin.math.min
import kotlin.math.max
import kotlin.math.sqrt

/**
 * Simulates golf ball rolling on a scanned green mesh.
 * Uses custom Verlet integration for prediction accuracy.
 *
 * Port of BallPhysicsEngine.swift — identical physics.
 * terrain reference is GreenReadSession (not ARCoreSession).
 */
class BallPhysicsEngine(
    private val terrain: GreenReadSession,
    stimpmeter: Float
) {
    companion object {
        const val BALL_MASS: Float = 0.046f       // kg — standard golf ball
        const val BALL_RADIUS: Float = 0.02135f   // meters
        const val GRAVITY: Float = 9.81f          // m/s²
        const val MIN_SPEED: Float = 0.02f        // m/s — stop threshold (PRD §2.2)
    }

    // Stimpmeter-derived friction
    // PRD: Higher stimp → lower friction → faster green
    // mu ≈ 1.0 / (stimp * 0.38) — calibrated for realistic roll
    private val stimpValue: Float = stimpmeter.coerceIn(7f, 13f)
    private val frictionCoeff: Float = 1.0f / (stimpValue * 0.38f)

    // State
    var position: Float3 = Float3.zero
        private set
    var velocity: Float3 = Float3.zero
        private set
    var isRolling: Boolean = false
        private set

    // Trail recording
    val trail: MutableList<Float3> = mutableListOf()
    private var startPosition: Float3 = Float3.zero
    private var totalDistance: Float = 0f
    private val maxTrailPoints = 500

    /**
     * Initialize a roll from ball position toward hole.
     * Calculates initial speed based on distance, slope, and green speed.
     */
    fun initRoll(from ballPos: Float3, toward holePos: Float3) {
        position = ballPos
        startPosition = ballPos
        trail.clear()
        trail.add(ballPos)
        isRolling = true
        totalDistance = 0f

        // Direction toward hole
        val direction = (holePos - ballPos).normalized()
        val distance = (holePos - ballPos).length()

        // Calculate initial speed based on distance and terrain
        var speed = distance * 1.4f + 0.5f

        // Adjust for average slope along putt line
        val midPoint = Float2(
            (ballPos.x + holePos.x) / 2f,
            (ballPos.z + holePos.z) / 2f
        )

        terrain.slopeAt(midPoint)?.let { slope ->
            val slopeComponent = Float3.dot(slope.normal, direction)
            if (slopeComponent < 0) {
                // Uphill — need more speed
                speed *= 1f + kotlin.math.abs(slopeComponent) * 2.5f
            } else {
                // Downhill — need less speed
                speed *= 1f - slopeComponent * 1.2f
            }
        }

        // Adjust for green speed
        speed *= (10.0f / stimpValue)

        velocity = Float3(
            direction.x * speed,
            0f,
            direction.z * speed
        )
    }

    /**
     * Physics update — Verlet integration with substeps.
     * Identical to Swift BallPhysicsEngine.update().
     */
    data class UpdateResult(
        val position: Float3,
        val velocity: Float3,
        val isRolling: Boolean
    )

    fun update(deltaTime: Float): UpdateResult {
        if (!isRolling) {
            return UpdateResult(position, velocity, false)
        }

        val dt = min(deltaTime, 0.016f) // Cap at ~60fps
        val substeps = 4
        val subDt = dt / substeps.toFloat()

        for (step in 0 until substeps) {
            // Get slope at current position
            val pos2D = Float2(position.x, position.z)

            val slope = terrain.slopeAt(pos2D)
            if (slope == null) {
                isRolling = false
                break
            }

            // Rolling friction (opposes velocity)
            val speed = velocity.length()
            var frictionForce = Float3.zero
            if (speed > 0.001f) {
                val velNorm = velocity.normalized()
                frictionForce = velNorm * (-frictionCoeff * GRAVITY)
            }

            // Gravity along slope surface — creates the break
            val slopeAngleRad = slope.degrees * (Math.PI.toFloat() / 180f)
            val slopeGravity = slope.fallLine *
                kotlin.math.sin(slopeAngleRad) * GRAVITY

            // Total acceleration
            val accel = slopeGravity + frictionForce

            // Verlet integration
            velocity = velocity + accel * subDt
            position = position + velocity * subDt

            // Snap to terrain surface
            terrain.heightAt(pos2D)?.let { height ->
                position = Float3(position.x, height + BALL_RADIUS, position.z)
            }

            totalDistance += speed * subDt

            // Stop condition (PRD §2.2: velocity < 0.02 m/s)
            if (speed < MIN_SPEED && totalDistance > 0.1f) {
                isRolling = false
                break
            }
        }

        // Record trail
        trail.add(position)
        if (trail.size > maxTrailPoints) {
            trail.removeAt(0)
        }

        return UpdateResult(position, velocity, isRolling)
    }

    /**
     * Calculate final result after ball stops.
     */
    fun calculateResult(holePosition: Float3): BallRollResult {
        val distance = (holePosition - startPosition).length()

        // Break calculation
        val (breakAmount, breakDir) = SlopeAnalyzer.calculateBreak(
            trail = trail,
            startPosition = startPosition,
            holePosition = holePosition
        )

        // Elevation change
        val elevationChange = holePosition.y - startPosition.y

        // Average slope along path
        var totalSlope = 0f
        var slopeCount = 0f
        for (point in trail) {
            terrain.slopeAt(Float2(point.x, point.z))?.let { slope ->
                totalSlope += slope.degrees
                slopeCount += 1f
            }
        }
        val avgSlope = if (slopeCount > 0) totalSlope / slopeCount else 0f

        return BallRollResult(
            finalPosition = position,
            trailPositions = trail.toList(),
            totalDistance = totalDistance,
            maxBreak = breakAmount,
            breakDirection = breakDir,
            avgSlopeAlongPath = avgSlope,
            elevationChange = elevationChange
        )
    }
}

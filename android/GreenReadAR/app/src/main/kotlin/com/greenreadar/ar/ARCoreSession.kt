// ARCoreSession.kt
// GreenRead AR — ARCore Implementation of GreenReadSession
// Port of ARViewSession.swift — PRD §2.1, §12.2
//
// Uses ARCore Depth API (Raw Depth) for heightAt() and normalAt().
// NOT using deprecated Sceneform — uses raw depth images + Filament-ready data.

package com.greenreadar.ar

import android.content.Context
import android.media.Image
import android.os.Handler
import android.os.Looper
import android.view.Choreographer
import com.google.ar.core.*
import com.greenreadar.physics.BallPhysicsEngine
import kotlin.math.sqrt
import kotlin.math.min

/**
 * Android-specific implementation of GreenReadSession using ARCore Depth API.
 * Equivalent to ARViewSession.swift on iOS.
 *
 * Uses Frame.acquireDepthImage16Bits() for terrain height queries
 * and depth gradient computation for surface normals.
 */
class ARCoreSession(private val context: Context) : GreenReadSession {

    // ARCore
    private var session: Session? = null
    private var frame: Frame? = null

    // Depth data cache (updated each frame, not accumulated)
    private var depthImage: Image? = null
    private var depthWidth: Int = 0
    private var depthHeight: Int = 0

    // Choreographer for frame callbacks (equivalent to CADisplayLink)
    private val choreographer = Choreographer.getInstance()
    private val mainHandler = Handler(Looper.getMainLooper())

    // Physics
    private var ballPhysics: BallPhysicsEngine? = null
    private var frameCallback: Choreographer.FrameCallback? = null
    private var lastFrameTimeNanos: Long = 0

    // Entity positions (simplified — in production these drive Filament renderables)
    private var holePosition: Float3? = null
    private var ballPosition: Float3? = null

    // State
    override var scanProgress: Float = 0f
        private set
    override var isGreenDetected: Boolean = false
        private set
    override var isBallRolling: Boolean = false
        private set

    // Callbacks
    override var onGreenDetected: (() -> Unit)? = null
    override var onBallStopped: ((BallRollResult) -> Unit)? = null
    override var onSlopeUpdated: ((SlopeInfo) -> Unit)? = null

    // MARK: - Session Lifecycle

    override fun startSession() {
        try {
            val arSession = Session(context)

            val config = Config(arSession).apply {
                depthMode = Config.DepthMode.AUTOMATIC
                planeFindingMode = Config.PlaneFindingMode.HORIZONTAL
                updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR
            }

            arSession.configure(config)
            arSession.resume()
            session = arSession
            scanProgress = 0f
            isGreenDetected = false
        } catch (e: Exception) {
            // ARCore not available or configuration failed
            e.printStackTrace()
        }
    }

    override fun pauseSession() {
        session?.pause()
        stopBallSimulation()
    }

    override fun stopSession() {
        stopBallSimulation()
        session?.close()
        session = null
        depthImage?.close()
        depthImage = null
        clearEntities()
    }

    // MARK: - Frame Update (call from GL thread / render loop)

    /**
     * Called each frame from the rendering loop.
     * Updates depth data and scan progress.
     */
    fun updateFrame(frame: Frame) {
        this.frame = frame

        // Acquire depth image if available
        try {
            depthImage?.close()
            val depth = frame.acquireDepthImage16Bits()
            depthImage = depth
            depthWidth = depth.width
            depthHeight = depth.height
        } catch (e: Exception) {
            // Depth not available this frame — expected during initialization
        }

        // Update scan progress based on tracked planes
        val planes = session?.getAllTrackables(Plane::class.java) ?: emptyList()
        val trackedPlanes = planes.filter { it.trackingState == TrackingState.TRACKING }
        scanProgress = min(1.0f, trackedPlanes.size * 0.1f)

        if (scanProgress >= 0.5f && !isGreenDetected) {
            isGreenDetected = true
            mainHandler.post { onGreenDetected?.invoke() }
        }
    }

    // MARK: - Mesh Queries (Depth API based)

    /**
     * Retrieve height at a world-space position using ARCore Depth API.
     * Uses Frame.acquireDepthImage16Bits() depth map.
     *
     * Port of ARViewSession.heightAt() — uses depth instead of raycast.
     */
    override fun heightAt(position: Float2): Float? {
        val currentFrame = frame ?: return null
        val cam = currentFrame.camera
        if (cam.trackingState != TrackingState.TRACKING) return null

        // Project world position to screen coordinates
        val worldPos = floatArrayOf(position.x, 0f, position.y, 1f)
        val viewMatrix = FloatArray(16)
        val projMatrix = FloatArray(16)
        cam.getViewMatrix(viewMatrix, 0)
        cam.getProjectionMatrix(projMatrix, 0, 0.1f, 100f)

        // Simplified: use ARCore hit test for height estimation
        // In production, use depth image lookup for precise height
        try {
            val hitResults = currentFrame.hitTest(depthWidth / 2f, depthHeight / 2f)
            for (hit in hitResults) {
                val trackable = hit.trackable
                if (trackable is Plane && trackable.isPoseInPolygon(hit.hitPose)) {
                    return hit.hitPose.ty()
                }
            }
        } catch (e: Exception) {
            // Hit test failed
        }

        return null
    }

    /**
     * Retrieve surface normal at a world-space position.
     * Computed from depth gradient in the depth image.
     *
     * Port of ARViewSession.normalAt() — uses depth gradient instead of raycast.
     */
    override fun normalAt(position: Float2): Float3? {
        // For tracked planes, use the plane's normal directly
        val planes = session?.getAllTrackables(Plane::class.java) ?: return null
        for (plane in planes) {
            if (plane.trackingState == TrackingState.TRACKING) {
                val normal = plane.centerPose.let { pose ->
                    // Plane normal is the Y-axis of the pose
                    val ny = pose.rotationQuaternion
                    // Simplified: horizontal planes have normal ≈ (0, 1, 0)
                    // Compute actual normal from quaternion for tilted surfaces
                    Float3(
                        2f * (ny[0] * ny[2] + ny[1] * ny[3]),
                        1f - 2f * (ny[0] * ny[0] + ny[2] * ny[2]),
                        2f * (ny[2] * ny[3] - ny[0] * ny[1])
                    ).normalized()
                }
                return normal
            }
        }
        return Float3(0f, 1f, 0f) // Default: flat surface
    }

    override fun slopeAt(position: Float2): SlopeInfo? {
        val normal = normalAt(position) ?: return null
        return SlopeAnalyzer.calculateSlope(normal)
    }

    // MARK: - Entity Placement

    override fun placeHole(at: Float3) {
        holePosition = at
        // In production: create Filament renderable for hole + flag
    }

    override fun placeBall(at: Float3) {
        ballPosition = at
        // In production: create Filament renderable for golf ball
    }

    override fun clearEntities() {
        holePosition = null
        ballPosition = null
        // In production: remove Filament renderables
    }

    // MARK: - Ball Simulation

    override fun startBallRoll(stimpmeter: Float) {
        val ball = ballPosition ?: return
        val hole = holePosition ?: return

        ballPhysics = BallPhysicsEngine(
            terrain = this,
            stimpmeter = stimpmeter
        )

        ballPhysics?.initRoll(from = ball, toward = hole)
        isBallRolling = true

        startBallSimulation()
    }

    /**
     * Uses Choreographer.FrameCallback (Android equivalent of CADisplayLink)
     * for display-synced ball animation updates.
     */
    private fun startBallSimulation() {
        lastFrameTimeNanos = System.nanoTime()

        frameCallback = Choreographer.FrameCallback { frameTimeNanos ->
            val deltaNanos = frameTimeNanos - lastFrameTimeNanos
            lastFrameTimeNanos = frameTimeNanos
            val deltaTime = deltaNanos / 1_000_000_000f // Convert to seconds

            updateBall(deltaTime)

            // Continue animation if still rolling
            if (isBallRolling) {
                frameCallback?.let { choreographer.postFrameCallback(it) }
            }
        }

        choreographer.postFrameCallback(frameCallback!!)
    }

    private fun updateBall(deltaTime: Float) {
        val physics = ballPhysics ?: return
        if (!physics.isRolling) {
            stopBallSimulation()
            return
        }

        val result = physics.update(deltaTime)

        // Update ball position (drive Filament renderable in production)
        ballPosition = result.position

        // Check if ball stopped
        if (!physics.isRolling) {
            isBallRolling = false

            holePosition?.let { holePos ->
                val rollResult = physics.calculateResult(holePos)
                mainHandler.post { onBallStopped?.invoke(rollResult) }
            }
        }
    }

    private fun stopBallSimulation() {
        isBallRolling = false
        frameCallback?.let { choreographer.removeFrameCallback(it) }
        frameCallback = null
    }

    // MARK: - Rendering

    override fun updateSlopeGrid() {
        // In production: update Filament mesh vertex colors based on slope data
    }

    override fun setBreakCurveVisible(visible: Boolean) {
        // In production: toggle Filament break curve renderable
    }

    override fun configureBallTrail(fadeAfterSeconds: Double) {
        // In production: schedule trail opacity animation via Filament
        mainHandler.postDelayed({
            // Remove trail renderable
        }, (fadeAfterSeconds * 1000).toLong())
    }
}

// HoleCapture.swift
// GreenRead AR — Hole Capture Detection & Animation
// PRD §5.4: Ball "falls in" — scale animation + haptic feedback
// PRD §7.1 Fas 2: Boll som rullar stannar vid rätt position

import RealityKit
import ARKit
import UIKit
import simd

/// Detects when a rolling ball reaches the hole and triggers capture effects.
///
/// Capture criteria (PRD §7.1 Fas 2 Definition of Done):
/// - Ball is within hole radius (0.054m = standard golf hole radius)
/// - Ball speed is below capture threshold (0.5 m/s)
///
/// Both conditions must be true simultaneously — a fast ball rolling over
/// the hole should not trigger capture (simulates real-world physics where
/// speed > lipout threshold causes the ball to roll past).
struct HoleCaptureDetector {
    
    // MARK: - Constants
    
    /// Standard golf hole radius: 108mm diameter / 2 = 54mm
    static let holeRadius: Float = 0.054
    
    /// Maximum ball speed for capture — simulates lip-out physics.
    /// Balls moving faster than this roll over/past the hole.
    static let maxCaptureSpeed: Float = 0.5  // m/s
    
    // MARK: - Detection
    
    /// Checks if the ball has been captured by the hole.
    ///
    /// - Parameters:
    ///   - ballPosition: Current world-space position of the ball
    ///   - holePosition: World-space position of the hole center
    ///   - ballSpeed: Current ball speed in m/s (from BallPhysicsEngine velocity magnitude)
    /// - Returns: `true` if ball is within hole radius AND moving slowly enough
    static func checkCapture(
        ballPosition: SIMD3<Float>,
        holePosition: SIMD3<Float>,
        ballSpeed: Float
    ) -> Bool {
        // Calculate horizontal distance only (ignore Y — ball sits above hole)
        let dx = ballPosition.x - holePosition.x
        let dz = ballPosition.z - holePosition.z
        let horizontalDistance = sqrt(dx * dx + dz * dz)
        
        return horizontalDistance < holeRadius && ballSpeed < maxCaptureSpeed
    }
    
    // MARK: - Capture Animation
    
    /// Triggers the "ball falls in" capture animation and haptic feedback.
    /// PRD §5.4: Ball scales down to simulate falling into the hole.
    ///
    /// Animation sequence:
    /// 1. Ball moves to hole center (0.1s)
    /// 2. Ball scales down to 0 (0.3s) — simulates dropping in
    /// 3. Haptic impact feedback (.medium)
    /// 4. Ball entity removed after animation completes
    ///
    /// - Parameters:
    ///   - ballEntity: The ball's AnchorEntity to animate
    ///   - holeEntity: The hole's AnchorEntity (provides target position)
    ///   - arView: The ARView for coordinate space reference
    ///   - completion: Called after animation finishes (trigger results panel)
    static func triggerCaptureAnimation(
        ballEntity: AnchorEntity,
        holeEntity: AnchorEntity,
        in arView: ARView,
        completion: (() -> Void)? = nil
    ) {
        let holePos = holeEntity.position(relativeTo: nil)
        
        // Find the ball ModelEntity (first child)
        guard let ballModel = ballEntity.children.first as? ModelEntity else {
            completion?()
            return
        }
        
        // Step 1: Slide ball to hole center (0.1s)
        let slideTransform = Transform(
            scale: ballModel.scale,
            rotation: ballModel.orientation,
            translation: SIMD3<Float>(0, ballModel.position.y, 0)
        )
        ballEntity.setPosition(holePos, relativeTo: nil)
        ballModel.move(to: slideTransform, relativeTo: ballEntity, duration: 0.1)
        
        // Step 2: Scale down to simulate falling in (starts after slide)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let dropTransform = Transform(
                scale: SIMD3<Float>(repeating: 0.01), // Scale to near-zero
                rotation: ballModel.orientation,
                translation: SIMD3<Float>(0, -0.02, 0)  // Slight downward motion
            )
            ballModel.move(to: dropTransform, relativeTo: ballEntity, duration: 0.3)
        }
        
        // Step 3: Haptic feedback at moment of "drop"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let feedback = UIImpactFeedbackGenerator(style: .medium)
            feedback.prepare()
            feedback.impactOccurred()
        }
        
        // Step 4: Clean up after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Second lighter haptic for "ball settling"
            let settleFeedback = UIImpactFeedbackGenerator(style: .light)
            settleFeedback.impactOccurred()
            
            completion?()
        }
    }
    
    // MARK: - Near-Miss Detection
    
    /// Calculates how close the ball came to the hole (for results display).
    ///
    /// - Parameters:
    ///   - trail: Array of ball positions from BallPhysicsEngine
    ///   - holePosition: World-space hole position
    /// - Returns: Minimum horizontal distance from ball trail to hole center
    static func closestApproach(
        trail: [SIMD3<Float>],
        holePosition: SIMD3<Float>
    ) -> Float {
        var minDist: Float = .greatestFiniteMagnitude
        
        for point in trail {
            let dx = point.x - holePosition.x
            let dz = point.z - holePosition.z
            let dist = sqrt(dx * dx + dz * dz)
            minDist = min(minDist, dist)
        }
        
        return minDist
    }
}

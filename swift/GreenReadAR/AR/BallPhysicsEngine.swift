// BallPhysicsEngine.swift
// GreenRead AR — Golf Ball Physics Simulation
// PRD §2.2: Rullande bollar
// Mass: 0.046 kg, variable friction per Stimpmeter (7–13)
//
// ARCHITECTURE NOTE — Verlet vs RealityKit Physics:
// ──────────────────────────────────────────────────
// This engine uses CUSTOM Verlet integration intentionally, NOT as a replacement
// for RealityKit's PhysicsBodyComponent. The two systems work together:
//
// 1. BallPhysicsEngine (this file) — PREDICTION & BREAK CALCULATION
//    - Runs the ball simulation using Verlet integration
//    - Uses terrain slope normals to calculate gravity-driven break curves
//    - Produces: trail positions, break amount/direction, speed recommendations
//    - Reason: RealityKit's built-in physics doesn't expose enough control over
//      rolling friction coefficients tied to Stimpmeter values, nor does it
//      provide trail/path recording needed for break curve visualization
//
// 2. RealityKit PhysicsBodyComponent (in ARViewSession.swift) — COLLISION & RENDERING
//    - Applied to ball ModelEntity for mesh collision response
//    - Handles visual rolling (rotation) against the scanned mesh
//    - Provides realistic bounce/settle behavior at hole
//    - The ball entity position is SET by this engine each frame
//
// This hybrid approach gives us:
//   ✅ Precise Stimpmeter-calibrated friction (custom)
//   ✅ Accurate break prediction with trail recording (custom)
//   ✅ Realistic mesh collision and visual response (RealityKit)
//   ✅ Same engine works on both iPhone and visionOS (platform-agnostic math)
//
// PRD §10.2-B compliance: This engine depends only on the GreenReadSession
// protocol's heightAt/slopeAt methods, so it works identically on ARView
// (iPhone) and ImmersiveSpace (visionOS).

import simd
import Foundation

/// Simulates golf ball rolling on a scanned green mesh.
///
/// Uses custom Verlet integration for prediction accuracy while RealityKit
/// PhysicsBodyComponent handles collision rendering. See architecture note above.
final class BallPhysicsEngine {
    
    // MARK: - Constants
    static let ballMass: Float = 0.046       // kg — standard golf ball
    static let ballRadius: Float = 0.02135   // meters
    static let gravity: Float = 9.81         // m/s²
    static let minSpeed: Float = 0.02        // m/s — stop threshold (PRD §2.2)
    
    // MARK: - Properties
    private weak var terrain: ARViewSession?
    private let stimpmeter: Float
    private let frictionCoeff: Float
    
    // State
    var position: SIMD3<Float> = .zero
    var velocity: SIMD3<Float> = .zero
    var isRolling: Bool = false
    
    // Trail recording
    private(set) var trail: [SIMD3<Float>] = []
    private var startPosition: SIMD3<Float> = .zero
    private var totalDistance: Float = 0
    private let maxTrailPoints = 500
    
    // MARK: - Init
    init(terrain: ARViewSession, stimpmeter: Float) {
        self.terrain = terrain
        self.stimpmeter = max(7, min(13, stimpmeter))
        
        // PRD: Higher stimp → lower friction → faster green
        // mu ≈ 1 / (stimp * 0.38) — calibrated for realistic roll
        self.frictionCoeff = 1.0 / (self.stimpmeter * 0.38)
    }
    
    // MARK: - Init Roll
    func initRoll(from ballPos: SIMD3<Float>, toward holePos: SIMD3<Float>) {
        position = ballPos
        startPosition = ballPos
        trail = [ballPos]
        isRolling = true
        totalDistance = 0
        
        // Direction toward hole
        let direction = normalize(holePos - ballPos)
        let distance = length(holePos - ballPos)
        
        // Calculate initial speed based on distance and terrain
        var speed = distance * 1.4 + 0.5
        
        // Adjust for average slope along putt line
        let midPoint = SIMD2<Float>(
            (ballPos.x + holePos.x) / 2,
            (ballPos.z + holePos.z) / 2
        )
        
        if let slope = terrain?.slopeAt(position: midPoint) {
            let slopeComponent = dot(slope.normal, direction)
            if slopeComponent < 0 {
                // Uphill — need more speed
                speed *= 1 + abs(slopeComponent) * 2.5
            } else {
                // Downhill — need less speed
                speed *= 1 - slopeComponent * 1.2
            }
        }
        
        // Adjust for green speed
        speed *= (10.0 / stimpmeter)
        
        velocity = SIMD3<Float>(
            direction.x * speed,
            0,
            direction.z * speed
        )
    }
    
    // MARK: - Physics Update
    struct UpdateResult {
        let position: SIMD3<Float>
        let velocity: SIMD3<Float>
        let isRolling: Bool
    }
    
    func update(deltaTime: Float) -> UpdateResult {
        guard isRolling else {
            return UpdateResult(position: position, velocity: velocity, isRolling: false)
        }
        
        let dt = min(deltaTime, 0.016) // Cap at ~60fps
        let substeps = 4
        let subDt = dt / Float(substeps)
        
        for _ in 0..<substeps {
            // Get slope at current position
            let pos2D = SIMD2<Float>(position.x, position.z)
            
            guard let slope = terrain?.slopeAt(position: pos2D) else {
                isRolling = false
                break
            }
            
            // Rolling friction (opposes velocity)
            let speed = length(velocity)
            var frictionForce = SIMD3<Float>.zero
            if speed > 0.001 {
                frictionForce = normalize(velocity) * (-frictionCoeff * Self.gravity)
            }
            
            // Gravity along slope surface — creates the break
            let slopeGravity = slope.fallLine *
                sin(slope.degrees * .pi / 180) * Self.gravity
            
            // Total acceleration
            let accel = slopeGravity + frictionForce
            
            // Verlet integration
            velocity += accel * subDt
            position += velocity * subDt
            
            // Snap to terrain surface
            if let height = terrain?.heightAt(position: pos2D) {
                position.y = height + Self.ballRadius
            }
            
            totalDistance += speed * subDt
            
            // Stop condition (PRD §2.2: velocity < 0.02 m/s)
            if speed < Self.minSpeed && totalDistance > 0.1 {
                isRolling = false
                break
            }
        }
        
        // Record trail
        trail.append(position)
        if trail.count > maxTrailPoints {
            trail.removeFirst()
        }
        
        return UpdateResult(position: position, velocity: velocity, isRolling: isRolling)
    }
    
    // MARK: - Calculate Result
    func calculateResult(holePosition: SIMD3<Float>) -> BallRollResult {
        let distance = length(holePosition - startPosition)
        
        // Break calculation
        let breakInfo = SlopeAnalyzer.calculateBreak(
            trail: trail,
            startPosition: startPosition,
            holePosition: holePosition
        )
        
        // Elevation change
        let elevationChange = holePosition.y - startPosition.y
        
        // Average slope along path
        var totalSlope: Float = 0
        var slopeCount: Float = 0
        for point in trail {
            if let slope = terrain?.slopeAt(position: SIMD2<Float>(point.x, point.z)) {
                totalSlope += slope.degrees
                slopeCount += 1
            }
        }
        let avgSlope = slopeCount > 0 ? totalSlope / slopeCount : 0
        
        return BallRollResult(
            finalPosition: position,
            trailPositions: trail,
            totalDistance: totalDistance,
            maxBreak: breakInfo.amount,
            breakDirection: breakInfo.direction,
            avgSlopeAlongPath: avgSlope,
            elevationChange: elevationChange
        )
    }
}

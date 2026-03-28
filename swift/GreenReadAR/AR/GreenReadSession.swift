// GreenReadSession.swift
// GreenRead AR — Session Protocol
// PRD §10.2-B: Abstracts rendering target for ARView (iPhone) vs ImmersiveSpace (visionOS)

import Foundation
import simd

// MARK: - GreenReadSession Protocol
/// Abstraction layer that enables the same scanning/analysis logic to run
/// on both iPhone (ARView) and visionOS (ImmersiveSpace/RealityView).
/// This is a KEY architectural decision per PRD §10.2-B for visionOS readiness.
protocol GreenReadSession: AnyObject {
    
    // MARK: - Session Lifecycle
    /// Start the AR scanning session
    func startSession()
    
    /// Pause the AR session (e.g., app backgrounded)
    func pauseSession()
    
    /// Stop and clean up the session
    func stopSession()
    
    // MARK: - Mesh & Scanning
    /// Current scan progress (0.0 – 1.0)
    var scanProgress: Float { get }
    
    /// Whether sufficient mesh data has been collected
    var isGreenDetected: Bool { get }
    
    /// Retrieve height at a world-space position on the green mesh
    func heightAt(position: SIMD2<Float>) -> Float?
    
    /// Retrieve surface normal at a world-space position
    func normalAt(position: SIMD2<Float>) -> SIMD3<Float>?
    
    /// Calculate slope information at a position
    func slopeAt(position: SIMD2<Float>) -> SlopeInfo?
    
    // MARK: - Entity Placement
    /// Place hole marker at world position
    func placeHole(at position: SIMD3<Float>)
    
    /// Place ball at world position
    func placeBall(at position: SIMD3<Float>)
    
    /// Remove all placed entities and reset
    func clearEntities()
    
    // MARK: - Ball Simulation
    /// Start ball roll simulation from current ball position toward hole
    func startBallRoll(stimpmeter: Float)
    
    /// Whether ball is currently rolling
    var isBallRolling: Bool { get }
    
    // MARK: - Rendering
    /// Update slope grid colors based on current mesh data
    func updateSlopeGrid()
    
    /// Show/hide the break curve overlay
    func setBreakCurveVisible(_ visible: Bool)
    
    /// Set trail visibility and fade duration
    func configureBallTrail(fadeAfterSeconds: TimeInterval)
    
    // MARK: - Callbacks
    var onGreenDetected: (() -> Void)? { get set }
    var onBallStopped: ((BallRollResult) -> Void)? { get set }
    var onSlopeUpdated: ((SlopeInfo) -> Void)? { get set }
}

// MARK: - Data Types

/// Slope information for a point on the green
struct SlopeInfo: Equatable {
    let degrees: Float        // Angle from horizontal
    let percent: Float        // Gradient as percentage
    let direction: String     // Compass direction: "↑ N", "↘ SE", etc.
    let fallLine: SIMD3<Float> // Normalized fall direction vector
    let normal: SIMD3<Float>   // Surface normal
    
    /// Color classification for the slope grid
    var colorCategory: SlopeColorCategory {
        if degrees < 0.8 {
            return .flat
        } else if degrees < 2.5 {
            return fallLine.z > 0.1 ? .moderateDownhill : .moderateUphill
        } else {
            return fallLine.z > 0.1 ? .steepDownhill : .steepUphill
        }
    }
}

enum SlopeColorCategory {
    case flat              // Green (#22C55E)
    case moderateDownhill  // Transitioning to blue
    case moderateUphill    // Transitioning to red
    case steepDownhill     // Blue (#3B82F6)
    case steepUphill       // Red (#EF4444)
}

/// Result from a completed ball roll simulation
struct BallRollResult {
    let finalPosition: SIMD3<Float>
    let trailPositions: [SIMD3<Float>]
    let totalDistance: Float
    let maxBreak: Float               // cm
    let breakDirection: BreakDirection
    let avgSlopeAlongPath: Float      // degrees
    let elevationChange: Float        // meters
    
    enum BreakDirection: String {
        case left = "Vänster"
        case right = "Höger"
        case straight = "Rak putt"
    }
}

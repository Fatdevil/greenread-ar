// AppState.swift
// GreenRead AR — Global Application State
// Observable state management for all screens

import SwiftUI
import ARKit
import Combine

// MARK: - Screen & Interaction State
enum AppScreen: Equatable {
    case splash
    case camera
    case settings
}

enum InteractionMode: Equatable {
    case scanning
    case placeHole
    case placeBall
    case ready
    case rolling
    case result
}

// MARK: - Settings
struct GreenReadSettings {
    var stimpmeter: Double = 10.0           // 7.0 – 13.0
    var useMetric: Bool = true              // metric vs imperial
    var breakInCm: Bool = true              // cm vs inches
    var numberOfBalls: Int = 1              // 1, 3, or 5
    var theme: AppTheme = .dark
    
    enum AppTheme {
        case dark, light
    }
    
    /// Friction coefficient derived from Stimpmeter
    /// Higher stimp = lower friction = faster green
    var frictionCoefficient: Float {
        return 1.0 / (Float(stimpmeter) * 0.38)
    }
}

// MARK: - Putt Result
struct PuttResult: Equatable {
    let distance: Double          // meters
    let breakAmount: Double       // centimeters
    let breakDirection: String    // "Vänster" / "Höger" / "Rak putt"
    let slopePercent: Double
    let slopeType: String         // "Uppförsbacke" / "Nedförsbacke" / "Plant"
    let speedRecommendation: String
    let speedPercent: Double      // 0–100 for UI bar
}

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var currentScreen: AppScreen = .splash
    @Published var interactionMode: InteractionMode = .scanning
    @Published var settings = GreenReadSettings()
    @Published var isPremium: Bool = false
    
    // LiDAR
    @Published var lidarSupported: Bool = true
    @Published var scanProgress: Double = 0.0  // 0.0 – 1.0
    @Published var greenDetected: Bool = false
    
    // Placement
    @Published var holePosition: SIMD3<Float>?
    @Published var ballPosition: SIMD3<Float>?
    @Published var puttDistance: Double = 0.0
    
    // Slope HUD
    @Published var slopeDegrees: Double = 0.0
    @Published var slopePercent: Double = 0.0
    @Published var slopeDirection: String = "—"
    
    // Results
    @Published var puttResult: PuttResult?
    @Published var showResultsPanel: Bool = false
    
    // MARK: - LiDAR Check
    func checkLiDARSupport() {
        lidarSupported = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }
    
    // MARK: - State Transitions
    func startScanning() {
        guard lidarSupported else { return }
        currentScreen = .camera
        interactionMode = .scanning
    }
    
    func greenWasDetected() {
        greenDetected = true
        interactionMode = .placeHole
    }
    
    func holePlaced(at position: SIMD3<Float>) {
        holePosition = position
        interactionMode = .placeBall
    }
    
    func ballPlaced(at position: SIMD3<Float>) {
        ballPosition = position
        interactionMode = .ready
        
        // Calculate distance
        if let hole = holePosition {
            let diff = position - hole
            puttDistance = Double(sqrt(diff.x * diff.x + diff.y * diff.y + diff.z * diff.z))
        }
    }
    
    func startRolling() {
        guard isPremium || interactionMode == .ready else { return }
        interactionMode = .rolling
        showResultsPanel = false
    }
    
    func rollComplete(result: PuttResult) {
        interactionMode = .result
        puttResult = result
        showResultsPanel = true
    }
    
    func resetPutt() {
        holePosition = nil
        ballPosition = nil
        puttResult = nil
        showResultsPanel = false
        puttDistance = 0
        interactionMode = .placeHole
    }
    
    func openSettings() {
        currentScreen = .settings
    }
    
    func closeSettings() {
        currentScreen = .camera
    }
    
    // MARK: - Mode Text
    var modeText: String {
        switch interactionMode {
        case .scanning:    return "Scanning pågår..."
        case .placeHole:   return "Tryck för att placera hål ⛳"
        case .placeBall:   return "Tryck för att placera boll 🏌️"
        case .ready:       return "Redo att rulla 🎯"
        case .rolling:     return "Bollen rullar..."
        case .result:      return "Resultat"
        }
    }
}

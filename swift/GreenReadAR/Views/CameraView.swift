// CameraView.swift
// GreenRead AR — Main Camera / Scanning View
// PRD §4.1 Skärm 2: Live AR feed with overlays
// UIViewRepresentable for ARView (only exception to 100% SwiftUI per PRD §10.2-C)

import SwiftUI
import ARKit
import RealityKit

// MARK: - ARView Container
struct ARViewContainer: UIViewRepresentable {
    @EnvironmentObject var appState: AppState
    let session: ARViewSession
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.cameraMode = .ar
        
        // Configure session
        session.configureARView(arView)
        
        // Tap gesture for placement
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tapGesture)
        
        // Long press for reset
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        arView.addGestureRecognizer(longPress)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) { }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState, session: session)
    }
    
    class Coordinator: NSObject {
        let appState: AppState
        let session: ARViewSession
        
        init(appState: AppState, session: ARViewSession) {
            self.appState = appState
            self.session = session
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = gesture.view as? ARView else { return }
            let location = gesture.location(in: arView)
            
            // Raycast to find position on mesh
            let results = arView.raycast(
                from: location,
                allowing: .estimatedPlane,
                alignment: .horizontal
            )
            
            guard let result = results.first else { return }
            let position = result.worldTransform.columns.3
            let worldPos = SIMD3<Float>(position.x, position.y, position.z)
            
            Task { @MainActor in
                switch appState.interactionMode {
                case .placeHole:
                    session.placeHole(at: worldPos)
                    appState.holePlaced(at: worldPos)
                    
                case .placeBall:
                    session.placeBall(at: worldPos)
                    appState.ballPlaced(at: worldPos)
                    
                case .ready:
                    // Tap to reposition ball
                    session.placeBall(at: worldPos)
                    appState.ballPlaced(at: worldPos)
                    
                default:
                    break
                }
            }
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return }
            Task { @MainActor in
                session.clearEntities()
                appState.resetPutt()
            }
        }
    }
}

// MARK: - Camera View
struct CameraView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var session = ARViewSession()
    
    var body: some View {
        ZStack {
            // AR Camera Feed
            ARViewContainer(session: session)
                .environmentObject(appState)
                .ignoresSafeArea()
            
            // ---- HUD Overlays ----
            
            // Top: Mode indicator
            VStack {
                ModeIndicator(text: appState.modeText)
                    .padding(.top, 60)
                
                // Slope HUD
                if appState.greenDetected {
                    SlopeHUD(
                        degrees: appState.slopeDegrees,
                        percent: appState.slopePercent,
                        direction: appState.slopeDirection
                    )
                    .padding(.top, 8)
                }
                
                Spacer()
                
                // Distance display
                if let _ = appState.ballPosition, let _ = appState.holePosition {
                    DistanceDisplay(
                        distance: appState.puttDistance,
                        useMetric: appState.settings.useMetric
                    )
                }
                
                // Scan badge
                ScanBadge(
                    isDetected: appState.greenDetected,
                    text: appState.greenDetected ? "Green detekterad ✓" : "Scanning..."
                )
                .padding(.bottom, 8)
                
                // Roll button
                if appState.interactionMode == .ready {
                    Button(action: {
                        appState.startRolling()
                        session.startBallRoll(stimpmeter: Float(appState.settings.stimpmeter))
                    }) {
                        Text("Rulla boll")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 48)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color("Primary"), Color("PrimaryLight")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: Color("Primary").opacity(0.3), radius: 20)
                    }
                }
                
                // Reset button
                if appState.interactionMode == .ready ||
                   appState.interactionMode == .result {
                    Button(action: {
                        session.clearEntities()
                        appState.resetPutt()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Återställ")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                }
                
                Spacer().frame(height: 50)
            }
            
            // Top-right: Settings button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { appState.openSettings() }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundColor(Color("TextSecondary"))
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 54)
                .padding(.trailing, 20)
                
                Spacer()
            }
            
            // Results panel (slide-up)
            if appState.showResultsPanel, let result = appState.puttResult {
                ResultsPanel(
                    result: result,
                    stimp: appState.settings.stimpmeter,
                    useMetric: appState.settings.useMetric,
                    breakInCm: appState.settings.breakInCm,
                    onRollAgain: {
                        appState.showResultsPanel = false
                        appState.interactionMode = .ready
                    },
                    onNewScan: {
                        session.clearEntities()
                        appState.resetPutt()
                    }
                )
            }
        }
        .onAppear {
            session.onGreenDetected = { [weak appState] in
                appState?.greenWasDetected()
            }
            session.onBallStopped = { [weak appState] rollResult in
                let result = PuttResult(
                    distance: Double(rollResult.totalDistance),
                    breakAmount: Double(rollResult.maxBreak),
                    breakDirection: rollResult.breakDirection.rawValue,
                    slopePercent: Double(rollResult.avgSlopeAlongPath),
                    slopeType: rollResult.elevationChange > 0.01 ? "Uppförsbacke" :
                               rollResult.elevationChange < -0.01 ? "Nedförsbacke" : "Plant",
                    speedRecommendation: Self.speedRecommendation(for: rollResult),
                    speedPercent: Self.speedPercent(for: rollResult)
                )
                appState?.rollComplete(result: result)
            }
        }
    }
    
    // MARK: - Speed Helpers
    static func speedRecommendation(for result: BallRollResult) -> String {
        let grade = abs(result.elevationChange / max(0.1, result.totalDistance)) * 100
        if result.elevationChange > 0.01 {
            return grade > 3 ? "Hårt — \(Int(grade))% uppförsbacke" :
                              "Normalt-Hårt — \(Int(grade))% uppför"
        } else if result.elevationChange < -0.01 {
            return grade > 3 ? "Mjukt — \(Int(grade))% nedförsbacke" :
                              "Mjukt-Normalt — \(Int(grade))% nedför"
        }
        return "Normalt slag"
    }
    
    static func speedPercent(for result: BallRollResult) -> Double {
        let grade = abs(result.elevationChange / max(0.1, result.totalDistance)) * 100
        var percent = 50.0
        if result.elevationChange > 0.01 {
            percent = Double(50 + grade * 5)
        } else if result.elevationChange < -0.01 {
            percent = Double(50 - grade * 5)
        }
        return max(5, min(95, percent))
    }
}

// MARK: - HUD Components

struct ModeIndicator: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Color("TextPrimary"))
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }
}

struct SlopeHUD: View {
    let degrees: Double
    let percent: Double
    let direction: String
    
    var degreesColor: Color {
        if degrees < 0.8 { return Color("Flat") }
        if degrees < 2.5 { return Color("BreakLine") }
        return Color("Uphill")
    }
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("LUTNING").font(.system(size: 10, weight: .medium)).foregroundColor(Color("TextDim"))
                Text(String(format: "%.1f°", degrees))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(degreesColor)
                    .monospacedDigit()
            }
            
            Divider().frame(height: 32)
            
            VStack(spacing: 2) {
                Text("GRADIENT").font(.system(size: 10, weight: .medium)).foregroundColor(Color("TextDim"))
                Text(String(format: "%.1f%%", percent))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color("TextPrimary"))
                    .monospacedDigit()
            }
            
            Divider().frame(height: 32)
            
            VStack(spacing: 2) {
                Text("RIKTNING").font(.system(size: 10, weight: .medium)).foregroundColor(Color("TextDim"))
                Text(direction)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color("TextPrimary"))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct ScanBadge: View {
    let isDetected: Bool
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color("PrimaryLight"))
                .frame(width: 8, height: 8)
                .shadow(color: isDetected ? Color("Primary").opacity(0.5) : .clear, radius: 4)
            
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isDetected ? Color("PrimaryLight") : Color("TextSecondary"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

struct DistanceDisplay: View {
    let distance: Double
    let useMetric: Bool
    
    var body: some View {
        Text(useMetric ?
             String(format: "%.1f m", distance) :
             String(format: "%.1f yd", distance * 1.0936))
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(Color("BreakLine"))
            .monospacedDigit()
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color("BreakLine").opacity(0.5), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

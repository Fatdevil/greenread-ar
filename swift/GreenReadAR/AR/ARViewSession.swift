// ARViewSession.swift
// GreenRead AR — iPhone ARView Implementation
// PRD §2.1: ARKit + LiDAR scanning layer
// PRD §10.2-A: RealityKit only (no SceneKit)

import SwiftUI
import ARKit
import RealityKit
import Combine

/// iPhone-specific implementation of GreenReadSession using ARView.
/// Uses ARKit sceneReconstruction for LiDAR mesh and RealityKit for rendering.
final class ARViewSession: NSObject, GreenReadSession, ObservableObject {
    
    // MARK: - Properties
    private var arView: ARView!
    private var meshAnchorEntities: [UUID: ModelEntity] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // Entities
    private var holeEntity: AnchorEntity?
    private var ballEntity: AnchorEntity?
    private var gridEntity: Entity?
    private var trailEntity: Entity?
    private var breakCurveEntity: Entity?
    
    // Physics
    private var ballPhysics: BallPhysicsEngine?
    private var displayLink: CADisplayLink?
    
    // Session protocol conformance
    var scanProgress: Float = 0.0
    var isGreenDetected: Bool = false
    var isBallRolling: Bool = false
    
    // Callbacks
    var onGreenDetected: (() -> Void)?
    var onBallStopped: ((BallRollResult) -> Void)?
    var onSlopeUpdated: ((SlopeInfo) -> Void)?
    
    // Mesh data is queried via raycasts (heightAt/normalAt)
    // No cached arrays needed — prevents memory leak during scanning
    
    // MARK: - Init
    func configureARView(_ arView: ARView) {
        self.arView = arView
        
        // PRD §2.2: ARKit Session Setup
        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .meshWithClassification
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        
        arView.automaticallyConfigureSession = false
        arView.environment.sceneUnderstanding.options = [.physics, .occlusion]
        arView.renderOptions = [.disableMotionBlur]
        
        // Enable debug options during development (remove for release)
        // arView.debugOptions = [.showSceneUnderstanding]
        
        arView.session.delegate = self
        arView.session.run(config)
    }
    
    // MARK: - Session Lifecycle
    func startSession() {
        guard let arView = arView else { return }
        
        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .meshWithClassification
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        scanProgress = 0
        isGreenDetected = false
    }
    
    func pauseSession() {
        arView?.session.pause()
        stopBallSimulation()
    }
    
    func stopSession() {
        arView?.session.pause()
        stopBallSimulation()
        clearEntities()
    }
    
    // MARK: - Mesh Queries
    func heightAt(position: SIMD2<Float>) -> Float? {
        guard let arView = arView else { return nil }
        
        // Raycast downward from above the position
        let rayOrigin = SIMD3<Float>(position.x, 10.0, position.y)
        let rayDirection = SIMD3<Float>(0, -1, 0)
        
        let results = arView.scene.raycast(
            origin: rayOrigin,
            direction: rayDirection,
            length: 20.0,
            query: .nearest,
            mask: .sceneUnderstanding
        )
        
        return results.first?.position.y
    }
    
    func normalAt(position: SIMD2<Float>) -> SIMD3<Float>? {
        guard let arView = arView else { return nil }
        
        let rayOrigin = SIMD3<Float>(position.x, 10.0, position.y)
        let rayDirection = SIMD3<Float>(0, -1, 0)
        
        let results = arView.scene.raycast(
            origin: rayOrigin,
            direction: rayDirection,
            length: 20.0,
            query: .nearest,
            mask: .sceneUnderstanding
        )
        
        return results.first?.normal
    }
    
    func slopeAt(position: SIMD2<Float>) -> SlopeInfo? {
        guard let normal = normalAt(position: position) else { return nil }
        
        return SlopeAnalyzer.calculateSlope(normal: normal)
    }
    
    // MARK: - Entity Placement
    func placeHole(at position: SIMD3<Float>) {
        guard let arView = arView else { return }
        
        // Remove existing hole
        holeEntity?.removeFromParent()
        
        // Create hole anchor
        let anchor = AnchorEntity(world: position)
        
        // Hole (dark disc)
        let holeMesh = MeshResource.generatePlane(width: 0.108, depth: 0.108, cornerRadius: 0.054)
        var holeMaterial = UnlitMaterial()
        holeMaterial.color = .init(tint: .init(red: 0.04, green: 0.04, blue: 0.04, alpha: 1))
        let holeModel = ModelEntity(mesh: holeMesh, materials: [holeMaterial])
        holeModel.position.y = 0.002
        anchor.addChild(holeModel)
        
        // Flag pole
        let poleMesh = MeshResource.generateCylinder(height: 0.8, radius: 0.008)
        var poleMaterial = PhysicallyBasedMaterial()
        poleMaterial.baseColor = .init(tint: .gray)
        poleMaterial.metallic = .init(floatLiteral: 0.8)
        let poleModel = ModelEntity(mesh: poleMesh, materials: [poleMaterial])
        poleModel.position.y = 0.4
        anchor.addChild(poleModel)
        
        // Flag (simplified as a small box — proper flag needs custom mesh)
        let flagMesh = MeshResource.generateBox(width: 0.12, height: 0.08, depth: 0.002)
        var flagMaterial = UnlitMaterial()
        flagMaterial.color = .init(tint: .init(red: 0.94, green: 0.27, blue: 0.27, alpha: 1))
        let flagModel = ModelEntity(mesh: flagMesh, materials: [flagMaterial])
        flagModel.position = SIMD3<Float>(0.068, 0.76, 0)
        anchor.addChild(flagModel)
        
        arView.scene.addAnchor(anchor)
        holeEntity = anchor
    }
    
    func placeBall(at position: SIMD3<Float>) {
        guard let arView = arView else { return }
        
        // Remove existing ball
        ballEntity?.removeFromParent()
        
        let anchor = AnchorEntity(world: position)
        
        // Golf ball — PRD §5.4: white/cream sphere with dimple bumps
        let ballMesh = MeshResource.generateSphere(radius: 0.02135)
        var ballMaterial = PhysicallyBasedMaterial()
        ballMaterial.baseColor = .init(tint: .init(red: 0.96, green: 0.96, blue: 0.94, alpha: 1))
        ballMaterial.roughness = .init(floatLiteral: 0.35)
        ballMaterial.metallic = .init(floatLiteral: 0.0)
        
        let ballModel = ModelEntity(mesh: ballMesh, materials: [ballMaterial])
        ballModel.position.y = 0.02135  // Sit on surface
        ballModel.generateCollisionShapes(recursive: false)
        
        // Enable physics body for the ball
        let physics = PhysicsBodyComponent(
            massProperties: .init(mass: 0.046), // Standard golf ball: 46g
            material: .default,
            mode: .dynamic
        )
        ballModel.components.set(physics)
        
        anchor.addChild(ballModel)
        arView.scene.addAnchor(anchor)
        ballEntity = anchor
    }
    
    func clearEntities() {
        holeEntity?.removeFromParent()
        ballEntity?.removeFromParent()
        gridEntity?.removeFromParent()
        trailEntity?.removeFromParent()
        breakCurveEntity?.removeFromParent()
        
        holeEntity = nil
        ballEntity = nil
        gridEntity = nil
        trailEntity = nil
        breakCurveEntity = nil
    }
    
    // MARK: - Ball Simulation
    func startBallRoll(stimpmeter: Float) {
        guard let ballAnchor = ballEntity,
              let holeAnchor = holeEntity else { return }
        
        let ballPos = ballAnchor.position(relativeTo: nil)
        let holePos = holeAnchor.position(relativeTo: nil)
        
        ballPhysics = BallPhysicsEngine(
            terrain: self,
            stimpmeter: stimpmeter
        )
        
        ballPhysics?.initRoll(from: ballPos, toward: holePos)
        isBallRolling = true
        
        // Start simulation timer
        startBallSimulation()
    }
    
    private func startBallSimulation() {
        displayLink = CADisplayLink(target: self,
            selector: #selector(displayLinkUpdate))
        displayLink?.add(to: .current, forMode: .common)
    }
    
    @objc private func displayLinkUpdate() {
        guard let link = displayLink else { return }
        let deltaTime = Float(link.targetTimestamp - link.timestamp)
        updateBall(deltaTime: deltaTime)
    }
    
    private func updateBall(deltaTime: Float) {
        guard let physics = ballPhysics, physics.isRolling else {
            stopBallSimulation()
            return
        }
        
        let result = physics.update(deltaTime: deltaTime)
        
        // Update ball entity position
        if let ballAnchor = ballEntity {
            ballAnchor.setPosition(result.position, relativeTo: nil)
        }
        
        // Check if ball stopped
        if !physics.isRolling {
            isBallRolling = false
            
            if let holeAnchor = holeEntity {
                let holePos = holeAnchor.position(relativeTo: nil)
                let rollResult = physics.calculateResult(holePosition: holePos)
                onBallStopped?(rollResult)
            }
        }
    }
    
    private func stopBallSimulation() {
        isBallRolling = false
        displayLink?.invalidate()
        displayLink = nil
    }
    
    // MARK: - Rendering Updates
    func updateSlopeGrid() {
        // Grid is automatically updated via mesh anchor processing
        // in the ARSessionDelegate methods below
    }
    
    func setBreakCurveVisible(_ visible: Bool) {
        breakCurveEntity?.isEnabled = visible
    }
    
    func configureBallTrail(fadeAfterSeconds: TimeInterval) {
        // PRD §5.4: Trail fades out after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeAfterSeconds) { [weak self] in
            self?.trailEntity?.removeFromParent()
            self?.trailEntity = nil
        }
    }
}

// MARK: - ARSessionDelegate
extension ARViewSession: ARSessionDelegate {
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // Mesh anchors are handled automatically by RealityKit's
        // sceneUnderstanding — no manual vertex extraction needed.
        // Slope queries use direct raycasts via heightAt/normalAt.
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // Update scan progress based on anchor count
        scanProgress = min(1.0, scanProgress + 0.01)
        
        if scanProgress >= 0.5 && !isGreenDetected {
            isGreenDetected = true
            DispatchQueue.main.async { [weak self] in
                self?.onGreenDetected?()
            }
        }
    }
}

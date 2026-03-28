// BallRollRenderer.swift
// GreenRead AR — Visual Trail & Break Curve Rendering
// PRD §5.4: Trail rendering, break curve visualization
// PRD §10.2-A: RealityKit only (no SceneKit)

import RealityKit
import simd
import Foundation

/// Renders the ball trail and break curve as RealityKit entities.
///
/// Trail: solid yellow line (#FACC15, 70% opacity) following the ball's actual path.
/// Break curve: CatmullRom-interpolated dashed yellow line showing predicted trajectory.
///
/// Both use MeshResource + UnlitMaterial for maximum performance on LiDAR mesh overlay.
/// Platform-agnostic: works identically on ARView (iPhone) and ImmersiveSpace (visionOS).
struct BallRollRenderer {
    
    // MARK: - Constants
    
    /// PRD §5.2: Break line color — #FACC15
    private static let trailColor = UIColor(
        red: 0.980, green: 0.800, blue: 0.082, alpha: 0.70
    )
    
    /// Trail line thickness in meters
    private static let trailWidth: Float = 0.004
    
    /// Break curve line thickness
    private static let breakCurveWidth: Float = 0.003
    
    /// Dash length for break curve (meters)
    private static let dashLength: Float = 0.02
    
    /// Gap length for break curve dashes (meters)
    private static let gapLength: Float = 0.01
    
    /// Minimum distance between trail segment vertices (performance)
    private static let minSegmentLength: Float = 0.005
    
    // MARK: - Trail Creation
    
    /// Creates a visual trail entity from recorded ball positions.
    /// PRD §5.4: Yellow trail (#FACC15) at 70% opacity following ball path.
    ///
    /// - Parameter points: Array of world-space positions from BallPhysicsEngine.trail
    /// - Returns: Entity containing the trail mesh, ready to add to scene
    static func createTrail(from points: [SIMD3<Float>]) -> Entity {
        guard points.count >= 2 else { return Entity() }
        
        // Filter points to enforce minimum segment length
        var filteredPoints = [points[0]]
        for i in 1..<points.count {
            let dist = length(points[i] - filteredPoints.last!)
            if dist >= minSegmentLength {
                filteredPoints.append(points[i])
            }
        }
        
        guard filteredPoints.count >= 2 else { return Entity() }
        
        let trailEntity = Entity()
        trailEntity.name = "ballTrail"
        
        // Build trail as a series of thin box segments connecting each pair of points
        for i in 0..<(filteredPoints.count - 1) {
            let start = filteredPoints[i]
            let end = filteredPoints[i + 1]
            let segment = createSegment(from: start, to: end, width: trailWidth, color: trailColor)
            trailEntity.addChild(segment)
        }
        
        return trailEntity
    }
    
    // MARK: - Break Curve
    
    /// Creates a CatmullRom-interpolated dashed break curve from ball to hole.
    /// PRD §5.4: Shows predicted trajectory with smooth curvature.
    ///
    /// - Parameter points: Control points for the curve (minimum 3 for meaningful interpolation)
    /// - Returns: Entity containing the dashed curve mesh
    static func createBreakCurve(from points: [SIMD3<Float>]) -> Entity {
        guard points.count >= 2 else { return Entity() }
        
        // Interpolate using Catmull-Rom spline
        let interpolated = catmullRomInterpolate(points: points, segmentsPerSpan: 10)
        
        let curveEntity = Entity()
        curveEntity.name = "breakCurve"
        
        // Create dashed pattern
        var accumulatedLength: Float = 0
        var isDash = true
        var dashStart: SIMD3<Float> = interpolated[0]
        
        for i in 1..<interpolated.count {
            let segLength = length(interpolated[i] - interpolated[i - 1])
            accumulatedLength += segLength
            
            let threshold = isDash ? dashLength : gapLength
            
            if accumulatedLength >= threshold {
                if isDash {
                    // Create a dash segment
                    let segment = createSegment(
                        from: dashStart,
                        to: interpolated[i],
                        width: breakCurveWidth,
                        color: trailColor
                    )
                    curveEntity.addChild(segment)
                }
                
                accumulatedLength = 0
                isDash.toggle()
                dashStart = interpolated[i]
            }
        }
        
        // Final dash if we ended mid-dash
        if isDash && accumulatedLength > minSegmentLength {
            let segment = createSegment(
                from: dashStart,
                to: interpolated.last!,
                width: breakCurveWidth,
                color: trailColor
            )
            curveEntity.addChild(segment)
        }
        
        return curveEntity
    }
    
    // MARK: - Trail Fade
    
    /// Fades out and removes a trail entity after the specified duration.
    /// PRD §5.4: Trail fades out after 3 seconds.
    ///
    /// - Parameters:
    ///   - entity: The trail entity to fade
    ///   - seconds: Duration before fade begins (default: 3.0)
    static func fadeTrail(entity: Entity, after seconds: TimeInterval = 3.0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            // Animate opacity reduction over 1 second
            let fadeSteps = 20
            let stepInterval = 1.0 / Double(fadeSteps)
            
            for step in 0...fadeSteps {
                DispatchQueue.main.asyncAfter(deadline: .now() + stepInterval * Double(step)) {
                    let alpha = Float(1.0 - Double(step) / Double(fadeSteps))
                    
                    // Update material opacity on all child segments
                    for child in entity.children {
                        guard let model = child as? ModelEntity else { continue }
                        var material = UnlitMaterial()
                        material.color = .init(tint: trailColor.withAlphaComponent(CGFloat(alpha * 0.7)))
                        material.blending = .transparent(opacity: .init(floatLiteral: alpha * 0.7))
                        model.model?.materials = [material]
                    }
                    
                    // Remove entity after last step
                    if step == fadeSteps {
                        entity.removeFromParent()
                    }
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    /// Creates a single line segment between two 3D points using a thin box mesh.
    private static func createSegment(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        width: Float,
        color: UIColor
    ) -> ModelEntity {
        let direction = end - start
        let segmentLength = length(direction)
        
        guard segmentLength > 0.001 else {
            return ModelEntity()
        }
        
        // Create thin box representing the segment
        let mesh = MeshResource.generateBox(
            width: width,
            height: 0.001,      // Very thin vertically
            depth: segmentLength // Length along z-axis
        )
        
        var material = UnlitMaterial()
        material.color = .init(tint: color)
        material.blending = .transparent(opacity: .init(floatLiteral: 0.7))
        
        let entity = ModelEntity(mesh: mesh, materials: [material])
        
        // Position at midpoint
        let midpoint = (start + end) / 2
        entity.position = midpoint
        
        // Slightly above terrain to prevent z-fighting
        entity.position.y += 0.002
        
        // Rotate to align with segment direction
        let forward = normalize(direction)
        let up = SIMD3<Float>(0, 1, 0)
        let right = normalize(cross(up, forward))
        let correctedUp = cross(forward, right)
        
        let rotationMatrix = simd_float3x3(columns: (right, correctedUp, forward))
        entity.orientation = simd_quatf(rotationMatrix)
        
        return entity
    }
    
    /// Catmull-Rom spline interpolation for smooth break curves.
    /// Produces segmentsPerSpan intermediate points between each pair of control points.
    private static func catmullRomInterpolate(
        points: [SIMD3<Float>],
        segmentsPerSpan: Int = 10
    ) -> [SIMD3<Float>] {
        guard points.count >= 2 else { return points }
        
        var result: [SIMD3<Float>] = []
        
        for i in 0..<(points.count - 1) {
            let p0 = points[max(0, i - 1)]
            let p1 = points[i]
            let p2 = points[min(points.count - 1, i + 1)]
            let p3 = points[min(points.count - 1, i + 2)]
            
            for j in 0..<segmentsPerSpan {
                let t = Float(j) / Float(segmentsPerSpan)
                let t2 = t * t
                let t3 = t2 * t
                
                // Catmull-Rom basis functions
                let point = 0.5 * (
                    (2 * p1) +
                    (-p0 + p2) * t +
                    (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
                    (-p0 + 3 * p1 - 3 * p2 + p3) * t3
                )
                
                result.append(point)
            }
        }
        
        // Add final point
        result.append(points.last!)
        
        return result
    }
}

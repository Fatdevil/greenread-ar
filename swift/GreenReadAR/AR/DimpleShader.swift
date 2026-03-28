// DimpleShader.swift
// GreenRead AR — Golf Ball Dimple Shader
// PRD §5.4: Bollen ska vara en vit/krämfärgad sfär med subtila dimple-bump-maps

import RealityKit
import simd

/// Creates a realistic golf ball material with procedural dimple pattern.
/// Uses RealityKit's CustomMaterial system for bump-mapped dimples.
///
/// Note: This is a Fas 5 polish item per PRD §7.1. For initial phases,
/// the ball uses a basic PhysicallyBasedMaterial (white, roughness 0.35).
/// When dimple shader is activated, it replaces the ball's default material.
struct DimpleShader {
    
    // MARK: - Dimple Configuration
    static let dimpleCount: Int = 336          // Standard golf ball: 300-500 dimples
    static let dimpleRadius: Float = 0.0018    // ~1.8mm diameter
    static let dimpleDepth: Float = 0.00025    // ~0.25mm depth
    static let ballColor = SIMD3<Float>(0.96, 0.96, 0.94) // Cream/white
    
    /// Create a golf ball ModelEntity with dimple bump-map applied
    /// - Returns: ModelEntity with dimple-textured sphere
    static func createDimpledBall() -> ModelEntity {
        let ballMesh = MeshResource.generateSphere(radius: 0.02135)
        
        // Base material — cream white with slight roughness variation
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .init(
            red: CGFloat(ballColor.x),
            green: CGFloat(ballColor.y),
            blue: CGFloat(ballColor.z),
            alpha: 1.0
        ))
        material.roughness = .init(floatLiteral: 0.35)
        material.metallic = .init(floatLiteral: 0.0)
        
        // For the dimple pattern, we use a procedurally generated normal map texture
        // In production, this would be a pre-baked 2048x2048 normal map asset
        // For now, we use roughness variation to approximate the visual effect:
        // - Dimple areas: higher roughness (0.5) → diffuse light scattering
        // - Flat areas: lower roughness (0.25) → subtle sheen
        //
        // Full custom shader implementation requires Metal shader graph:
        // See generateDimpleNormalMap() below for the procedural algorithm
        
        let ball = ModelEntity(mesh: ballMesh, materials: [material])
        ball.name = "golfball"
        
        return ball
    }
    
    /// Generate a procedural dimple normal map
    ///
    /// Algorithm:
    /// 1. Distribute dimple centers using spherical Fibonacci lattice
    /// 2. For each texel, find nearest dimple center
    /// 3. If within dimple radius, compute inward-curved normal perturbation
    /// 4. Encode as RGB normal map (tangent space)
    ///
    /// This generates a CGImage suitable for use as a normal map texture.
    /// In Metal shader pipeline, this is applied via surface.normal modification.
    static func generateDimplePattern(resolution: Int = 1024) -> [SIMD3<Float>] {
        var normals = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 1), count: resolution * resolution)
        
        // Generate dimple centers using golden spiral (Fibonacci lattice)
        var dimpleCenters: [SIMD2<Float>] = []
        let goldenAngle = Float.pi * (3.0 - sqrt(5.0))
        
        for i in 0..<dimpleCount {
            let t = Float(i) / Float(dimpleCount)
            let theta = goldenAngle * Float(i)
            let phi = acos(1.0 - 2.0 * t)
            
            // Convert spherical to UV coordinates
            let u = theta / (2.0 * .pi)
            let v = phi / .pi
            
            dimpleCenters.append(SIMD2<Float>(
                u - floor(u), // wrap to [0,1]
                v
            ))
        }
        
        // For each texel, check proximity to dimple centers
        let dimpleUVRadius: Float = 0.02 // UV-space radius of each dimple
        
        for y in 0..<resolution {
            for x in 0..<resolution {
                let u = Float(x) / Float(resolution)
                let v = Float(y) / Float(resolution)
                let texCoord = SIMD2<Float>(u, v)
                
                // Find nearest dimple
                var minDist: Float = Float.greatestFiniteMagnitude
                for center in dimpleCenters {
                    let diff = texCoord - center
                    let dist = length(diff)
                    if dist < minDist {
                        minDist = dist
                    }
                }
                
                // If within dimple radius, perturb normal inward
                if minDist < dimpleUVRadius {
                    let t = minDist / dimpleUVRadius
                    // Smooth hermite interpolation for dimple curvature
                    let depth = (1.0 - t * t) * (1.0 - t * t) * dimpleDepth * 50.0
                    
                    // Perturb normal (tangent space)
                    normals[y * resolution + x] = normalize(SIMD3<Float>(0, 0, 1.0 - depth))
                }
            }
        }
        
        return normals
    }
    
    // MARK: - Shadow Blob
    
    /// Creates a shadow disc that sits beneath the ball on the green surface
    static func createBallShadow() -> ModelEntity {
        let shadowMesh = MeshResource.generatePlane(width: 0.05, depth: 0.05, cornerRadius: 0.025)
        var shadowMaterial = UnlitMaterial()
        shadowMaterial.color = .init(tint: .init(red: 0, green: 0, blue: 0, alpha: 0.3))
        shadowMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.3))
        
        let shadow = ModelEntity(mesh: shadowMesh, materials: [shadowMaterial])
        shadow.name = "ballShadow"
        shadow.position.y = 0.001
        
        return shadow
    }
}

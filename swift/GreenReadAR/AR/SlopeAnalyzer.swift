// SlopeAnalyzer.swift
// GreenRead AR — Slope Calculation Engine
// PRD §2.2: normalvektor → lutningsberäkning

import simd
import Foundation

/// Analyzes surface normals to compute slope angle, direction, and grade.
/// Used by both ARViewSession (iPhone) and future VisionProSession.
struct SlopeAnalyzer {
    
    /// PRD §2.2 Formula:
    /// slopeAngle = acos(dot(normal, upVector))
    /// slopeDirection = atan2(normal.x, normal.z)
    /// fallLine = normalize(SIMD3(normal.x, 0, normal.z))
    static func calculateSlope(normal: SIMD3<Float>) -> SlopeInfo {
        let upVector = SIMD3<Float>(0, 1, 0)
        
        // Slope angle from horizontal
        let dotProduct = min(1.0, max(-1.0, dot(normal, upVector)))
        let slopeAngle = acos(dotProduct)  // radians
        let slopeDegrees = slopeAngle * (180.0 / .pi)
        let slopePercent = tan(slopeAngle) * 100.0
        
        // Fall line direction (horizontal component of normal)
        let fallLine: SIMD3<Float>
        let horizontalLength = sqrt(normal.x * normal.x + normal.z * normal.z)
        if horizontalLength > 0.001 {
            fallLine = normalize(SIMD3<Float>(normal.x, 0, normal.z))
        } else {
            fallLine = SIMD3<Float>(0, 0, 0)
        }
        
        // Compass direction from fall line
        let direction = compassDirection(from: fallLine, slopeDegrees: slopeDegrees)
        
        return SlopeInfo(
            degrees: slopeDegrees,
            percent: slopePercent,
            direction: direction,
            fallLine: fallLine,
            normal: normal
        )
    }
    
    /// Convert fall direction vector to compass string
    private static func compassDirection(from fallDir: SIMD3<Float>, slopeDegrees: Float) -> String {
        guard slopeDegrees > 0.3 else { return "—" }
        
        let angle = atan2(fallDir.x, fallDir.z) * (180.0 / .pi)
        
        switch angle {
        case -22.5...22.5:     return "↑ N"
        case 22.5...67.5:      return "↗ NE"
        case 67.5...112.5:     return "→ E"
        case 112.5...157.5:    return "↘ SE"
        case -67.5...(-22.5):  return "↖ NW"
        case -112.5...(-67.5): return "← W"
        case -157.5...(-112.5):return "↙ SW"
        default:               return "↓ S"
        }
    }
    
    // MARK: - Grid Color Mapping
    
    /// PRD §5.3: Map slope to grid cell color
    /// Flat (0-1°): green
    /// Moderate (1-3°): gradient yellow→orange
    /// Steep (3°+): red (uphill) or blue (downhill)
    static func slopeColor(for info: SlopeInfo) -> (r: Float, g: Float, b: Float) {
        let d = info.degrees
        
        if d < 0.8 {
            // Flat — green (#22C55E → r:0.133, g:0.773, b:0.369)
            return (0.133, 0.773, 0.369)
        } else if d < 3.0 {
            let t = (d - 0.8) / 2.2
            if info.fallLine.z > 0.1 {
                // Transitioning to blue (downhill)
                return (
                    0.133 + t * (0.231 - 0.133),
                    0.773 + t * (0.510 - 0.773),
                    0.369 + t * (0.965 - 0.369)
                )
            } else {
                // Transitioning to red (uphill)
                return (
                    0.133 + t * (0.937 - 0.133),
                    0.773 + t * (0.267 - 0.773),
                    0.369 + t * (0.267 - 0.369)
                )
            }
        } else {
            if info.fallLine.z > 0.1 {
                // Steep downhill — blue (#3B82F6)
                return (0.231, 0.510, 0.965)
            } else {
                // Steep uphill — red (#EF4444)
                return (0.937, 0.267, 0.267)
            }
        }
    }
    
    // MARK: - Break Calculation
    
    /// Calculate total break between two positions along a trail
    static func calculateBreak(
        trail: [SIMD3<Float>],
        startPosition: SIMD3<Float>,
        holePosition: SIMD3<Float>
    ) -> (amount: Float, direction: BallRollResult.BreakDirection) {
        let lineDir = normalize(holePosition - startPosition)
        var maxLateral: Float = 0
        var maxCross: Float = 0
        
        for point in trail {
            let toPoint = point - startPosition
            let projection = lineDir * dot(toPoint, lineDir)
            let lateral = toPoint - projection
            let lateralDist = length(lateral)
            
            if lateralDist > abs(maxLateral) {
                let crossProduct = cross(
                    SIMD3<Float>(lineDir.x, 0, lineDir.z),
                    SIMD3<Float>(lateral.x, 0, lateral.z)
                )
                maxLateral = lateralDist
                maxCross = crossProduct.y
            }
        }
        
        let breakCm = maxLateral * 100 // meters to cm
        
        if breakCm < 0.5 {
            return (breakCm, .straight)
        } else if maxCross > 0 {
            return (breakCm, .left)
        } else {
            return (breakCm, .right)
        }
    }
}

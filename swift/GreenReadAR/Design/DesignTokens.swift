// DesignTokens.swift
// GreenRead AR — Design System Tokens
// PRD §5.2: Complete color palette + typography

import SwiftUI

extension Color {
    // PRD §5.2 Color Palette
    static let backgroundDeep = Color("BackgroundDeep")       // #0D1F14
    static let backgroundSurface = Color("BackgroundSurface") // #122A1A
    static let backgroundCard = Color("BackgroundCard")       // #183322
    static let primary = Color("Primary")                     // #1A7A4A
    static let primaryLight = Color("PrimaryLight")           // #22A55E
    static let downhill = Color("Downhill")                   // #3B82F6
    static let uphill = Color("Uphill")                       // #EF4444
    static let flat = Color("Flat")                           // #22C55E
    static let ball = Color("Ball")                           // #FFFFFF
    static let breakLine = Color("BreakLine")                 // #FACC15
    static let textPrimary = Color("TextPrimary")             // #F0FDF4
    static let textSecondary = Color("TextSecondary")         // #A7C4B8
    static let textDim = Color("TextDim")                     // #5A7D6C
    static let border = Color("Border")                       // rgba(26,122,74,0.2)
}

// Convenience extensions for hex colors used in RealityKit materials
extension UIColor {
    static let grdBackgroundDeep = UIColor(red: 0.051, green: 0.122, blue: 0.078, alpha: 1)
    static let grdPrimary = UIColor(red: 0.102, green: 0.478, blue: 0.290, alpha: 1)
    static let grdDownhill = UIColor(red: 0.231, green: 0.510, blue: 0.965, alpha: 1)
    static let grdUphill = UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1)
    static let grdFlat = UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1)
    static let grdBreakLine = UIColor(red: 0.980, green: 0.800, blue: 0.082, alpha: 1)
}

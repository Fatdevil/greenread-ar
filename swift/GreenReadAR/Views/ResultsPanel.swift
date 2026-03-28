// ResultsPanel.swift
// GreenRead AR — Putt Results View
// PRD §4.1 Skärm 3: Slide-up result panel

import SwiftUI

struct ResultsPanel: View {
    let result: PuttResult
    let stimp: Double
    let useMetric: Bool
    let breakInCm: Bool
    let onRollAgain: () -> Void
    let onNewScan: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(Color("TextDim"))
                    .frame(width: 36, height: 4)
                    .opacity(0.5)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                
                // Title
                Text("Putt-analys")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color("TextPrimary"))
                    .padding(.bottom, 20)
                
                // Results grid (2x2)
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    // Distance
                    ResultCard(
                        label: "Avstånd",
                        value: distanceText,
                        valueColor: Color("TextPrimary")
                    )
                    
                    // Break
                    ResultCard(
                        label: "Break",
                        value: breakText,
                        subtitle: result.breakDirection,
                        valueColor: breakColor
                    )
                    
                    // Slope
                    ResultCard(
                        label: "Lutning",
                        value: String(format: "%.1f%%", result.slopePercent),
                        subtitle: result.slopeType,
                        valueColor: Color("TextPrimary")
                    )
                    
                    // Green speed
                    ResultCard(
                        label: "Greenshastighet",
                        value: String(format: "%.1f", stimp),
                        subtitle: "Stimp",
                        valueColor: Color("TextPrimary")
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                
                // Speed recommendation bar
                SpeedRecommendationBar(
                    recommendation: result.speedRecommendation,
                    percent: result.speedPercent
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                
                // Action buttons
                HStack(spacing: 12) {
                    Button(action: onRollAgain) {
                        Text("Rulla igen")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color("TextPrimary"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color("BackgroundCard"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color("Border"), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    Button(action: onNewScan) {
                        Text("Ny scanning")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color("TextPrimary"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color("BackgroundCard"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color("Border"), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
            .background(Color("BackgroundSurface"))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .transition(.move(edge: .bottom))
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: true)
    }
    
    // MARK: - Computed Properties
    private var distanceText: String {
        useMetric ?
            String(format: "%.1f m", result.distance) :
            String(format: "%.1f yd", result.distance * 1.0936)
    }
    
    private var breakText: String {
        breakInCm ?
            String(format: "%.1f cm", result.breakAmount) :
            String(format: "%.1f\"", result.breakAmount * 0.3937)
    }
    
    private var breakColor: Color {
        if result.breakAmount < 2 { return Color("Flat") }
        if result.breakAmount < 8 { return Color("BreakLine") }
        return Color("Uphill")
    }
}

// MARK: - Result Card
struct ResultCard: View {
    let label: String
    let value: String
    var subtitle: String? = nil
    var valueColor: Color = .white
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color("TextDim"))
                .tracking(1)
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(valueColor)
                .monospacedDigit()
            
            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: 12))
                    .foregroundColor(Color("TextSecondary"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color("BackgroundCard"))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color("Border"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Speed Bar
struct SpeedRecommendationBar: View {
    let recommendation: String
    let percent: Double
    
    var body: some View {
        VStack(spacing: 12) {
            Text("SLAGHASTIGHET")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color("TextDim"))
                .tracking(1)
            
            // Bar with marker
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Gradient bar
                    LinearGradient(
                        colors: [
                            Color("Downhill"),
                            Color("Flat"),
                            Color("BreakLine"),
                            Color("Uphill")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 8)
                    .clipShape(Capsule())
                    
                    // Marker
                    Circle()
                        .fill(.white)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(Color("Primary"), lineWidth: 3)
                        )
                        .shadow(color: Color("Primary").opacity(0.3), radius: 6)
                        .offset(x: geo.size.width * CGFloat(percent / 100) - 9)
                        .animation(.spring(response: 0.4), value: percent)
                }
            }
            .frame(height: 18)
            
            // Labels
            HStack {
                Text("Mjukt").font(.system(size: 11)).foregroundColor(Color("TextDim"))
                Spacer()
                Text("Normalt").font(.system(size: 11)).foregroundColor(Color("TextDim"))
                Spacer()
                Text("Hårt").font(.system(size: 11)).foregroundColor(Color("TextDim"))
            }
            
            // Recommendation text
            Text(recommendation)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color("PrimaryLight"))
        }
        .padding(20)
        .background(Color("BackgroundCard"))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color("Border"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

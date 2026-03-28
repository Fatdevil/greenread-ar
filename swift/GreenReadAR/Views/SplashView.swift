// SplashView.swift
// GreenRead AR — Onboarding / Splash Screen
// PRD §4.1 Skärm 1: LiDAR check, camera permission, onboarding

import SwiftUI

struct SplashView: View {
    @EnvironmentObject var appState: AppState
    @State private var animateIcon = false
    @State private var showError = false
    
    var body: some View {
        ZStack {
            // Background with subtle gradients
            Color("BackgroundDeep")
                .ignoresSafeArea()
            
            RadialGradient(
                colors: [Color("Primary").opacity(0.15), .clear],
                center: .topLeading,
                startRadius: 50,
                endRadius: 300
            )
            .ignoresSafeArea()
            
            RadialGradient(
                colors: [Color("Downhill").opacity(0.08), .clear],
                center: .bottomTrailing,
                startRadius: 50,
                endRadius: 250
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // App Icon
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color("Primary"), Color("Downhill")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .fill(Color("Primary"))
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .fill(Color("BreakLine"))
                        .frame(width: 10, height: 10)
                }
                .shadow(color: Color("Primary").opacity(0.3), radius: animateIcon ? 25 : 10)
                .scaleEffect(animateIcon ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: animateIcon)
                .padding(.bottom, 32)
                
                // Title
                HStack(spacing: 4) {
                    Text("GreenRead")
                        .font(.system(size: 42, weight: .heavy))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color("TextPrimary"), Color("PrimaryLight")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("AR")
                        .font(.system(size: 42, weight: .heavy))
                        .foregroundColor(Color("PrimaryLight"))
                }
                .padding(.bottom, 8)
                
                Text("Läs greenen. Se breaken. Sänk putten.")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(Color("TextSecondary"))
                    .tracking(0.5)
                    .padding(.bottom, 48)
                
                // Feature list
                VStack(spacing: 16) {
                    FeatureRow(icon: "📡", text: "LiDAR-scanning av greenens yta")
                    FeatureRow(icon: "🎯", text: "Färgkodat lutningsrutnät i AR")
                    FeatureRow(icon: "⛳", text: "Simulerad bollrullning med break")
                }
                .padding(.bottom, 48)
                
                // CTA Button
                Button(action: {
                    if appState.lidarSupported {
                        appState.startScanning()
                    } else {
                        showError = true
                    }
                }) {
                    HStack(spacing: 10) {
                        Text("Börja scanna")
                            .font(.system(size: 17, weight: .semibold))
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
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
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                }
                .padding(.bottom, 24)
                
                Text("Kräver LiDAR-kompatibel enhet (iPhone 12 Pro+)")
                    .font(.system(size: 12))
                    .foregroundColor(Color("TextDim"))
                
                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .onAppear { animateIcon = true }
        .alert("LiDAR ej tillgänglig", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text("Din iPhone stöder inte LiDAR.\nKrävs: iPhone 12 Pro eller senare.")
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 14) {
            Text(icon)
                .font(.system(size: 20))
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color("TextSecondary"))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color("BackgroundSurface"))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color("Border"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

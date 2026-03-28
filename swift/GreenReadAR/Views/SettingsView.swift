// SettingsView.swift
// GreenRead AR — Settings Screen
// PRD §4.1 Skärm 4: Stimp slider, units, theme, IAP

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var storeManager: StoreManager
    
    var body: some View {
        ZStack {
            Color("BackgroundDeep")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Inställningar")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color("TextPrimary"))
                    
                    Spacer()
                    
                    Button(action: { appState.closeSettings() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color("TextSecondary"))
                            .frame(width: 36, height: 36)
                            .background(Color("BackgroundSurface"))
                            .overlay(
                                Circle().stroke(Color("Border"), lineWidth: 1)
                            )
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 20)
                
                Divider()
                    .background(Color("Border"))
                
                // Settings list
                ScrollView {
                    VStack(spacing: 28) {
                        
                        // ---- Greenshastighet ----
                        SettingGroup(label: "Greenshastighet (Stimpmeter)") {
                            HStack(spacing: 16) {
                                Slider(
                                    value: $appState.settings.stimpmeter,
                                    in: 7...13,
                                    step: 0.5
                                )
                                .tint(Color("Primary"))
                                
                                Text(String(format: "%.1f", appState.settings.stimpmeter))
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(Color("PrimaryLight"))
                                    .monospacedDigit()
                                    .frame(minWidth: 42)
                            }
                            
                            HStack {
                                Text("7 — Långsam")
                                Spacer()
                                Text("10 — Normal")
                                Spacer()
                                Text("13 — Snabb")
                            }
                            .font(.system(size: 11))
                            .foregroundColor(Color("TextDim"))
                        }
                        
                        // ---- Måttenhet ----
                        SettingGroup(label: "Måttenhet") {
                            HStack(spacing: 8) {
                                ToggleButton(
                                    title: "Meter",
                                    isSelected: appState.settings.useMetric
                                ) { appState.settings.useMetric = true }
                                
                                ToggleButton(
                                    title: "Yard",
                                    isSelected: !appState.settings.useMetric
                                ) { appState.settings.useMetric = false }
                            }
                        }
                        
                        // ---- Break-visning ----
                        SettingGroup(label: "Break-visning") {
                            HStack(spacing: 8) {
                                ToggleButton(
                                    title: "Centimeter",
                                    isSelected: appState.settings.breakInCm
                                ) { appState.settings.breakInCm = true }
                                
                                ToggleButton(
                                    title: "Tum",
                                    isSelected: !appState.settings.breakInCm
                                ) { appState.settings.breakInCm = false }
                            }
                        }
                        
                        // ---- Antal bollar (Premium) ----
                        SettingGroup(label: "Antal bollar", badge: "PREMIUM") {
                            HStack(spacing: 8) {
                                ForEach([1, 3, 5], id: \.self) { count in
                                    ToggleButton(
                                        title: "\(count)",
                                        isSelected: appState.settings.numberOfBalls == count
                                    ) {
                                        if appState.isPremium || count == 1 {
                                            appState.settings.numberOfBalls = count
                                        }
                                    }
                                }
                            }
                        }
                        
                        // ---- Premium Upgrade ----
                        if !appState.isPremium {
                            PremiumUpgradeButton(storeManager: storeManager)
                        }
                        
                        // ---- Restore Purchases ----
                        Button(action: {
                            Task {
                                await storeManager.restorePurchases()
                            }
                        }) {
                            Text("Återställ köp")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                        }
                        .padding(.top, 8)
                        
                    }
                    .padding(24)
                }
            }
        }
    }
}

// MARK: - Setting Group
struct SettingGroup<Content: View>: View {
    let label: String
    var badge: String? = nil
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(label.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color("TextSecondary"))
                    .tracking(0.8)
                
                Spacer()
                
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Color("BackgroundDeep"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(
                            LinearGradient(
                                colors: [Color("BreakLine"), .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            
            content()
        }
    }
}

// MARK: - Toggle Button
struct ToggleButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : Color("TextSecondary"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color("Primary") : Color("BackgroundCard"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? Color("PrimaryLight") : Color("Border"),
                            lineWidth: 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: isSelected ? Color("Primary").opacity(0.3) : .clear, radius: 8)
        }
    }
}

// MARK: - Premium Upgrade
struct PremiumUpgradeButton: View {
    @ObservedObject var storeManager: StoreManager
    
    var body: some View {
        Button(action: {
            Task {
                await storeManager.purchasePremium()
            }
        }) {
            HStack(spacing: 14) {
                Text("⭐")
                    .font(.system(size: 24))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Uppgradera till Premium")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color("TextPrimary"))
                    
                    Text("99 kr — Engångsköp")
                        .font(.system(size: 12))
                        .foregroundColor(Color("BreakLine"))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Color("TextSecondary"))
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [
                        Color("BreakLine").opacity(0.1),
                        .orange.opacity(0.05)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color("BreakLine").opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

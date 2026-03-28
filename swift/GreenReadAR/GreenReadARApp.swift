// GreenReadARApp.swift
// GreenRead AR — Main App Entry Point
// 100% SwiftUI, RealityKit-based (PRD §10.2-C)

import SwiftUI

@main
struct GreenReadARApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var storeManager = StoreManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(storeManager)
                .preferredColorScheme(.dark)
        }
    }
}

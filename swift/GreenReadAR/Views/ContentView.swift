// ContentView.swift
// GreenRead AR — Root Navigation
// Manages transitions: Splash → Camera → Results

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            Color("BackgroundDeep")
                .ignoresSafeArea()
            
            switch appState.currentScreen {
            case .splash:
                SplashView()
                    .transition(.opacity)
                
            case .camera:
                CameraView()
                    .transition(.opacity)
                
            case .settings:
                SettingsView()
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.currentScreen)
        .onAppear {
            appState.checkLiDARSupport()
        }
    }
}

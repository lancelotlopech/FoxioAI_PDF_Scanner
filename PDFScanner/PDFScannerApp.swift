//
//  PDFScannerApp.swift
//  PDFScanner
//
//  Created by 陈先生 on 2025/11/25.
//

import SwiftUI
import AppTrackingTransparency

@main
struct PDFScannerApp: App {
    @StateObject private var store = FoxDocumentStore()
    @State private var isAppActive = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isAppActive {
                    MainTabView()
                        .environmentObject(store)
                        .tint(.black)
                        .transition(.opacity)
                        .onAppear {
                            requestTracking()
                        }
                } else {
                    SplashView(isActive: $isAppActive)
                }
            }
            .animation(.easeOut, value: isAppActive)
        }
    }
    
    private func requestTracking() {
        // Delay slightly to ensure the view is loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    print("Tracking authorized")
                case .denied:
                    print("Tracking denied")
                case .notDetermined:
                    print("Tracking not determined")
                case .restricted:
                    print("Tracking restricted")
                @unknown default:
                    break
                }
            }
        }
    }
}

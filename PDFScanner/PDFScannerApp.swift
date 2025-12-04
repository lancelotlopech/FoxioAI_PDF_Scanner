//
//  PDFScannerApp.swift
//  PDFScanner
//
//  Created by 陈先生 on 2025/11/25.
//

import SwiftUI

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
                } else {
                    SplashView(isActive: $isAppActive)
                }
            }
            .animation(.easeOut, value: isAppActive)
        }
    }
}

//
//  PDFScannerApp.swift
//  PDFScanner
//
//  Created by 陈先生 on 2025/11/25.
//

import SwiftUI
import AppTrackingTransparency
import FacebookCore
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Initialize Firebase
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Initialize Facebook SDK
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        Settings.shared.isAutoLogAppEventsEnabled = true
        Settings.shared.isAdvertiserTrackingEnabled = true
        
        // Increment launch count on app start
        RatingManager.shared.incrementLaunchCount()
        
        return true
    }
    
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
            annotation: options[UIApplication.OpenURLOptionsKey.annotation]
        )
    }
}

@main
struct PDFScannerApp: App {
    // Inject AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var store = FoxDocumentStore()
    @State private var isAppActive = false
    @State private var showSubscriptionOnLaunch = false
    
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
                            checkSubscriptionStatus()
                            
                            // Try to show rating on launch (e.g. 3rd launch)
                            // Delay to avoid conflict with subscription sheet
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                RatingManager.shared.tryShowRating()
                            }
                        }
                        .fullScreenCover(isPresented: $showSubscriptionOnLaunch) {
                            SubscriptionView()
                        }
                } else {
                    SplashView(isActive: $isAppActive)
                }
            }
            .animation(.easeOut, value: isAppActive)
            .onOpenURL { url in
                // Handle Facebook Deep Linking (Fallback if AppDelegate doesn't catch it)
                ApplicationDelegate.shared.application(
                    UIApplication.shared,
                    open: url,
                    sourceApplication: nil,
                    annotation: [UIApplication.OpenURLOptionsKey.annotation]
                )
            }
        }
    }
    
    private func checkSubscriptionStatus() {
        // Delay slightly to ensure UI is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Task {
                await SubscriptionManager.shared.updateSubscriptionStatus()
                if !SubscriptionManager.shared.isPremium {
                    showSubscriptionOnLaunch = true
                }
            }
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

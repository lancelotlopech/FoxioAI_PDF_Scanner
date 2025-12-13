import SwiftUI
import StoreKit

struct SettingsView: View {
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @ObservedObject var ratingManager = RatingManager.shared
    @State private var showSubscription = false
    @State private var showFeedback = false
    @State private var showDebugAlert = false
    @Environment(\.requestReview) var requestReview
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    var body: some View {
        ZStack {
            NavigationStack {
                List {
                // VIP Banner Section
                if !subscriptionManager.isPremium {
                    Section {
                        Button {
                            showSubscription = true
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "crown.fill")
                                        .foregroundStyle(.white)
                                        .font(.title2)
                                    Text("Get Premium")
                                        .font(.title3.bold())
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                                Text("Unlock all features")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.9, green: 0.2, blue: 0.4), // Deeper Pink
                                    Color(red: 0.9, green: 0.5, blue: 0.1)  // Deeper Orange
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }
                }
                
                // Support Section
                Section("Support") {
                    Button {
                        showFeedback = true
                    } label: {
                        SettingsRow(icon: "bubble.left.and.bubble.right.fill", color: .blue, title: "Give Feedback")
                    }
                    .foregroundStyle(.primary)
                    
                    Button {
                        ratingManager.showRating()
                    } label: {
                        SettingsRow(icon: "star.fill", color: Color(red: 1.0, green: 0.84, blue: 0.0), title: "Rate Us")
                    }
                    .foregroundStyle(.primary)
                    
                    /*
                    // Placeholder URL for App Store - Hidden for submission until App ID is available
                    ShareLink(item: URL(string: "https://apps.apple.com")!) {
                        SettingsRow(icon: "square.and.arrow.up.fill", color: .green, title: "Share App")
                    }
                    .foregroundStyle(.primary)
                    */
                }
                
                // About Section
                Section("About") {
                    Link(destination: URL(string: "https://privacypolicypdf.moonspace.workers.dev/")!) {
                        SettingsRow(icon: "hand.raised.fill", color: .gray, title: "Privacy Policy")
                    }
                    .foregroundStyle(.primary)
                    
                    Link(destination: URL(string: "https://termsofuspdf.moonspace.workers.dev/")!) {
                        SettingsRow(icon: "doc.text.fill", color: .gray, title: "Terms of Use")
                    }
                    .foregroundStyle(.primary)
                }
                
                // Version Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                            .contentShape(Rectangle()) // Ensure tap area is large enough
                            .onTapGesture(count: 8) {
                                print("Debug VIP Activated") // Debug log
                                subscriptionManager.activateDebugVip()
                                showDebugAlert = true
                            }
                    }
                }
            }
            .navigationTitle("FoxioAI")
            .listStyle(.insetGrouped)
            .fullScreenCover(isPresented: $showSubscription) {
                SubscriptionView()
            }
            .sheet(isPresented: $showFeedback) {
                FeedbackView()
            }
            .alert("Debug Mode", isPresented: $showDebugAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You have activated 7 days of VIP access for testing.")
            }
            }
            
            if ratingManager.showRatingPopup {
                RatingPopupView(isPresented: $ratingManager.showRatingPopup)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
    }
}

// MARK: - Helper Views

struct SettingsRow: View {
    let icon: String
    let color: Color
    let title: LocalizedStringKey
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            Text(title)
                .font(.body)
        }
    }
}

#Preview {
    SettingsView()
}

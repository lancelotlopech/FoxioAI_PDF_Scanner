import SwiftUI
import StoreKit

struct RatingPopupView: View {
    @Binding var isPresented: Bool
    @State private var rating: Int = 0
    @State private var showFeedback = false
    
    // App Store ID
    private let appID = "6756200466"
    
    // Environment for system review prompt
    @Environment(\.requestReview) var requestReview
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // Popup Content
            VStack(spacing: 20) {
                // Icon
                Image("AppIcon") // Fallback to system if not found
                    .resizable()
                    .frame(width: 60, height: 60)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    .overlay {
                        if UIImage(named: "AppIcon") == nil {
                            Image(systemName: "doc.viewfinder")
                                .font(.system(size: 30))
                                .foregroundStyle(.blue)
                        }
                    }
                
                // Step 1: Rating
                Text("Enjoying FoxioAI?")
                    .font(.title3.bold())
                
                Text("Tap a star to rate it on the App Store.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                // Stars
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 32))
                            .foregroundStyle(.orange)
                            .onTapGesture {
                                withAnimation {
                                    rating = star
                                }
                                handleRating(star)
                            }
                    }
                }
                .padding(.vertical, 10)
                
                Button("Not Now") {
                    // Treat "Not Now" as rated for this version to avoid nagging
                    RatingManager.shared.markRated()
                    isPresented = false
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(.horizontal, 40)
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView()
        }
    }
    
    private func handleRating(_ star: Int) {
        // Delay slightly to show the star animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if star >= 4 {
                // High rating
                RatingManager.shared.markRated()
                
                // Close our popup immediately to avoid overlap
                isPresented = false
                
                // Check source
                if RatingManager.shared.currentSource == .active {
                    // Active (Settings): Jump to App Store to guarantee rating
                    if let url = URL(string: "itms-apps://itunes.apple.com/app/id\(appID)?action=write-review") {
                        UIApplication.shared.open(url)
                    }
                } else {
                    // Passive (Auto): Try system popup (non-intrusive)
                    // Delay slightly to ensure our popup is gone
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        requestReview()
                    }
                }
            } else {
                // Low rating -> Feedback
                showFeedback = true
                isPresented = false
            }
        }
    }
}

#Preview {
    RatingPopupView(isPresented: .constant(true))
}

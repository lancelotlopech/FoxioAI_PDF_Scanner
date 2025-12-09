import SwiftUI

struct SplashView: View {
    @Binding var isActive: Bool
    @State private var progress: Double = 0.0
    @State private var opacity: Double = 1.0
    
    // Background Color: #FEF7EA
    private let backgroundColor = Color(red: 254/255, green: 247/255, blue: 234/255)
    
    var body: some View {
        if isActive {
            EmptyView()
        } else {
            ZStack {
                // Background Color
                backgroundColor.ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    // Centered Image (Fox)
                    Image("LoadingImage")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 240, height: 240) // Adjusted size for visibility
                    
                    Spacer()
                    
                    // Progress Bar Container
                    VStack(spacing: 10) {
                        Text("Loading Resources...")
                            .font(.caption)
                            .foregroundColor(.black.opacity(0.8))
                            .fontWeight(.semibold)
                        
                        ProgressView(value: progress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .frame(width: 200)
                    }
                    .padding(.bottom, 80) // Lifted up slightly
                }
            }
            .opacity(opacity)
            .onAppear {
                startLoading()
            }
        }
    }
    
    func startLoading() {
        // Simulate loading process (Optimized to ~1.5s)
        // Interval 0.015s * 100 steps = 1.5s
        Timer.scheduledTimer(withTimeInterval: 0.015, repeats: true) { timer in
            if progress < 1.0 {
                progress += 0.01
            } else {
                timer.invalidate()
                
                // Transition to main app
                withAnimation(.easeOut(duration: 0.5)) {
                    opacity = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isActive = true
                }
            }
        }
    }
}

struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        SplashView(isActive: .constant(false))
    }
}

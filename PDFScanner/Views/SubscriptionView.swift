import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var subManager = SubscriptionManager.shared
    @State private var selectedProductID: String = SubscriptionManager.mockYearly.id // Default to Yearly
    @State private var isTrialEnabled: Bool = false
    @State private var isAnimating = false
    
    // Theme Gradient
    private let brandGradient = LinearGradient(
        colors: [
            Color(red: 0.9, green: 0.2, blue: 0.4), // Deeper Pink
            Color(red: 0.9, green: 0.5, blue: 0.1)  // Deeper Orange
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Solid Color for fallback (using the Pink)
    private let brandColor = Color(red: 0.9, green: 0.2, blue: 0.4)
    
    // Mock Products
    let mockWeekly = SubscriptionManager.mockWeekly
    let mockYearly = SubscriptionManager.mockYearly
    
    var weeklyProduct: Product? {
        subManager.products.first(where: { $0.id == mockWeekly.id })
    }
    
    var yearlyProduct: Product? {
        subManager.products.first(where: { $0.id == mockYearly.id })
    }
    
    var weeklyPrice: String {
        weeklyProduct?.displayPrice ?? mockWeekly.displayPrice
    }
    
    var yearlyPrice: String {
        yearlyProduct?.displayPrice ?? mockYearly.displayPrice
    }
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Header
                headerView
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                // Adaptive Content Area
                // ViewThatFits (iOS 16+) automatically picks the first view that fits.
                // If the Fixed Layout (VStack with Spacers) fits, it uses that (One Screen Experience).
                // If it doesn't fit (Small Screen), it falls back to the ScrollView layout.
                ViewThatFits(in: .vertical) {
                    // Option A: Fixed One-Screen Layout
                    fixedContentLayout
                    
                    // Option B: Scrollable Layout (Fallback for SE/Small screens)
                    scrollableContentLayout
                }
                
                // 7. Bottom Button (Always Sticky)
                bottomSection
            }
        }
        .onChange(of: isTrialEnabled) { oldValue, newValue in
            // Logic 1: If Free Trial is enabled -> Auto switch to Weekly plan
            if newValue {
                 selectedProductID = mockWeekly.id
            }
        }
        .onChange(of: selectedProductID) { oldValue, newValue in
            // Logic 2: If User switches to Yearly -> Auto turn off Free Trial
            if newValue == mockYearly.id {
                isTrialEnabled = false
            }
        }
        .task {
            await subManager.requestProducts()
        }
    }
    
    // MARK: - Layout Variants
    
    private var fixedContentLayout: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 2)
            heroSection
            Spacer(minLength: 2)
            featuresList.padding(.horizontal, 32)
            Spacer(minLength: 4)
            trialToggleSection.padding(.horizontal, 20)
            Spacer(minLength: 4)
            pricingSection.padding(.horizontal, 20)
            Spacer(minLength: 4)
            assuranceSection
            Spacer(minLength: 8)
        }
    }
    
    private var scrollableContentLayout: some View {
        ScrollView {
            VStack(spacing: 12) {
                heroSection
                    .padding(.top, 10)
                featuresList
                    .padding(.horizontal, 32)
                trialToggleSection
                    .padding(.horizontal, 20)
                pricingSection
                    .padding(.horizontal, 20)
                assuranceSection
                
                Spacer(minLength: 20)
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Components
    
    private var headerView: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.gray.opacity(0.5))
            }
            
            Spacer()
            
            Button("Restore") {
                Task {
                    await subManager.restorePurchases()
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }
    
    private var heroSection: some View {
        VStack(spacing: 4) {
            // Complex Tech Hero Graphic (Scaled Down)
            ZStack {
                // Outer Glow
                Circle()
                    .fill(brandColor.opacity(0.05))
                    .frame(width: 100, height: 100)
                    .blur(radius: 10)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .opacity(isAnimating ? 0.5 : 0.8)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                
                // Outer Ring
                Circle()
                    .stroke(brandColor.opacity(0.2), lineWidth: 1)
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: isAnimating)
                
                // Middle Dashed Ring
                Circle()
                    .stroke(brandColor.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                    .frame(width: 76, height: 76)
                    .rotationEffect(.degrees(isAnimating ? -360 : 0))
                    .animation(.linear(duration: 15).repeatForever(autoreverses: false), value: isAnimating)
                
                // Inner Background
                Circle()
                    .fill(brandColor.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                // Main Icon
                Image(systemName: "doc.viewfinder.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(brandGradient)
                    .shadow(color: brandColor.opacity(0.3), radius: 6, y: 3)
                
                // Satellite Icons (Scaled Down)
                ZStack {
                    // Lock
                    Circle()
                        .fill(Color(uiColor: .systemBackground))
                        .frame(width: 20, height: 20)
                        .shadow(radius: 2)
                        .overlay(
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.red)
                                .font(.system(size: 10, weight: .bold))
                        )
                        .offset(x: 35, y: 0) // Start at 3 o'clock
                    
                    // Signature
                    Circle()
                        .fill(Color(uiColor: .systemBackground))
                        .frame(width: 20, height: 20)
                        .shadow(radius: 2)
                        .overlay(
                            Image(systemName: "signature")
                                .foregroundStyle(.purple)
                                .font(.system(size: 10, weight: .bold))
                        )
                        .offset(x: -17.5, y: 30.3) // Start at ~7 o'clock
                        
                    // Cloud/Sync
                    Circle()
                        .fill(Color(uiColor: .systemBackground))
                        .frame(width: 16, height: 16)
                        .shadow(radius: 2)
                        .overlay(
                            Image(systemName: "icloud.fill")
                                .foregroundStyle(.blue)
                                .font(.system(size: 8, weight: .bold))
                        )
                        .offset(x: -17.5, y: -30.3) // Start at ~11 o'clock
                }
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 10).repeatForever(autoreverses: false), value: isAnimating)
            }
            .padding(.bottom, 2)
            .onAppear {
                isAnimating = true
            }
            
            Text("Unlimited Access")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .padding(.horizontal)
        }
    }
    
    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 4) {
            FeatureRow(text: "Unlimited Scans & Exports", gradient: brandGradient)
            FeatureRow(text: "Text Recognition (OCR)", gradient: brandGradient)
            FeatureRow(text: "Sign & Protect Documents", gradient: brandGradient)
        }
        .frame(maxWidth: .infinity) // Center the block
    }
    
    private var trialToggleSection: some View {
        HStack {
            Text(isTrialEnabled ? String(localized: "Free Trial Enabled") : String(localized: "Not sure yet? Enable free trial"))
                .font(.subheadline.bold())
                .foregroundStyle(isTrialEnabled ? brandColor : .secondary)
            
            Spacer()
            
            Toggle("", isOn: $isTrialEnabled)
                .labelsHidden()
                .tint(brandColor)
        }
        .padding(10)
        .background(isTrialEnabled ? brandColor.opacity(0.1) : Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isTrialEnabled ? brandColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var pricingSection: some View {
        VStack(spacing: 8) {
            // Yearly Option
            PricingCardNew(
                title: "YEARLY ACCESS",
                price: "\(yearlyPrice)/year",
                subtitle: "Just $0.76 per week",
                badge: "Save 80%",
                isSelected: selectedProductID == mockYearly.id,
                brandGradient: brandGradient,
                onTap: { selectedProductID = mockYearly.id }
            )
            
            // Weekly Option
            PricingCardNew(
                title: "WEEKLY ACCESS",
                price: "\(weeklyPrice)/week",
                subtitle: isTrialEnabled ? "3 Days Free Trial" : nil,
                badge: isTrialEnabled ? "Popular" : nil,
                isSelected: selectedProductID == mockWeekly.id,
                brandGradient: brandGradient,
                onTap: { selectedProductID = mockWeekly.id }
            )
        }
    }
    
    private var assuranceSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(.green)
                .font(.caption)
            Text("You can cancel anytime.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    private var bottomSection: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    if let product = subManager.products.first(where: { $0.id == selectedProductID }) {
                        try? await subManager.purchase(product)
                    } else {
                        print("Product not found, using mock purchase flow or showing error")
                    }
                }
            } label: {
                if subManager.isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(brandGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                } else {
                    Text(LocalizedStringKey(buttonText))
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(brandGradient) // Gradient
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: brandColor.opacity(0.3), radius: 8, y: 4)
                }
            }
            
            HStack(spacing: 20) {
                Link("Terms of Usage", destination: URL(string: "https://foxio-pdf-scanner.pages.dev/#terms")!)
                Link("Privacy Policy", destination: URL(string: "https://foxio-pdf-scanner.pages.dev/#privacy")!)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .buttonStyle(.plain) // Ensure they look like text but clickable
            .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20) // Increased bottom padding for safety
    }
    
    private var buttonText: String {
        if isTrialEnabled {
            return "Start Free Trial"
        } else {
            return "Continue"
        }
    }
}

// MARK: - Subviews

struct FeatureRow: View {
    let text: LocalizedStringKey
    let gradient: LinearGradient
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .bold)) // Smaller
                .foregroundStyle(gradient)
            
            Text(text)
                .font(.footnote) // Smaller
                .foregroundStyle(.primary)
        }
    }
}

struct PricingCardNew: View {
    let title: LocalizedStringKey
    let price: String
    let subtitle: String?
    let badge: String?
    let isSelected: Bool
    let brandGradient: LinearGradient
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                HStack {
                    // Radio Circle
                    ZStack {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(brandGradient)
                        } else {
                            Image(systemName: "circle")
                                .font(.title3)
                                .foregroundStyle(.gray.opacity(0.5))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        
                        if let subtitle = subtitle {
                            Text(LocalizedStringKey(subtitle))
                                .font(.caption2)
                                .foregroundStyle(isSelected ? brandGradient : LinearGradient(colors: [.secondary], startPoint: .leading, endPoint: .trailing))
                                .fontWeight(isSelected ? .medium : .regular)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    Spacer()
                    
                    Text(price)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10) // Slightly more padding for touch target
                .frame(minHeight: 50)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isSelected ? brandGradient : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing), lineWidth: 2)
                )
                
                if let badge = badge {
                    Text(LocalizedStringKey(badge))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: .orange.opacity(0.3), radius: 2, x: 0, y: 1)
                        .offset(x: 8, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .padding(.trailing, 6)
    }
}

#Preview {
    SubscriptionView()
}

import Foundation
import StoreKit
import Combine

// MARK: - Subscription Manager
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var isPremium = false
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Feature Enums
    enum Feature {
        case ocr
        case signature
        case security
    }
    
    // Replace these with your actual Product IDs from App Store Connect
    private let productDict: [String: String] = [
        "weekly": "com.pdfscanner.weekly6.99",
        "yearly": "yearlypro.39.99"
    ]
    
    private var updates: Task<Void, Never>? = nil
    
    private init() {
        // Start listening for transaction updates (e.g. renewals, external purchases)
        updates = newTransactionListenerTask()
        
        // Check initial status
        Task {
            await updateSubscriptionStatus()
            // In a real app, you would call this. For UI dev, we might verify mock data.
            // await requestProducts()
        }
    }
    
    // MARK: - Usage Tracking
    
    func checkAccess(for feature: Feature) -> Bool {
        if isPremium { return true }
        return false
    }
    
    deinit {
        updates?.cancel()
    }
    
    // MARK: - StoreKit Logic
    
    func requestProducts() async {
        do {
            isLoading = true
            // Request products from App Store
            let storeProducts = try await Product.products(for: Set(productDict.values))
            self.products = storeProducts.sorted(by: { $0.price < $1.price })
            isLoading = false
        } catch {
            print("Failed to load products: \(error)")
            isLoading = false
            errorMessage = "Failed to load subscription options."
        }
    }
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // Check if the transaction is verified
            let transaction = try checkVerified(verification)
            
            // The transaction is valid. Update status.
            await updateSubscriptionStatus()
            
            // Always finish a transaction.
            await transaction.finish()
            
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }
    
    func restorePurchases() async {
        // App Store syncs automatically, but we can force a sync check
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }
    
    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        
        // Iterate through all of the user's purchased products
        for await result in Transaction.currentEntitlements {
            do {
                // Check if the transaction is verified
                let transaction = try checkVerified(result)
                
                // Check if it's a subscription and if it's not revoked/expired
                if transaction.productType == .autoRenewable || transaction.productType == .nonConsumable {
                    hasActiveSubscription = true
                }
            } catch {
                print("Transaction verification failed")
            }
        }
        
        self.isPremium = hasActiveSubscription
    }
    
    private func newTransactionListenerTask() -> Task<Void, Never> {
        Task.detached {
            // Iterate through any transactions that don't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification")
                }
            }
        }
    }
    
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        // Check whether the JWS passes StoreKit verification.
        switch result {
        case .unverified:
            // StoreKit parses the JWS, but it failed verification.
            throw StoreError.failedVerification
        case .verified(let safe):
            // The result is verified. Return the unwrapped value.
            return safe
        }
    }
    
    enum StoreError: Error {
        case failedVerification
    }
}

// MARK: - Mock Data (For UI Development)
extension SubscriptionManager {
    struct MockProduct: Identifiable {
        let id: String
        let displayName: String
        let displayPrice: String
        let price: Decimal
        let description: String
        let period: String // "week" or "year"
        let trial: String // "3 Days Free"
    }
    
    static let mockWeekly = MockProduct(
        id: "com.pdfscanner.weekly6.99",
        displayName: "Weekly Access",
        displayPrice: "$6.99",
        price: 6.99,
        description: "Weekly subscription",
        period: "week",
        trial: "3 Days Free"
    )
    
    static let mockYearly = MockProduct(
        id: "yearlypro.39.99",
        displayName: "Yearly Access",
        displayPrice: "$39.99",
        price: 39.99,
        description: "Yearly subscription",
        period: "year",
        trial: "3 Days Free"
    )
}

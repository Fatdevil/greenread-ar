// StoreManager.swift
// GreenRead AR — StoreKit 2 In-App Purchase
// PRD §6: IAP structure — Premium (99 kr), Family Pack (149 kr)
// No backend required — StoreKit handles verification natively

import StoreKit
import SwiftUI

@MainActor
class StoreManager: ObservableObject {
    
    // MARK: - Product IDs
    static let premiumProductID = "com.greenreadar.premium"
    static let familyPackProductID = "com.greenreadar.familypack"
    
    // MARK: - State
    @Published var products: [Product] = []
    @Published var isPremium: Bool = false
    @Published var purchaseError: String?
    @Published var isLoading: Bool = false
    
    // MARK: - Private
    private var transactionListener: Task<Void, Error>?
    
    // MARK: - Init
    init() {
        // Start listening for transactions
        transactionListener = listenForTransactions()
        
        // Check existing entitlements on launch
        Task {
            await checkCurrentEntitlements()
            await loadProducts()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Load Products
    func loadProducts() async {
        do {
            let productIDs: Set<String> = [
                Self.premiumProductID,
                Self.familyPackProductID
            ]
            
            products = try await Product.products(for: productIDs)
            products.sort { $0.price < $1.price }
        } catch {
            print("GreenRead: Failed to load products: \(error)")
        }
    }
    
    // MARK: - Purchase Premium
    func purchasePremium() async {
        guard let product = products.first(where: { $0.id == Self.premiumProductID }) else {
            purchaseError = "Produkten hittades inte. Försök igen."
            return
        }
        
        await purchase(product)
    }
    
    func purchaseFamilyPack() async {
        guard let product = products.first(where: { $0.id == Self.familyPackProductID }) else {
            purchaseError = "Produkten hittades inte. Försök igen."
            return
        }
        
        await purchase(product)
    }
    
    private func purchase(_ product: Product) async {
        isLoading = true
        purchaseError = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerification(verification)
                
                // Grant premium access
                isPremium = true
                
                // Finish the transaction
                await transaction.finish()
                
            case .userCancelled:
                // User cancelled — no error needed
                break
                
            case .pending:
                // Transaction pending (e.g., Ask to Buy)
                purchaseError = "Köpet väntar på godkännande."
                
            @unknown default:
                purchaseError = "Okänt köpresultat."
            }
        } catch {
            purchaseError = "Köpet misslyckades: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Restore Purchases
    /// PRD §6.2: Restore Purchases using StoreKit 2 Transaction.currentEntitlement
    func restorePurchases() async {
        isLoading = true
        
        // Sync with App Store
        try? await AppStore.sync()
        
        // Re-check entitlements
        await checkCurrentEntitlements()
        
        if !isPremium {
            purchaseError = "Inga tidigare köp hittades."
        }
        
        isLoading = false
    }
    
    // MARK: - Check Entitlements
    /// PRD §6.2: Uses Transaction.currentEntitlement — no backend server needed
    func checkCurrentEntitlements() async {
        // Check for Premium
        if let result = await Transaction.currentEntitlement(for: Self.premiumProductID) {
            if case .verified(_) = result {
                isPremium = true
                return
            }
        }
        
        // Check for Family Pack
        if let result = await Transaction.currentEntitlement(for: Self.familyPackProductID) {
            if case .verified(_) = result {
                isPremium = true
                return
            }
        }
        
        isPremium = false
    }
    
    // MARK: - Transaction Listener
    /// Listen for transaction updates (renewals, revocations, etc.)
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerification(result)
                    
                    // Update premium status
                    await MainActor.run {
                        self.isPremium = true
                    }
                    
                    await transaction.finish()
                } catch {
                    print("GreenRead: Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verification
    private func checkVerification<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}

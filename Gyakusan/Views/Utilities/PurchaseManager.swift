//
//  PurchaseManager.swift
//  Gyakusan
//

import Foundation
import StoreKit
import Combine

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    
    // Product ID definition
    static let proProductID = "com.suzuki.kenichiro.Gyakusan.pro"
    
    private static let sharedStore = UserDefaults(suiteName: "group.com.suzuki.kenichiro.Gyakusan")
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var isProPurchased: Bool = false {
        didSet {
            Self.sharedStore?.set(isProPurchased, forKey: "isProPurchased")
        }
    }
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private var transactionListener: Task<Void, Error>? = nil
    
    private init() {
        // Retrieve initial status from AppGroup
        self.isProPurchased = Self.sharedStore?.bool(forKey: "isProPurchased") ?? false
        
        // Start listening for transactions on app launch
        transactionListener = listenForTransactions()
        
        Task {
            await requestProducts()
            await updatePurchasedStatus()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // Fetch product information
    func requestProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: [Self.proProductID])
        } catch {
            print("Failed to fetch products: \(error)")
        }
    }
    
    // Purchase process
    func purchase() async -> Bool {
        guard let product = products.first(where: { $0.id == Self.proProductID }) else {
            errorMessage = "Failed to load product information."
            return false
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                await transaction.finish()
                await updatePurchasedStatus()
                return true
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // Restore purchases
    func restore() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AppStore.sync()
            await updatePurchasedStatus()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }
    }
    
    // Update active entitlement status
    func updatePurchasedStatus() async {
        var hasPro = false
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try Self.checkVerified(result)
                if transaction.productID == Self.proProductID {
                    hasPro = true
                }
            } catch {
                print("Transaction verification failed: \(error)")
            }
        }
        self.isProPurchased = hasPro
    }
    
    // Listen for background transaction updates
        private func listenForTransactions() -> Task<Void, Error> {
            Task.detached {
                for await result in Transaction.updates {
                    do {
                        let transaction = try Self.checkVerified(result)
                        await self.updatePurchasedStatus()
                        await transaction.finish()
                    } catch {
                        print("Transaction update failed: \(error)")
                    }
                }
            }
        }
        
        // ★ nonisolated static メソッドとして定義
        nonisolated private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
            switch result {
            case .unverified(_, let error):
                throw error
            case .verified(let safe):
                return safe
            }
        }
}

//
//  StoreManager.swift
//  TIP CALCULATOR
//
//  StoreKit 2 entitlement for "DipOut Pro" — a single non-consumable lifetime unlock that
//  removes the free-scan limit. No backend: entitlement is read from the App Store directly.
//

import Foundation
import StoreKit

@Observable
final class StoreManager {
    /// Launch price is $2.99 (see Products.storekit); raise to $4.99 after traction.
    static let productID = "com.esks42.dipout.premium.lifetime"

    var isPremium = false
    var product: Product?

    private var listener: Task<Void, Never>?

    init() {
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.apply(result)
            }
        }
        Task {
            await loadProduct()
            await refreshEntitlement()
        }
    }

    deinit { listener?.cancel() }

    func loadProduct() async {
        product = try? await Product.products(for: [Self.productID]).first
    }

    func refreshEntitlement() async {
        for await result in Transaction.currentEntitlements {
            await apply(result)
        }
    }

    /// Returns true once the purchase is verified and the entitlement is granted.
    @discardableResult
    func purchase() async -> Bool {
        guard let product else { return false }
        guard let result = try? await product.purchase() else { return false }
        switch result {
        case .success(let verification):
            await apply(verification)
            return isPremium
        case .pending, .userCancelled:
            return false
        @unknown default:
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }

    @MainActor
    private func apply(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result,
              transaction.productID == Self.productID else { return }
        isPremium = transaction.revocationDate == nil
        await transaction.finish()
    }
}

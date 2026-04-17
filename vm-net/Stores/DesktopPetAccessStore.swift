//
//  DesktopPetAccessStore.swift
//  vm-net
//
//  Created by Codex on 2026/4/17.
//

import Foundation
import StoreKit

enum DesktopPetAccessStatus: Equatable {
    case loading
    case eligibleForTrial
    case inTrial(daysRemaining: Int, expiresAt: Date)
    case unlocked
    case expired(expiresAt: Date)

    var hasAccess: Bool {
        switch self {
        case .eligibleForTrial, .inTrial, .unlocked:
            return true
        case .loading, .expired:
            return false
        }
    }

    var requiresPurchase: Bool {
        if case .expired = self {
            return true
        }

        return false
    }
}

enum DesktopPetAccessMessageKind: Equatable {
    case neutral
    case success
    case error
}

@MainActor
final class DesktopPetAccessStore: ObservableObject {

    private enum Keys {
        static let trialStartedAt =
            "cn.tpshion.vm-net.desktop-pet-trial-started-at"
        static let lifetimeUnlocked =
            "cn.tpshion.vm-net.desktop-pet-lifetime-unlocked"
    }

    static let productID = "cn.tpshion.vm_net.desktop_pet.lifetime"

    private static let trialDuration: TimeInterval = 7 * 24 * 60 * 60

    private let defaults: UserDefaults
    private var transactionUpdatesTask: Task<Void, Never>?
    private var trialStartedAt: Date? {
        didSet {
            if let trialStartedAt {
                defaults.set(trialStartedAt, forKey: Keys.trialStartedAt)
            } else {
                defaults.removeObject(forKey: Keys.trialStartedAt)
            }
        }
    }

    private var hasLifetimeUnlock: Bool {
        didSet {
            defaults.set(hasLifetimeUnlock, forKey: Keys.lifetimeUnlocked)
        }
    }

    @Published private(set) var status: DesktopPetAccessStatus
    @Published private(set) var product: Product?
    @Published private(set) var isPurchaseInProgress = false
    @Published var lastAccessMessage: String?
    @Published private(set) var lastAccessMessageKind: DesktopPetAccessMessageKind = .neutral

    var unlockButtonTitle: String {
        if let displayPrice = product?.displayPrice {
            return L10n.tr("desktopPet.access.unlockWithPrice", displayPrice)
        }

        return L10n.tr("desktopPet.access.unlock")
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedTrialStartedAt =
            defaults.object(forKey: Keys.trialStartedAt) as? Date
        self.hasLifetimeUnlock = defaults.bool(forKey: Keys.lifetimeUnlocked)
        let seededTrialStartedAt: Date?
        if hasLifetimeUnlock {
            seededTrialStartedAt = storedTrialStartedAt
        } else {
            seededTrialStartedAt = storedTrialStartedAt ?? Date()
        }
        self.trialStartedAt = seededTrialStartedAt
        if storedTrialStartedAt == nil, let seededTrialStartedAt {
            defaults.set(seededTrialStartedAt, forKey: Keys.trialStartedAt)
        }
        self.status = Self.makeStatus(
            trialStartedAt: seededTrialStartedAt,
            hasLifetimeUnlock: self.hasLifetimeUnlock,
            now: Date()
        )

        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handle(transactionResult: result)
            }
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func prepare() async {
        await refreshProduct()
        await refreshEntitlementStatus()
    }

    func refresh() async {
        await refreshProduct()
        await refreshEntitlementStatus()
    }

    @discardableResult
    func prepareForUse() -> Bool {
        switch status {
        case .eligibleForTrial:
            clearMessage()
            return true
        case .inTrial, .unlocked:
            clearMessage()
            return true
        case .expired:
            clearMessage()
            return false
        case .loading:
            updateStatus()
            return status.hasAccess
        }
    }

    @discardableResult
    func purchaseLifetimeUnlock() async -> Bool {
        clearMessage()

        if product == nil {
            await refreshProduct()
        }

        guard let product else {
            setMessage(
                L10n.tr("desktopPet.access.purchaseUnavailable"),
                kind: .error
            )
            return false
        }

        isPurchaseInProgress = true
        defer { isPurchaseInProgress = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                hasLifetimeUnlock = transaction.revocationDate == nil
                await refreshEntitlementStatus()
                if hasLifetimeUnlock {
                    setMessage(
                        L10n.tr("desktopPet.access.purchaseSucceeded"),
                        kind: .success
                    )
                    return true
                }

                setMessage(
                    L10n.tr("desktopPet.access.purchaseFailed"),
                    kind: .error
                )
                return false
            case .userCancelled:
                clearMessage()
                return false
            case .pending:
                setMessage(
                    L10n.tr("desktopPet.access.purchasePending"),
                    kind: .neutral
                )
                return false
            @unknown default:
                setMessage(
                    L10n.tr("desktopPet.access.purchaseFailed"),
                    kind: .error
                )
                return false
            }
        } catch {
            setMessage(message(for: error), kind: .error)
            return false
        }
    }

    @discardableResult
    func restorePurchases() async -> Bool {
        clearMessage()

        do {
            try await AppStore.sync()
            await refreshEntitlementStatus()
            if hasLifetimeUnlock {
                setMessage(
                    L10n.tr("desktopPet.access.restoreSucceeded"),
                    kind: .success
                )
                return true
            }

            setMessage(
                L10n.tr("desktopPet.access.restoreUnavailable"),
                kind: .error
            )
            return false
        } catch {
            setMessage(message(for: error), kind: .error)
            return false
        }
    }

    private func refreshProduct() async {
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
        } catch {
            product = nil
        }
    }

    private func refreshEntitlementStatus() async {
        var hasActiveUnlock = false

        for await result in Transaction.currentEntitlements {
            guard
                case .verified(let transaction) = result,
                transaction.productID == Self.productID,
                transaction.revocationDate == nil
            else {
                continue
            }

            hasActiveUnlock = true
            break
        }

        hasLifetimeUnlock = hasActiveUnlock
        updateStatus()
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = transactionResult else {
            return
        }

        guard transaction.productID == Self.productID else {
            await transaction.finish()
            return
        }

        hasLifetimeUnlock = transaction.revocationDate == nil
        updateStatus()
        await transaction.finish()
    }

    private func updateStatus(now: Date = Date()) {
        status = Self.makeStatus(
            trialStartedAt: trialStartedAt,
            hasLifetimeUnlock: hasLifetimeUnlock,
            now: now
        )
    }

    private func checkVerified<T>(
        _ result: VerificationResult<T>
    ) throws -> T {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw StoreError.failedVerification
        }
    }

    private func clearMessage() {
        lastAccessMessage = nil
        lastAccessMessageKind = .neutral
    }

    private func setMessage(
        _ message: String,
        kind: DesktopPetAccessMessageKind
    ) {
        lastAccessMessage = message
        lastAccessMessageKind = kind
    }

    private func message(for error: Error) -> String {
        if let storeError = error as? StoreError {
            switch storeError {
            case .failedVerification:
                return L10n.tr("desktopPet.access.verificationFailed")
            }
        }

        if let storeKitError = error as? StoreKitError {
            switch storeKitError {
            case .networkError:
                return L10n.tr("desktopPet.access.networkError")
            case .notAvailableInStorefront:
                return L10n.tr("desktopPet.access.purchaseUnavailable")
            default:
                return L10n.tr("desktopPet.access.purchaseFailed")
            }
        }

        return L10n.tr("desktopPet.access.purchaseFailed")
    }

    private static func makeStatus(
        trialStartedAt: Date?,
        hasLifetimeUnlock: Bool,
        now: Date
    ) -> DesktopPetAccessStatus {
        if hasLifetimeUnlock {
            return .unlocked
        }

        guard let trialStartedAt else {
            return .eligibleForTrial
        }

        let expiresAt = trialStartedAt.addingTimeInterval(trialDuration)
        guard now < expiresAt else {
            return .expired(expiresAt: expiresAt)
        }

        let daysRemaining = max(
            1,
            Int(ceil(expiresAt.timeIntervalSince(now) / (24 * 60 * 60)))
        )
        return .inTrial(daysRemaining: daysRemaining, expiresAt: expiresAt)
    }
}

private enum StoreError: Error {
    case failedVerification
}

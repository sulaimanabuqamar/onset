import Combine
import Foundation
import RevenueCat

/// RevenueCat powers the Family plan.
/// Principle: the emergency check is free forever. Money only buys the
/// *ongoing* care around it — baselines for the people you look after,
/// weekly check-ins, and the trend that shows when "normal" is changing.
@MainActor
final class PurchaseManager: NSObject, ObservableObject {
    static let entitlementID = "family"

    @Published private(set) var isFamily = false
    @Published private(set) var offering: Offering?
    @Published private(set) var isLoading = false
    @Published var lastError: String?

    /// Free plan: yourself + unlimited emergency checks on anyone.
    static let freeProfileLimit = 1

    private var configured = false

    func configure() {
        guard !configured else { return }
        configured = true
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Config.revenueCatAPIKey)
        Purchases.shared.delegate = self
        Task { await refresh() }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let info = try await Purchases.shared.customerInfo()
            apply(info)
            offering = try await Purchases.shared.offerings().current
        } catch {
            lastError = error.localizedDescription
        }
    }

    func purchase(_ package: Package) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            apply(result.customerInfo)
            return !result.userCancelled && isFamily
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            apply(try await Purchases.shared.restorePurchases())
        } catch {
            lastError = error.localizedDescription
        }
    }

    fileprivate func apply(_ info: CustomerInfo) {
        isFamily = info.entitlements[Self.entitlementID]?.isActive == true
    }
}

extension PurchaseManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in self.apply(customerInfo) }
    }
}

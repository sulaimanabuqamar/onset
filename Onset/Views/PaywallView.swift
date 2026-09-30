import RevenueCat
import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Package?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 10) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 64)).foregroundStyle(Theme.red)
                        Text("Onset Family").font(.largeTitle.weight(.heavy))
                        Text("Look after the people most at risk — before the emergency.")
                            .font(.title3).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    }
                    .padding(.top, 10)

                    VStack(alignment: .leading, spacing: 14) {
                        perk("person.3.fill", "Up to 6 family members", "Each with their own saved normal face, arms and voice.")
                        perk("calendar.badge.clock", "Weekly 20-second check-ins", "A reminder, a quick check, compared with their normal.")
                        perk("chart.xyaxis.line", "See changes over time", "A smile getting weaker week by week is worth showing a doctor.")
                        perk("cross.case.fill", "Paramedic cards ready", "Blood thinners and conditions on the card the moment it matters.")
                    }

                    Card {
                        Label {
                            Text("The emergency check stays free for everyone, forever. We never charge for the moment someone might be having a stroke.")
                                .font(.subheadline)
                        } icon: {
                            Image(systemName: "checkmark.shield.fill").foregroundStyle(Theme.green)
                        }
                    }

                    packages

                    if purchases.isFamily {
                        Label("Family is active — thank you", systemImage: "checkmark.circle.fill")
                            .font(.headline).foregroundStyle(Theme.green)
                    } else {
                        PrimaryButton(title: purchases.isLoading ? "Working…" : ctaTitle, color: Theme.red) {
                            guard let pkg = selected ?? purchases.offering?.availablePackages.first else { return }
                            Task {
                                if await purchases.purchase(pkg) {
                                    Haptics.success()
                                    dismiss()
                                }
                            }
                        }
                        .disabled(purchases.isLoading || purchases.offering == nil)
                    }

                    Button("Restore purchases") { Task { await purchases.restore() } }
                        .font(.footnote)

                    if let err = purchases.lastError {
                        Text(err).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } }
            }
            .task {
                if purchases.offering == nil { await purchases.refresh() }
                selected = purchases.offering?.annual ?? purchases.offering?.availablePackages.first
            }
        }
    }

    private var ctaTitle: String {
        guard let pkg = selected else { return "Continue" }
        if let intro = pkg.storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial {
            return "Start free trial"
        }
        return "Continue — \(pkg.storeProduct.localizedPriceString)"
    }

    @ViewBuilder private var packages: some View {
        if let offering = purchases.offering {
            VStack(spacing: 10) {
                ForEach(offering.availablePackages, id: \.identifier) { pkg in
                    Button { selected = pkg } label: { packageRow(pkg) }
                        .buttonStyle(.plain)
                }
            }
        } else if purchases.isLoading {
            ProgressView()
        } else {
            Text("Plans couldn't load. Check your connection.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func packageRow(_ pkg: Package) -> some View {
        let isSelected = selected?.identifier == pkg.identifier
        return HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title(for: pkg)).font(.headline)
                Text(detail(for: pkg)).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(pkg.storeProduct.localizedPriceString).font(.headline)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2).foregroundStyle(isSelected ? Theme.red : Color(.tertiaryLabel))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(isSelected ? Theme.red : .clear, lineWidth: 2))
    }

    private func title(for pkg: Package) -> String {
        switch pkg.packageType {
        case .annual: return "Yearly"
        case .monthly: return "Monthly"
        case .lifetime: return "Lifetime"
        default: return pkg.storeProduct.localizedTitle
        }
    }

    private func detail(for pkg: Package) -> String {
        switch pkg.packageType {
        case .annual:
            if let monthly = pkg.storeProduct.localizedPricePerMonth { return "\(monthly)/month · best value" }
            return "Best value"
        case .monthly: return "Cancel anytime"
        case .lifetime: return "Pay once"
        default: return ""
        }
    }

    private func perk(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(Theme.red).frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

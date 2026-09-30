import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: OnsetStore
    @State private var page = 0

    var body: some View {
        VStack {
            TabView(selection: $page) {
                pageView(icon: "brain.head.profile", color: Theme.red,
                         title: "Every minute of a stroke counts",
                         text: "Most people don't recognise a stroke — or wait to see if it passes. Onset turns your iPhone into a 60-second stroke check anyone can run.")
                    .tag(0)
                pageView(icon: "iphone.gen3.radiowaves.left.and.right", color: Theme.calm,
                         title: "Your iPhone is the instrument",
                         text: "The 3D face camera measures a drooping smile. The motion sensors feel an arm sinking. On-device listening scores slurred speech. Nothing leaves the phone.")
                    .tag(1)
                disclaimer.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            PrimaryButton(title: page < 2 ? "Next" : "I understand — start", color: page < 2 ? Theme.calm : Theme.red) {
                if page < 2 { withAnimation { page += 1 } } else { store.onboarded = true }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func pageView(icon: String, color: Color, title: String, text: String) -> some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: icon).font(.system(size: 96)).foregroundStyle(color)
            Text(title).font(.largeTitle.weight(.heavy)).multilineTextAlignment(.center)
            Text(text).font(.title3).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(28)
    }

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Image(systemName: "phone.arrow.up.right.fill").font(.system(size: 64)).foregroundStyle(Theme.red)
            Text("If in doubt, call first").font(.largeTitle.weight(.heavy))
            Text("Onset is a screening aid, not a diagnosis. A normal result does not rule out a stroke, and stroke signs can come and go.")
                .font(.title3)
            Text("If you think someone is having a stroke, call \(EmergencyNumber.current) straight away. The call button is on every screen.")
                .font(.title3.weight(.semibold))
            Spacer()
        }
        .padding(28)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: OnsetStore
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("voicePrompts") private var voicePrompts = true
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan") {
                    HStack {
                        Text("Onset Family")
                        Spacer()
                        Text(purchases.isFamily ? "Active" : "Not active").foregroundStyle(.secondary)
                    }
                    if !purchases.isFamily { Button("See Family plan") { showPaywall = true } }
                    Button("Restore purchases") { Task { await purchases.restore() } }
                }
                Section {
                    Toggle("Spoken instructions", isOn: $voicePrompts)
                        .onChange(of: voicePrompts) { _, on in Narrator.shared.enabled = on }
                    HStack {
                        Text("Emergency number")
                        Spacer()
                        Text(EmergencyNumber.current).foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("The emergency number follows your phone's region.")
                }
                Section {
                    Button("Load sample family") { store.loadSampleFamily() }
                } header: {
                    Text("Demo")
                } footer: {
                    Text("Adds two sample parents with nine weeks of check-ins, to show how the Family trend looks.")
                }
                Section("About") {
                    Text("Onset is a screening aid based on the FAST / BE-FAST stroke signs. It is not a medical device and does not diagnose. If in doubt, always call emergency services.")
                        .font(.footnote)
                    Text("All data stays on this iPhone. No account, no server.").font(.footnote)
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(purchases) }
        }
    }
}

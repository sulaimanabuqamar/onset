import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: OnsetStore
    @EnvironmentObject private var purchases: PurchaseManager

    @State private var choosingPerson = false
    @State private var activeCheck: ActiveCheck?
    @State private var showPaywall = false
    @State private var editingProfile: Profile?
    @State private var showSettings = false

    struct ActiveCheck: Identifiable {
        let id = UUID()
        let kind: CheckKind
        let profileID: UUID?
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    bigButton
                    fastExplainer
                    familySection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Onset")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItem(placement: .topBarLeading) { CallNowPill() }
            }
            .navigationDestination(for: UUID.self) { id in
                ProfileDetailView(profileID: id,
                                  startCheck: { kind in activeCheck = ActiveCheck(kind: kind, profileID: id) },
                                  showPaywall: { showPaywall = true })
            }
        }
        .confirmationDialog("Who are you checking?", isPresented: $choosingPerson, titleVisibility: .visible) {
            ForEach(store.profiles) { p in
                Button(p.name) { activeCheck = ActiveCheck(kind: .emergency, profileID: p.id) }
            }
            Button("Someone else") { activeCheck = ActiveCheck(kind: .emergency, profileID: nil) }
        }
        .fullScreenCover(item: $activeCheck) { c in
            CheckFlowView(kind: c.kind, profileID: c.profileID)
                .environmentObject(store)
                .environmentObject(purchases)
        }
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(purchases) }
        .sheet(item: $editingProfile) { p in ProfileEditor(profile: p).environmentObject(store) }
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(store).environmentObject(purchases) }
    }

    private var bigButton: some View {
        Button {
            Haptics.tick()
            if store.profiles.isEmpty {
                activeCheck = ActiveCheck(kind: .emergency, profileID: nil)
            } else {
                choosingPerson = true
            }
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(.white.opacity(0.15)).frame(width: 120, height: 120)
                    Image(systemName: "brain.head.profile").font(.system(size: 58, weight: .semibold))
                }
                Text("Start stroke check").font(.title.weight(.heavy))
                Text("60 seconds · face · arms · speech · time").font(.subheadline).opacity(0.9)
                Text("Free, always. No account.").font(.caption.weight(.semibold)).opacity(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(LinearGradient(colors: [Theme.red, Theme.deepRed], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: Theme.red.opacity(0.35), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var fastExplainer: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("How it works").font(.headline)
                HStack(alignment: .top, spacing: 12) {
                    tile("F", "Face", "3D face camera measures a drooping smile")
                    tile("A", "Arms", "The phone in their palm feels an arm sink")
                    tile("S", "Speech", "On-device listening scores slurred words")
                    tile("T", "Time", "Records when it started, for the ambulance")
                }
            }
        }
    }

    private func tile(_ letter: String, _ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(letter).font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(Theme.red)
            Text(title).font(.caption.weight(.bold))
            Text(text).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var familySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("People you look after").font(.title3.weight(.bold))
                Spacer()
                if purchases.isFamily {
                    Label("Family", systemImage: "heart.fill").font(.caption.weight(.bold)).foregroundStyle(Theme.red)
                }
            }
            Text("Save each person's normal face, arms and voice. Checks compare against *them*, not an average.")
                .font(.subheadline).foregroundStyle(.secondary)

            ForEach(store.profiles) { p in
                NavigationLink(value: p.id) { ProfileRow(profile: p, lastCheck: store.history(for: p.id).last) }
                    .buttonStyle(.plain)
            }

            Button {
                if store.profiles.count >= PurchaseManager.freeProfileLimit && !purchases.isFamily {
                    showPaywall = true
                } else {
                    editingProfile = Profile(name: "", relation: store.profiles.isEmpty ? "Me" : "")
                }
            } label: {
                Label(store.profiles.isEmpty ? "Add yourself" : "Add a family member", systemImage: "person.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
        }
    }
}

struct ProfileRow: View {
    let profile: Profile
    let lastCheck: CheckRecord?
    var body: some View {
        HStack(spacing: 14) {
            Text(profile.initials)
                .font(.headline).foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Theme.calm.gradient, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: profile.baseline == nil ? "exclamationmark.circle" : "checkmark.seal.fill")
                .foregroundStyle(profile.baseline == nil ? Theme.amber : Theme.green)
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var subtitle: String {
        if profile.baseline == nil { return "\(profile.relation) · no normal saved yet" }
        if let last = lastCheck { return "\(profile.relation) · last check \(last.date.formatted(.relative(presentation: .named)))" }
        return "\(profile.relation) · normal saved"
    }
}

import Charts
import SwiftUI

struct ProfileDetailView: View {
    let profileID: UUID
    let startCheck: (CheckKind) -> Void
    let showPaywall: () -> Void

    @EnvironmentObject private var store: OnsetStore
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var editing: Profile?
    @State private var confirmDelete = false
    @Environment(\.dismiss) private var dismiss

    private var profile: Profile? { store.profile(profileID) }
    private var history: [CheckRecord] { store.history(for: profileID) }

    var body: some View {
        if let profile {
            ScrollView {
                VStack(spacing: 18) {
                    header(profile)
                    baselineCard(profile)
                    checkInCard(profile)
                    trendCard(profile)
                    historyList
                    Button("Remove \(profile.name)", role: .destructive) { confirmDelete = true }
                        .padding(.top, 8)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(profile.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Edit") { editing = profile } }
            .sheet(item: $editing) { p in ProfileEditor(profile: p).environmentObject(store) }
            .confirmationDialog("Remove \(profile.name) and their history?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Remove", role: .destructive) { store.delete(profile); dismiss() }
            }
        } else {
            Text("Not found")
        }
    }

    private func header(_ p: Profile) -> some View {
        HStack(spacing: 16) {
            Text(p.initials).font(.title.weight(.bold)).foregroundStyle(.white)
                .frame(width: 70, height: 70).background(Theme.calm.gradient, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(p.name).font(.title2.weight(.bold))
                Text([p.relation, p.age.map { "\($0) years" }].compactMap { $0 }.joined(separator: " · "))
                    .foregroundStyle(.secondary)
                if p.takesBloodThinners {
                    Label("Takes blood thinners", systemImage: "drop.fill").font(.caption.weight(.semibold)).foregroundStyle(Theme.red)
                }
            }
            Spacer()
        }
    }

    private func baselineCard(_ p: Profile) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label(p.baseline == nil ? "No normal saved yet" : "Normal saved", systemImage: p.baseline == nil ? "exclamationmark.circle" : "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(p.baseline == nil ? Theme.amber : Theme.green)
                if let b = p.baseline {
                    HStack(spacing: 18) {
                        stat("Smile", "\(Int((1 - b.face.smileAsymmetry) * 100))% even")
                        stat("Arm drift", String(format: "%.0f° / %.0f°", b.arm.leftDrift, b.arm.rightDrift))
                        stat("Speech", "\(Int(b.speech.wordAccuracy * 100))%")
                    }
                    Text("Recorded \(b.recordedAt.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Record it on a normal day, when they feel well. It takes 60 seconds and makes every future check compare against their own face and voice.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                PrimaryButton(title: p.baseline == nil ? "Record their normal" : "Re-record normal", systemImage: "person.crop.circle.badge.checkmark") {
                    startCheck(.baseline)
                }
            }
        }
    }

    private func checkInCard(_ p: Profile) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Weekly check-in", systemImage: "calendar.badge.clock").font(.headline)
                    Spacer()
                    if !purchases.isFamily { Label("Family", systemImage: "lock.fill").font(.caption.weight(.bold)).foregroundStyle(.secondary) }
                }
                Text("A 20-second check every week, compared with their normal. Small changes — a weaker smile, a drifting arm — can be warning signs worth showing a doctor.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if purchases.isFamily {
                    if let day = p.checkInWeekday {
                        Text("Reminder every \(Calendar.current.weekdaySymbols[day - 1]) at 10:00").font(.subheadline.weight(.semibold))
                        HStack {
                            PrimaryButton(title: "Check in now", systemImage: "play.fill") { startCheck(.weekly) }
                            Button("Stop") { store.cancelWeeklyCheckIn(for: p) }.padding(.horizontal)
                        }
                    } else {
                        PrimaryButton(title: "Remind me every Friday", systemImage: "bell.fill") {
                            store.scheduleWeeklyCheckIn(for: p, weekday: 6)
                        }
                    }
                } else {
                    PrimaryButton(title: "Unlock with Family", systemImage: "heart.fill", color: Theme.red) { showPaywall() }
                }
            }
        }
        .disabled(p.baseline == nil && purchases.isFamily)
        .opacity(p.baseline == nil && purchases.isFamily ? 0.5 : 1)
    }

    private func trendCard(_ p: Profile) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Smile symmetry over time").font(.headline)
                    Spacer()
                    if !purchases.isFamily { Image(systemName: "lock.fill").foregroundStyle(.secondary) }
                }
                let points = history.filter { $0.face != nil }
                if points.count < 2 {
                    Text("The trend appears after a few check-ins.").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Chart {
                        if let b = p.baseline {
                            RuleMark(y: .value("Normal", (1 - b.face.smileAsymmetry) * 100))
                                .foregroundStyle(Theme.green)
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .annotation(position: .top, alignment: .leading) {
                                    Text("their normal").font(.caption2).foregroundStyle(Theme.green)
                                }
                        }
                        ForEach(points) { r in
                            LineMark(x: .value("Date", r.date), y: .value("Even %", (1 - (r.face?.smileAsymmetry ?? 0)) * 100))
                                .foregroundStyle(Theme.calm)
                                .interpolationMethod(.catmullRom)
                            PointMark(x: .value("Date", r.date), y: .value("Even %", (1 - (r.face?.smileAsymmetry ?? 0)) * 100))
                                .foregroundStyle(r.callNow ? Theme.red : Theme.calm)
                        }
                    }
                    .chartYScale(domain: 40...100)
                    .frame(height: 180)
                    .blur(radius: purchases.isFamily ? 0 : 6)
                    .overlay {
                        if !purchases.isFamily {
                            Button("See the trend with Family") { showPaywall() }
                                .font(.headline).buttonStyle(.borderedProminent).tint(Theme.red)
                        }
                    }
                }
            }
        }
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !history.isEmpty { Text("History").font(.headline) }
            ForEach(Array(history.reversed().prefix(10))) { r in
                HStack {
                    Image(systemName: r.kind == .baseline ? "person.crop.circle.badge.checkmark" : (r.callNow ? "exclamationmark.triangle.fill" : "checkmark.circle"))
                        .foregroundStyle(r.callNow ? Theme.red : Theme.green)
                    Text(r.kind == .baseline ? "Normal recorded" : (r.kind == .weekly ? "Weekly check-in" : "Stroke check"))
                    Spacer()
                    Text(r.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
    }
}

struct ProfileEditor: View {
    @State var profile: Profile
    @EnvironmentObject private var store: OnsetStore
    @Environment(\.dismiss) private var dismiss

    private let relations = ["Me", "Mother", "Father", "Grandmother", "Grandfather", "Partner", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Who") {
                    TextField("Name", text: $profile.name)
                    Picker("Relation", selection: $profile.relation) {
                        ForEach(relations, id: \.self) { Text($0).tag($0) }
                        if !profile.relation.isEmpty && !relations.contains(profile.relation) {
                            Text(profile.relation).tag(profile.relation)
                        }
                    }
                    Picker("Born", selection: Binding(get: { profile.birthYear ?? 1960 }, set: { profile.birthYear = $0 })) {
                        ForEach((1920...2015).reversed(), id: \.self) { Text(String($0)).tag($0) }
                    }
                }
                Section {
                    Toggle("Takes blood thinners", isOn: $profile.takesBloodThinners)
                    TextField("Conditions, medications, allergies", text: $profile.medicalNotes, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("For the paramedic card")
                } footer: {
                    Text("Blood thinners change which treatment a hospital can give. This stays on your phone.")
                }
            }
            .navigationTitle(profile.name.isEmpty ? "New person" : profile.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if profile.relation.isEmpty { profile.relation = "Other" }
                        store.upsert(profile)
                        dismiss()
                    }
                    .disabled(profile.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

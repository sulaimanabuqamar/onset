import SwiftUI

struct ResultView: View {
    let record: CheckRecord
    let profile: Profile?
    let onClose: () -> Void

    @State private var showCard = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                headline

                VStack(spacing: 10) {
                    findingRow("F", "Face", record.faceFinding, detail: faceDetail)
                    findingRow("A", "Arms", record.armFinding, detail: armDetail)
                    findingRow("S", "Speech", record.speechFinding, detail: speechDetail)
                    if record.kind == .emergency {
                        findingRow("T", "Last known well", .skipped, detail: timeDetail, neutral: true)
                    }
                    if record.otherSigns.any {
                        findingRow("+", "Other sudden signs", .abnormal, detail: record.otherSigns.list.joined(separator: " · "))
                    }
                }

                if record.kind == .emergency {
                    Button { showCard = true } label: {
                        Label("Show paramedic card", systemImage: "cross.case.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                }

                Text(profile?.baseline != nil
                     ? "Compared with \(profile?.name ?? "their") saved normal from \(profile!.baseline!.recordedAt.formatted(date: .abbreviated, time: .omitted))."
                     : "No saved normal for this person, so general thresholds were used. Faces are never perfectly even — a saved baseline makes this check sharper.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)

                Text("Onset is a quick-check aid, not a diagnosis. Stroke signs can come and go. If in doubt, always call.")
                    .font(.footnote.weight(.semibold)).foregroundStyle(.secondary).multilineTextAlignment(.center)

                Button("Done", action: onClose).padding(.top, 4)
            }
            .padding()
        }
        .sheet(isPresented: $showCard) {
            ParamedicCardView(record: record, profile: profile)
        }
        .onAppear {
            if record.callNow {
                Haptics.warning()
                Narrator.shared.say("Possible stroke signs. Call \(EmergencyNumber.current) now.")
            }
        }
    }

    @ViewBuilder private var headline: some View {
        if record.callNow {
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 54))
                Text("Possible stroke signs").font(.largeTitle.weight(.heavy)).multilineTextAlignment(.center)
                Text("Call an ambulance now. Every minute counts.").font(.title3)
                if let url = EmergencyNumber.url {
                    Link(destination: url) {
                        Label("Call \(EmergencyNumber.current)", systemImage: "phone.fill")
                            .font(.title2.weight(.heavy))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(.white, in: RoundedRectangle(cornerRadius: 20))
                            .foregroundStyle(Theme.red)
                    }
                }
                if let lkw = record.lastKnownWell {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Text("Time since last known well: \(durationString(ctx.date.timeIntervalSince(lkw)))")
                            .font(.headline.monospacedDigit())
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(22)
            .frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [Theme.red, Theme.deepRed], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        } else if record.watch {
            banner(icon: "eye.fill", title: "Different from usual", text: "Something measured outside the normal range. Repeat the check in a few minutes. If anything looks wrong, call \(EmergencyNumber.current).", color: Theme.amber)
        } else {
            banner(icon: "checkmark.seal.fill", title: "No FAST signs found", text: "Keep watching. Stroke signs can appear later or come and go — if you notice any, call \(EmergencyNumber.current).", color: Theme.green)
        }
    }

    private func banner(icon: String, title: String, text: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 46))
            Text(title).font(.title.weight(.heavy))
            Text(text).multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(color, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func findingRow(_ letter: String, _ title: String, _ f: Finding, detail: String, neutral: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(letter)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(neutral ? Theme.ink : Theme.color(for: f), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    if !neutral { FindingBadge(finding: f) }
                }
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var faceDetail: String {
        guard let f = record.face else { return "Not tested" }
        if f.leftSmile + f.rightSmile == 1 && (f.smileAsymmetry == 1 || f.smileAsymmetry == 0) {
            return f.smileAsymmetry == 1 ? "Judged by eye: one side droops" : "Judged by eye: looks even"
        }
        var s = "Smile \(Int((1 - f.smileAsymmetry) * 100))% even"
        if let b = profile?.baseline { s += " (normal: \(Int((1 - b.face.smileAsymmetry) * 100))%)" }
        return s
    }

    private var armDetail: String {
        guard let a = record.arm else { return "Not tested" }
        return String(format: "Drift left %.0f° · right %.0f°", a.leftDrift, a.rightDrift)
    }

    private var speechDetail: String {
        guard let s = record.speech else { return "Not tested" }
        if s.transcript == "(judged by ear)" { return s.wordAccuracy < 0.5 ? "Judged by ear: slurred" : "Judged by ear: clear" }
        return "\(Int(s.wordAccuracy * 100))% of words clear — heard “\(s.transcript)”"
    }

    private var timeDetail: String {
        if record.lastKnownWellUnknown { return "Unknown — tell the paramedics when they were last seen normal" }
        guard let t = record.lastKnownWell else { return "—" }
        return "\(t.clock) (\(t.formatted(.relative(presentation: .named))))"
    }
}

/// Big, high-contrast summary to hand to the ambulance crew.
struct ParamedicCardView: View {
    let record: CheckRecord
    let profile: Profile?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("SUSPECTED STROKE — FAST CHECK")
                        .font(.headline.weight(.heavy)).foregroundStyle(Theme.red)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile?.name ?? record.personName).font(.largeTitle.weight(.heavy))
                        if let age = profile?.age { Text("Age \(age)").font(.title3) }
                    }

                    block("LAST KNOWN WELL") {
                        if record.lastKnownWellUnknown {
                            Text("UNKNOWN (woke with symptoms / not witnessed)").font(.title2.weight(.bold))
                        } else if let t = record.lastKnownWell {
                            Text(t.formatted(date: .abbreviated, time: .shortened)).font(.title.weight(.heavy))
                            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                                Text("\(durationString(ctx.date.timeIntervalSince(t))) ago").font(.title3.monospacedDigit())
                            }
                        }
                    }

                    block("BLOOD THINNERS") {
                        Text(profile == nil ? "Not recorded" : (profile!.takesBloodThinners ? "YES" : "No"))
                            .font(.title.weight(.heavy))
                            .foregroundStyle(profile?.takesBloodThinners == true ? Theme.red : .primary)
                        if let notes = profile?.medicalNotes, !notes.isEmpty { Text(notes).font(.body) }
                    }

                    block("FINDINGS (checked \(record.date.clock))") {
                        line("Face", record.faceFinding, record.face.map { $0.leftSmile + $0.rightSmile == 1 ? "judged by eye" : "smile \(Int((1 - $0.smileAsymmetry) * 100))% even" })
                        line("Arms", record.armFinding, record.arm.map { String(format: "drift L %.0f° / R %.0f°", $0.leftDrift, $0.rightDrift) })
                        line("Speech", record.speechFinding, record.speech.map { "\(Int($0.wordAccuracy * 100))% words clear" })
                        ForEach(record.otherSigns.list, id: \.self) { Text("• \($0)").font(.headline) }
                    }

                    Text("Generated by Onset on the phone. Measurements are a screening aid, not a diagnosis.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: shareText) { Image(systemName: "square.and.arrow.up") }
                }
            }
        }
    }

    private func block<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.heavy)).foregroundStyle(.secondary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func line(_ name: String, _ f: Finding, _ detail: String?) -> some View {
        HStack {
            Text(name).font(.headline).frame(width: 70, alignment: .leading)
            FindingBadge(finding: f)
            Text(detail ?? "").font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var shareText: String {
        var s = "SUSPECTED STROKE — \(profile?.name ?? record.personName)\n"
        if record.lastKnownWellUnknown { s += "Last known well: UNKNOWN\n" }
        else if let t = record.lastKnownWell { s += "Last known well: \(t.formatted(date: .abbreviated, time: .shortened))\n" }
        s += "Face: \(record.faceFinding.label) · Arms: \(record.armFinding.label) · Speech: \(record.speechFinding.label)\n"
        if let p = profile { s += "Blood thinners: \(p.takesBloodThinners ? "YES" : "no")\n" }
        s += "Checked with Onset at \(record.date.clock)"
        return s
    }
}

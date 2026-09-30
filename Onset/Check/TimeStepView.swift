import SwiftUI

/// B/E — the two signs FAST misses (balance, eyes), plus sudden headache or confusion.
struct OtherSignsStepView: View {
    let onDone: (OtherSigns) -> Void
    @State private var signs = OtherSigns()

    var body: some View {
        VStack(spacing: 18) {
            StepHeader(letter: "+", title: "Anything else sudden?", subtitle: "Tap any that started suddenly")
            VStack(spacing: 12) {
                toggle("Loss of balance or dizziness", "figure.fall", $signs.balance)
                toggle("Blurred, double or lost vision", "eye.trianglebadge.exclamationmark", $signs.eyes)
                toggle("Sudden, severe headache", "bolt.horizontal.circle", $signs.headache)
                toggle("Confusion or trouble understanding", "questionmark.bubble", $signs.confusion)
            }
            Spacer(minLength: 0)
            PrimaryButton(title: signs.any ? "Next" : "None of these — next", systemImage: "arrow.right") { onDone(signs) }
                .padding(.bottom, 8)
        }
        .padding(.horizontal)
    }

    private func toggle(_ title: String, _ icon: String, _ binding: Binding<Bool>) -> some View {
        Button {
            binding.wrappedValue.toggle()
            Haptics.tick()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title2).frame(width: 36)
                Text(title).font(.headline).multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: binding.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(binding.wrappedValue ? Theme.red : Color(.tertiaryLabel))
            }
            .padding(16)
            .background(binding.wrappedValue ? Theme.red.opacity(0.12) : Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// T — Time. The single most important fact for the hospital:
/// clot-busting treatment is only possible within a few hours of the last time
/// the person was known to be well.
struct TimeStepView: View {
    let onDone: (Date?, Bool) -> Void
    @State private var custom = Date()
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 16) {
            StepHeader(letter: "T", title: "Time", subtitle: "When were they last seen completely normal?")
            ScrollView {
                VStack(spacing: 10) {
                    option("Just now — it started in front of me", minutesAgo: 0)
                    option("About 15 minutes ago", minutesAgo: 15)
                    option("About 30 minutes ago", minutesAgo: 30)
                    option("About 1 hour ago", minutesAgo: 60)
                    option("About 2 hours ago", minutesAgo: 120)
                    Button { showPicker.toggle() } label: {
                        row("Pick the exact time", icon: "clock")
                    }.buttonStyle(.plain)
                    if showPicker {
                        DatePicker("Last known well", selection: $custom, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                        PrimaryButton(title: "Use \(custom.clock)") { onDone(custom, false) }
                    }
                    Button { onDone(nil, true) } label: {
                        row("Unknown / woke up like this", icon: "moon.zzz")
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
        .onAppear { Narrator.shared.say("When were they last seen completely normal?") }
    }

    private func option(_ title: String, minutesAgo: Double) -> some View {
        Button { onDone(Date().addingTimeInterval(-minutesAgo * 60), false) } label: {
            row(title, icon: "clock.arrow.circlepath")
        }
        .buttonStyle(.plain)
    }

    private func row(_ title: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title3).frame(width: 30).foregroundStyle(Theme.calm)
            Text(title).font(.headline)
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

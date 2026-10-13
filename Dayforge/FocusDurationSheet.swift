import SwiftUI

struct FocusDurationSheet: View {
    @ObservedObject var timer: FocusTimer
    var onSave: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPreset: Int?
    @State private var customText: String

    private let presets = [15, 25, 45, 60]

    init(timer: FocusTimer, onSave: @escaping (Int) -> Void) {
        self.timer = timer
        self.onSave = onSave
        let current = timer.totalSeconds / 60
        if [15, 25, 45, 60].contains(current) {
            _selectedPreset = State(initialValue: current)
            _customText = State(initialValue: "")
        } else {
            _selectedPreset = State(initialValue: nil)
            _customText = State(initialValue: String(current))
        }
    }

    private var trimmedCustomText: String {
        customText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var customMinutes: Int? {
        guard !trimmedCustomText.isEmpty else { return nil }
        return Int(trimmedCustomText)
    }

    private var duration: Int? {
        selectedPreset ?? customMinutes
    }

    private var validationMessage: String? {
        if timer.phase == .running { return "Pause the timer before changing its duration." }
        if selectedPreset != nil { return nil }
        guard !trimmedCustomText.isEmpty else { return "Choose a preset or enter a duration." }
        guard let customMinutes, (5...120).contains(customMinutes) else {
            return "Enter a whole number from 5 to 120 minutes."
        }
        return nil
    }

    private var canSave: Bool { duration != nil && validationMessage == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Focus duration")
                        .font(Theme.title(26))
                        .foregroundStyle(Theme.ink)

                    Text("Set the length of your next focus session. Saving resets the timer to the new duration.")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)

                    presetPicker
                    customField

                    if let validationMessage {
                        Label(validationMessage, systemImage: timer.phase == .running ? "pause.circle.fill" : "exclamationmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(timer.phase == .running ? Theme.blue : Theme.clay)
                    }

                    Button {
                        guard let duration else { return }
                        onSave(duration)
                        dismiss()
                    } label: {
                        Label("Save duration", systemImage: "checkmark")
                    }
                    .buttonStyle(FilledButtonStyle(tint: canSave ? Theme.blue : Theme.inkSoft.opacity(0.4)))
                    .disabled(!canSave)
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Focus settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var presetPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Presets")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.inkSoft)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(presets, id: \.self) { minutes in
                    Button {
                        selectedPreset = minutes
                        customText = ""
                    } label: {
                        Text("\(minutes) minutes")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(selectedPreset == minutes ? .white : Theme.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(selectedPreset == minutes ? Theme.blue : Theme.blue.opacity(0.14),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedPreset == minutes ? [.isSelected] : [])
                }
            }
        }
    }

    private var customField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom duration")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.inkSoft)

            HStack(spacing: 10) {
                TextField("5–120", text: $customText)
                    .font(Theme.number(28))
                    .keyboardType(.numberPad)
                    .onChange(of: customText) { _, newValue in
                        if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            selectedPreset = nil
                        }
                    }
                Text("minutes")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
        }
    }
}

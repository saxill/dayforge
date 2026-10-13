import SwiftUI

struct AlarmEditorSheet: View {
    let alarm: Alarm
    var onSave: (Alarm) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var time: Date
    @State private var label: String
    @State private var repeatOption: AlarmRepeatOption

    init(alarm: Alarm, onSave: @escaping (Alarm) -> Void) {
        self.alarm = alarm
        self.onSave = onSave
        _time = State(initialValue: Self.date(for: alarm))
        _label = State(initialValue: alarm.label)
        _repeatOption = State(initialValue: AlarmRepeatOption(repeatText: alarm.repeatText))
    }

    private var trimmedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool { !trimmedLabel.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    timeField
                    labelField
                    repeatPicker

                    Button {
                        save()
                    } label: {
                        Label("Save alarm", systemImage: "checkmark")
                    }
                    .buttonStyle(FilledButtonStyle(tint: canSave ? Theme.yellow : Theme.inkSoft.opacity(0.4), foreground: Theme.ink))
                    .disabled(!canSave)
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Edit alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var timeField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.inkSoft)
            DatePicker("Alarm time", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var labelField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Label")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.inkSoft)
            TextField("Wake-up", text: $label)
                .font(.system(size: 16, design: .rounded))
                .padding(16)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(canSave ? Theme.hairline : Theme.clay, lineWidth: canSave ? 1 : 2))
            if !canSave {
                Label("Add a label for this alarm.", systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.clay)
            }
        }
    }

    private var repeatPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Repeat")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.inkSoft)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(AlarmRepeatOption.allCases) { option in
                    Button {
                        repeatOption = option
                    } label: {
                        Text(option.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(repeatOption == option ? .white : Theme.yellow)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(repeatOption == option ? Theme.yellow : Theme.yellow.opacity(0.15),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(repeatOption == option ? [.isSelected] : [])
                }
            }
        }
    }

    private func save() {
        guard canSave else { return }
        let calendar = Calendar.current
        let updated = Alarm(hour: calendar.component(.hour, from: time),
                            minute: calendar.component(.minute, from: time),
                            label: trimmedLabel,
                            repeatText: repeatOption.title,
                            isOn: alarm.isOn)
        onSave(updated)
        dismiss()
    }

    private static func date(for alarm: Alarm) -> Date {
        Calendar.current.date(bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: Date()) ?? Date()
    }
}

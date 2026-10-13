import SwiftUI

struct BudgetSheet: View {
    let currentBudget: Double
    var onSave: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String
    @State private var showedValidation = false
    @FocusState private var amountFocused: Bool

    init(currentBudget: Double, onSave: @escaping (Double) -> Void) {
        self.currentBudget = currentBudget
        self.onSave = onSave
        _amountText = State(initialValue: String(format: "%.2f", currentBudget))
    }

    private var trimmedAmount: String {
        amountText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedAmount: Double? {
        let cleaned = trimmedAmount.replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Double(cleaned), value.isFinite else { return nil }
        return value
    }

    private var validationMessage: String? {
        if trimmedAmount.isEmpty { return showedValidation ? "Enter a monthly budget." : nil }
        guard let value = parsedAmount else { return "That doesn't look like a number." }
        if value <= 0 { return "Budget must be greater than 0." }
        if value > 1_000_000 { return "Budget must be at or below 1,000,000." }
        return nil
    }

    private var canSave: Bool { parsedAmount != nil && validationMessage == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Monthly budget")
                            .font(Theme.title(26))
                            .foregroundStyle(Theme.ink)
                        Text("Set the amount you want to keep this month's spending under.")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Theme.inkSoft)
                    }

                    amountField

                    Button {
                        save()
                    } label: {
                        Label("Save budget", systemImage: "checkmark")
                    }
                    .buttonStyle(FilledButtonStyle(tint: canSave ? Theme.clay : Theme.inkSoft.opacity(0.4)))
                    .disabled(!canSave)
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Edit budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { amountFocused = true }
        }
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amount")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.inkSoft)

            HStack {
                Text(Locale.current.currencySymbol ?? "$")
                    .font(Theme.number(30))
                    .foregroundStyle(Theme.inkSoft)
                TextField("600.00", text: $amountText)
                    .font(Theme.number(34))
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .onChange(of: amountText) { _, _ in showedValidation = true }
                    .accessibilityLabel("Monthly budget")
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(validationMessage == nil ? Theme.hairline : Theme.clay,
                                                                                        lineWidth: validationMessage == nil ? 1 : 2))

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.clay)
            }
        }
    }

    private func save() {
        showedValidation = true
        guard let value = parsedAmount, validationMessage == nil else { return }
        onSave(value)
        dismiss()
    }
}

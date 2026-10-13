import SwiftUI

struct AddExpenseSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var category: ExpenseCategory = .food
    @State private var note = ""
    @State private var showedValidation = false
    @FocusState private var amountFocused: Bool

    private let noteLimit = 80

    private var trimmedAmount: String {
        amountText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedAmount: Double? {
        let cleaned = trimmedAmount.replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Double(cleaned), value.isFinite else { return nil }
        return value
    }

    /// Nil when the input is valid (or still untouched).
    private var validationMessage: String? {
        if trimmedAmount.isEmpty {
            return showedValidation ? "Enter an amount." : nil
        }
        guard let value = parsedAmount else { return "That doesn't look like a number." }
        if value <= 0 { return "Amount must be greater than 0." }
        if value > 1_000_000 { return "That is above the 1,000,000 limit." }
        return nil
    }

    private var canSave: Bool { parsedAmount != nil && validationMessage == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    amountField
                    categoryPicker
                    noteField

                    Button {
                        save()
                    } label: {
                        Label("Save expense", systemImage: "checkmark")
                    }
                    .buttonStyle(FilledButtonStyle(tint: canSave ? Theme.clay : Theme.inkSoft.opacity(0.4)))
                    .disabled(!canSave)
                    .accessibilityHint(canSave ? "Adds the expense to this month" : "Enter a valid amount first")
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Add expense")
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
                TextField("0.00", text: $amountText)
                    .font(Theme.number(34))
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .onChange(of: amountText) { _, _ in showedValidation = true }
                    .accessibilityLabel("Expense amount")
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(validationMessage == nil ? Theme.hairline : Theme.clay, lineWidth: validationMessage == nil ? 1 : 2)
            )

            if let message = validationMessage {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.clay)
                    .accessibilityLabel("Error: \(message)")
            }
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.inkSoft)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                ForEach(ExpenseCategory.allCases) { item in
                    Button {
                        category = item
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 18, weight: .semibold))
                            Text(item.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(category == item ? .white : item.accent.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            category == item ? item.accent.color : item.accent.soft,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(item.title) category")
                    .accessibilityAddTraits(category == item ? [.isSelected] : [])
                }
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Note (optional)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
                Text("\(note.count)/\(noteLimit)")
                    .font(.system(size: 12, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.inkSoft)
            }
            TextField("What was it for?", text: $note)
                .font(.system(size: 16, design: .rounded))
                .padding(16)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
                .onChange(of: note) { _, newValue in
                    if newValue.count > noteLimit { note = String(newValue.prefix(noteLimit)) }
                }
                .accessibilityLabel("Expense note, optional")
        }
    }

    private func save() {
        showedValidation = true
        guard let value = parsedAmount, validationMessage == nil else { return }
        app.addExpense(amount: value, category: category, note: note)
        dismiss()
    }
}

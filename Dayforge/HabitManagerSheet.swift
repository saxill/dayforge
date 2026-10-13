import SwiftUI

struct HabitManagerSheet: View {
    let initialHabits: [Habit]
    var onSave: ([Habit]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftHabits: [Habit]
    @State private var editingHabit: Habit?

    init(habits: [Habit], onSave: @escaping ([Habit]) -> Void) {
        self.initialHabits = habits
        self.onSave = onSave
        _draftHabits = State(initialValue: habits)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Keep your daily list useful. Edit a habit's details, completion state, icon, or accent.")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)

                    if draftHabits.isEmpty {
                        EmptyStateView(icon: "leaf", title: "No habits yet", message: "Use Add habit to create your first daily check-in.")
                    } else {
                        ForEach(draftHabits) { habit in
                            habitRow(habit)
                        }
                    }

                    Button {
                        editingHabit = Habit(id: UUID().uuidString, title: "", detail: "", icon: "checkmark.circle.fill",
                                             accent: .moss, streak: 0, isDone: false)
                    } label: {
                        Label("Add habit", systemImage: "plus")
                    }
                    .buttonStyle(FilledButtonStyle(tint: Theme.moss))
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Manage habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(draftHabits)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(item: $editingHabit) { habit in
                HabitEditorSheet(habit: habit) { updated in
                    save(updated)
                } onDelete: { id in
                    draftHabits.removeAll { $0.id == id }
                    editingHabit = nil
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func habitRow(_ habit: Habit) -> some View {
        HStack(spacing: 12) {
            Button {
                editingHabit = habit
            } label: {
                HStack(spacing: 12) {
                    IconBadge(systemName: habit.icon, accent: habit.accent, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(habit.title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Text(habit.detail.isEmpty ? "No detail" : habit.detail)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(2)
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .buttonStyle(.plain)

            Toggle("Completed", isOn: completionBinding(for: habit.id))
                .labelsHidden()
                .tint(Theme.moss)
                .accessibilityLabel("\(habit.title) completed today")
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
    }

    private func completionBinding(for id: String) -> Binding<Bool> {
        Binding {
            draftHabits.first(where: { $0.id == id })?.isDone ?? false
        } set: { isDone in
            guard let index = draftHabits.firstIndex(where: { $0.id == id }) else { return }
            draftHabits[index].isDone = isDone
        }
    }

    private func save(_ updated: Habit) {
        if let index = draftHabits.firstIndex(where: { $0.id == updated.id }) {
            draftHabits[index] = updated
        } else {
            draftHabits.append(updated)
        }
    }
}

private struct HabitEditorSheet: View {
    let habitID: String
    let initialStreak: Int
    let isNew: Bool
    var onSave: (Habit) -> Void
    var onDelete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var detail: String
    @State private var icon: String
    @State private var accent: Accent
    @State private var isDone: Bool

    private let icons = ["checkmark.circle.fill", "drop.fill", "figure.walk", "book.fill", "pencil.line", "heart.fill", "moon.stars.fill", "figure.run"]

    init(habit: Habit, onSave: @escaping (Habit) -> Void, onDelete: @escaping (String) -> Void) {
        habitID = habit.id
        initialStreak = habit.streak
        isNew = habit.title.isEmpty
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: habit.title)
        _detail = State(initialValue: habit.detail)
        _icon = State(initialValue: habit.icon)
        _accent = State(initialValue: habit.accent)
        _isDone = State(initialValue: habit.isDone)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool { !trimmedTitle.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    textFields
                    iconPicker
                    accentPicker

                    Toggle("Completed today", isOn: $isDone)
                        .tint(Theme.moss)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))

                    if !canSave {
                        Label("Enter a habit title before saving.", systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.clay)
                    }

                    Button {
                        save()
                    } label: {
                        Label("Save habit", systemImage: "checkmark")
                    }
                    .buttonStyle(FilledButtonStyle(tint: canSave ? Theme.moss : Theme.inkSoft.opacity(0.4)))
                    .disabled(!canSave)

                    if !isNew {
                        Button(role: .destructive) {
                            onDelete(habitID)
                            dismiss()
                        } label: {
                            Label("Delete habit", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(isNew ? "New habit" : "Edit habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var textFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.inkSoft)
                TextField("e.g. Drink water", text: $title)
                    .font(.system(size: 16, design: .rounded))
                    .padding(16)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(canSave ? Theme.hairline : Theme.clay, lineWidth: canSave ? 1 : 2))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Detail")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.inkSoft)
                TextField("e.g. 8 glasses", text: $detail)
                    .font(.system(size: 16, design: .rounded))
                    .padding(16)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
            }
        }
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Icon")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.inkSoft)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 10)], spacing: 10) {
                ForEach(icons, id: \.self) { item in
                    Button {
                        icon = item
                    } label: {
                        Image(systemName: item)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(icon == item ? .white : accent.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(icon == item ? accent.color : accent.soft,
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(item) icon")
                    .accessibilityAddTraits(icon == item ? [.isSelected] : [])
                }
            }
        }
    }

    private var accentPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Accent")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.inkSoft)
            HStack(spacing: 12) {
                ForEach(Accent.allCases, id: \.self) { item in
                    Button {
                        accent = item
                    } label: {
                        Circle()
                            .fill(item.color)
                            .frame(width: 34, height: 34)
                            .overlay {
                                if accent == item {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(item.rawValue) accent")
                    .accessibilityAddTraits(accent == item ? [.isSelected] : [])
                }
            }
        }
    }

    private func save() {
        guard canSave else { return }
        onSave(Habit(id: habitID, title: trimmedTitle,
                     detail: detail.trimmingCharacters(in: .whitespacesAndNewlines), icon: icon,
                     accent: accent, streak: initialStreak, isDone: isDone))
        dismiss()
    }
}

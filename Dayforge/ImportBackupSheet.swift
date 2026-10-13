import SwiftUI

/// Shows what is inside a backup and lets you decide what each folder becomes before anything is added.
struct ImportBackupSheet: View {
    var backup: ParsedBackup
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var mapping: [Int: LibraryStatus] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("MangaPin backup")
                            .font(Theme.title(28))
                            .foregroundStyle(Theme.ink)
                        Text("\(backup.items.count) series · \(backup.fileName)")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Theme.inkSoft)
                        if backup.skipped > 0 {
                            Label("\(backup.skipped) entries had no title and will be skipped.", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.clay)
                        }
                    }

                    Text("Pick what each folder in your backup becomes. I guessed from how the series look, so check them.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)

                    ForEach(backup.folders, id: \.self) { folder in
                        folderCard(folder)
                    }

                    Button {
                        let count = app.importBackup(backup.items, statusForFolder: mapping)
                        _ = count
                        dismiss()
                    } label: {
                        Label("Import \(backup.items.count) series", systemImage: "square.and.arrow.down.fill")
                    }
                    .buttonStyle(FilledButtonStyle(tint: Theme.clay))
                    .accessibilityHint("Adds these series to your library")
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear {
                if mapping.isEmpty {
                    for folder in backup.folders { mapping[folder] = backup.suggestedStatus(forFolder: folder) }
                }
            }
        }
    }

    private func folderCard(_ folder: Int) -> some View {
        let group = backup.items(inFolder: folder)
        let status = mapping[folder] ?? backup.suggestedStatus(forFolder: folder)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Folder \(folder)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(group.count) series")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.inkSoft)
            }

            Text(group.prefix(3).map(\.name).joined(separator: " · "))
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(2)

            Menu {
                ForEach(LibraryStatus.allCases) { option in
                    Button {
                        mapping[folder] = option
                    } label: {
                        Label(option.title, systemImage: status == option ? "checkmark" : option.icon)
                    }
                }
            } label: {
                HStack {
                    Label(status.title, systemImage: status.icon)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(status.accent.color)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(status.accent.soft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .accessibilityLabel("Folder \(folder) becomes \(status.title)")
            .accessibilityHint("Choose a status for this folder")
        }
        .dayCard(padding: 14)
    }
}

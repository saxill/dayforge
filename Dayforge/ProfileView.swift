import SwiftUI
import PhotosUI

/// Profile tab: the blob avatar, account and cloud sync, and every setting that changes how the app looks.
struct ProfileView: View {
    @EnvironmentObject private var app: AppState
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var showAuth = false
    @State private var showPairing = false
    @State private var confirmDelete = false
    @State private var deleteError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                accountCard
                if app.account != nil { teamCard }
                customizeAvatar
                customizeTheme
                customizeToday
                cloudCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .sheet(isPresented: $showAuth) {
            AuthSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPairing) {
            PairingSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let raw = try? await item.loadTransferable(type: Data.self), let small = AvatarImage.prepare(raw) {
                    app.profile.avatarData = small
                }
                pickedPhoto = nil
            }
        }
        .alert("Delete your account?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                Task {
                    do { try await app.deleteAccount() } catch { deleteError = error.localizedDescription }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your account and the synced copy of your data from the server. Data on this phone stays.")
        }
        .alert("Couldn't delete", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    private var teamCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Team", trailing: teamStatus)
            Text("A private motivation partner can see your Pulse, daily ritual totals, focus momentum and shared aggregate history. Habit definitions, names and IDs, plus expenses, alarms, manga and notes stay private.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Theme.inkSoft)
            Button {
                showPairing = true
            } label: {
                Label(teamActionTitle, systemImage: "person.2.fill")
            }
            .buttonStyle(FilledButtonStyle(tint: Theme.moss))
            .accessibilityLabel(teamActionTitle)
            .accessibilityHint("Opens your private motivation partner settings")
        }
        .dayCard()
    }

    private var teamStatus: String {
        guard let pair = app.pair else { return "not set up" }
        return pair.status == "waiting" ? "code ready" : "connected"
    }

    private var teamActionTitle: String {
        guard let pair = app.pair else { return "Set up a motivation partner" }
        return pair.status == "waiting" ? "Open team code" : "Open motivation team"
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 6) {
            AvatarView(data: app.profile.avatarData, name: app.profile.name, size: 130)
            PhotosPicker(selection: $pickedPhoto, matching: .images) {
                Label(app.profile.avatarData == nil ? "Add a photo" : "Change photo", systemImage: "photo.badge.plus")
            }
            .buttonStyle(SoftButtonStyle(tint: Theme.moss))
            .accessibilityHint("Pick a picture from your photos")
            if app.profile.avatarData != nil {
                Button("Remove photo") { app.profile.avatarData = nil }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.inkSoft)
            }
            Text(app.profile.name.isEmpty ? "Your profile" : app.profile.name)
                .font(Theme.title(28))
                .foregroundStyle(Theme.ink)
            Text(app.account?.email ?? "Not signed in")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    // MARK: Account

    @ViewBuilder
    private var accountCard: some View {
        if let account = app.account {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Signed in").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(Theme.ink)
                        Text(account.email).font(.system(size: 13, design: .rounded)).foregroundStyle(Theme.inkSoft)
                    }
                    Spacer()
                    syncBadge
                }
                HStack(spacing: 10) {
                    Button { Task { await app.pullAndMerge(preferRemote: true) } } label: {
                        Label("Fetch from cloud", systemImage: "icloud.and.arrow.down")
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .buttonStyle(SoftButtonStyle(tint: Theme.moss))
                    .frame(maxWidth: .infinity)
                    Button { Task { await app.push(app.makeCloudData()) } } label: {
                        Label("Back up now", systemImage: "icloud.and.arrow.up")
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .buttonStyle(SoftButtonStyle(tint: Theme.blue))
                    .frame(maxWidth: .infinity)
                }
                if let last = app.lastSynced {
                    Text("Last synced \(last.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 12, design: .rounded)).foregroundStyle(Theme.inkSoft)
                }
                if case .failed(let message) = app.syncState {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.clay)
                }
            }
            .dayCard()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Keep your data safe")
                    .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(Theme.ink)
                Text("Sign in and Dayforge backs up your habits, spending, drill scores, library and settings to your own cloud, then brings them back on any phone you install it on.")
                    .font(.system(size: 14, design: .rounded)).foregroundStyle(Theme.inkSoft)
                Button { showAuth = true } label: { Label("Sign in or create account", systemImage: "person.crop.circle.badge.plus") }
                    .buttonStyle(FilledButtonStyle(tint: Theme.moss))
            }
            .dayCard()
        }
    }

    @ViewBuilder
    private var syncBadge: some View {
        switch app.syncState {
        case .syncing:
            ProgressView()
        case .idle:
            Label("Synced", systemImage: "checkmark.icloud.fill")
                .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(Theme.moss)
        case .failed:
            Label("Retry", systemImage: "exclamationmark.icloud.fill")
                .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(Theme.clay)
        case .signedOut:
            EmptyView()
        }
    }

    // MARK: Customise

    private var customizeAvatar: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "You")
            TextField("Your name", text: Binding(get: { app.profile.name }, set: { app.profile.name = $0 }))
                .textContentType(.name)
                .font(.system(size: 16, design: .rounded))
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Theme.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel("Your name")
        }
        .dayCard()
    }

    private var customizeTheme: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Colours", trailing: "whole app")
            HStack(spacing: 10) {
                ForEach(ThemePreset.allCases) { preset in
                    Button { withAnimation(.snappy) { app.profile.theme = preset } } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle().fill(preset.brand).frame(width: 44, height: 44)
                                Circle().fill(preset.highlight).frame(width: 16, height: 16).offset(x: 14, y: 14)
                            }
                            Text(preset.title).font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.ink)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(app.profile.theme == preset ? preset.brand.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(app.profile.theme == preset ? preset.brand : Theme.hairline, lineWidth: app.profile.theme == preset ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(preset.title) colours")
                    .accessibilityAddTraits(app.profile.theme == preset ? [.isSelected] : [])
                }
            }
        }
        .dayCard()
    }

    private var customizeToday: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "Today screen", trailing: "show or hide")
            ForEach(TodaySection.allCases) { section in
                Toggle(isOn: Binding(
                    get: { app.profile.shows(section) },
                    set: { on in
                        if on { app.profile.hiddenSections.remove(section) } else { app.profile.hiddenSections.insert(section) }
                    })) {
                    Label(section.title, systemImage: section.icon)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.moss)
                .padding(.vertical, 6)
            }
        }
        .dayCard()
    }

    // MARK: Cloud

    private var cloudCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Cloud")
            Text("Your personal Dayforge data syncs securely when you sign in. The sync service is managed by the app.")
                .font(.system(size: 13, design: .rounded)).foregroundStyle(Theme.inkSoft)
            if app.account != nil {
                HStack(spacing: 10) {
                    Button { Task { await app.signOut() } } label: { Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right") }
                        .buttonStyle(SoftButtonStyle(tint: Theme.ink))
                    Button { confirmDelete = true } label: { Label("Delete account", systemImage: "trash") }
                        .buttonStyle(SoftButtonStyle(tint: Theme.clay))
                }
            }
        }
        .dayCard()
    }
}

/// Email and password sign in / sign up against the Dayforge sync service.
struct AuthSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var creating = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var busy = false
    @State private var error: String?

    private var valid: Bool {
        email.contains("@") && email.contains(".") && password.count >= (creating ? 8 : 1)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(creating ? "Create your account" : "Welcome back")
                        .font(Theme.title(28)).foregroundStyle(Theme.ink)
                    Picker("Mode", selection: $creating) {
                        Text("Sign in").tag(false)
                        Text("Create account").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if creating {
                        field("Name", text: $name, content: .name)
                    }
                    field("Email", text: $email, content: .emailAddress, keyboard: .emailAddress)
                    VStack(alignment: .leading, spacing: 6) {
                        SecureField(creating ? "Password (8+ characters)" : "Password", text: $password)
                            .textContentType(creating ? .newPassword : .password)
                            .font(.system(size: 16, design: .rounded))
                            .padding(.horizontal, 14).padding(.vertical, 14)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
                    }
                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Theme.clay)
                    }
                    Button { submit() } label: {
                        if busy { ProgressView().tint(.white) } else { Text(creating ? "Create account" : "Sign in") }
                    }
                    .buttonStyle(FilledButtonStyle(tint: Theme.moss))
                    .disabled(!valid || busy)
                    .opacity(valid ? 1 : 0.5)
                    Text("Sign in with Apple and Google need extra setup, so they aren't here yet.")
                        .font(.system(size: 12, design: .rounded)).foregroundStyle(Theme.inkSoft)
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func field(_ title: String, text: Binding<String>, content: UITextContentType, keyboard: UIKeyboardType = .default) -> some View {
        TextField(title, text: text)
            .textContentType(content)
            .keyboardType(keyboard)
            .textInputAutocapitalization(content == .name ? .words : .never)
            .autocorrectionDisabled()
            .font(.system(size: 16, design: .rounded))
            .padding(.horizontal, 14).padding(.vertical, 14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
    }

    private func submit() {
        busy = true
        error = nil
        Task {
            do {
                if creating {
                    try await app.register(email: email, password: password, name: name)
                } else {
                    try await app.signIn(email: email, password: password)
                }
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }
}

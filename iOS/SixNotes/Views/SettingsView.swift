import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var notesManager: NotesManager
    @Environment(\.dismiss) var dismiss

    private var accountStatusText: String {
        switch notesManager.syncEngine.accountStatus {
        case .available:
            return "Available"
        case .noAccount:
            return "No iCloud Account"
        case .restricted:
            return "Restricted"
        case .couldNotDetermine:
            return "Unknown"
        case .temporarilyUnavailable:
            return "Temporarily Unavailable"
        }
    }

    private var accountStatusColor: Color {
        switch notesManager.syncEngine.accountStatus {
        case .available:
            return .green
        case .noAccount, .restricted:
            return .red
        case .couldNotDetermine, .temporarilyUnavailable:
            return .orange
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("iCloud Sync", isOn: $notesManager.isSyncEnabled)

                    if notesManager.isSyncEnabled {
                        HStack {
                            Text("Account")
                            Spacer()
                            Text(accountStatusText)
                                .foregroundColor(accountStatusColor)
                        }

                        HStack {
                            Text("Status")
                            Spacer()
                            SyncStatusView(
                                isSyncing: notesManager.isSyncing,
                                lastSyncDate: notesManager.lastSyncDate,
                                syncError: notesManager.syncError
                            )
                        }

                        Button {
                            Task {
                                await notesManager.performSync()
                            }
                        } label: {
                            HStack {
                                Text("Sync Now")
                                Spacer()
                                if notesManager.isSyncing {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(notesManager.isSyncing)
                    }
                } header: {
                    Text("iCloud")
                } footer: {
                    if notesManager.isSyncEnabled {
                        Text("Notes sync automatically when edited. Changes from other devices appear within seconds.")
                    }
                }

                Section("Editor Font") {
                    FontSettingRow(fontSetting: $notesManager.textFont, availableFonts: FontSetting.availableFonts)
                }

                Section("Code Font") {
                    FontSettingRow(fontSetting: $notesManager.codeFont, availableFonts: FontSetting.availableMonoFonts)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SyncStatusView: View {
    let isSyncing: Bool
    let lastSyncDate: Date?
    let syncError: String?

    var body: some View {
        HStack(spacing: 6) {
            if isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Syncing...")
                    .foregroundColor(.secondary)
            } else if let error = syncError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(error)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else if let date = lastSyncDate {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(date.formatted(.relative(presentation: .named)))
                    .foregroundColor(.secondary)
            } else {
                Text("Never synced")
                    .foregroundColor(.secondary)
            }
        }
        .font(.caption)
    }
}

struct FontSettingRow: View {
    @Binding var fontSetting: FontSetting
    let availableFonts: [String]

    var body: some View {
        Picker("Font", selection: $fontSetting.name) {
            ForEach(availableFonts, id: \.self) { fontName in
                Text(fontName)
                    .tag(fontName)
            }
        }

        HStack {
            Text("Size")
            Spacer()
            Stepper("\(Int(fontSetting.size)) pt", value: $fontSetting.size, in: 10...32, step: 1)
        }

        Text("Preview: The quick brown fox")
            .font(fontSetting.font)
            .foregroundColor(.secondary)
    }
}

#Preview {
    SettingsView()
        .environmentObject(NotesManager())
}

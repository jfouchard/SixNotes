import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var notesManager: NotesManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
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

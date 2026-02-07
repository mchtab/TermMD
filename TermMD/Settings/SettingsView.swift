import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) var dismiss
    @State private var shellPathValid = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.bold)

            Form {
                TextField("Claude Command:", text: $appSettings.claudeCommand)
                    .textFieldStyle(.roundedBorder)

                Toggle("Auto-save before Send to Claude", isOn: $appSettings.autoSaveBeforeSend)

                HStack {
                    TextField("Shell Path:", text: $appSettings.shellPath)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: appSettings.shellPath) { newValue in
                            shellPathValid = FileManager.default.isExecutableFile(atPath: newValue)
                        }
                    if !shellPathValid {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                            .help("Shell path is not a valid executable")
                    }
                }
            }

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 450)
        .onAppear {
            shellPathValid = FileManager.default.isExecutableFile(atPath: appSettings.shellPath)
        }
    }
}

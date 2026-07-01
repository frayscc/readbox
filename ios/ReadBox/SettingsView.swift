import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiBaseURL = ReadBoxSettings.apiBaseURL
    @State private var apiToken = ReadBoxSettings.apiToken

    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("https://readbox.example.com", text: $apiBaseURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    SecureField("API Token", text: $apiToken)
                }

                Section {
                    Button("Save") {
                        ReadBoxSettings.apiBaseURL = apiBaseURL
                        ReadBoxSettings.apiToken = apiToken
                        onSave()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

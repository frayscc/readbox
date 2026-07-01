import SwiftUI

struct AddURLView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var title = ""
    @State private var isSaving = false
    @State private var message: String?

    private let client = ReadBoxAPIClient()
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Article") {
                    TextField("https://example.com/article", text: $url)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("Optional title", text: $title)
                }

                if let message {
                    Section {
                        Text(message)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(isSaving ? "Saving..." : "Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Add URL")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        message = nil
        defer { isSaving = false }

        do {
            _ = try await client.createItem(
                url: url.trimmingCharacters(in: .whitespacesAndNewlines),
                title: title.isEmpty ? nil : title,
                source: "web"
            )
            onSave()
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}

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
            ZStack {
                ReadBoxTheme.bg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    Capsule()
                        .fill(ReadBoxTheme.border)
                        .frame(width: 44, height: 5)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("添加 URL")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(ReadBoxTheme.inkDeep)
                        Text("保存后会立即进入列表，后端继续解析正文。")
                            .font(.subheadline)
                            .foregroundStyle(ReadBoxTheme.muted)
                    }

                    ReadBoxCard {
                        VStack(alignment: .leading, spacing: 14) {
                            FieldLabel("网页链接")
                            TextField("https://example.com/article", text: $url)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                .textFieldStyle(ReadBoxTextFieldStyle())

                            FieldLabel("标题（可选）")
                            TextField("Optional title", text: $title)
                                .textFieldStyle(ReadBoxTextFieldStyle())
                        }
                    }

                    if let message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(ReadBoxTheme.muted)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ReadBoxTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button(isSaving ? "保存中..." : "保存到 ReadBox") {
                        Task { await save() }
                    }
                    .buttonStyle(ReadBoxPrimaryButtonStyle())
                    .disabled(isSaving || url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()
                }
                .padding(18)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundStyle(ReadBoxTheme.ink)
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
                source: "ios"
            )
            onSave()
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}

struct FieldLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(ReadBoxTheme.inkDeep)
    }
}

struct ReadBoxTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(ReadBoxTheme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(ReadBoxTheme.border, lineWidth: 1)
            }
    }
}

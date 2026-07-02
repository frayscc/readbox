import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiBaseURL = ReadBoxSettings.apiBaseURL
    @State private var username = ReadBoxSettings.username
    @State private var password = ""
    @State private var message: String?
    @State private var isSaving = false

    private let apiClient = ReadBoxAPIClient()

    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                ReadBoxTheme.bg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        ReadBoxMark(size: 34)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("设置")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(ReadBoxTheme.inkDeep)
                            Text("连接你的自部署 ReadBox 服务")
                                .font(.subheadline)
                                .foregroundStyle(ReadBoxTheme.muted)
                        }
                    }

                    ReadBoxCard {
                        VStack(alignment: .leading, spacing: 14) {
                            FieldLabel("API Base URL")
                            TextField("https://readbox.example.com", text: $apiBaseURL)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                .textFieldStyle(ReadBoxTextFieldStyle())

                            FieldLabel("用户名")
                            TextField("readbox", text: $username)
                                .textInputAutocapitalization(.never)
                                .textFieldStyle(ReadBoxTextFieldStyle())

                            FieldLabel("密码")
                            SecureField("Password", text: $password)
                                .textFieldStyle(ReadBoxTextFieldStyle())
                        }
                    }

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(ReadBoxTheme.danger)
                    }

                    Text("密码不会保存在本机。Chrome 插件和 Web 端需要分别登录。")
                        .font(.footnote)
                        .foregroundStyle(ReadBoxTheme.muted)

                    Button(isSaving ? "正在登录..." : "登录并保存") {
                        Task { await save() }
                    }
                    .buttonStyle(ReadBoxPrimaryButtonStyle())
                    .disabled(isSaving)

                    Spacer()
                }
                .padding(18)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
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
        do {
            let session = try await apiClient.login(
                apiBaseURL: apiBaseURL,
                username: username,
                password: password
            )
            ReadBoxSettings.apiBaseURL = apiBaseURL
            ReadBoxSettings.username = session.username
            ReadBoxSettings.apiToken = session.accessToken
            onSave()
            dismiss()
        } catch {
            message = error.localizedDescription
        }
        isSaving = false
    }
}

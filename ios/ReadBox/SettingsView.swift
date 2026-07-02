import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiBaseURL = ReadBoxSettings.apiBaseURL
    @State private var apiToken = ReadBoxSettings.apiToken

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

                            FieldLabel("API Token")
                            SecureField("API Token", text: $apiToken)
                                .textFieldStyle(ReadBoxTextFieldStyle())
                        }
                    }

                    Text("这些信息只保存在本机。Chrome 插件和 Web 端需要分别配置。")
                        .font(.footnote)
                        .foregroundStyle(ReadBoxTheme.muted)

                    Button("保存设置") {
                        ReadBoxSettings.apiBaseURL = apiBaseURL
                        ReadBoxSettings.apiToken = apiToken
                        onSave()
                        dismiss()
                    }
                    .buttonStyle(ReadBoxPrimaryButtonStyle())

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
}

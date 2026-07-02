import SwiftUI

struct ShareExtensionView: View {
    @StateObject private var viewModel: ShareViewModel

    init(extensionContext: NSExtensionContext?) {
        _viewModel = StateObject(wrappedValue: ShareViewModel(extensionContext: extensionContext))
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(ReadBoxTheme.border)
                .frame(width: 42, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 8)

            header

            VStack(spacing: 16) {
                statusIcon

                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(ReadBoxTheme.inkDeep)

                Text(viewModel.message)
                    .font(.subheadline)
                    .foregroundStyle(ReadBoxTheme.muted)
                    .multilineTextAlignment(.center)

                if viewModel.isSaving {
                    ProgressView()
                        .tint(ReadBoxTheme.ink)
                }

                Button(viewModel.isSuccess ? "完成" : "关闭") {
                    viewModel.close()
                }
                .buttonStyle(viewModel.isSuccess ? AnyButtonStyle(ReadBoxPrimaryButtonStyle()) : AnyButtonStyle(ReadBoxSecondaryButtonStyle()))
            }
            .padding(20)
        }
        .background(ReadBoxTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(ReadBoxTheme.border, lineWidth: 1)
        }
        .padding(14)
        .task {
            await viewModel.saveSharedURL()
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 9) {
                ReadBoxMark(size: 30)
                Text("ReadBox")
                    .font(.headline)
                    .foregroundStyle(ReadBoxTheme.inkDeep)
            }

            Spacer()

            Button("关闭") {
                viewModel.close()
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(ReadBoxTheme.muted)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ReadBoxTheme.border)
                .frame(height: 1)
        }
    }

    private var statusIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(iconBackground)
                .frame(width: 48, height: 48)

            Image(systemName: iconName)
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(iconForeground)
        }
    }

    private var title: String {
        if viewModel.isSaving { return "正在保存" }
        return viewModel.isSuccess ? "已保存" : "保存失败"
    }

    private var iconName: String {
        if viewModel.isSaving { return "arrow.triangle.2.circlepath" }
        return viewModel.isSuccess ? "checkmark" : "xmark"
    }

    private var iconBackground: Color {
        if viewModel.isSuccess || viewModel.isSaving {
            return ReadBoxTheme.accent.opacity(0.24)
        }
        return ReadBoxTheme.danger.opacity(0.14)
    }

    private var iconForeground: Color {
        if viewModel.isSuccess || viewModel.isSaving {
            return ReadBoxTheme.inkDeep
        }
        return ReadBoxTheme.danger
    }
}

struct ReadBoxSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(ReadBoxTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(ReadBoxTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(ReadBoxTheme.border, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        make = { configuration in AnyView(style.makeBody(configuration: configuration)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        make(configuration)
    }
}

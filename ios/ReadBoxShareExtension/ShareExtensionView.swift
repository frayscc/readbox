import SwiftUI

struct ShareExtensionView: View {
    @StateObject private var viewModel: ShareViewModel

    init(extensionContext: NSExtensionContext?) {
        _viewModel = StateObject(wrappedValue: ShareViewModel(extensionContext: extensionContext))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: viewModel.isSuccess ? "checkmark.circle.fill" : "square.and.arrow.down")
                    .font(.system(size: 44))
                    .foregroundStyle(viewModel.isSuccess ? .green : .accentColor)

                Text("Save to ReadBox")
                    .font(.title2.weight(.semibold))

                Text(viewModel.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if viewModel.isSaving {
                    ProgressView()
                }

                Button(viewModel.isSuccess ? "Done" : "Close") {
                    viewModel.close()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(28)
            .task {
                await viewModel.saveSharedURL()
            }
        }
    }
}

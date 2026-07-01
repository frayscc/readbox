import Foundation
import UniformTypeIdentifiers

@MainActor
final class ShareViewModel: ObservableObject {
    @Published var message = "Preparing shared item..."
    @Published var isSaving = false
    @Published var isSuccess = false

    private weak var extensionContext: NSExtensionContext?
    private let client = ReadBoxAPIClient()

    init(extensionContext: NSExtensionContext?) {
        self.extensionContext = extensionContext
    }

    func saveSharedURL() async {
        guard !isSaving, !isSuccess else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            guard ReadBoxSettings.isConfigured else {
                throw ReadBoxAPIError.notConfigured
            }

            guard let url = try await extractURL() else {
                throw ReadBoxAPIError.server("No URL found in the shared item.")
            }

            _ = try await client.createItem(url: url.absoluteString, title: nil, source: "ios_share")
            isSuccess = true
            message = "Saved successfully."
        } catch {
            isSuccess = false
            message = error.localizedDescription
        }
    }

    func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func extractURL() async throws -> URL? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            return nil
        }

        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let url = try await loadURL(from: provider) {
                    return url
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let text = try await loadText(from: provider),
                   let url = firstURL(in: text) {
                    return url
                }
            }
        }

        return nil
    }

    private func loadURL(from provider: NSItemProvider) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let string = item as? String {
                    continuation.resume(returning: URL(string: string))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadText(from provider: NSItemProvider) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let string = item as? String {
                    continuation.resume(returning: string)
                } else if let data = item as? Data {
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func firstURL(in text: String) -> URL? {
        let pattern = #"https?://[^\s<>"']+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let urlRange = Range(match.range, in: text) else {
            return nil
        }

        return URL(string: String(text[urlRange]))
    }
}

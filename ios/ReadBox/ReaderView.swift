import SwiftUI
import WebKit

struct ReaderView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: ReadBoxItem
    @State private var message: String?

    private let client = ReadBoxAPIClient()
    let onChange: () -> Void

    init(item: ReadBoxItem, onChange: @escaping () -> Void) {
        _item = State(initialValue: item)
        self.onChange = onChange
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.title ?? item.url)
                    .font(.largeTitle.weight(.bold))

                Link("Open Original", destination: URL(string: item.canonicalURL ?? item.url)!)
                    .font(.subheadline)

                if let message {
                    Text(message)
                        .foregroundStyle(.secondary)
                }

                if let html = item.contentHTML, !html.isEmpty {
                    HTMLReader(html: html)
                        .frame(minHeight: 480)
                } else {
                    Text(item.contentText ?? "No extracted article body yet. Open the original link to read it.")
                        .font(.body)
                        .lineSpacing(6)
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding()
        }
        .navigationTitle("Reader")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task { await toggleRead() }
                } label: {
                    Image(systemName: item.status == .read ? "envelope.open" : "checkmark.circle")
                }

                Button {
                    Task { await toggleFavorite() }
                } label: {
                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                }

                Button(role: .destructive) {
                    Task { await delete() }
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }

    private func toggleRead() async {
        do {
            item = try await client.updateItem(
                id: item.id,
                status: item.status == .read ? .unread : .read
            )
            onChange()
        } catch {
            message = error.localizedDescription
        }
    }

    private func toggleFavorite() async {
        do {
            item = try await client.updateItem(id: item.id, isFavorite: !item.isFavorite)
            onChange()
        } catch {
            message = error.localizedDescription
        }
    }

    private func delete() async {
        do {
            _ = try await client.deleteItem(id: item.id)
            onChange()
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}

struct HTMLReader: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let document = """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body { font: -apple-system-body; line-height: 1.65; padding: 0; margin: 0; color: CanvasText; background: Canvas; }
            img, video { max-width: 100%; height: auto; }
            pre { overflow-x: auto; }
          </style>
        </head>
        <body>\(html)</body>
        </html>
        """
        webView.loadHTMLString(document, baseURL: nil)
    }
}

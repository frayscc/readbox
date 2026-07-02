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
        ZStack {
            ReadBoxTheme.reader.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(item.title ?? item.url)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .lineSpacing(2)
                        .foregroundStyle(ReadBoxTheme.inkDeep)

                    HStack(spacing: 12) {
                        Text(item.siteName ?? URL(string: item.url)?.host ?? "ReadBox")
                        Text("保存于 ReadBox")
                    }
                    .font(.caption)
                    .foregroundStyle(ReadBoxTheme.muted)

                    if let message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(ReadBoxTheme.muted)
                            .padding(12)
                            .background(ReadBoxTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    if let html = item.contentHTML, !html.isEmpty {
                        HTMLReader(html: html)
                            .frame(minHeight: 520)
                    } else {
                        Text(item.contentText ?? "暂无提取正文。可以打开原文链接阅读，保存记录已经保留。")
                            .font(.system(size: 18, design: .serif))
                            .lineSpacing(8)
                            .foregroundStyle(ReadBoxTheme.ink)
                    }
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("阅读")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let originalURL = URL(string: item.canonicalURL ?? item.url) {
                    Link(destination: originalURL) {
                        Image(systemName: "safari")
                    }
                }

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

    private func loadDetail() async {
        do {
            item = try await client.getItem(id: item.id)
        } catch {
            message = error.localizedDescription
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
            body {
              color: #183b34;
              background: #fffef9;
              font-family: "LXGW WenKai Screen", "Songti SC", "Noto Serif CJK SC", serif;
              font-size: 18px;
              line-height: 1.82;
              padding: 0;
              margin: 0;
            }
            p, li, blockquote { margin: 0 0 1.05em; }
            h1, h2, h3 {
              color: #0c211e;
              font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif;
              line-height: 1.25;
              margin: 1.4em 0 .7em;
            }
            img, video { max-width: 100%; height: auto; border-radius: 12px; }
            pre {
              overflow-x: auto;
              border: 1px solid #dce5df;
              border-radius: 12px;
              padding: 12px;
              background: #ffffff;
            }
          </style>
        </head>
        <body>\(html)</body>
        </html>
        """
        webView.loadHTMLString(document, baseURL: nil)
    }
}

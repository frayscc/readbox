import Foundation

enum ItemListMode: String, CaseIterable, Identifiable {
    case unread
    case read
    case favorite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unread: return "未读"
        case .read: return "已读"
        case .favorite: return "收藏"
        }
    }
}

@MainActor
final class ItemListViewModel: ObservableObject {
    @Published var items: [ReadBoxItem] = []
    @Published var mode: ItemListMode = .unread
    @Published var isLoading = false
    @Published var message: String?

    private let client = ReadBoxAPIClient()

    func load() async {
        guard ReadBoxSettings.isConfigured else {
            items = []
            message = "请先在设置里配置服务地址和 Token。"
            return
        }

        isLoading = true
        message = nil
        defer { isLoading = false }

        do {
            switch mode {
            case .unread:
                items = try await client.listItems(status: "unread")
            case .read:
                items = try await client.listItems(status: "read")
            case .favorite:
                items = try await client.listItems(status: "all", favorite: true)
            }
        } catch {
            items = []
            message = error.localizedDescription
        }
    }
}

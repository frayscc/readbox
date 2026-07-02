import Foundation

struct ReadBoxItem: Identifiable, Codable, Equatable, Hashable {
    let id: Int
    let url: String
    let canonicalURL: String?
    var title: String?
    let author: String?
    let siteName: String?
    let excerpt: String?
    let contentHTML: String?
    let contentText: String?
    let coverURL: String?
    var status: ItemStatus
    var isFavorite: Bool
    let source: String?
    let createdAt: String
    let updatedAt: String
    let readAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case canonicalURL = "canonical_url"
        case title
        case author
        case siteName = "site_name"
        case excerpt
        case contentHTML = "content_html"
        case contentText = "content_text"
        case coverURL = "cover_url"
        case status
        case isFavorite = "is_favorite"
        case source
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case readAt = "read_at"
    }
}

enum ItemStatus: String, Codable, Hashable {
    case unread
    case read
    case deleted
}

struct ItemListResponse: Codable {
    let items: [ReadBoxItem]
    let limit: Int
    let offset: Int
}

struct CreateItemRequest: Codable {
    let url: String
    let title: String?
    let source: String
}

struct UpdateItemRequest: Codable {
    let status: ItemStatus?
    let isFavorite: Bool?
    let title: String?

    enum CodingKeys: String, CodingKey {
        case status
        case isFavorite = "is_favorite"
        case title
    }
}

struct LoginRequest: Codable {
    let username: String
    let password: String
}

struct LoginResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let username: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case username
    }
}

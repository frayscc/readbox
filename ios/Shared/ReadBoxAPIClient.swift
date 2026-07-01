import Foundation

enum ReadBoxAPIError: LocalizedError {
    case notConfigured
    case invalidBaseURL
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "ReadBox server is not configured."
        case .invalidBaseURL:
            return "API Base URL is invalid."
        case .invalidResponse:
            return "Server returned an invalid response."
        case .server(let message):
            return message
        }
    }
}

final class ReadBoxAPIClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func listItems(status: String = "unread", favorite: Bool? = nil) async throws -> [ReadBoxItem] {
        var query = [URLQueryItem(name: "status", value: status)]
        if let favorite {
            query.append(URLQueryItem(name: "favorite", value: favorite ? "true" : "false"))
        }

        var components = try components(path: "/api/items")
        components.queryItems = query
        let response: ItemListResponse = try await request(components.url!, method: "GET")
        return response.items
    }

    func createItem(url: String, title: String? = nil, source: String) async throws -> ReadBoxItem {
        try await request(
            endpoint(path: "/api/items"),
            method: "POST",
            body: CreateItemRequest(url: url, title: title, source: source)
        )
    }

    func updateItem(
        id: Int,
        status: ItemStatus? = nil,
        isFavorite: Bool? = nil,
        title: String? = nil
    ) async throws -> ReadBoxItem {
        try await request(
            endpoint(path: "/api/items/\(id)"),
            method: "PATCH",
            body: UpdateItemRequest(status: status, isFavorite: isFavorite, title: title)
        )
    }

    func deleteItem(id: Int) async throws -> ReadBoxItem {
        try await request(endpoint(path: "/api/items/\(id)"), method: "DELETE")
    }

    private func endpoint(path: String) throws -> URL {
        guard let url = try components(path: path).url else {
            throw ReadBoxAPIError.invalidBaseURL
        }
        return url
    }

    private func components(path: String) throws -> URLComponents {
        guard ReadBoxSettings.isConfigured else {
            throw ReadBoxAPIError.notConfigured
        }

        guard var components = URLComponents(string: ReadBoxSettings.apiBaseURL) else {
            throw ReadBoxAPIError.invalidBaseURL
        }

        components.path = path
        return components
    }

    private func request<T: Decodable, Body: Encodable>(
        _ url: URL,
        method: String,
        body: Body
    ) async throws -> T {
        var request = authorizedRequest(url: url, method: method)
        request.httpBody = try JSONEncoder().encode(body)
        return try await perform(request)
    }

    private func request<T: Decodable>(_ url: URL, method: String) async throws -> T {
        try await perform(authorizedRequest(url: url, method: method))
    }

    private func authorizedRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(ReadBoxSettings.apiToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ReadBoxAPIError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw ReadBoxAPIError.server(message)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

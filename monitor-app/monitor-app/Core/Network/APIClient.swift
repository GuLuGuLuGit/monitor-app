import Foundation

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private var isRefreshing = false
    private var pendingRequests: [CheckedContinuation<Void, Never>] = []

    private var baseURL: URL {
        URL(string: AppConfig.baseURL)!
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Generic request (without body)

    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        try await request(endpoint, bodyData: nil, queryItems: queryItems)
    }

    // MARK: - Generic request (with body)

    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        body: some Encodable,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        let encoder = JSONEncoder()
        let data = try encoder.encode(body)
        return try await request(endpoint, bodyData: data, queryItems: queryItems)
    }

    // MARK: - Core request implementation

    private func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        bodyData: Data?,
        queryItems: [URLQueryItem]
    ) async throws -> T {
        var urlRequest: URLRequest
        if queryItems.isEmpty {
            urlRequest = endpoint.urlRequest(baseURL: baseURL)
        } else {
            urlRequest = endpoint.urlRequest(baseURL: baseURL, queryItems: queryItems)
        }

        if endpoint.requiresAuth, let token = await KeychainStore.shared.getToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let bodyData {
            urlRequest.httpBody = bodyData
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await performRequest(urlRequest)
        let httpResponse = response as! HTTPURLResponse

        if endpoint.requiresAuth && httpResponse.statusCode == 401 {
            let refreshed = await refreshTokenIfNeeded()
            if refreshed {
                return try await request(endpoint, bodyData: bodyData, queryItems: queryItems)
            } else {
                await KeychainStore.shared.clearAll()
                throw APIError.unauthorized
            }
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let apiResp = try? JSONDecoder.api.decode(APIResponse<EmptyResponse>.self, from: data) {
                throw APIError.server(code: apiResp.code, message: apiResp.message)
            }
            throw APIError.server(code: httpResponse.statusCode, message: "HTTP \(httpResponse.statusCode)")
        }

        do {
            let apiResponse = try JSONDecoder.api.decode(APIResponse<T>.self, from: data)
            guard apiResponse.code == 0 else {
                throw APIError.server(code: apiResponse.code, message: apiResponse.message)
            }
            guard let result = apiResponse.data else {
                throw APIError.emptyData
            }
            return result
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.decodingError(error)
        }
    }

    /// Fire-and-forget request (without body)
    func requestVoid(_ endpoint: APIEndpoint) async throws {
        let _: EmptyResponse? = try? await request(endpoint)
    }

    /// Fire-and-forget request (with body)
    func requestVoid(_ endpoint: APIEndpoint, body: some Encodable) async throws {
        let _: EmptyResponse? = try? await request(endpoint, body: body)
    }

    // MARK: - Token refresh

    private func refreshTokenIfNeeded() async -> Bool {
        if isRefreshing {
            await withCheckedContinuation { continuation in
                pendingRequests.append(continuation)
            }
            return await KeychainStore.shared.getToken() != nil
        }

        isRefreshing = true
        defer {
            isRefreshing = false
            for continuation in pendingRequests {
                continuation.resume()
            }
            pendingRequests.removeAll()
        }

        guard let currentToken = await KeychainStore.shared.getToken() else {
            return false
        }

        do {
            var urlRequest = APIEndpoint.refreshToken.urlRequest(baseURL: baseURL)
            urlRequest.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (data, response) = try await performRequest(urlRequest)
            let httpResponse = response as! HTTPURLResponse

            guard httpResponse.statusCode == 200 else { return false }

            let apiResponse = try JSONDecoder.api.decode(APIResponse<RefreshTokenResponse>.self, from: data)
            guard apiResponse.code == 0, let refreshData = apiResponse.data else { return false }

            await KeychainStore.shared.saveToken(refreshData.token)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Helpers

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }
    }
}

extension JSONDecoder {
    static let api: JSONDecoder = {
        let decoder = JSONDecoder()
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoNoFrac = ISO8601DateFormatter()
        isoNoFrac.formatOptions = [.withInternetDateTime]

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            if let date = iso.date(from: dateStr) { return date }
            if let date = isoNoFrac.date(from: dateStr) { return date }

            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let date = df.date(from: dateStr) { return date }

            df.dateFormat = "yyyy-MM-dd HH:mm:ss"
            if let date = df.date(from: dateStr) { return date }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateStr)")
        }
        return decoder
    }()
}

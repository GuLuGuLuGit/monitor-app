import Foundation

struct APIResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?
    let timestamp: String?
}

struct EmptyResponse: Decodable {}

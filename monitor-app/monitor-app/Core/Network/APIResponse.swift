import Foundation

struct APIResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?
    let timestamp: String?
}

struct PagedData<T: Decodable>: Decodable {
    let items: [T]
    let pagination: Pagination

    struct Pagination: Decodable {
        let page: Int
        let pageSize: Int
        let total: Int64
        let totalPages: Int

        enum CodingKeys: String, CodingKey {
            case page
            case pageSize = "page_size"
            case total
            case totalPages = "total_pages"
        }
    }
}

struct EmptyResponse: Decodable {}

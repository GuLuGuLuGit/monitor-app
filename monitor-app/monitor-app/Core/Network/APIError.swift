import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case encodingFailed
    case server(code: Int, message: String)
    case emptyData
    case unauthorized
    case networkError(Error)
    case decodingError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "无效的请求地址"
        case .encodingFailed:
            "请求数据编码失败"
        case .server(_, let message):
            message
        case .emptyData:
            "服务器返回空数据"
        case .unauthorized:
            "登录已过期，请重新登录"
        case .networkError(let error):
            "网络错误: \(error.localizedDescription)"
        case .decodingError(let error):
            "数据解析错误: \(error.localizedDescription)"
        case .unknown:
            "未知错误"
        }
    }
}

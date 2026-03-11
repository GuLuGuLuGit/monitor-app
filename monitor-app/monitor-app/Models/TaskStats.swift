import Foundation

struct TaskStats: Codable {
    let total: Int64
    let running: Int64
    let completed: Int64
    let failed: Int64
    let pending: Int64
    let timeout: Int64
}

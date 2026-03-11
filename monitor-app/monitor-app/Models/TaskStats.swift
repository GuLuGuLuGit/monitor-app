import Foundation

struct TaskStats: Codable {
    let total: Int64
    let running: Int64
    let completed: Int64
    let failed: Int64
    let pending: Int64
    let timeout: Int64

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        running = try container.decodeIfPresent(Int64.self, forKey: .running) ?? 0
        completed = try container.decodeIfPresent(Int64.self, forKey: .completed) ?? 0
        failed = try container.decodeIfPresent(Int64.self, forKey: .failed) ?? 0
        pending = try container.decodeIfPresent(Int64.self, forKey: .pending) ?? 0
        timeout = try container.decodeIfPresent(Int64.self, forKey: .timeout) ?? 0
        total = try container.decodeIfPresent(Int64.self, forKey: .total) ?? (running + completed + failed + pending + timeout)
    }
}

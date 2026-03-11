import Foundation

struct SystemMetric: Codable, Identifiable {
    let id: UInt
    let deviceId: UInt
    let metricTime: Date
    let cpuUsage: Double
    let memoryUsage: Double
    let memoryUsed: Int64
    let memoryAvailable: Int64
    let diskUsage: Double
    let diskUsed: Int64
    let diskAvailable: Int64
    let networkIn: Int64
    let networkOut: Int64
    let loadAverage1: Double
    let loadAverage5: Double
    let loadAverage15: Double
    let processCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case deviceId = "device_id"
        case metricTime = "metric_time"
        case cpuUsage = "cpu_usage"
        case memoryUsage = "memory_usage"
        case memoryUsed = "memory_used"
        case memoryAvailable = "memory_available"
        case diskUsage = "disk_usage"
        case diskUsed = "disk_used"
        case diskAvailable = "disk_available"
        case networkIn = "network_in"
        case networkOut = "network_out"
        case loadAverage1 = "load_average_1"
        case loadAverage5 = "load_average_5"
        case loadAverage15 = "load_average_15"
        case processCount = "process_count"
        case createdAt = "created_at"
    }
}

import Foundation

struct Device: Codable, Identifiable {
    let id: UInt
    let deviceId: String
    let nodeId: String?
    let hostname: String
    let macAddress: String
    let osVersion: String
    let cpuModel: String
    let cpuCores: Int
    let memoryTotal: Int64
    let diskTotal: Int64
    let agentVersion: String
    let status: Int8
    let lastHeartbeatAt: Date?
    let registeredAt: Date
    let createdAt: Date?
    let updatedAt: Date?
    let extraData: String?
    let latestMetric: SystemMetric?

    enum CodingKeys: String, CodingKey {
        case id
        case deviceId = "device_id"
        case nodeId = "node_id"
        case hostname
        case macAddress = "mac_address"
        case osVersion = "os_version"
        case cpuModel = "cpu_model"
        case cpuCores = "cpu_cores"
        case memoryTotal = "memory_total"
        case diskTotal = "disk_total"
        case agentVersion = "agent_version"
        case status
        case lastHeartbeatAt = "last_heartbeat_at"
        case registeredAt = "registered_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case extraData = "extra_data"
        case latestMetric = "latest_metric"
    }
}

extension Device {
    enum Status: Int8 {
        case online = 1
        case offline = 0
        case disabled = -1
    }

    var deviceStatus: Status {
        Status(rawValue: status) ?? .offline
    }

    var isOnline: Bool { status == 1 }

    var formattedCPU: String {
        let model = cpuModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let coreText = cpuCores > 0 ? "\(cpuCores) 核" : nil
        let parts = [model.isEmpty ? nil : model, coreText].compactMap { $0 }
        return parts.isEmpty ? "待上报" : parts.joined(separator: " · ")
    }

    var formattedMemory: String {
        formattedMemory(using: latestMetric)
    }

    var formattedDisk: String {
        formattedDisk(using: latestMetric)
    }

    func effectiveMemoryTotal(using metric: SystemMetric? = nil) -> Int64 {
        if memoryTotal > 0 {
            return memoryTotal
        }
        guard let metric else {
            return 0
        }
        let derived = metric.memoryUsed + metric.memoryAvailable
        return derived > 0 ? derived : 0
    }

    func effectiveDiskTotal(using metric: SystemMetric? = nil) -> Int64 {
        if diskTotal > 0 {
            return diskTotal
        }
        guard let metric else {
            return 0
        }
        let derived = metric.diskUsed + metric.diskAvailable
        return derived > 0 ? derived : 0
    }

    func formattedMemory(using metric: SystemMetric? = nil) -> String {
        let total = effectiveMemoryTotal(using: metric)
        guard total > 0 else { return "待上报" }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .memory)
    }

    func formattedDisk(using metric: SystemMetric? = nil) -> String {
        let total = effectiveDiskTotal(using: metric)
        guard total > 0 else { return "待上报" }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
}

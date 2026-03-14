import Foundation

struct DeviceWorkspaceOverview: Codable {
    let deviceSummary: DeviceWorkspaceDeviceSummary
    let metricsSummary: DeviceWorkspaceMetricsSummary
    let skillsSummary: DeviceWorkspaceSkillsSummary
    let logsSummary: DeviceWorkspaceLogsSummary
    let recentDevices: [Device]

    enum CodingKeys: String, CodingKey {
        case deviceSummary = "device_summary"
        case metricsSummary = "metrics_summary"
        case skillsSummary = "skills_summary"
        case logsSummary = "logs_summary"
        case recentDevices = "recent_devices"
    }
}

struct DeviceWorkspaceDeviceSummary: Codable {
    let total: Int64
    let online: Int64
    let offline: Int64
    let disabled: Int64
}

struct DeviceWorkspaceMetricsSummary: Codable {
    let totalRecords: Int64
    let todayRecords: Int64
    let avgCpuUsage: Double
    let avgMemoryUsage: Double
    let avgDiskUsage: Double

    enum CodingKeys: String, CodingKey {
        case totalRecords = "total_records"
        case todayRecords = "today_records"
        case avgCpuUsage = "avg_cpu_usage"
        case avgMemoryUsage = "avg_memory_usage"
        case avgDiskUsage = "avg_disk_usage"
    }
}

struct DeviceWorkspaceSkillsSummary: Codable {
    let totalSkills: Int64
    let enabledSkills: Int64
    let disabledSkills: Int64

    enum CodingKeys: String, CodingKey {
        case totalSkills = "total_skills"
        case enabledSkills = "enabled_skills"
        case disabledSkills = "disabled_skills"
    }
}

struct DeviceWorkspaceLogsSummary: Codable {
    let totalLogs: Int64
    let todayLogs: Int64
    let errorLogs: Int64
    let warnLogs: Int64

    enum CodingKeys: String, CodingKey {
        case totalLogs = "total_logs"
        case todayLogs = "today_logs"
        case errorLogs = "error_logs"
        case warnLogs = "warn_logs"
    }
}

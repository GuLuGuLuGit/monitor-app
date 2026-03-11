import Foundation

struct TaskProgress: Codable, Identifiable {
    let id: Int64
    let commandId: Int64
    let nodeId: String
    let status: String
    let progress: Int
    let currentStep: String?
    let totalSteps: Int
    let completedSteps: Int
    let snapshotUrl: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case commandId = "command_id"
        case nodeId = "node_id"
        case status, progress
        case currentStep = "current_step"
        case totalSteps = "total_steps"
        case completedSteps = "completed_steps"
        case snapshotUrl = "snapshot_url"
        case createdAt = "created_at"
    }
}

extension TaskProgress {
    var progressPercent: Double {
        Double(progress) / 100.0
    }

    var isCompleted: Bool {
        status == "completed"
    }

    var isFailed: Bool {
        status == "failed"
    }

    var isRunning: Bool {
        status == "running"
    }
}

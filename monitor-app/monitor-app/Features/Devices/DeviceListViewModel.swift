import Foundation
import Observation

@Observable
@MainActor
final class DeviceListViewModel {
    private(set) var devices: [Device] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var unreadMessageCounts: [String: Int] = [:]

    var searchText = ""
    var statusFilter: Int8? = nil

    private var refreshTimer: Timer?
    private let unreadSeenKey = "device_agent_unread_seen_at"

    var filteredDevices: [Device] {
        var result = devices
        if let filter = statusFilter {
            result = result.filter { $0.status == filter }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.hostname.localizedCaseInsensitiveContains(searchText) ||
                $0.deviceId.localizedCaseInsensitiveContains(searchText) ||
                ($0.nodeId?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                $0.osVersion.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var onlineDevices: [Device] {
        filteredDevices.filter { $0.status == 1 }
    }

    var offlineDevices: [Device] {
        filteredDevices.filter { $0.status != 1 }
    }

    func load() async {
        isLoading = devices.isEmpty
        errorMessage = nil

        do {
            let result: PagedData<Device> = try await APIClient.shared.request(
                .devices,
                queryItems: [
                    URLQueryItem(name: "page", value: "1"),
                    URLQueryItem(name: "page_size", value: "100"),
                ]
            )
            devices = result.items
            await loadUnreadMessageCounts()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func updateDeviceStatus(device: Device, newStatus: Int8) async -> Bool {
        struct StatusBody: Encodable { let status: Int8 }
        do {
            try await APIClient.shared.requestVoid(.deviceStatus(id: device.id), body: StatusBody(status: newStatus))
            await load()
            return true
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func deleteDevice(_ device: Device) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.deleteDevice(id: device.id))
            devices.removeAll { $0.id == device.id }
            return true
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: AppConfig.heartbeatInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.load() }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func unreadCount(for deviceId: String) -> Int {
        unreadMessageCounts[deviceId] ?? 0
    }

    func markMessagesRead(for deviceId: String) {
        var seenMap = unreadSeenMap()
        seenMap[deviceId] = ISO8601DateFormatter().string(from: Date())
        UserDefaults.standard.set(seenMap, forKey: unreadSeenKey)
        unreadMessageCounts[deviceId] = 0
    }

    private func loadUnreadMessageCounts() async {
        do {
            let response: CommandListResponse = try await APIClient.shared.request(
                .commands,
                queryItems: [
                    URLQueryItem(name: "command_type", value: "openclaw_message"),
                    URLQueryItem(name: "page", value: "1"),
                    URLQueryItem(name: "page_size", value: "100"),
                ]
            )

            let seenMap = unreadSeenDates()
            var counts: [String: Int] = [:]

            for command in response.commands {
                let replyText = command.result.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !replyText.isEmpty else { continue }

                let eventTime = command.executedAt ?? command.updatedAt
                let seenAt = seenMap[command.deviceId] ?? .distantPast
                guard eventTime > seenAt else { continue }
                counts[command.deviceId, default: 0] += 1
            }

            unreadMessageCounts = counts
        } catch {
            unreadMessageCounts = [:]
        }
    }

    private func unreadSeenMap() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: unreadSeenKey) as? [String: String] ?? [:]
    }

    private func unreadSeenDates() -> [String: Date] {
        let formatter = ISO8601DateFormatter()
        return unreadSeenMap().compactMapValues { formatter.date(from: $0) }
    }
}

import Foundation
import Observation

@Observable
@MainActor
final class DeviceListViewModel {
    private(set) var devices: [Device] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var searchText = ""
    var statusFilter: Int8? = nil

    private var refreshTimer: Timer?

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
            let result: [Device] = try await APIClient.shared.request(
                .devices,
                queryItems: [
                    URLQueryItem(name: "page", value: "1"),
                    URLQueryItem(name: "page_size", value: "100"),
                ]
            )
            devices = result
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
}

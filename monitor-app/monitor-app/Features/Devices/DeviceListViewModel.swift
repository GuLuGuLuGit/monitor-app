import Foundation
import Observation

@Observable
@MainActor
final class DeviceListViewModel {
    private(set) var devices: [Device] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var isShowingStaleData = false
    private(set) var hasLoadedOnce = false

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
        if !hasLoadedOnce {
            isLoading = true
        }
        errorMessage = nil

        do {
            if AuthManager.shared.isDemoMode {
                devices = DemoModeStore.shared.devices()
            } else {
                let result: PagedData<Device> = try await APIClient.shared.request(
                    .devices,
                    queryItems: [
                        URLQueryItem(name: "page", value: "1"),
                        URLQueryItem(name: "page_size", value: "100"),
                    ]
                )
                devices = result.items
            }
            isShowingStaleData = false
            hasLoadedOnce = true
            WidgetSnapshotStore.save(devices: devices)
        } catch let error as APIError {
            errorMessage = error.errorDescription
            isShowingStaleData = !devices.isEmpty
        } catch {
            errorMessage = error.localizedDescription
            isShowingStaleData = !devices.isEmpty
        }

        hasLoadedOnce = true
        isLoading = false
    }

    func updateDeviceStatus(device: Device, newStatus: Int8) async -> Bool {
        struct StatusBody: Encodable { let status: Int8 }
        do {
            if AuthManager.shared.isDemoMode {
                _ = DemoModeStore.shared.updateDeviceStatus(id: device.id, status: newStatus)
            } else {
                try await APIClient.shared.requestVoid(.deviceStatus(id: device.id), body: StatusBody(status: newStatus))
            }
            await load()
            return true
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func deleteDevice(_ device: Device) async -> Bool {
        do {
            if AuthManager.shared.isDemoMode {
                DemoModeStore.shared.deleteDevice(id: device.id)
            } else {
                try await APIClient.shared.requestVoid(.deleteDevice(id: device.id))
            }
            devices.removeAll { $0.id == device.id }
            WidgetSnapshotStore.save(devices: devices)
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
        devices.first(where: { $0.deviceId == deviceId })?.agentUnreadCount ?? 0
    }

    func clearError() {
        errorMessage = nil
    }
}

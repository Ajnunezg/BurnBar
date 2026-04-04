import Foundation
import OpenBurnBarCore

extension DataStore {
    func fetchDevices() throws -> [DeviceRecord] {
        try deviceStore.fetchDevices()
    }

    func upsertDevice(_ device: DeviceRecord) throws {
        try deviceStore.upsertDevice(device)
    }

    func deviceUsageSummaries() throws -> [DeviceUsageSummary] {
        try deviceStore.deviceUsageSummaries()
    }

    func updateDeviceIcon(deviceId: String, customIcon: String?) throws {
        try deviceStore.updateDeviceIcon(deviceId: deviceId, customIcon: customIcon)
    }
}

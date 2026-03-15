import Foundation
import Observation

@Observable
@MainActor
final class CommandViewModel {
    private(set) var commands: [AgentCommand] = []
    private(set) var isLoading = false
    private(set) var isSending = false
    var errorMessage: String?

    var filterDeviceId: String? = nil

    /// In-memory public key cache: deviceId -> PEM string
    private var publicKeyCache: [String: String] = [:]

    func loadCommands(deviceId: String? = nil) async {
        isLoading = commands.isEmpty
        errorMessage = nil

        var queryItems = [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "page_size", value: "50"),
        ]
        if let deviceId = deviceId ?? filterDeviceId {
            queryItems.append(URLQueryItem(name: "device_id", value: deviceId))
        }

        do {
            let result: CommandListResponse = try await APIClient.shared.request(.commands, queryItems: queryItems)
            commands = result.commands
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func sendCommand(deviceId: String, deviceInternalId: UInt, commandType: AgentCommand.CommandType, params: [String: Any]? = nil) async -> Bool {
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            let publicKey = try await fetchPublicKey(deviceInternalId: deviceInternalId)

            let commandData = CommandPayload(commandType: commandType.rawValue, params: params)
            let envelopeJson = try E2ECrypto.sealJSON(commandData, publicKeyPEM: publicKey)

            let shouldPersistParams = (commandType == .message)
            let persistedParams = shouldPersistParams ? params?.mapValues { AnyCodable($0) } : nil

            let request = CreateEncryptedCommandRequest(
                deviceId: deviceId,
                commandType: commandType.rawValue,
                commandParams: persistedParams,
                encryptedPayload: envelopeJson,
                isEncrypted: true
            )

            let _: AgentCommand = try await APIClient.shared.request(.createCommand, body: request)
            await loadCommands(deviceId: deviceId)
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch let error as CryptoError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        return false
    }

    func deleteCommand(_ id: Int64, deviceId: String? = nil) async -> Bool {
        errorMessage = nil
        do {
            let _: CommandCleanupResponse = try await APIClient.shared.request(.deleteCommand(id: id))
            await loadCommands(deviceId: deviceId ?? filterDeviceId)
            return true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        return false
    }

    func cleanupCommands(
        deviceId: String? = nil,
        commandTypes: [String]? = nil,
        statuses: [Int8]? = nil
    ) async -> Int64? {
        errorMessage = nil
        do {
            let result: CommandCleanupResponse = try await APIClient.shared.request(
                .cleanupCommands,
                body: CommandCleanupRequest(
                    deviceId: deviceId ?? filterDeviceId,
                    commandTypes: commandTypes,
                    statuses: statuses
                )
            )
            await loadCommands(deviceId: deviceId ?? filterDeviceId)
            return result.deleted
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        return nil
    }

    private func fetchPublicKey(deviceInternalId: UInt) async throws -> String {
        let cacheKey = "\(deviceInternalId)"
        if let cached = publicKeyCache[cacheKey] {
            return cached
        }

        let response: PublicKeyResponse = try await APIClient.shared.request(.devicePublicKey(id: deviceInternalId))
        publicKeyCache[cacheKey] = response.publicKey
        return response.publicKey
    }
}

// MARK: - Request/Response models

struct PublicKeyResponse: Decodable {
    let publicKey: String

    enum CodingKeys: String, CodingKey {
        case publicKey = "public_key"
    }
}

struct CommandPayload: Encodable {
    let commandType: String
    let commandParams: [String: AnyCodable]?

    init(commandType: String, params: [String: Any]?) {
        self.commandType = commandType
        self.commandParams = params?.mapValues { AnyCodable($0) }
    }

    enum CodingKeys: String, CodingKey {
        case commandType = "command_type"
        case commandParams = "command_params"
    }
}

struct CreateEncryptedCommandRequest: Encodable {
    let deviceId: String
    let commandType: String
    let commandParams: [String: AnyCodable]?
    let encryptedPayload: String
    let isEncrypted: Bool

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case commandType = "command_type"
        case commandParams = "command_params"
        case encryptedPayload = "encrypted_payload"
        case isEncrypted = "is_encrypted"
    }
}

struct CommandListResponse: Decodable {
    let commands: [AgentCommand]
    let total: Int64
}

struct CommandCleanupRequest: Encodable {
    let deviceId: String?
    let commandTypes: [String]?
    let statuses: [Int8]?

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case commandTypes = "command_types"
        case statuses
    }
}

struct CommandCleanupResponse: Decodable {
    let deleted: Int64
}

import Foundation
import CryptoKit
import Security

struct Envelope: Codable {
    let version: Int
    let encryptedKey: String
    let nonce: String
    let ciphertext: String
    let timestamp: Int64

    enum CodingKeys: String, CodingKey {
        case version
        case encryptedKey = "encrypted_key"
        case nonce
        case ciphertext
        case timestamp
    }
}

enum CryptoError: LocalizedError {
    case invalidPEM
    case keyImportFailed
    case rsaEncryptionFailed
    case aesEncryptionFailed

    var errorDescription: String? {
        switch self {
        case .invalidPEM: "无效的公钥格式"
        case .keyImportFailed: "公钥导入失败"
        case .rsaEncryptionFailed: "RSA 加密失败"
        case .aesEncryptionFailed: "AES 加密失败"
        }
    }
}

enum E2ECrypto {

    /// Seal encrypts plaintext using hybrid RSA-OAEP + AES-256-GCM.
    /// Output Envelope is compatible with Go `crypto.Open` and Web `seal()`.
    static func seal(publicKeyPEM: String, plaintext: Data) throws -> Envelope {
        let publicKey = try importPublicKey(pem: publicKeyPEM)

        let sessionKey = SymmetricKey(size: .bits256)

        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(plaintext, using: sessionKey, nonce: nonce)

        let sessionKeyData = sessionKey.withUnsafeBytes { Data($0) }
        var error: Unmanaged<CFError>?
        guard let encryptedKey = SecKeyCreateEncryptedData(
            publicKey,
            .rsaEncryptionOAEPSHA256,
            sessionKeyData as CFData,
            &error
        ) as Data? else {
            throw CryptoError.rsaEncryptionFailed
        }

        // GCM: ciphertext || tag (same layout as Go's gcm.Seal)
        let combined = sealedBox.ciphertext + sealedBox.tag

        return Envelope(
            version: 1,
            encryptedKey: encryptedKey.base64EncodedString(),
            nonce: Data(nonce).base64EncodedString(),
            ciphertext: combined.base64EncodedString(),
            timestamp: Int64(Date().timeIntervalSince1970)
        )
    }

    static func sealJSON(_ value: some Encodable, publicKeyPEM: String) throws -> String {
        let jsonData = try JSONEncoder().encode(value)
        let envelope = try seal(publicKeyPEM: publicKeyPEM, plaintext: jsonData)
        let envelopeData = try JSONEncoder().encode(envelope)
        return String(data: envelopeData, encoding: .utf8)!
    }

    private static func importPublicKey(pem: String) throws -> SecKey {
        let stripped = pem
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let derData = Data(base64Encoded: stripped) else {
            throw CryptoError.invalidPEM
        }

        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
        ]

        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(derData as CFData, attributes as CFDictionary, &error) else {
            throw CryptoError.keyImportFailed
        }
        return key
    }
}

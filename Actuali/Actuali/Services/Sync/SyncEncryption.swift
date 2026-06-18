// Actuali/Actuali/Services/Sync/SyncEncryption.swift

import Foundation
import CryptoKit
import CommonCrypto

enum SyncEncryptionError: Error {
    case encryptionFailed
    case decryptionFailed
    case invalidKey
    case missingKey
}

/// Encryption/decryption for sync messages (AES-256-GCM)
enum SyncEncryption {

    /// Encrypt data for sync
    static func encrypt(_ plaintext: Data, using key: SymmetricKey) throws -> EncryptedData {
        do {
            let nonce = AES.GCM.Nonce()
            let sealedBox = try AES.GCM.seal(plaintext, using: key, nonce: nonce)

            var encrypted = EncryptedData()
            encrypted.iv = Data(nonce)
            encrypted.authTag = sealedBox.tag
            encrypted.data = sealedBox.ciphertext

            return encrypted
        } catch {
            throw SyncEncryptionError.encryptionFailed
        }
    }

    /// Decrypt data from sync
    static func decrypt(_ encrypted: EncryptedData, using key: SymmetricKey) throws -> Data {
        do {
            let nonce = try AES.GCM.Nonce(data: encrypted.iv)
            let sealedBox = try AES.GCM.SealedBox(
                nonce: nonce,
                ciphertext: encrypted.data,
                tag: encrypted.authTag
            )

            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw SyncEncryptionError.decryptionFailed
        }
    }

    /// Derive encryption key from password using PBKDF2-SHA512
    /// Matches Actual's key derivation (10,000 iterations)
    static func deriveKey(password: String, salt: Data) -> SymmetricKey {
        var derivedKey = [UInt8](repeating: 0, count: 32)
        let passwordData = password.data(using: .utf8)!

        _ = passwordData.withUnsafeBytes { passwordBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                    passwordData.count,
                    saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512),
                    10_000,  // iterations - matches Actual
                    &derivedKey,
                    32
                )
            }
        }

        return SymmetricKey(data: derivedKey)
    }
}

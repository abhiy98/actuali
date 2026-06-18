// Sync.pb.swift
// Manual protobuf implementation for Actual Budget sync protocol
// This replaces the SwiftProtobuf-based implementation to avoid internal protocol issues

import Foundation

// MARK: - Protobuf Wire Format Helpers

/// Minimal protobuf encoder
struct ProtobufEncoder {
    private var data = Data()

    mutating func writeVarint(_ value: UInt64) {
        var v = value
        while v > 127 {
            data.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }
        data.append(UInt8(v))
    }

    mutating func writeTag(fieldNumber: Int, wireType: Int) {
        writeVarint(UInt64((fieldNumber << 3) | wireType))
    }

    mutating func writeString(fieldNumber: Int, value: String) {
        guard !value.isEmpty else { return }
        let bytes = value.utf8
        writeTag(fieldNumber: fieldNumber, wireType: 2) // Length-delimited
        writeVarint(UInt64(bytes.count))
        data.append(contentsOf: bytes)
    }

    mutating func writeBytes(fieldNumber: Int, value: Data) {
        guard !value.isEmpty else { return }
        writeTag(fieldNumber: fieldNumber, wireType: 2) // Length-delimited
        writeVarint(UInt64(value.count))
        data.append(value)
    }

    mutating func writeBool(fieldNumber: Int, value: Bool) {
        guard value else { return } // Default false is not written
        writeTag(fieldNumber: fieldNumber, wireType: 0) // Varint
        writeVarint(1)
    }

    mutating func writeMessage(fieldNumber: Int, value: Data) {
        writeTag(fieldNumber: fieldNumber, wireType: 2) // Length-delimited
        writeVarint(UInt64(value.count))
        data.append(value)
    }

    func finish() -> Data { data }
}

/// Minimal protobuf decoder
struct ProtobufDecoder {
    private var data: Data
    private var offset: Int = 0

    init(data: Data) {
        self.data = data
    }

    var isAtEnd: Bool { offset >= data.count }

    mutating func readVarint() -> UInt64? {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while offset < data.count {
            let byte = data[offset]
            offset += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 {
                return result
            }
            shift += 7
            if shift >= 64 { return nil }
        }
        return nil
    }

    mutating func readTag() -> (fieldNumber: Int, wireType: Int)? {
        guard let tag = readVarint() else { return nil }
        return (Int(tag >> 3), Int(tag & 0x07))
    }

    mutating func readLengthDelimited() -> Data? {
        guard let length = readVarint(), length <= data.count - offset else { return nil }
        let result = data[offset..<(offset + Int(length))]
        offset += Int(length)
        return Data(result)
    }

    mutating func readString() -> String? {
        guard let bytes = readLengthDelimited() else { return nil }
        return String(data: bytes, encoding: .utf8)
    }

    mutating func readBool() -> Bool? {
        guard let value = readVarint() else { return nil }
        return value != 0
    }

    mutating func skipField(wireType: Int) {
        switch wireType {
        case 0: _ = readVarint() // Varint
        case 1: offset += 8 // 64-bit
        case 2: if let data = readLengthDelimited() { _ = data } // Length-delimited
        case 5: offset += 4 // 32-bit
        default: break
        }
    }
}

// MARK: - Sync Protocol Types

struct EncryptedData: Equatable, Sendable {
    var iv: Data = Data()
    var authTag: Data = Data()
    var data: Data = Data()

    init() {}

    init(iv: Data, authTag: Data, data: Data) {
        self.iv = iv
        self.authTag = authTag
        self.data = data
    }

    init(serializedData: Data) throws {
        var decoder = ProtobufDecoder(data: serializedData)
        while !decoder.isAtEnd {
            guard let (fieldNumber, wireType) = decoder.readTag() else { break }
            switch fieldNumber {
            case 1: if let v = decoder.readLengthDelimited() { iv = v }
            case 2: if let v = decoder.readLengthDelimited() { authTag = v }
            case 3: if let v = decoder.readLengthDelimited() { data = v }
            default: decoder.skipField(wireType: wireType)
            }
        }
    }

    func serializedData() throws -> Data {
        var encoder = ProtobufEncoder()
        encoder.writeBytes(fieldNumber: 1, value: iv)
        encoder.writeBytes(fieldNumber: 2, value: authTag)
        encoder.writeBytes(fieldNumber: 3, value: data)
        return encoder.finish()
    }
}

struct Message: Equatable, Sendable {
    var dataset: String = ""
    var row: String = ""
    var column: String = ""
    var value: String = ""

    init() {}

    init(serializedData: Data) throws {
        var decoder = ProtobufDecoder(data: serializedData)
        while !decoder.isAtEnd {
            guard let (fieldNumber, wireType) = decoder.readTag() else { break }
            switch fieldNumber {
            case 1: if let v = decoder.readString() { dataset = v }
            case 2: if let v = decoder.readString() { row = v }
            case 3: if let v = decoder.readString() { column = v }
            case 4: if let v = decoder.readString() { value = v }
            default: decoder.skipField(wireType: wireType)
            }
        }
    }

    func serializedData() throws -> Data {
        var encoder = ProtobufEncoder()
        encoder.writeString(fieldNumber: 1, value: dataset)
        encoder.writeString(fieldNumber: 2, value: row)
        encoder.writeString(fieldNumber: 3, value: column)
        encoder.writeString(fieldNumber: 4, value: value)
        return encoder.finish()
    }
}

struct MessageEnvelope: Equatable, Sendable {
    var timestamp: String = ""
    var isEncrypted: Bool = false
    var content: Data = Data()

    init() {}

    init(serializedData: Data) throws {
        var decoder = ProtobufDecoder(data: serializedData)
        while !decoder.isAtEnd {
            guard let (fieldNumber, wireType) = decoder.readTag() else { break }
            switch fieldNumber {
            case 1: if let v = decoder.readString() { timestamp = v }
            case 2: if let v = decoder.readBool() { isEncrypted = v }
            case 3: if let v = decoder.readLengthDelimited() { content = v }
            default: decoder.skipField(wireType: wireType)
            }
        }
    }

    func serializedData() throws -> Data {
        var encoder = ProtobufEncoder()
        encoder.writeString(fieldNumber: 1, value: timestamp)
        encoder.writeBool(fieldNumber: 2, value: isEncrypted)
        encoder.writeBytes(fieldNumber: 3, value: content)
        return encoder.finish()
    }
}

struct SyncRequest: Equatable, Sendable {
    var messages: [MessageEnvelope] = []
    var fileID: String = ""
    var groupID: String = ""
    var keyID: String = ""
    var since: String = ""

    init() {}

    init(serializedData: Data) throws {
        var decoder = ProtobufDecoder(data: serializedData)
        while !decoder.isAtEnd {
            guard let (fieldNumber, wireType) = decoder.readTag() else { break }
            switch fieldNumber {
            case 1:
                if let msgData = decoder.readLengthDelimited() {
                    let envelope = try MessageEnvelope(serializedData: msgData)
                    messages.append(envelope)
                }
            case 2: if let v = decoder.readString() { fileID = v }
            case 3: if let v = decoder.readString() { groupID = v }
            case 5: if let v = decoder.readString() { keyID = v }
            case 6: if let v = decoder.readString() { since = v }
            default: decoder.skipField(wireType: wireType)
            }
        }
    }

    func serializedData() throws -> Data {
        var encoder = ProtobufEncoder()
        for msg in messages {
            let msgData = try msg.serializedData()
            encoder.writeMessage(fieldNumber: 1, value: msgData)
        }
        encoder.writeString(fieldNumber: 2, value: fileID)
        encoder.writeString(fieldNumber: 3, value: groupID)
        encoder.writeString(fieldNumber: 5, value: keyID)
        encoder.writeString(fieldNumber: 6, value: since)
        return encoder.finish()
    }
}

struct SyncResponse: Equatable, Sendable {
    var messages: [MessageEnvelope] = []
    var merkle: String = ""

    init() {}

    init(serializedData: Data) throws {
        var decoder = ProtobufDecoder(data: serializedData)
        while !decoder.isAtEnd {
            guard let (fieldNumber, wireType) = decoder.readTag() else { break }
            switch fieldNumber {
            case 1:
                if let msgData = decoder.readLengthDelimited() {
                    let envelope = try MessageEnvelope(serializedData: msgData)
                    messages.append(envelope)
                }
            case 2: if let v = decoder.readString() { merkle = v }
            default: decoder.skipField(wireType: wireType)
            }
        }
    }

    func serializedData() throws -> Data {
        var encoder = ProtobufEncoder()
        for msg in messages {
            let msgData = try msg.serializedData()
            encoder.writeMessage(fieldNumber: 1, value: msgData)
        }
        encoder.writeString(fieldNumber: 2, value: merkle)
        return encoder.finish()
    }
}

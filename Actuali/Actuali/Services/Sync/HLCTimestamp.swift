// Actuali/Actuali/Services/Sync/HLCTimestamp.swift

import Foundation

/// Hybrid Logical Clock timestamp
/// Format: 2025-12-09T14:30:45.123Z-0000-9f66d38cba0ef956
///         |ISO 8601 timestamp    |cntr|node ID (16 hex)
struct HLCTimestamp: Comparable, Hashable, Codable, CustomStringConvertible {
    let millis: Int64      // Wall clock time in milliseconds
    let counter: UInt16    // Logical counter for same-millisecond events
    let node: String       // 16-char hex device ID

    // MARK: - Formatting

    var description: String {
        toString()
    }

    func toString() -> String {
        // Format milliseconds as ISO 8601
        let seconds = Double(millis) / 1000.0
        let date = Date(timeIntervalSince1970: seconds)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoString = formatter.string(from: date)

        // Format counter as 4-digit uppercase hex
        let counterHex = String(format: "%04X", counter)

        // Ensure node is 16 chars, padded with leading zeros
        let paddedNode = String(repeating: "0", count: Swift.max(0, 16 - node.count)) + node.suffix(16)

        return "\(isoString)-\(counterHex)-\(paddedNode)"
    }

    // MARK: - Parsing

    /// Parse a timestamp string into an HLCTimestamp
    /// Returns nil if the string is invalid
    static func parse(_ string: String) -> HLCTimestamp? {
        // Format: 2015-04-24T22:23:42.123Z-1000-0123456789ABCDEF
        // Split by "-" but ISO date has dashes too, so split smartly
        let parts = string.split(separator: "-")
        guard parts.count == 5 else { return nil }

        // Reconstruct ISO date from first 3 parts
        let isoString = "\(parts[0])-\(parts[1])-\(parts[2])"

        // Parse ISO date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: String(isoString)) else { return nil }

        let millis = Int64(date.timeIntervalSince1970 * 1000)

        // Validate millis range (1970 to 9999)
        guard millis >= 0 && millis < 253402300800000 else { return nil }

        // Parse counter (hex)
        guard let counter = UInt16(parts[3], radix: 16) else { return nil }

        // Parse node
        let node = String(parts[4])
        guard node.count <= 16 else { return nil }

        return HLCTimestamp(millis: millis, counter: counter, node: node)
    }

    // MARK: - Comparable

    static func < (lhs: HLCTimestamp, rhs: HLCTimestamp) -> Bool {
        // Lexicographic comparison of string representation works correctly
        lhs.toString() < rhs.toString()
    }

    // MARK: - Hashing (for Merkle tree)

    /// Returns hash as Int32 to match JavaScript's signed 32-bit XOR behavior
    func hash() -> Int32 {
        Int32(bitPattern: MurmurHash3.hash(toString()))
    }

    // MARK: - Constants

    static let zero = HLCTimestamp(millis: 0, counter: 0, node: "0000000000000000")
    static let max = HLCTimestamp(millis: 253402300799999, counter: 0xFFFF, node: "FFFFFFFFFFFFFFFF")

    /// Create a "since" timestamp for a given ISO date string
    static func since(_ isoString: String) -> String {
        "\(isoString)-0000-0000000000000000"
    }
}

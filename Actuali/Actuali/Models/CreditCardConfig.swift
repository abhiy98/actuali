import Foundation

/// Synced configuration for a credit card account, persisted in Actual's `preferences` table.
/// Stored under the key `actuali:credit_card:<accountId>` as a JSON string.
struct CreditCardConfig: Codable, Equatable, Hashable, Sendable {
    var statementDay: Int
    var statementDayIsLast: Bool = false
    var dueOffsetDays: Int = CreditCardCycle.defaultDueOffsetDays
    var dueDay: Int? = nil
    var limit: Int? = nil
}

extension CreditCardConfig {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // ponytail: Normalize values written by the earlier in-branch implementation instead of preserving magic day numbers.
        let decodedStatementDay = try container.decode(Int.self, forKey: .statementDay)
        let legacyStatementDayIsLast = decodedStatementDay == 32
        guard (1...31).contains(decodedStatementDay) || legacyStatementDayIsLast else {
            throw DecodingError.dataCorruptedError(
                forKey: .statementDay,
                in: container,
                debugDescription: "statementDay must be between 1 and 31"
            )
        }
        let storedStatementDayIsLast = try container.decodeIfPresent(Bool.self, forKey: .statementDayIsLast) ?? false
        statementDayIsLast = legacyStatementDayIsLast || storedStatementDayIsLast
        statementDay = statementDayIsLast ? 31 : decodedStatementDay

        dueOffsetDays = try container.decodeIfPresent(Int.self, forKey: .dueOffsetDays) ?? CreditCardCycle.defaultDueOffsetDays
        let decodedDueDay = try container.decodeIfPresent(Int.self, forKey: .dueDay)
        if let decodedDueDay {
            // Older builds briefly wrote 32 for month-end; keep those preferences readable.
            guard (1...31).contains(decodedDueDay) || decodedDueDay == 32 else {
                throw DecodingError.dataCorruptedError(
                    forKey: .dueDay,
                    in: container,
                    debugDescription: "dueDay must be between 1 and 31"
                )
            }
            dueDay = min(decodedDueDay, 31)
        } else {
            dueDay = nil
        }
        limit = try container.decodeIfPresent(Int.self, forKey: .limit)
    }

    var paymentDue: CreditCardCycle.PaymentDue {
        if let dueDay {
            return .dayOfMonth(dueDay)
        }
        return .daysAfter(dueOffsetDays)
    }
}

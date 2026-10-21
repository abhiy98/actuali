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
        let decodedStatementDay = try container.decode(Int.self, forKey: .statementDay)
        guard (1...31).contains(decodedStatementDay) else {
            throw DecodingError.dataCorruptedError(
                forKey: .statementDay,
                in: container,
                debugDescription: "statementDay must be between 1 and 31"
            )
        }
        statementDayIsLast = try container.decodeIfPresent(Bool.self, forKey: .statementDayIsLast) ?? false
        statementDay = statementDayIsLast ? 31 : decodedStatementDay

        dueOffsetDays = try container.decodeIfPresent(Int.self, forKey: .dueOffsetDays) ?? CreditCardCycle.defaultDueOffsetDays
        let decodedDueDay = try container.decodeIfPresent(Int.self, forKey: .dueDay)
        if let decodedDueDay, !(1...31).contains(decodedDueDay) {
            throw DecodingError.dataCorruptedError(
                forKey: .dueDay,
                in: container,
                debugDescription: "dueDay must be between 1 and 31"
            )
        }
        dueDay = decodedDueDay
        limit = try container.decodeIfPresent(Int.self, forKey: .limit)
    }

    var paymentDue: CreditCardCycle.PaymentDue {
        if let dueDay {
            return .dayOfMonth(dueDay)
        }
        return .daysAfter(dueOffsetDays)
    }
}

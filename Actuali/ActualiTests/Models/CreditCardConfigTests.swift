import Foundation
import Testing
@testable import Actuali

struct CreditCardConfigTests {
    @Test func encodesAndDecodesJSON() throws {
        let config = CreditCardConfig(
            statementDay: 18,
            dueOffsetDays: 25,
            limit: 500_000
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(CreditCardConfig.self, from: data)

        #expect(decoded.statementDay == 18)
        #expect(decoded.dueOffsetDays == 25)
        #expect(decoded.limit == 500_000)
    }

    @Test func decodesWithDefaultDueOffsetAndNoLimit() throws {
        let json = """
        {
            "statementDay": 15
        }
        """

        let data = try #require(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(CreditCardConfig.self, from: data)
        #expect(decoded.statementDay == 15)
        #expect(decoded.dueOffsetDays == CreditCardCycle.defaultDueOffsetDays)
        #expect(decoded.dueDay == nil)
        #expect(decoded.paymentDue == .daysAfter(CreditCardCycle.defaultDueOffsetDays))
        #expect(decoded.limit == nil)
    }

    @Test func encodesAndDecodesLastDayFlagsWithoutSpecialDayNumbers() throws {
        let config = CreditCardConfig(
            statementDay: 31,
            statementDayIsLast: true,
            dueDay: 31,
            dueDayIsLast: true
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(CreditCardConfig.self, from: data)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(decoded.statementDay == 31)
        #expect(decoded.statementDayIsLast)
        #expect(decoded.dueDay == 31)
        #expect(decoded.dueDayIsLast)
        #expect(decoded.paymentDue == .lastDayOfMonth)
        #expect(json["statementDay"] as? Int == 31)
        #expect(json["dueDay"] as? Int == 31)
    }

    @Test func migratesLegacySentinelValuesToDayAndFlags() throws {
        let json = """
        {
            "statementDay": 32,
            "dueOffsetDays": 15,
            "dueDay": 32
        }
        """
        let data = try #require(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(CreditCardConfig.self, from: data)
        let encoded = try JSONEncoder().encode(decoded)
        let encodedJSON = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        #expect(decoded.statementDay == 31)
        #expect(decoded.statementDayIsLast)
        #expect(decoded.dueDay == 31)
        #expect(decoded.dueDayIsLast)
        #expect(decoded.paymentDue == .lastDayOfMonth)
        #expect(encodedJSON["statementDay"] as? Int == 31)
        #expect(encodedJSON["dueDay"] as? Int == 31)
        #expect(encodedJSON["statementDayIsLast"] as? Bool == true)
        #expect(encodedJSON["dueDayIsLast"] as? Bool == true)
    }

    @Test func encodesAndDecodesJSONWithDueDay() throws {
        let config = CreditCardConfig(
            statementDay: 15,
            dueOffsetDays: CreditCardCycle.defaultDueOffsetDays,
            dueDay: 1,
            limit: nil
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(CreditCardConfig.self, from: data)

        #expect(decoded.statementDay == 15)
        #expect(decoded.dueDay == 1)
        #expect(decoded.paymentDue == .dayOfMonth(1))
        #expect(decoded.limit == nil)
    }
}

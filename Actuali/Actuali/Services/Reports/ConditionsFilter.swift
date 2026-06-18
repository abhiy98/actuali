import Foundation

enum ConditionsFilter {

    /// Returns `true` if the transaction matches the condition set under the
    /// given combinator. Empty/nil conditions always match.
    static func matches(
        transaction: Transaction,
        conditions: [WidgetRuleCondition]?,
        op: String?
    ) -> Bool {
        guard let conditions, !conditions.isEmpty else { return true }
        let combinator = (op ?? "and").lowercased()
        if combinator == "or" {
            return conditions.contains { matches(transaction: transaction, condition: $0) }
        }
        return conditions.allSatisfy { matches(transaction: transaction, condition: $0) }
    }

    private static func matches(transaction tx: Transaction, condition c: WidgetRuleCondition) -> Bool {
        let txValue = transactionValue(tx, field: c.field)
        let condValue = decodeValue(c.value)

        switch c.op {
        case "is":
            return valuesEqual(txValue, condValue)
        case "isNot":
            return !valuesEqual(txValue, condValue)
        case "oneOf":
            return inArray(txValue, condValue)
        case "notOneOf":
            return !inArray(txValue, condValue)
        case "gt":
            return compareInt(txValue, condValue) { $0 > $1 }
        case "lt":
            return compareInt(txValue, condValue) { $0 < $1 }
        case "gte":
            return compareInt(txValue, condValue) { $0 >= $1 }
        case "lte":
            return compareInt(txValue, condValue) { $0 <= $1 }
        case "contains":
            return stringContains(txValue, condValue)
        case "doesNotContain":
            return !stringContains(txValue, condValue)
        default:
            // Unknown ops pass through. Better to show too many transactions
            // than to silently filter everything out.
            return true
        }
    }

    /// Map a condition field name to the corresponding transaction value.
    /// Boolean-typed fields (transfer, cleared, reconciled) return Bool;
    /// id/text fields return String?; amount/date return Int.
    private static func transactionValue(_ tx: Transaction, field: String) -> Any? {
        switch field {
        case "category": return tx.categoryId
        case "account": return tx.accountId
        case "payee", "description": return tx.payeeId
        case "amount": return tx.amount
        case "notes": return tx.notes
        case "date": return tx.date
        case "transfer": return tx.transferId != nil
        case "cleared": return tx.cleared
        case "reconciled": return tx.reconciled
        case "imported_payee": return tx.importedPayee
        default: return nil
        }
    }

    /// Decodes an `AnyCodable` JSON value into a primitive (`Bool`, `String`,
    /// `Int`, `Double`) or `[String]` for array conditions. Order matters —
    /// Bool must be tried before Int because some JSON libs accept 0/1 for both.
    private static func decodeValue(_ value: AnyCodable?) -> Any? {
        guard let value else { return nil }
        if let b = try? JSONDecoder().decode(Bool.self, from: value.raw) { return b }
        if let s = try? JSONDecoder().decode(String.self, from: value.raw) { return s }
        if let i = try? JSONDecoder().decode(Int.self, from: value.raw) { return i }
        if let d = try? JSONDecoder().decode(Double.self, from: value.raw) { return d }
        if let arr = try? JSONDecoder().decode([String].self, from: value.raw) { return arr }
        if let arr = try? JSONDecoder().decode([Int].self, from: value.raw) {
            return arr.map(String.init)
        }
        return nil
    }

    /// Type-aware equality. Handles Bool/Bool, String/String, Int/Int.
    /// Empty strings never match (treated like missing values).
    /// Nil on either side never matches (a missing tx value can't equal a
    /// non-nil condition value).
    private static func valuesEqual(_ a: Any?, _ b: Any?) -> Bool {
        if let ba = a as? Bool, let bb = b as? Bool { return ba == bb }
        if a == nil || b == nil { return false }
        if let sa = a as? String, let sb = b as? String {
            return !sa.isEmpty && sa == sb
        }
        if let ia = (a as? Int) ?? (a as? Double).map(Int.init),
           let ib = (b as? Int) ?? (b as? Double).map(Int.init) {
            return ia == ib
        }
        return false
    }

    private static func inArray(_ value: Any?, _ list: Any?) -> Bool {
        guard let arr = list as? [String] else { return false }
        let s = (value as? String) ?? ""
        return !s.isEmpty && arr.contains(s)
    }

    private static func stringContains(_ haystack: Any?, _ needle: Any?) -> Bool {
        guard let h = haystack as? String, let n = needle as? String, !n.isEmpty else { return false }
        return h.localizedCaseInsensitiveContains(n)
    }

    private static func compareInt(_ a: Any?, _ b: Any?, op: (Int, Int) -> Bool) -> Bool {
        let ia: Int? = (a as? Int) ?? (a as? Double).map(Int.init)
        let ib: Int? = (b as? Int) ?? (b as? Double).map(Int.init)
        guard let ia, let ib else { return false }
        return op(ia, ib)
    }
}

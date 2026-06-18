import Foundation
import Testing
@testable import Actuali

@MainActor
struct ConditionsFilterTests {

    private func makeTransaction(
        category: String? = nil,
        account: String = "acc1",
        amount: Int = -1000,
        payee: String? = nil
    ) -> Transaction {
        Transaction(
            id: UUID().uuidString,
            accountId: account,
            date: 20260301,
            amount: amount,
            payeeId: payee,
            payeeName: nil,
            categoryId: category,
            categoryName: nil,
            notes: nil,
            cleared: false,
            reconciled: false,
            transferId: nil,
            isParent: false,
            parentId: nil,
            tombstone: false,
            sortOrder: nil,
            importedPayee: nil
        )
    }

    @Test func passesWithNoConditions() {
        let tx = makeTransaction()
        #expect(ConditionsFilter.matches(transaction: tx, conditions: [], op: "and"))
    }

    @Test func passesWithNilConditions() {
        let tx = makeTransaction()
        #expect(ConditionsFilter.matches(transaction: tx, conditions: nil, op: "and"))
    }

    @Test func categoryIsMatch() {
        let tx = makeTransaction(category: "groceries")
        let cond = WidgetRuleCondition.makeMock(op: "is", field: "category", stringValue: "groceries")
        #expect(ConditionsFilter.matches(transaction: tx, conditions: [cond], op: "and"))
    }

    @Test func categoryIsMismatch() {
        let tx = makeTransaction(category: "rent")
        let cond = WidgetRuleCondition.makeMock(op: "is", field: "category", stringValue: "groceries")
        #expect(!ConditionsFilter.matches(transaction: tx, conditions: [cond], op: "and"))
    }

    @Test func accountIsMatch() {
        let tx = makeTransaction(account: "checking")
        let cond = WidgetRuleCondition.makeMock(op: "is", field: "account", stringValue: "checking")
        #expect(ConditionsFilter.matches(transaction: tx, conditions: [cond], op: "and"))
    }

    @Test func amountGreaterThan() {
        let tx = makeTransaction(amount: -2000)
        let cond = WidgetRuleCondition.makeMock(op: "gt", field: "amount", intValue: -3000)
        // tx.amount (-2000) > -3000 → true
        #expect(ConditionsFilter.matches(transaction: tx, conditions: [cond], op: "and"))
    }

    @Test func isNotInverts() {
        let tx = makeTransaction(category: "groceries")
        let cond = WidgetRuleCondition.makeMock(op: "isNot", field: "category", stringValue: "rent")
        #expect(ConditionsFilter.matches(transaction: tx, conditions: [cond], op: "and"))
    }

    @Test func andRequiresAllMatch() {
        let tx = makeTransaction(category: "groceries", account: "checking")
        let conds = [
            WidgetRuleCondition.makeMock(op: "is", field: "category", stringValue: "groceries"),
            WidgetRuleCondition.makeMock(op: "is", field: "account", stringValue: "savings")
        ]
        #expect(!ConditionsFilter.matches(transaction: tx, conditions: conds, op: "and"))
    }

    @Test func orRequiresOneMatch() {
        let tx = makeTransaction(category: "groceries", account: "checking")
        let conds = [
            WidgetRuleCondition.makeMock(op: "is", field: "category", stringValue: "rent"),
            WidgetRuleCondition.makeMock(op: "is", field: "account", stringValue: "checking")
        ]
        #expect(ConditionsFilter.matches(transaction: tx, conditions: conds, op: "or"))
    }

    @Test func unknownOpPassesThrough() {
        // Unknown ops default to true so widgets don't silently filter
        // everything out. Better to show too many transactions than zero.
        let tx = makeTransaction(category: "groceries")
        let cond = WidgetRuleCondition.makeMock(op: "weirdOp", field: "category", stringValue: "groceries")
        #expect(ConditionsFilter.matches(transaction: tx, conditions: [cond], op: "and"))
    }

    @Test func oneOfMatchesAnyValue() {
        let tx = makeTransaction(category: "groceries")
        let cond = WidgetRuleCondition.makeMock(
            op: "oneOf", field: "category",
            stringArrayValue: ["rent", "groceries", "fuel"]
        )
        #expect(ConditionsFilter.matches(transaction: tx, conditions: [cond], op: "and"))
    }

    @Test func oneOfMissesWhenNotInList() {
        let tx = makeTransaction(category: "entertainment")
        let cond = WidgetRuleCondition.makeMock(
            op: "oneOf", field: "category",
            stringArrayValue: ["rent", "groceries", "fuel"]
        )
        #expect(!ConditionsFilter.matches(transaction: tx, conditions: [cond], op: "and"))
    }

    @Test func notOneOfInverts() {
        // Common pattern: "exclude income categories" -> notOneOf(category, [income_ids])
        let tx = makeTransaction(category: "groceries")
        let cond = WidgetRuleCondition.makeMock(
            op: "notOneOf", field: "category",
            stringArrayValue: ["income-salary", "income-bonus"]
        )
        #expect(ConditionsFilter.matches(transaction: tx, conditions: [cond], op: "and"))
    }

    @Test func notOneOfRejectsListedValue() {
        let tx = makeTransaction(category: "income-salary")
        let cond = WidgetRuleCondition.makeMock(
            op: "notOneOf", field: "category",
            stringArrayValue: ["income-salary", "income-bonus"]
        )
        #expect(!ConditionsFilter.matches(transaction: tx, conditions: [cond], op: "and"))
    }

    @Test func containsIsCaseInsensitive() {
        let tx = Transaction(
            id: "1", accountId: "a", date: 20260301, amount: -100,
            payeeId: nil, payeeName: nil, categoryId: nil, categoryName: nil,
            notes: "Coffee at Bluebird Cafe", cleared: false, reconciled: false,
            transferId: nil, isParent: false, parentId: nil,
            tombstone: false, sortOrder: nil, importedPayee: nil
        )
        let cond = WidgetRuleCondition.makeMock(op: "contains", field: "notes", stringValue: "bluebird")
        #expect(ConditionsFilter.matches(transaction: tx, conditions: [cond], op: "and"))
    }
}

/// Test helper to build WidgetRuleCondition values from primitives.
extension WidgetRuleCondition {
    static func makeMock(
        op: String,
        field: String,
        stringValue: String? = nil,
        intValue: Int? = nil,
        stringArrayValue: [String]? = nil
    ) -> WidgetRuleCondition {
        let json: String
        if let arr = stringArrayValue {
            let arrJSON = "[" + arr.map { "\"\($0)\"" }.joined(separator: ",") + "]"
            json = #"{"op":"\#(op)","field":"\#(field)","value":\#(arrJSON)}"#
        } else if let s = stringValue {
            json = #"{"op":"\#(op)","field":"\#(field)","value":"\#(s)"}"#
        } else if let i = intValue {
            json = #"{"op":"\#(op)","field":"\#(field)","value":\#(i)}"#
        } else {
            json = #"{"op":"\#(op)","field":"\#(field)","value":null}"#
        }
        return try! JSONDecoder().decode(WidgetRuleCondition.self, from: Data(json.utf8))
    }
}

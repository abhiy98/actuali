import Foundation
import Testing
@testable import Actuali

@MainActor
struct SpendingEngineTests {

    private var asOf: Date {
        var c = DateComponents(); c.year = 2026; c.month = 5; c.day = 14
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    private func tx(date: Int, amount: Int) -> Transaction {
        Transaction(
            id: UUID().uuidString,
            accountId: "a1", date: date, amount: amount,
            payeeId: nil, payeeName: nil, categoryId: nil, categoryName: nil,
            notes: nil, cleared: false, reconciled: false,
            transferId: nil, isParent: false, parentId: nil,
            tombstone: false, sortOrder: nil, importedPayee: nil
        )
    }

    @Test func currentMonthSpendingExcludesIncome() {
        let transactions = [
            tx(date: 20260501, amount: -10000),
            tx(date: 20260502, amount: 50000),   // income — excluded
            tx(date: 20260503, amount: -2000)
        ]
        let meta = SpendingMeta(name: nil, conditions: nil, conditionsOp: nil,
                                compare: nil, compareTo: nil, isLive: true, mode: .average)
        let result = SpendingEngine.compute(meta: meta, transactions: transactions, today: asOf)
        #expect(result.currentSpentCents == 12000)
    }

    @Test func averageOfPriorMonths() {
        // asOf is 2026-05-14, so prior-month spending is averaged month-to-date
        // (through day 14) over the 3 prior months: Feb, Mar, Apr.
        let transactions = [
            tx(date: 20260210, amount: -10000),  // Feb, within MTD cutoff
            tx(date: 20260310, amount: -10000),  // Mar, within MTD cutoff
            tx(date: 20260410, amount: -10000),  // Apr, within MTD cutoff
            tx(date: 20260420, amount: -50000),  // Apr, after day 14 — excluded by MTD cutoff
            tx(date: 20260505, amount: -5000)    // current month
        ]
        let meta = SpendingMeta(name: nil, conditions: nil, conditionsOp: nil,
                                compare: nil, compareTo: nil, isLive: true, mode: .average)
        let result = SpendingEngine.compute(meta: meta, transactions: transactions, today: asOf)
        #expect(result.currentSpentCents == 5000)
        // 3 prior months MTD: 10000 each (the 20260420 tx is past day 14), sum 30000, avg 30000/3 = 10000
        #expect(result.comparisonCents == 10000)
    }

    @Test func singleMonthCompareTo() {
        let transactions = [
            tx(date: 20260301, amount: -7777),   // March
            tx(date: 20260501, amount: -100)     // current
        ]
        let meta = SpendingMeta(name: nil, conditions: nil, conditionsOp: nil,
                                compare: nil, compareTo: "2026-03", isLive: true, mode: .singleMonth)
        let result = SpendingEngine.compute(meta: meta, transactions: transactions, today: asOf)
        #expect(result.comparisonCents == 7777)
    }

    @Test func budgetModeReturnsZeroComparison() {
        let meta = SpendingMeta(name: nil, conditions: nil, conditionsOp: nil,
                                compare: nil, compareTo: nil, isLive: true, mode: .budget)
        let result = SpendingEngine.compute(meta: meta, transactions: [], today: asOf)
        #expect(result.comparisonCents == 0)
    }
}

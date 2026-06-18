import Foundation

struct SummaryData: Equatable {
    let totalCents: Int
}

enum SummaryEngine {

    static func compute(
        meta: SummaryMeta?,
        transactions: [Transaction],
        today: Date
    ) -> SummaryData {
        guard let meta else { return SummaryData(totalCents: 0) }

        let (start, end) = TimeFrame.resolve(meta.timeFrame, asOf: today)
        let startYMD = ymdInt(from: start)
        let endYMD = ymdInt(from: end)

        let total = transactions
            .filter { !$0.tombstone }
            .filter { $0.date >= startYMD && $0.date <= endYMD }
            .filter { ConditionsFilter.matches(transaction: $0, conditions: meta.conditions, op: meta.conditionsOp) }
            .reduce(0) { $0 + $1.amount }

        return SummaryData(totalCents: total)
    }

    private static func ymdInt(from date: Date) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return (comps.year ?? 0) * 10000 + (comps.month ?? 0) * 100 + (comps.day ?? 0)
    }
}

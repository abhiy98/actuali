import Foundation

/// Mirrors loot-core's rule model. Conditions and actions are stored as JSON
/// blobs in the `rules` table; field names use the *internal* schema names
/// (e.g. `description` for payee, `imported_description` for imported_payee,
/// `acct` for account). They are translated to public names on parse.
///
/// Subset of upstream support:
/// - Stages: `pre`, default (nil), `post` — runs in that order.
/// - Condition ops: is, isNot, contains, doesNotContain, oneOf, notOneOf,
///   matches, gt, gte, lt, lte, isbetween, isapprox.
/// - Action ops: set, prepend-notes, append-notes.
/// - Skipped (logged + treated as no-op): link-schedule, set-split-amount,
///   delete-transaction, formula/handlebars templates, hasTags,
///   recurring-date conditions, onBudget/offBudget.
struct Rule: Identifiable {
    let id: String
    let stage: Stage
    let conditionsOp: ConditionsOp
    let conditions: [Condition]
    let actions: [Action]

    enum Stage: Int, Comparable {
        case pre = 0
        case `default` = 1
        case post = 2

        static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }

        init(raw: String?) {
            switch raw {
            case "pre": self = .pre
            case "post": self = .post
            default: self = .default
            }
        }
    }

    enum ConditionsOp: String {
        case and
        case or

        init(raw: String?) {
            self = raw?.lowercased() == "or" ? .or : .and
        }
    }

    struct Condition {
        let op: String
        let field: String   // public field name (e.g. "imported_payee")
        let value: Any?
        let options: [String: Any]?
    }

    struct Action {
        let op: String
        let field: String?  // nil for ops without a field (e.g. link-schedule)
        let value: Any?
        let options: [String: Any]?
    }
}

// MARK: - JSON parsing

enum RuleParseError: Error {
    case invalidJSON
    case notArray
}

/// Internal-to-public field-name translation, mirroring
/// `schemaConfig.views.transactions.fields` in loot-core.
private let internalToPublicField: [String: String] = [
    "isParent": "is_parent",
    "isChild": "is_child",
    "acct": "account",
    "financial_id": "imported_id",
    "imported_description": "imported_payee",
    "transferred_id": "transfer_id",
    "description": "payee",
]

private func publicField(from internalField: String) -> String {
    internalToPublicField[internalField] ?? internalField
}

extension Rule {
    /// Parse a single rule row from the `rules` table.
    /// `conditionsJSON` and `actionsJSON` are the raw JSON text columns.
    static func parse(
        id: String,
        stage: String?,
        conditionsOp: String?,
        conditionsJSON: String?,
        actionsJSON: String?
    ) throws -> Rule {
        let conditions = try parseConditions(conditionsJSON)
        let actions = try parseActions(actionsJSON)
        return Rule(
            id: id,
            stage: Stage(raw: stage),
            conditionsOp: ConditionsOp(raw: conditionsOp),
            conditions: conditions,
            actions: actions
        )
    }

    private static func parseConditions(_ json: String?) throws -> [Condition] {
        let items = try parseArray(json)
        return items.compactMap { item -> Condition? in
            guard
                let op = item["op"] as? String,
                let internalField = item["field"] as? String
            else { return nil }
            return Condition(
                op: op,
                field: publicField(from: internalField),
                value: item["value"] ?? nil,
                options: item["options"] as? [String: Any]
            )
        }
    }

    private static func parseActions(_ json: String?) throws -> [Action] {
        let items = try parseArray(json)
        return items.compactMap { item -> Action? in
            guard let op = item["op"] as? String else { return nil }
            let internalField = item["field"] as? String
            return Action(
                op: op,
                field: internalField.map(publicField(from:)),
                value: item["value"] ?? nil,
                options: item["options"] as? [String: Any]
            )
        }
    }

    private static func parseArray(_ json: String?) throws -> [[String: Any]] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        let any = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        guard let arr = any as? [[String: Any]] else {
            if any is NSNull { return [] }
            throw RuleParseError.notArray
        }
        return arr
    }
}

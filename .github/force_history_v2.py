from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: str, old: str, new: str) -> None:
    file = ROOT / path
    text = file.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Expected exactly one match in {path}; found {count}")
    file.write_text(text.replace(old, new, 1))

budget_store = "Actuali/Actuali/Services/BudgetStore.swift"

replace_once(
    budget_store,
    '''        let changedFields = Self.changedFields(original: original, updated: updated)\n        try await syncClient.updateTransaction(updated, changedFields: changedFields)\n        await refreshDataOnly()''',
    '''        let changedFields = Self.changedFields(original: original, updated: updated)\n        try await syncClient.updateTransaction(updated, changedFields: changedFields)\n        if let budgetID = currentBudgetId {\n            HistoryStore.shared.record(budgetID: budgetID, kind: .edited, before: [original], after: [updated])\n        }\n        await refreshDataOnly()'''
)

replace_once(
    budget_store,
    '''        do {\n            try await syncClient.updateTransactions(deleted, changedFields: ["tombstone"])\n        } catch {\n            self.error = "Failed to delete transaction: \\(error.localizedDescription)"\n        }\n        await refreshDataOnly()''',
    '''        var didWrite = false\n        do {\n            try await syncClient.updateTransactions(deleted, changedFields: ["tombstone"])\n            didWrite = true\n        } catch {\n            self.error = "Failed to delete transaction: \\(error.localizedDescription)"\n        }\n        if didWrite, let budgetID = currentBudgetId {\n            let ids = Set(deleted.map(\\.id))\n            let before = transactions.filter { ids.contains($0.id) }\n            HistoryStore.shared.record(budgetID: budgetID, kind: .deleted, before: before, after: deleted)\n        }\n        await refreshDataOnly()'''
)

replace_once(
    budget_store,
    '''                try await createTransaction(transaction)\n                if form.recordLocation, let payeeId {''',
    '''                try await createTransaction(transaction)\n                if let budgetID = currentBudgetId {\n                    HistoryStore.shared.record(budgetID: budgetID, kind: .created, before: [], after: [transaction])\n                }\n                if form.recordLocation, let payeeId {'''
)

replace_once(
    budget_store,
    '''            try await syncClient.createSplit(parent: parent, children: children)\n            await refreshDataOnly()''',
    '''            try await syncClient.createSplit(parent: parent, children: children)\n            if let budgetID = currentBudgetId {\n                HistoryStore.shared.record(budgetID: budgetID, kind: .created, before: [], after: [parent] + children)\n            }\n            await refreshDataOnly()'''
)

replace_once(
    budget_store,
    '''        try await syncClient.createTransfer(source: source, target: target)\n        await refreshDataOnly()''',
    '''        try await syncClient.createTransfer(source: source, target: target)\n        if let budgetID = currentBudgetId {\n            HistoryStore.shared.record(budgetID: budgetID, kind: .created, before: [], after: [source, target])\n        }\n        await refreshDataOnly()'''
)

replace_once(
    budget_store,
    '''        if !targetChanges.isEmpty {\n            try await syncClient.updateTransaction(target, changedFields: targetChanges)\n        }\n        await refreshDataOnly()''',
    '''        if !targetChanges.isEmpty {\n            try await syncClient.updateTransaction(target, changedFields: targetChanges)\n        }\n        if let budgetID = currentBudgetId {\n            HistoryStore.shared.record(budgetID: budgetID, kind: .edited, before: [sourceLeg, targetLeg], after: [source, target])\n        }\n        await refreshDataOnly()'''
)

# The runner is disposable. The final branch contains only product/test code.
(ROOT / ".github/force_history.py").unlink(missing_ok=True)
(ROOT / ".github/force_history_v2.py").unlink(missing_ok=True)
(ROOT / ".github/workflows/force-history.yml").unlink(missing_ok=True)

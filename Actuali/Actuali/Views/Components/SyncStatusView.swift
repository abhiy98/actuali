// Actuali/Actuali/Views/Components/SyncStatusView.swift

import SwiftUI

struct SyncStatusView: View {
    let state: SyncState

    var body: some View {
        HStack(spacing: 4) {
            switch state {
            case .idle:
                Image(systemName: "checkmark.icloud")
                    .foregroundStyle(.green)
            case .syncing:
                ProgressView()
                    .scaleEffect(0.7)
            case .offline:
                Image(systemName: "icloud.slash")
                    .foregroundStyle(.orange)
            case .error:
                Image(systemName: "exclamationmark.icloud")
                    .foregroundStyle(.red)
            }
        }
        .font(.footnote)
    }
}

#Preview("Idle") {
    SyncStatusView(state: .idle)
}

#Preview("Syncing") {
    SyncStatusView(state: .syncing)
}

#Preview("Offline") {
    SyncStatusView(state: .offline)
}

#Preview("Error") {
    SyncStatusView(state: .error("Test error"))
}

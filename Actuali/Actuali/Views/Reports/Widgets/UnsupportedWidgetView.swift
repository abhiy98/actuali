import SwiftUI

struct UnsupportedWidgetView: View {
    let displayName: String
    let typeLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayName)
                .font(.headline)
            HStack(spacing: 6) {
                Image(systemName: "hourglass")
                    .foregroundStyle(.secondary)
                Text("Coming soon: \(typeLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    UnsupportedWidgetView(displayName: "Money Flow", typeLabel: "sankey-card")
        .padding()
}

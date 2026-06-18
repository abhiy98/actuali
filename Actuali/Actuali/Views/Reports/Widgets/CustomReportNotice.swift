import SwiftUI

/// Banner shown at the top of the Reports dashboard when the user has one or
/// more widgets of types we don't render yet. Lists the types hidden so the
/// user knows what's missing.
struct UnsupportedTypesNotice: View {
    let typeLabels: [String]

    private var message: String {
        let list: String
        switch typeLabels.count {
        case 0: list = ""
        case 1: list = typeLabels[0]
        case 2: list = "\(typeLabels[0]) and \(typeLabels[1])"
        default:
            let head = typeLabels.dropLast().joined(separator: ", ")
            list = "\(head), and \(typeLabels.last!)"
        }
        return "\(list) cards are not currently supported."
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("One") {
    UnsupportedTypesNotice(typeLabels: ["Custom Report"])
        .padding()
}

#Preview("Two") {
    UnsupportedTypesNotice(typeLabels: ["Custom Report", "Formula"])
        .padding()
}

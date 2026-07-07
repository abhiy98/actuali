import Foundation

/// Whether the user has opted into transaction notifications (GH #27).
/// Default off — this gates background-refresh scheduling and notification
/// posting, so no user gets background activity without asking for it.
struct TransactionNotificationSettings {

    static let key = "transactionNotificationsEnabled"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Self.key) }
        nonmutating set { defaults.set(newValue, forKey: Self.key) }
    }
}

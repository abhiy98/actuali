import AppIntents

struct ActualiShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogTransactionIntent(),
            phrases: [
                "Log transaction in \(.applicationName)",
                "Add transaction to \(.applicationName)",
                "Log a transaction in \(.applicationName)",
            ],
            shortTitle: "Log Transaction",
            systemImageName: "dollarsign.circle"
        )
    }
}

import Foundation
import Testing
import BackgroundTasks
@testable import Actuali

struct TransactionNotificationSettingsTests {

    private func makeDefaults() -> UserDefaults {
        let name = "TransactionNotificationSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func disabledByDefault() {
        let settings = TransactionNotificationSettings(defaults: makeDefaults())

        #expect(settings.isEnabled == false)
    }

    @Test func enablementPersistsAcrossInstances() {
        let defaults = makeDefaults()

        TransactionNotificationSettings(defaults: defaults).isEnabled = true

        #expect(TransactionNotificationSettings(defaults: defaults).isEnabled == true)
    }

    @Test func scheduleIfEnabledSubmitsWhenEnabled() {
        let defaults = makeDefaults()
        TransactionNotificationSettings(defaults: defaults).isEnabled = true
        let spy = SubmitSpy()

        BackgroundRefresh.scheduleIfEnabled(
            settings: TransactionNotificationSettings(defaults: defaults),
            using: spy, now: Date(timeIntervalSince1970: 0))

        #expect(spy.submitted.map(\.identifier) == [BackgroundRefresh.taskIdentifier])
    }

    @Test func scheduleIfEnabledDoesNothingWhenDisabled() {
        let spy = SubmitSpy()

        BackgroundRefresh.scheduleIfEnabled(
            settings: TransactionNotificationSettings(defaults: makeDefaults()),
            using: spy, now: Date(timeIntervalSince1970: 0))

        #expect(spy.submitted.isEmpty)
    }
}

private final class SubmitSpy: BackgroundTaskRequesting {
    var submitted: [BGTaskRequest] = []

    func submit(_ taskRequest: BGTaskRequest) throws {
        submitted.append(taskRequest)
    }
}

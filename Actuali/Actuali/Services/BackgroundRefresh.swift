import Foundation
import BackgroundTasks
import os

private let bgLog = Logger(subsystem: "com.mfazz.Actuali", category: "BackgroundRefresh")

/// Seam over BGTaskScheduler's submit so scheduling logic is testable.
protocol BackgroundTaskRequesting {
    func submit(_ taskRequest: BGTaskRequest) throws
}

extension BGTaskScheduler: BackgroundTaskRequesting {}

/// Periodic background refresh that will drive transaction notifications:
/// iOS wakes the app, we sync headlessly and notify about new transactions.
/// The task handler is a stub until the headless sync lands; this layer only
/// owns registration, scheduling, and keeping the refresh chain alive.
enum BackgroundRefresh {

    /// Must stay listed in BGTaskSchedulerPermittedIdentifiers (both Info
    /// plists) — registering an unlisted identifier crashes at launch.
    static let taskIdentifier = "com.mfazz.ActualiOS.refresh"

    /// Hint to iOS for the earliest next run; actual timing is at the
    /// system's discretion and typically less frequent.
    static let minimumInterval: TimeInterval = 4 * 60 * 60

    static func makeRequest(now: Date) -> BGAppRefreshTaskRequest {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = now.addingTimeInterval(minimumInterval)
        return request
    }

    /// Schedule only when the user has opted into transaction notifications —
    /// the sole reason this refresh exists.
    static func scheduleIfEnabled(settings: TransactionNotificationSettings = TransactionNotificationSettings(),
                                  using scheduler: BackgroundTaskRequesting = BGTaskScheduler.shared,
                                  now: Date = Date()) {
        guard settings.isEnabled else { return }
        schedule(using: scheduler, now: now)
    }

    /// Called when the user turns transaction notifications off.
    static func cancelPending() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
    }

    static func schedule(using scheduler: BackgroundTaskRequesting = BGTaskScheduler.shared,
                         now: Date = Date()) {
        do {
            try scheduler.submit(makeRequest(now: now))
        } catch {
            // Expected on simulator and when Background App Refresh is off.
            bgLog.error("Failed to schedule background refresh: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Must be called before the app finishes launching.
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(refreshTask)
        }
    }

    static func handle(_ task: BGAppRefreshTask) {
        // A task submitted before the user disabled notifications can still
        // fire; treat it as a no-op and let the chain die.
        guard TransactionNotificationSettings().isEnabled else {
            task.setTaskCompleted(success: true)
            return
        }
        // Reschedule first so the chain survives regardless of the outcome.
        schedule()
        bgLog.info("Background refresh fired, starting headless sync")
        let work = Task { @MainActor in
            let store = BudgetStore.shared
            let synced = await store.syncInBackground()
            if synced {
                let fresh = await store.detectNewTransactionsForNotification()
                await NewTransactionNotifier.notify(about: fresh, currencyCode: store.currencyCode)
            }
            bgLog.info("Background sync finished (budgetConfigured: \(synced))")
            task.setTaskCompleted(success: synced)
        }
        // On expiration, cancellation propagates into URLSession so the sync
        // aborts quickly; the task body still runs to setTaskCompleted.
        task.expirationHandler = { work.cancel() }
    }
}

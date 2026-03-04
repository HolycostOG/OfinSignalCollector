//
//  NotificationManager.swift
//  OdinSignalCollector
//
//  Local notification management service for scheduling and managing alerts.
//

import Foundation
import UserNotifications

// MARK: - Notification Manager

/// Service responsible for scheduling, managing, and cancelling local notifications.
///
/// `NotificationManager` wraps `UNUserNotificationCenter` with a DI-friendly
/// design and exposes the current authorization status as `@Published` properties.
/// It enforces an alert cooldown window to prevent duplicate notifications within a
/// configurable time interval, and persists the timestamp of the last alert in
/// `UserDefaults` using ISO-8601 format.
///
/// ## Singleton usage
/// ```swift
/// NotificationManager.shared.scheduleAlert(title: "Weak Signal", body: "Signal dropped below threshold")
/// ```
///
/// ## Dependency-injection usage
/// ```swift
/// let manager = NotificationManager(cooldownInterval: 30)
/// viewModel.notificationManager = manager
/// ```
@MainActor
final class NotificationManager: ObservableObject {

    // MARK: - Singleton

    /// Shared singleton instance for app-wide use.
    static let shared = NotificationManager()

    // MARK: - Published Properties

    /// Current notification authorization status reported by the system.
    ///
    /// Updated after `requestAuthorization()` completes and whenever
    /// `refreshAuthorizationStatus()` is called.
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// `true` when the user has granted notification permission (`.authorized`).
    @Published var isAuthorized: Bool = false

    // MARK: - Public Properties

    /// Duration in seconds during which duplicate alerts are suppressed.
    ///
    /// Set to `0` to disable the cooldown entirely.
    var cooldownInterval: TimeInterval

    // MARK: - Private Properties

    private let notificationCenter: UNUserNotificationCenter
    private let userDefaults: UserDefaults

    private let lastAlertTimestampKey = "NotificationManager.lastAlertTimestamp"

    private let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // MARK: - Initialization

    /// Creates a `NotificationManager` and immediately requests notification authorization.
    ///
    /// Authorization is requested asynchronously; ``isAuthorized`` and
    /// ``authorizationStatus`` reflect the user's decision once the system dialog
    /// is dismissed and may not be accurate immediately after `init` returns.
    ///
    /// - Parameters:
    ///   - cooldownInterval: Minimum number of seconds between successive scheduled alerts.
    ///                       Defaults to `AppConfiguration.alertCooldownInterval`.
    ///   - notificationCenter: `UNUserNotificationCenter` instance to use.
    ///                         Defaults to `.current()`.
    ///   - userDefaults: `UserDefaults` suite used to persist the last-alert timestamp.
    ///                   Defaults to `.standard`.
    init(
        cooldownInterval: TimeInterval = AppConfiguration.alertCooldownInterval,
        notificationCenter: UNUserNotificationCenter = .current(),
        userDefaults: UserDefaults = .standard
    ) {
        self.cooldownInterval = cooldownInterval
        self.notificationCenter = notificationCenter
        self.userDefaults = userDefaults
        requestAuthorization()
    }

    // MARK: - Authorization

    /// Requests `.alert`, `.sound`, and `.badge` notification permissions from the user.
    ///
    /// On completion, ``authorizationStatus`` and ``isAuthorized`` are updated on the
    /// main actor. Safe to call multiple times; the system presents the dialog only once.
    func requestAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let error = error {
                    print("✗ Notification authorization error: \(error.localizedDescription)")
                }
                self.isAuthorized = granted
                await self.refreshAuthorizationStatus()
                print(granted ? "✓ Notifications authorized" : "ℹ Notifications not authorized")
            }
        }
    }

    /// Queries `UNUserNotificationCenter` and refreshes ``authorizationStatus`` and
    /// ``isAuthorized`` with the current system values.
    func refreshAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Scheduling

    /// Schedules a local notification alert.
    ///
    /// The notification is delivered after a 1-second delay using
    /// `UNTimeIntervalNotificationTrigger`. If an alert was already sent within
    /// ``cooldownInterval`` seconds, or if authorization has not been granted,
    /// the method returns `false` without scheduling anything.
    ///
    /// - Parameters:
    ///   - identifier: A unique string that identifies the notification request.
    ///                 Defaults to a freshly generated `UUID` string.
    ///                 Use a stable identifier to update or cancel a specific notification.
    ///   - title:      The localised title line of the notification.
    ///   - body:       The localised body message of the notification.
    ///   - payload:    Optional dictionary of additional data attached to the
    ///                 notification's `userInfo`. Must contain only property-list-compatible
    ///                 types (e.g. `String`, `Int`, `Date`).
    /// - Returns: `true` if the notification was successfully submitted for scheduling;
    ///            `false` if it was suppressed by the cooldown window or because the app
    ///            is not authorized to send notifications.
    @discardableResult
    func scheduleAlert(
        identifier: String = UUID().uuidString,
        title: String,
        body: String,
        payload: [AnyHashable: Any]? = nil
    ) -> Bool {
        guard isAuthorized else {
            print("ℹ Notification skipped – not authorized")
            return false
        }

        // Enforce cooldown window
        if cooldownInterval > 0, let lastDate = loadLastAlertTimestamp() {
            let elapsed = Date().timeIntervalSince(lastDate)
            if elapsed < cooldownInterval {
                print("ℹ Alert suppressed by cooldown – \(Int(ceil(cooldownInterval - elapsed)))s remaining")
                return false
            }
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let payload = payload {
            content.userInfo = payload
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error = error {
                print("✗ Failed to schedule notification '\(identifier)': \(error.localizedDescription)")
            } else {
                print("✓ Notification scheduled: \(identifier)")
                Task { @MainActor [weak self] in
                    self?.persistLastAlertTimestamp(Date())
                }
            }
        }

        return true
    }

    // MARK: - Cancellation

    /// Cancels all pending (not yet delivered) local notification requests.
    func cancelAllPendingNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        print("✓ All pending notifications cancelled")
    }

    /// Cancels pending notification requests with the specified identifiers.
    ///
    /// - Parameter identifiers: An array of notification identifiers to cancel.
    ///                          Identifiers that do not match any pending request are silently ignored.
    func cancelNotifications(withIdentifiers identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("✓ Cancelled notifications: \(identifiers.joined(separator: ", "))")
    }

    // MARK: - Cooldown Helpers

    /// Returns the timestamp of the last successfully scheduled alert.
    ///
    /// The value is read from `UserDefaults` where it is persisted as an ISO-8601
    /// string. Returns `nil` if no alert has ever been scheduled, or if the stored
    /// value cannot be parsed.
    ///
    /// - Returns: The `Date` of the last alert, or `nil`.
    func lastAlertDate() -> Date? {
        return loadLastAlertTimestamp()
    }

    // MARK: - Private Helpers

    private func persistLastAlertTimestamp(_ date: Date) {
        let iso8601String = iso8601Formatter.string(from: date)
        userDefaults.set(iso8601String, forKey: lastAlertTimestampKey)
    }

    private func loadLastAlertTimestamp() -> Date? {
        guard let iso8601String = userDefaults.string(forKey: lastAlertTimestampKey) else {
            return nil
        }
        return iso8601Formatter.date(from: iso8601String)
    }
}

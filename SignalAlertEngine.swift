//
//  SignalAlertEngine.swift
//  OdinSignalCollector
//
//  Alert engine for signal quality monitoring and notifications
//

import Foundation
import Combine
import UserNotifications

// MARK: - Alert Engine Service

/// Service responsible for monitoring signal quality and triggering alerts
@MainActor
class SignalAlertEngine: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var activeAlerts: [SignalAlert] = []
    @Published var alertHistory: [SignalAlert] = []
    @Published var alertThreshold: AlertThreshold = .default
    @Published var isEnabled: Bool = false
    @Published var notificationsEnabled: Bool = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let notificationCenter = UNUserNotificationCenter.current()
    private let maxAlertHistorySize = 100
    
    // Alert cooldown to prevent spam
    private var lastAlertTime: Date?
    private let alertCooldownInterval: TimeInterval = 60.0 // 1 minute
    
    // MARK: - Initialization
    
    init() {
        loadSettings()
        requestNotificationPermission()
    }
    
    // MARK: - Public Methods
    
    /// Enable alert monitoring
    func enable() {
        isEnabled = true
        saveSettings()
        print("✓ Alert engine enabled")
    }
    
    /// Disable alert monitoring
    func disable() {
        isEnabled = false
        saveSettings()
        print("✓ Alert engine disabled")
    }
    
    /// Update alert threshold configuration
    func updateThreshold(_ threshold: AlertThreshold) {
        alertThreshold = threshold
        saveSettings()
        print("✓ Alert threshold updated: \(threshold.minimumSignalStrength) dBm")
    }
    
    /// Check signal data and trigger alert if necessary
    func checkSignal(_ signalData: SignalData) {
        guard isEnabled && alertThreshold.enabled else { return }
        
        // Check if signal strength is below threshold
        guard let signalStrength = signalData.signalStrength else { return }
        
        if signalStrength < alertThreshold.minimumSignalStrength {
            triggerAlert(for: signalData)
        }
    }
    
    /// Acknowledge an alert
    func acknowledgeAlert(_ alertId: UUID) {
        if let index = activeAlerts.firstIndex(where: { $0.id == alertId }) {
            activeAlerts[index].acknowledged = true
            
            // Move to history after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.moveAlertToHistory(alertId)
            }
        }
    }
    
    /// Dismiss an alert
    func dismissAlert(_ alertId: UUID) {
        activeAlerts.removeAll { $0.id == alertId }
        print("✓ Alert dismissed: \(alertId)")
    }
    
    /// Clear all active alerts
    func clearActiveAlerts() {
        activeAlerts.removeAll()
        print("✓ All active alerts cleared")
    }
    
    /// Clear alert history
    func clearAlertHistory() {
        alertHistory.removeAll()
        print("✓ Alert history cleared")
    }
    
    /// Get unacknowledged alerts count
    func getUnacknowledgedCount() -> Int {
        return activeAlerts.filter { !$0.acknowledged }.count
    }
    
    /// Get alerts for a specific time range
    func getAlerts(from startDate: Date, to endDate: Date) -> [SignalAlert] {
        let allAlerts = activeAlerts + alertHistory
        return allAlerts.filter { alert in
            alert.timestamp >= startDate && alert.timestamp <= endDate
        }
    }
    
    /// Enable push notifications for alerts
    func enableNotifications() {
        requestNotificationPermission()
    }
    
    // MARK: - Private Methods
    
    private func triggerAlert(for signalData: SignalData) {
        // Check cooldown to prevent alert spam
        if let lastAlert = lastAlertTime,
           Date().timeIntervalSince(lastAlert) < alertCooldownInterval {
            return
        }
        
        lastAlertTime = Date()
        
        // Create alert
        let alert = SignalAlert(
            signalData: signalData,
            message: generateAlertMessage(for: signalData)
        )
        
        // Add to active alerts
        activeAlerts.insert(alert, at: 0)
        
        // Send notification if enabled
        if notificationsEnabled {
            sendNotification(for: alert)
        }
        
        print("⚠️ Alert triggered: \(alert.message)")
    }
    
    private func generateAlertMessage(for signalData: SignalData) -> String {
        if let strength = signalData.signalStrength {
            return "Signal strength dropped to \(strength) dBm (\(signalData.strengthLevel.rawValue)) on \(signalData.technology)"
        } else {
            return alertThreshold.alertMessage
        }
    }
    
    private func moveAlertToHistory(_ alertId: UUID) {
        guard let index = activeAlerts.firstIndex(where: { $0.id == alertId }) else { return }
        
        let alert = activeAlerts.remove(at: index)
        alertHistory.insert(alert, at: 0)
        
        // Maintain history size
        if alertHistory.count > maxAlertHistorySize {
            alertHistory.removeLast()
        }
    }
    
    // MARK: - Notifications
    
    private func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            Task { @MainActor [weak self] in
                if let error = error {
                    print("✗ Notification permission error: \(error.localizedDescription)")
                    self?.notificationsEnabled = false
                } else {
                    self?.notificationsEnabled = granted
                    print(granted ? "✓ Notifications enabled" : "ℹ Notifications denied")
                }
            }
        }
    }
    
    private func sendNotification(for alert: SignalAlert) {
        let content = UNMutableNotificationContent()
        content.title = "Signal Alert"
        content.body = alert.message
        content.sound = .default
        content.badge = NSNumber(value: getUnacknowledgedCount())
        
        // Create trigger (immediate)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: alert.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        notificationCenter.add(request) { error in
            if let error = error {
                print("✗ Failed to send notification: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Persistence
    
    private func saveSettings() {
        let encoder = JSONEncoder()
        
        // Save threshold
        if let thresholdData = try? encoder.encode(alertThreshold) {
            UserDefaults.standard.set(thresholdData, forKey: "alertThreshold")
        }
        
        // Save enabled state
        UserDefaults.standard.set(isEnabled, forKey: "alertEngineEnabled")
    }
    
    private func loadSettings() {
        let decoder = JSONDecoder()
        
        // Load threshold
        if let thresholdData = UserDefaults.standard.data(forKey: "alertThreshold"),
           let threshold = try? decoder.decode(AlertThreshold.self, from: thresholdData) {
            alertThreshold = threshold
        }
        
        // Load enabled state
        isEnabled = UserDefaults.standard.bool(forKey: "alertEngineEnabled")
    }
}

// MARK: - Alert Statistics

extension SignalAlertEngine {
    
    /// Get alert statistics
    func getAlertStatistics() -> AlertStatistics {
        let totalAlerts = activeAlerts.count + alertHistory.count
        let acknowledgedCount = alertHistory.count + activeAlerts.filter { $0.acknowledged }.count
        
        // Group by signal strength level
        let allAlerts = activeAlerts + alertHistory
        let alertsByStrength = Dictionary(grouping: allAlerts) { alert in
            alert.signalData.strengthLevel.rawValue
        }.mapValues { $0.count }
        
        return AlertStatistics(
            totalAlerts: totalAlerts,
            activeAlerts: activeAlerts.count,
            acknowledgedAlerts: acknowledgedCount,
            alertDistribution: alertsByStrength
        )
    }
}

// MARK: - Alert Statistics Model

/// Statistical data about alerts
struct AlertStatistics {
    let totalAlerts: Int
    let activeAlerts: Int
    let acknowledgedAlerts: Int
    let alertDistribution: [String: Int]
}

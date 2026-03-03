//
//  SignalDashboardViewModel.swift
//  OdinSignalCollector
//
//  ViewModel for the signal dashboard, coordinating all services
//

import Foundation
import Combine
import SwiftUI

// MARK: - Dashboard ViewModel

/// Main ViewModel coordinating all signal monitoring services
@MainActor
class SignalDashboardViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    // Current state
    @Published var currentSignal: SignalData?
    @Published var connectionStatus: ConnectionStatus = .unknown
    @Published var isMonitoring: Bool = false
    
    // Statistics
    @Published var signalStatistics: SignalStatistics?
    @Published var alertStatistics: AlertStatistics?
    
    // Alerts
    @Published var activeAlertCount: Int = 0
    @Published var recentAlerts: [SignalAlert] = []
    
    // Settings
    @Published var monitoringInterval: TimeInterval = 5.0
    @Published var alertsEnabled: Bool = false
    @Published var alertThreshold: Int = -100
    
    // MARK: - Services
    
    private let signalMonitor: SignalMonitor
    private let historyLogger: SignalHistoryLogger
    private let alertEngine: SignalAlertEngine
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        signalMonitor: SignalMonitor = SignalMonitor(),
        historyLogger: SignalHistoryLogger = SignalHistoryLogger(),
        alertEngine: SignalAlertEngine = SignalAlertEngine()
    ) {
        self.signalMonitor = signalMonitor
        self.historyLogger = historyLogger
        self.alertEngine = alertEngine
        
        setupBindings()
        loadSettings()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring signals
    func startMonitoring() {
        signalMonitor.startMonitoring()
        historyLogger.startLogging()
        
        if alertsEnabled {
            alertEngine.enable()
        }
        
        print("✓ Dashboard monitoring started")
    }
    
    /// Stop monitoring signals
    func stopMonitoring() {
        signalMonitor.stopMonitoring()
        historyLogger.stopLogging()
        alertEngine.disable()
        
        print("✓ Dashboard monitoring stopped")
    }
    
    /// Toggle monitoring on/off
    func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }
    
    /// Pause monitoring
    func pauseMonitoring() {
        signalMonitor.pauseMonitoring()
    }
    
    /// Resume monitoring
    func resumeMonitoring() {
        signalMonitor.resumeMonitoring()
    }
    
    /// Refresh signal data immediately
    func refreshSignal() async {
        await signalMonitor.refreshSignalData()
    }
    
    /// Update monitoring interval
    func updateMonitoringInterval(_ interval: TimeInterval) {
        monitoringInterval = interval
        signalMonitor.setUpdateInterval(interval)
        saveSettings()
    }
    
    /// Toggle alerts on/off
    func toggleAlerts() {
        alertsEnabled.toggle()
        
        if alertsEnabled {
            alertEngine.enable()
        } else {
            alertEngine.disable()
        }
        
        saveSettings()
    }
    
    /// Update alert threshold
    func updateAlertThreshold(_ threshold: Int) {
        alertThreshold = threshold
        
        let alertConfig = AlertThreshold(
            enabled: true,
            minimumSignalStrength: threshold,
            alertMessage: "Signal strength dropped below \(threshold) dBm"
        )
        
        alertEngine.updateThreshold(alertConfig)
        saveSettings()
    }
    
    /// Acknowledge an alert
    func acknowledgeAlert(_ alertId: UUID) {
        alertEngine.acknowledgeAlert(alertId)
    }
    
    /// Dismiss an alert
    func dismissAlert(_ alertId: UUID) {
        alertEngine.dismissAlert(alertId)
    }
    
    /// Clear all alerts
    func clearAllAlerts() {
        alertEngine.clearActiveAlerts()
    }
    
    /// Get signal history
    func getSignalHistory() -> [SignalData] {
        return historyLogger.signalHistory
    }
    
    /// Get recent signal history (last N hours)
    func getRecentHistory(hours: Int) -> [SignalData] {
        return historyLogger.getRecentHistory(hours: hours)
    }
    
    /// Export history as JSON
    func exportHistory() -> String? {
        return historyLogger.exportHistory()
    }
    
    /// Clear history
    func clearHistory() {
        historyLogger.clearHistory()
    }
    
    /// Refresh statistics
    func refreshStatistics() {
        signalStatistics = historyLogger.getStatistics()
        alertStatistics = alertEngine.getAlertStatistics()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Monitor signal updates
        signalMonitor.$currentSignalData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] signalData in
                guard let self = self else { return }
                
                self.currentSignal = signalData
                
                // Log signal if available
                if let signal = signalData {
                    self.historyLogger.logSignal(signal)
                    
                    // Check for alerts
                    if self.alertsEnabled {
                        self.alertEngine.checkSignal(signal)
                    }
                }
                
                // Update statistics
                self.refreshStatistics()
            }
            .store(in: &cancellables)
        
        // Monitor connection status
        signalMonitor.$connectionStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionStatus, on: self)
            .store(in: &cancellables)
        
        // Monitor monitoring state
        signalMonitor.$isMonitoring
            .receive(on: DispatchQueue.main)
            .assign(to: \.isMonitoring, on: self)
            .store(in: &cancellables)
        
        // Monitor active alerts
        alertEngine.$activeAlerts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] alerts in
                self?.activeAlertCount = alerts.count
                self?.recentAlerts = Array(alerts.prefix(5))
            }
            .store(in: &cancellables)
        
        // Monitor alert enabled state
        alertEngine.$isEnabled
            .receive(on: DispatchQueue.main)
            .assign(to: \.alertsEnabled, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Persistence
    
    private func saveSettings() {
        UserDefaults.standard.set(monitoringInterval, forKey: "monitoringInterval")
        UserDefaults.standard.set(alertsEnabled, forKey: "alertsEnabled")
        UserDefaults.standard.set(alertThreshold, forKey: "alertThreshold")
    }
    
    private func loadSettings() {
        // Load monitoring interval
        let savedInterval = UserDefaults.standard.double(forKey: "monitoringInterval")
        if savedInterval > 0 {
            monitoringInterval = savedInterval
            signalMonitor.setUpdateInterval(savedInterval)
        }
        
        // Load alerts enabled state
        alertsEnabled = UserDefaults.standard.bool(forKey: "alertsEnabled")
        
        // Load alert threshold
        let savedThreshold = UserDefaults.standard.integer(forKey: "alertThreshold")
        if savedThreshold != 0 {
            alertThreshold = savedThreshold
        }
    }
}

// MARK: - Computed Properties

extension SignalDashboardViewModel {
    
    /// Current signal strength description
    var signalStrengthDescription: String {
        guard let signal = currentSignal else {
            return "No signal data"
        }
        return signal.signalDescription
    }
    
    /// Current signal strength level
    var signalStrengthLevel: SignalStrength {
        currentSignal?.strengthLevel ?? .noSignal
    }
    
    /// Connection status color
    var connectionStatusColor: Color {
        Color(hex: connectionStatus.colorHex)
    }
    
    /// Signal strength color
    var signalStrengthColor: Color {
        Color(hex: signalStrengthLevel.colorHex)
    }
    
    /// Has active alerts
    var hasActiveAlerts: Bool {
        activeAlertCount > 0
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

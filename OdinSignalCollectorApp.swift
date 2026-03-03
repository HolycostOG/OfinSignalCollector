//
//  OdinSignalCollectorApp.swift
//  OdinSignalCollector
//
//  Main application entry point
//

import SwiftUI

@main
struct OdinSignalCollectorApp: App {
    
    // MARK: - App State
    
    @StateObject private var appState = AppState()
    
    // MARK: - Scene Configuration
    
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(appState)
                .onAppear {
                    setupApp()
                }
        }
    }
    
    // MARK: - App Setup
    
    private func setupApp() {
        print("🚀 Odin Signal Collector initialized")
        
        // Configure appearance
        configureAppearance()
        
        // Request necessary permissions
        requestPermissions()
    }
    
    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    private func requestPermissions() {
        // Permissions for notifications and location would be requested here
        // These are handled in respective service classes
        print("ℹ️ Permissions will be requested as needed")
    }
}

// MARK: - App State

/// Global application state
@MainActor
class AppState: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isActive: Bool = false
    @Published var launchCount: Int = 0
    @Published var lastLaunchDate: Date?
    
    // MARK: - Constants
    
    private let launchCountKey = "app.launchCount"
    private let lastLaunchDateKey = "app.lastLaunchDate"
    
    // MARK: - Initialization
    
    init() {
        loadState()
        incrementLaunchCount()
        updateLastLaunchDate()
    }
    
    // MARK: - Public Methods
    
    /// Mark app as active
    func setActive(_ active: Bool) {
        isActive = active
    }
    
    /// Get app version
    func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    /// Get app name
    func getAppName() -> String {
        return Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Odin Signal Collector"
    }
    
    // MARK: - Private Methods
    
    private func loadState() {
        launchCount = UserDefaults.standard.integer(forKey: launchCountKey)
        
        if let timestamp = UserDefaults.standard.object(forKey: lastLaunchDateKey) as? TimeInterval {
            lastLaunchDate = Date(timeIntervalSince1970: timestamp)
        }
    }
    
    private func incrementLaunchCount() {
        launchCount += 1
        UserDefaults.standard.set(launchCount, forKey: launchCountKey)
        print("📊 App launch count: \(launchCount)")
    }
    
    private func updateLastLaunchDate() {
        let now = Date()
        lastLaunchDate = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastLaunchDateKey)
    }
}

// MARK: - App Info Extension

extension OdinSignalCollectorApp {
    
    /// Get app information
    static var appInfo: AppInfo {
        return AppInfo(
            name: Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Odin Signal Collector",
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "com.odinsignalcollector.app"
        )
    }
}

// MARK: - App Info Model

/// Application information
struct AppInfo {
    let name: String
    let version: String
    let build: String
    let bundleIdentifier: String
    
    var versionString: String {
        return "\(version) (\(build))"
    }
    
    var displayName: String {
        return name
    }
}

// MARK: - App Configuration

/// Configuration constants for the application
enum AppConfiguration {
    
    // MARK: - Monitoring
    
    static let defaultMonitoringInterval: TimeInterval = 5.0
    static let minimumMonitoringInterval: TimeInterval = 1.0
    static let maximumMonitoringInterval: TimeInterval = 60.0
    
    // MARK: - History
    
    static let maxHistorySize: Int = 1000
    static let historyRetentionDays: Int = 30
    
    // MARK: - Alerts
    
    static let defaultAlertThreshold: Int = -100 // dBm
    static let alertCooldownInterval: TimeInterval = 60.0 // seconds
    static let maxAlertHistorySize: Int = 100
    
    // MARK: - UI
    
    static let refreshAnimationDuration: TimeInterval = 0.3
    static let chartMaxDataPoints: Int = 100
    
    // MARK: - Network
    
    static let networkTimeoutInterval: TimeInterval = 30.0
    
    // MARK: - Debug
    
    #if DEBUG
    static let isDebugMode: Bool = true
    static let verboseLogging: Bool = true
    #else
    static let isDebugMode: Bool = false
    static let verboseLogging: Bool = false
    #endif
}

// MARK: - App Lifecycle Events

extension OdinSignalCollectorApp {
    
    /// Handle app becoming active
    func handleAppDidBecomeActive() {
        appState.setActive(true)
        print("✓ App became active")
    }
    
    /// Handle app entering background
    func handleAppDidEnterBackground() {
        appState.setActive(false)
        print("✓ App entered background")
    }
    
    /// Handle app will terminate
    func handleAppWillTerminate() {
        print("✓ App will terminate")
    }
}

// MARK: - Environment Values

private struct AppStateKey: EnvironmentKey {
    static let defaultValue: AppState? = nil
}

extension EnvironmentValues {
    var appState: AppState? {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }
}

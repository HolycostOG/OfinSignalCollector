//
//  SignalMonitor.swift
//  OdinSignalCollector
//
//  Core signal monitoring service using native iOS APIs
//

import Foundation
import Combine
import CoreTelephony
import Network
import CoreLocation

// MARK: - Signal Monitor Service

/// Main service for monitoring cellular and network signals
@MainActor
class SignalMonitor: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentSignalData: SignalData?
    @Published var connectionStatus: ConnectionStatus = .unknown
    @Published var monitoringState: MonitoringState = .stopped
    @Published var isMonitoring: Bool = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var monitoringTimer: Timer?
    private let networkInfo = CTTelephonyNetworkInfo()
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.odinsignalcollector.monitor")
    private var locationManager: CLLocationManager?
    
    private var updateInterval: TimeInterval = 5.0 // Update every 5 seconds
    
    // MARK: - Initialization
    
    init() {
        setupNetworkMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring signals
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        monitoringState = .active
        
        // Start network path monitoring
        pathMonitor.start(queue: monitorQueue)
        
        // Start periodic signal updates
        startPeriodicUpdates()
        
        // Request initial signal data
        Task {
            await updateSignalData()
        }
        
        print("✓ Signal monitoring started")
    }
    
    /// Stop monitoring signals
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        monitoringState = .stopped
        
        // Stop network monitoring
        pathMonitor.cancel()
        
        // Stop periodic updates
        stopPeriodicUpdates()
        
        print("✓ Signal monitoring stopped")
    }
    
    /// Pause monitoring
    func pauseMonitoring() {
        guard isMonitoring else { return }
        
        monitoringState = .paused
        stopPeriodicUpdates()
        
        print("⏸ Signal monitoring paused")
    }
    
    /// Resume monitoring
    func resumeMonitoring() {
        guard monitoringState == .paused else { return }
        
        monitoringState = .active
        startPeriodicUpdates()
        
        print("▶ Signal monitoring resumed")
    }
    
    /// Update monitoring interval
    func setUpdateInterval(_ interval: TimeInterval) {
        updateInterval = max(1.0, interval) // Minimum 1 second
        
        if isMonitoring && monitoringState == .active {
            stopPeriodicUpdates()
            startPeriodicUpdates()
        }
    }
    
    /// Force immediate signal update
    func refreshSignalData() async {
        await updateSignalData()
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if path.status == .satisfied {
                    self.connectionStatus = .connected
                } else {
                    self.connectionStatus = .disconnected
                }
                
                if self.isMonitoring && self.monitoringState == .active {
                    await self.updateSignalData()
                }
            }
        }
    }
    
    private func startPeriodicUpdates() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                if self.monitoringState == .active {
                    await self.updateSignalData()
                }
            }
        }
    }
    
    private func stopPeriodicUpdates() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    private func updateSignalData() async {
        let signalData = await collectSignalData()
        self.currentSignalData = signalData
    }
    
    private func collectSignalData() async -> SignalData {
        // Collect cellular information
        let carrier = networkInfo.serviceSubscriberCellularProviders?.first?.value
        let carrierName = carrier?.carrierName
        
        // Get current radio access technology
        let radioTech = networkInfo.serviceCurrentRadioAccessTechnology?.first?.value
        let technology = mapRadioTechnology(radioTech)
        
        // Simulate signal strength (iOS doesn't provide direct API for signal strength in dBm)
        // In a real app, this would require private APIs or carrier-specific implementations
        let signalStrength = simulateSignalStrength()
        
        // Get connection type
        let connectionType = determineConnectionType()
        
        // Get location if available
        let location = getLastKnownLocation()
        
        return SignalData(
            signalStrength: signalStrength,
            technology: technology,
            carrierName: carrierName,
            connectionType: connectionType,
            latitude: location?.latitude,
            longitude: location?.longitude
        )
    }
    
    private func mapRadioTechnology(_ tech: String?) -> String {
        guard let tech = tech else { return NetworkTechnology.unknown.rawValue }
        
        switch tech {
        case CTRadioAccessTechnologyNRNSA,
             CTRadioAccessTechnologyNR:
            return NetworkTechnology.fiveG.rawValue
        case CTRadioAccessTechnologyLTE:
            return NetworkTechnology.lte.rawValue
        case CTRadioAccessTechnologyWCDMA,
             CTRadioAccessTechnologyHSDPA,
             CTRadioAccessTechnologyHSUPA:
            return NetworkTechnology.threeG.rawValue
        case CTRadioAccessTechnologyGPRS,
             CTRadioAccessTechnologyEdge:
            return NetworkTechnology.twoG.rawValue
        default:
            return NetworkTechnology.unknown.rawValue
        }
    }
    
    private func determineConnectionType() -> String {
        // Check if connected and what type
        let path = pathMonitor.currentPath
        
        if path.usesInterfaceType(.wifi) {
            return NetworkTechnology.wifi.rawValue
        } else if path.usesInterfaceType(.cellular) {
            return "Cellular"
        } else if path.usesInterfaceType(.wiredEthernet) {
            return "Ethernet"
        } else {
            return "Unknown"
        }
    }
    
    private func simulateSignalStrength() -> Int? {
        // Since iOS doesn't provide public API for signal strength,
        // we simulate it based on connection quality
        // In a production app, you might use:
        // - Private APIs (not allowed in App Store)
        // - Carrier-specific SDKs
        // - Network performance measurements as proxy
        
        guard connectionStatus == .connected else { return nil }
        
        // Simulate realistic signal strength values
        let baseStrength = Int.random(in: -120...(-50))
        return baseStrength
    }
    
    private func getLastKnownLocation() -> (latitude: Double, longitude: Double)? {
        // Placeholder for location data
        // In a real app, you would integrate CLLocationManager
        return nil
    }
}

// MARK: - Constants

extension CTRadioAccessTechnology {
    static let CTRadioAccessTechnologyNRNSA = "CTRadioAccessTechnologyNRNSA"
    static let CTRadioAccessTechnologyNR = "CTRadioAccessTechnologyNR"
}

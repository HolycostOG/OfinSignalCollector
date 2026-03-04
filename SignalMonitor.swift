//
//  SignalMonitor.swift
//  OdinSignalCollector
//
//  Core signal monitoring service using native iOS APIs.
//
//  Frameworks used:
//    - CoreTelephony                     – radio access technology and carrier information
//    - SystemConfiguration.CaptiveNetwork – Wi-Fi SSID
//    - CoreLocation                       – GPS positioning
//    - Network                            – network path / connection-type detection
//

import Foundation
import Combine
import CoreTelephony
import Network
import CoreLocation
import SystemConfiguration.CaptiveNetwork

// MARK: - Signal Monitor Service

/// Main service for monitoring cellular and network signals.
///
/// Exposes real-time data sourced exclusively from public iOS frameworks,
/// making the implementation suitable for App Store submission.
///
/// ## Permissions required
/// - **Location** – "When In Use" authorization is requested automatically so
///   that ``location`` can be populated and Wi-Fi SSID can be read.
/// - **Access Wi-Fi Information** capability – must be enabled in the Xcode
///   project's Signing & Capabilities pane for ``wifiSSID`` to return a real
///   value.
@MainActor
class SignalMonitor: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// Most recently collected signal snapshot; `nil` before the first poll.
    @Published var currentSignalData: SignalData?

    /// Overall network reachability, updated by `NWPathMonitor`.
    @Published var connectionStatus: ConnectionStatus = .unknown

    /// Lifecycle state of the monitor (active / paused / stopped).
    @Published var monitoringState: MonitoringState = .stopped

    /// `true` while the monitor is running (active or paused).
    @Published var isMonitoring: Bool = false

    /// Human-readable radio access technology, e.g. `"LTE"`, `"5G"`, `"3G"`.
    /// Sourced from `CTTelephonyNetworkInfo.serviceCurrentRadioAccessTechnology`.
    @Published var radioTech: String = "Unknown"

    /// Carrier name from the primary SIM card.
    /// Sourced from `CTCarrier.carrierName`; `"Unknown"` when unavailable.
    @Published var carrierName: String = "Unknown"

    /// SSID of the currently associated Wi-Fi network.
    /// Sourced from `CNCopyCurrentNetworkInfo`; `"Unknown"` when unavailable
    /// or when the required entitlement / location permission is absent.
    @Published var wifiSSID: String = "Unknown"

    /// Wi-Fi received signal strength in dBm.
    /// iOS provides no public API to read Wi-Fi RSSI, so this is always `0`.
    @Published var wifiRSSI: Int = 0

    /// Most recent GPS fix from `CLLocationManager`; `nil` until the first
    /// location update is received.
    @Published var location: CLLocation?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var monitoringTimer: Timer?
    private let networkInfo = CTTelephonyNetworkInfo()
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.odinsignalcollector.monitor")
    private var locationManager: CLLocationManager?

    /// Polling interval in seconds (default 5 s, minimum 1 s).
    private var updateInterval: TimeInterval = 5.0

    // MARK: - Initialization

    override init() {
        super.init()
        setupLocationManager()
        setupNetworkMonitoring()
    }

    deinit {
        monitoringTimer?.invalidate()
        pathMonitor.cancel()
        locationManager?.stopUpdatingLocation()
    }

    // MARK: - Public Methods

    /// Start monitoring signals.
    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        monitoringState = .active

        pathMonitor.start(queue: monitorQueue)
        startPeriodicUpdates()

        Task {
            await updateSignalData()
        }

        print("✓ Signal monitoring started")
    }

    /// Stop monitoring signals.
    func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false
        monitoringState = .stopped

        pathMonitor.cancel()
        stopPeriodicUpdates()

        print("✓ Signal monitoring stopped")
    }

    /// Pause monitoring without fully stopping it.
    func pauseMonitoring() {
        guard isMonitoring else { return }

        monitoringState = .paused
        stopPeriodicUpdates()

        print("⏸ Signal monitoring paused")
    }

    /// Resume a previously paused monitor.
    func resumeMonitoring() {
        guard monitoringState == .paused else { return }

        monitoringState = .active
        startPeriodicUpdates()

        print("▶ Signal monitoring resumed")
    }

    /// Change the polling interval (minimum 1 second).
    func setUpdateInterval(_ interval: TimeInterval) {
        updateInterval = max(1.0, interval)

        if isMonitoring && monitoringState == .active {
            stopPeriodicUpdates()
            startPeriodicUpdates()
        }
    }

    /// Trigger an immediate signal-data refresh.
    func refreshSignalData() async {
        await updateSignalData()
    }

    // MARK: - Private Setup

    /// Configures `CLLocationManager`, requests when-in-use authorization, and
    /// starts updating once permission is granted (handled in the delegate).
    private func setupLocationManager() {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
        locationManager = manager
        manager.requestWhenInUseAuthorization()
    }

    /// Configures `NWPathMonitor` to keep ``connectionStatus`` current and
    /// trigger a signal-data refresh whenever the path changes.
    private func setupNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                self.connectionStatus = path.status == .satisfied ? .connected : .disconnected

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
        let signalData = collectSignalData()
        self.currentSignalData = signalData
    }

    // MARK: - Data Collection

    /// Collects a ``SignalData`` snapshot from real iOS APIs and updates all
    /// relevant `@Published` properties as a side-effect.
    private func collectSignalData() -> SignalData {
        // Capture location once; both this method and the delegate callback
        // run on @MainActor, so no race is possible, but capturing up-front
        // makes the intent explicit.
        let currentLocation = self.location

        let (name, tech) = readCellularInfo()
        let ssid = readWiFiSSID()

        self.carrierName = name
        self.radioTech   = tech
        self.wifiSSID    = ssid
        // wifiRSSI stays 0 — no public iOS API exposes Wi-Fi RSSI.

        return SignalData(
            signalStrength: nil,   // No public API for cellular signal strength in dBm.
            technology: tech,
            carrierName: name == "Unknown" ? nil : name,
            connectionType: determineConnectionType(),
            latitude: currentLocation?.coordinate.latitude,
            longitude: currentLocation?.coordinate.longitude
        )
    }

    /// Returns `(carrierName, radioTech)` sourced from `CTTelephonyNetworkInfo`.
    ///
    /// MCC, MNC, and ISO country code are read from `CTCarrier` and emitted
    /// to the console for diagnostics but are not exposed as published properties.
    private func readCellularInfo() -> (carrierName: String, radioTech: String) {
        let provider = networkInfo.serviceSubscriberCellularProviders?.values.first
        let name     = provider?.carrierName       ?? "Unknown"
        let mcc      = provider?.mobileCountryCode ?? ""
        let mnc      = provider?.mobileNetworkCode ?? ""
        let iso      = provider?.isoCountryCode    ?? ""

        if !mcc.isEmpty {
            print("ℹ Carrier – name: \(name), MCC: \(mcc), MNC: \(mnc), ISO: \(iso)")
        }

        let techConstant = networkInfo.serviceCurrentRadioAccessTechnology?.values.first
        let tech = mapRadioTechnology(techConstant)

        return (name, tech)
    }

    /// Maps a `CTRadioAccessTechnology` constant string to a human-readable label.
    ///
    /// `CTRadioAccessTechnologyNR` and `CTRadioAccessTechnologyNRNSA` are
    /// `@available(iOS 14.1, *)` API symbols (not plain string literals), so the
    /// `#available` guard is required to keep the code compilable on earlier
    /// deployment targets.
    private func mapRadioTechnology(_ tech: String?) -> String {
        guard let tech = tech else { return NetworkTechnology.unknown.rawValue }

        if #available(iOS 14.1, *) {
            if tech == CTRadioAccessTechnologyNR || tech == CTRadioAccessTechnologyNRNSA {
                return NetworkTechnology.fiveG.rawValue
            }
        }

        switch tech {
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

    /// Reads the current Wi-Fi SSID via the `CaptiveNetwork` API.
    ///
    /// Returns `"Unknown"` when:
    /// - The device is not connected to Wi-Fi.
    /// - The "Access Wi-Fi Information" capability is missing.
    /// - Location authorization has not been granted.
    private func readWiFiSSID() -> String {
        guard let interfaces = CNCopySupportedInterfaces() as? [String] else {
            return "Unknown"
        }
        for interface in interfaces {
            if let info = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: AnyObject],
               let ssid = info[kCNNetworkInfoKeySSID as String] as? String {
                return ssid
            }
        }
        return "Unknown"
    }

    private func determineConnectionType() -> String {
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
}

// MARK: - CLLocationManagerDelegate

extension SignalMonitor: CLLocationManagerDelegate {

    /// Responds to authorization changes by starting or stopping location updates.
    ///
    /// This is the recommended pattern from Apple's documentation: call
    /// `requestWhenInUseAuthorization()` in setup and let this callback start
    /// actual updates. The delegate is also invoked immediately when the app
    /// launches if authorization is already granted, ensuring updates start
    /// without any extra logic in `setupLocationManager`. Calling
    /// `startUpdatingLocation()` while updates are already running is a no-op.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            Task { @MainActor [weak self] in
                self?.locationManager?.startUpdatingLocation()
            }
        case .denied, .restricted:
            print("ℹ Location access denied or restricted – GPS and Wi-Fi SSID unavailable")
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    /// Stores the latest GPS fix as ``location``.
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        Task { @MainActor [weak self] in
            self?.location = newLocation
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("✗ Location update failed: \(error.localizedDescription)")
    }
}

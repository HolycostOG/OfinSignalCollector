//
//  SignalTypes.swift
//  OdinSignalCollector
//
//  Core data models and enums for signal monitoring
//

import Foundation
import CoreTelephony
import Network

// MARK: - Signal Strength Levels

/// Signal strength categorization
enum SignalStrength: String, CaseIterable, Identifiable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case noSignal = "No Signal"
    
    var id: String { rawValue }
    
    /// Returns signal strength based on dBm value
    static func from(dBm: Int?) -> SignalStrength {
        guard let dBm = dBm else { return .noSignal }
        
        switch dBm {
        case -70...0:
            return .excellent
        case -85..<(-70):
            return .good
        case -100..<(-85):
            return .fair
        case -120..<(-100):
            return .poor
        default:
            return .noSignal
        }
    }
    
    /// Color representation for UI
    var colorHex: String {
        switch self {
        case .excellent:
            return "#00C851" // Green
        case .good:
            return "#FFD700" // Yellow
        case .fair:
            return "#FF8800" // Orange
        case .poor:
            return "#FF4444" // Red
        case .noSignal:
            return "#666666" // Gray
        }
    }
}

// MARK: - Network Technology Type

/// Network technology types
enum NetworkTechnology: String, CaseIterable, Identifiable {
    case fiveG = "5G"
    case lte = "LTE"
    case fourG = "4G"
    case threeG = "3G"
    case twoG = "2G"
    case wifi = "Wi-Fi"
    case unknown = "Unknown"
    
    var id: String { rawValue }
}

// MARK: - Signal Data Model

/// Complete signal data snapshot
struct SignalData: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let signalStrength: Int? // dBm
    let technology: String
    let carrierName: String?
    let connectionType: String
    let latitude: Double?
    let longitude: Double?
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        signalStrength: Int?,
        technology: String,
        carrierName: String? = nil,
        connectionType: String,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.signalStrength = signalStrength
        self.technology = technology
        self.carrierName = carrierName
        self.connectionType = connectionType
        self.latitude = latitude
        self.longitude = longitude
    }
    
    /// Computed signal strength level
    var strengthLevel: SignalStrength {
        SignalStrength.from(dBm: signalStrength)
    }
    
    /// Human-readable signal description
    var signalDescription: String {
        if let dBm = signalStrength {
            return "\(dBm) dBm (\(strengthLevel.rawValue))"
        }
        return "No signal data"
    }
}

// MARK: - Alert Configuration

/// Alert threshold configuration
struct AlertThreshold: Codable, Equatable {
    var enabled: Bool
    var minimumSignalStrength: Int // dBm threshold
    var alertMessage: String
    
    static let `default` = AlertThreshold(
        enabled: true,
        minimumSignalStrength: -100,
        alertMessage: "Signal strength is below acceptable level"
    )
}

// MARK: - Alert Model

/// Signal alert representation
struct SignalAlert: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let signalData: SignalData
    let message: String
    var acknowledged: Bool
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        signalData: SignalData,
        message: String,
        acknowledged: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.signalData = signalData
        self.message = message
        self.acknowledged = acknowledged
    }
}

// MARK: - Connection Status

/// Current connection status
enum ConnectionStatus: String, CaseIterable {
    case connected = "Connected"
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case unknown = "Unknown"
    
    var colorHex: String {
        switch self {
        case .connected:
            return "#00C851" // Green
        case .disconnected:
            return "#FF4444" // Red
        case .connecting:
            return "#FFD700" // Yellow
        case .unknown:
            return "#666666" // Gray
        }
    }
}

// MARK: - Monitoring State

/// Signal monitoring state
enum MonitoringState: String {
    case active = "Active"
    case paused = "Paused"
    case stopped = "Stopped"
}

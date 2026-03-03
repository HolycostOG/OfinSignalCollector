//
//  SignalHistoryLogger.swift
//  OdinSignalCollector
//
//  Service for logging and managing signal history
//

import Foundation
import Combine

// MARK: - History Logger Service

/// Service responsible for logging and persisting signal history
@MainActor
class SignalHistoryLogger: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var signalHistory: [SignalData] = []
    @Published var isLogging: Bool = false
    
    // MARK: - Private Properties
    
    private let maxHistorySize: Int
    private let persistenceKey = "com.odinsignalcollector.history"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(maxHistorySize: Int = 1000) {
        self.maxHistorySize = maxHistorySize
        loadHistory()
    }
    
    // MARK: - Public Methods
    
    /// Start logging signal data
    func startLogging() {
        isLogging = true
        print("✓ Signal history logging started")
    }
    
    /// Stop logging signal data
    func stopLogging() {
        isLogging = false
        saveHistory()
        print("✓ Signal history logging stopped")
    }
    
    /// Log a new signal data entry
    func logSignal(_ signalData: SignalData) {
        guard isLogging else { return }
        
        signalHistory.insert(signalData, at: 0)
        
        // Maintain maximum history size
        if signalHistory.count > maxHistorySize {
            signalHistory.removeLast()
        }
        
        // Auto-save periodically
        if signalHistory.count % 10 == 0 {
            saveHistory()
        }
    }
    
    /// Get history for a specific time range
    func getHistory(from startDate: Date, to endDate: Date) -> [SignalData] {
        return signalHistory.filter { signal in
            signal.timestamp >= startDate && signal.timestamp <= endDate
        }
    }
    
    /// Get history for the last N hours
    func getRecentHistory(hours: Int) -> [SignalData] {
        let cutoffDate = Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? Date()
        return signalHistory.filter { $0.timestamp >= cutoffDate }
    }
    
    /// Get statistics for logged signals
    func getStatistics() -> SignalStatistics {
        guard !signalHistory.isEmpty else {
            return SignalStatistics(
                totalRecords: 0,
                averageSignalStrength: nil,
                minSignalStrength: nil,
                maxSignalStrength: nil,
                mostCommonTechnology: nil,
                signalDistribution: [:]
            )
        }
        
        let validSignals = signalHistory.compactMap { $0.signalStrength }
        
        let avg = validSignals.isEmpty ? nil : Double(validSignals.reduce(0, +)) / Double(validSignals.count)
        let min = validSignals.min()
        let max = validSignals.max()
        
        // Technology distribution
        let techCounts = Dictionary(grouping: signalHistory, by: { $0.technology })
            .mapValues { $0.count }
        let mostCommon = techCounts.max(by: { $0.value < $1.value })?.key
        
        // Signal strength distribution
        let strengthDistribution = Dictionary(grouping: signalHistory, by: { $0.strengthLevel.rawValue })
            .mapValues { $0.count }
        
        return SignalStatistics(
            totalRecords: signalHistory.count,
            averageSignalStrength: avg,
            minSignalStrength: min,
            maxSignalStrength: max,
            mostCommonTechnology: mostCommon,
            signalDistribution: strengthDistribution
        )
    }
    
    /// Export history as JSON
    func exportHistory() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        guard let jsonData = try? encoder.encode(signalHistory),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        
        return jsonString
    }
    
    /// Clear all history
    func clearHistory() {
        signalHistory.removeAll()
        saveHistory()
        print("✓ Signal history cleared")
    }
    
    /// Clear history older than specified days
    func clearOldHistory(olderThanDays days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let countBefore = signalHistory.count
        
        signalHistory.removeAll { $0.timestamp < cutoffDate }
        
        let removed = countBefore - signalHistory.count
        saveHistory()
        
        print("✓ Removed \(removed) old history entries")
    }
    
    // MARK: - Persistence
    
    private func saveHistory() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(signalHistory)
            UserDefaults.standard.set(data, forKey: persistenceKey)
            print("✓ History saved (\(signalHistory.count) entries)")
        } catch {
            print("✗ Failed to save history: \(error.localizedDescription)")
        }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else {
            print("ℹ No saved history found")
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            signalHistory = try decoder.decode([SignalData].self, from: data)
            print("✓ History loaded (\(signalHistory.count) entries)")
        } catch {
            print("✗ Failed to load history: \(error.localizedDescription)")
            signalHistory = []
        }
    }
}

// MARK: - Signal Statistics

/// Statistical data about logged signals
struct SignalStatistics {
    let totalRecords: Int
    let averageSignalStrength: Double?
    let minSignalStrength: Int?
    let maxSignalStrength: Int?
    let mostCommonTechnology: String?
    let signalDistribution: [String: Int]
    
    var averageSignalStrengthFormatted: String {
        guard let avg = averageSignalStrength else { return "N/A" }
        return String(format: "%.1f dBm", avg)
    }
    
    var signalRangeFormatted: String {
        guard let min = minSignalStrength, let max = maxSignalStrength else {
            return "N/A"
        }
        return "\(min) to \(max) dBm"
    }
}

// MARK: - History Filter Options

/// Filter options for history queries
struct HistoryFilter {
    var startDate: Date?
    var endDate: Date?
    var minSignalStrength: Int?
    var maxSignalStrength: Int?
    var technology: String?
    var strengthLevel: SignalStrength?
}

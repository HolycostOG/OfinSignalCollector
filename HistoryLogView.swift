//
//  HistoryLogView.swift
//  OdinSignalCollector
//
//  View for displaying signal history logs
//

import SwiftUI
import Charts

// MARK: - History Log View

struct HistoryLogView: View {
    
    @ObservedObject var viewModel: SignalDashboardViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTimeRange: TimeRange = .last24Hours
    @State private var showingFilterOptions = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Time Range Picker
                timeRangePicker
                
                // History List
                historyList
            }
            .navigationTitle("Signal History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: exportHistory) {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(role: .destructive, action: clearHistory) {
                            Label("Clear History", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    // MARK: - Time Range Picker
    
    private var timeRangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimeRange.allCases) { range in
                    Button(action: {
                        selectedTimeRange = range
                    }) {
                        Text(range.rawValue)
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedTimeRange == range ? Color.blue : Color(.systemGray6))
                            .foregroundColor(selectedTimeRange == range ? .white : .primary)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - History List
    
    private var historyList: some View {
        List {
            // Statistics Summary
            Section {
                statisticsSummary
            }
            
            // Signal Chart
            if #available(iOS 16.0, *) {
                Section("Signal Trend") {
                    signalChart
                }
            }
            
            // History Entries
            Section("History Log") {
                ForEach(filteredHistory) { signal in
                    historyRow(signal: signal)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Statistics Summary
    
    private var statisticsSummary: some View {
        VStack(spacing: 12) {
            if let stats = viewModel.signalStatistics {
                HStack(spacing: 20) {
                    statCard(
                        title: "Records",
                        value: "\(filteredHistory.count)",
                        icon: "list.bullet"
                    )
                    
                    statCard(
                        title: "Avg Signal",
                        value: stats.averageSignalStrengthFormatted,
                        icon: "antenna.radiowaves.left.and.right"
                    )
                }
                
                HStack(spacing: 20) {
                    statCard(
                        title: "Min",
                        value: stats.minSignalStrength.map { "\($0) dBm" } ?? "N/A",
                        icon: "arrow.down"
                    )
                    
                    statCard(
                        title: "Max",
                        value: stats.maxSignalStrength.map { "\($0) dBm" } ?? "N/A",
                        icon: "arrow.up"
                    )
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Signal Chart
    
    @available(iOS 16.0, *)
    private var signalChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(filteredHistory.reversed()) { signal in
                    if let strength = signal.signalStrength {
                        LineMark(
                            x: .value("Time", signal.timestamp),
                            y: .value("Signal", strength)
                        )
                        .foregroundStyle(Color.blue)
                        
                        AreaMark(
                            x: .value("Time", signal.timestamp),
                            y: .value("Signal", strength)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)")
                                .font(.caption)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
        }
    }
    
    // MARK: - History Row
    
    private func historyRow(signal: SignalData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Signal Strength
                HStack(spacing: 4) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(Color(hex: signal.strengthLevel.colorHex))
                    
                    if let strength = signal.signalStrength {
                        Text("\(strength) dBm")
                            .font(.headline)
                    } else {
                        Text("N/A")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Signal Level Badge
                Text(signal.strengthLevel.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: signal.strengthLevel.colorHex).opacity(0.2))
                    .foregroundColor(Color(hex: signal.strengthLevel.colorHex))
                    .cornerRadius(6)
            }
            
            // Network Info
            HStack(spacing: 12) {
                Label(signal.technology, systemImage: "network")
                    .font(.caption)
                
                Label(signal.connectionType, systemImage: "link")
                    .font(.caption)
                
                if let carrier = signal.carrierName {
                    Label(carrier, systemImage: "simcard")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
            
            // Timestamp
            Text(signal.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Location (if available)
            if let lat = signal.latitude, let lon = signal.longitude {
                Label("\(String(format: "%.4f", lat)), \(String(format: "%.4f", lon))", systemImage: "location")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Computed Properties
    
    private var filteredHistory: [SignalData] {
        let history = viewModel.getRecentHistory(hours: selectedTimeRange.hours)
        
        if searchText.isEmpty {
            return history
        }
        
        return history.filter { signal in
            signal.technology.localizedCaseInsensitiveContains(searchText) ||
            signal.connectionType.localizedCaseInsensitiveContains(searchText) ||
            signal.carrierName?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    // MARK: - Helper Methods
    
    private func exportHistory() {
        guard let jsonString = viewModel.exportHistory() else {
            print("Failed to export history")
            return
        }
        
        // In a real app, this would share/save the file
        print("Exported history:\n\(jsonString)")
    }
    
    private func clearHistory() {
        viewModel.clearHistory()
    }
}

// MARK: - Time Range Enum

enum TimeRange: String, CaseIterable, Identifiable {
    case last1Hour = "1 Hour"
    case last6Hours = "6 Hours"
    case last24Hours = "24 Hours"
    case last7Days = "7 Days"
    case last30Days = "30 Days"
    case all = "All"
    
    var id: String { rawValue }
    
    var hours: Int {
        switch self {
        case .last1Hour: return 1
        case .last6Hours: return 6
        case .last24Hours: return 24
        case .last7Days: return 24 * 7
        case .last30Days: return 24 * 30
        case .all: return Int.max
        }
    }
}

// MARK: - Preview

struct HistoryLogView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryLogView(viewModel: SignalDashboardViewModel())
    }
}

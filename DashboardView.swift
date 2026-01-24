//
//  DashboardView.swift
//  OdinSignalCollector
//
//  Main dashboard view for signal monitoring
//

import SwiftUI

// MARK: - Dashboard View

struct DashboardView: View {
    
    @StateObject private var viewModel = SignalDashboardViewModel()
    @State private var showingSettings = false
    @State private var showingHistory = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Monitoring Controls
                    monitoringControlsSection
                    
                    // Current Signal Status
                    currentSignalSection
                    
                    // Alerts Section
                    if viewModel.hasActiveAlerts {
                        alertsSection
                    }
                    
                    // Statistics Section
                    statisticsSection
                    
                    // Quick Actions
                    quickActionsSection
                }
                .padding()
            }
            .navigationTitle("Odin Signal Collector")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingHistory) {
                HistoryLogView(viewModel: viewModel)
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - Monitoring Controls Section
    
    private var monitoringControlsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Monitoring Status")
                    .font(.headline)
                Spacer()
                
                // Status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.isMonitoring ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                    Text(viewModel.isMonitoring ? "Active" : "Stopped")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Start/Stop Button
            Button(action: {
                viewModel.toggleMonitoring()
            }) {
                HStack {
                    Image(systemName: viewModel.isMonitoring ? "stop.circle.fill" : "play.circle.fill")
                    Text(viewModel.isMonitoring ? "Stop Monitoring" : "Start Monitoring")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isMonitoring ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Current Signal Section
    
    private var currentSignalSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Current Signal")
                    .font(.headline)
                Spacer()
                Button(action: {
                    Task {
                        await viewModel.refreshSignal()
                    }
                }) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            
            if let signal = viewModel.currentSignal {
                VStack(spacing: 12) {
                    // Signal Strength
                    signalStrengthCard(signal: signal)
                    
                    // Network Info
                    networkInfoCard(signal: signal)
                    
                    // Connection Status
                    connectionStatusCard
                }
            } else {
                Text("No signal data available")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func signalStrengthCard(signal: SignalData) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Signal Strength")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let strength = signal.signalStrength {
                    Text("\(strength) dBm")
                        .font(.title2)
                        .bold()
                } else {
                    Text("N/A")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(signal.strengthLevel.rawValue)
                    .font(.headline)
                    .foregroundColor(viewModel.signalStrengthColor)
                
                // Signal strength bars
                signalBarsView(level: signal.strengthLevel)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private func networkInfoCard(signal: SignalData) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                infoRow(label: "Technology", value: signal.technology)
                infoRow(label: "Connection", value: signal.connectionType)
                if let carrier = signal.carrierName {
                    infoRow(label: "Carrier", value: carrier)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private var connectionStatusCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Connection Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(viewModel.connectionStatus.rawValue)
                    .font(.headline)
                    .foregroundColor(viewModel.connectionStatusColor)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .bold()
        }
    }
    
    private func signalBarsView(level: SignalStrength) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Rectangle()
                    .fill(barColor(for: index, level: level))
                    .frame(width: 6, height: CGFloat(8 + index * 3))
            }
        }
    }
    
    private func barColor(for index: Int, level: SignalStrength) -> Color {
        let barCount: Int
        switch level {
        case .excellent: barCount = 5
        case .good: barCount = 4
        case .fair: barCount = 3
        case .poor: barCount = 2
        case .noSignal: barCount = 0
        }
        
        return index < barCount ? viewModel.signalStrengthColor : Color.gray.opacity(0.3)
    }
    
    // MARK: - Alerts Section
    
    private var alertsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Active Alerts")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.activeAlertCount)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            ForEach(viewModel.recentAlerts) { alert in
                alertCard(alert: alert)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func alertCard(alert: SignalAlert) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.message)
                    .font(.subheadline)
                Text(alert.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                viewModel.acknowledgeAlert(alert.id)
            }) {
                Text("OK")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Statistics")
                    .font(.headline)
                Spacer()
            }
            
            if let stats = viewModel.signalStatistics {
                VStack(spacing: 8) {
                    statisticRow(label: "Total Records", value: "\(stats.totalRecords)")
                    statisticRow(label: "Average Signal", value: stats.averageSignalStrengthFormatted)
                    statisticRow(label: "Signal Range", value: stats.signalRangeFormatted)
                    if let tech = stats.mostCommonTechnology {
                        statisticRow(label: "Most Common Tech", value: tech)
                    }
                }
            } else {
                Text("No statistics available")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func statisticRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .bold()
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Quick Actions")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 12) {
                quickActionButton(
                    title: "History",
                    icon: "clock.arrow.circlepath",
                    color: .blue
                ) {
                    showingHistory = true
                }
                
                quickActionButton(
                    title: "Export",
                    icon: "square.and.arrow.up",
                    color: .green
                ) {
                    exportHistory()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func quickActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(8)
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
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var viewModel: SignalDashboardViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Monitoring") {
                    HStack {
                        Text("Update Interval")
                        Spacer()
                        Text("\(Int(viewModel.monitoringInterval))s")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $viewModel.monitoringInterval, in: 1...60, step: 1)
                        .onChange(of: viewModel.monitoringInterval) { newValue in
                            viewModel.updateMonitoringInterval(newValue)
                        }
                }
                
                Section("Alerts") {
                    Toggle("Enable Alerts", isOn: Binding(
                        get: { viewModel.alertsEnabled },
                        set: { _ in viewModel.toggleAlerts() }
                    ))
                    
                    if viewModel.alertsEnabled {
                        HStack {
                            Text("Alert Threshold")
                            Spacer()
                            Text("\(viewModel.alertThreshold) dBm")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: Binding(
                            get: { Double(viewModel.alertThreshold) },
                            set: { viewModel.updateAlertThreshold(Int($0)) }
                        ), in: -120...(-50), step: 5)
                    }
                }
                
                Section("Data") {
                    Button("Clear History") {
                        viewModel.clearHistory()
                    }
                    .foregroundColor(.red)
                    
                    Button("Clear All Alerts") {
                        viewModel.clearAllAlerts()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}

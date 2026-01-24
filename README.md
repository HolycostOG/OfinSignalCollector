# Odin Signal Collector

A comprehensive iOS signal monitoring application built with SwiftUI and clean architecture principles.

## Overview

Odin Signal Collector is a native iOS application designed to monitor, log, and analyze cellular network signal strength in real-time. The app provides detailed insights into signal quality, connection status, and network performance with an intuitive, user-friendly interface.

## Features

### 🔍 Real-Time Signal Monitoring
- Continuous monitoring of cellular signal strength (dBm)
- Real-time network technology detection (5G, LTE, 4G, 3G, 2G, Wi-Fi)
- Connection status tracking
- Carrier information display
- Customizable monitoring intervals (1-60 seconds)

### 📊 Signal History & Analytics
- Persistent storage of signal measurements
- Historical data visualization with interactive charts
- Statistical analysis (average, min, max signal strength)
- Time-range filtering (1 hour to 30 days)
- Export history as JSON

### ⚠️ Smart Alert System
- Configurable signal strength thresholds
- Push notifications for poor signal quality
- Alert cooldown to prevent notification spam
- Alert history tracking
- Customizable alert messages

### 📱 Modern UI/UX
- Clean, intuitive SwiftUI interface
- Real-time signal strength indicators
- Color-coded signal quality visualization
- Signal strength bars animation
- Comprehensive settings panel

## Architecture

The project follows **Clean Architecture** principles with clear separation of concerns:

```
OdinSignalCollector/
├── Models & Types
│   └── SignalTypes.swift           # Core data models and enums
│
├── Services (Business Logic)
│   ├── SignalMonitor.swift         # Signal monitoring service
│   ├── SignalHistoryLogger.swift   # History logging service
│   └── SignalAlertEngine.swift     # Alert management service
│
├── ViewModels
│   └── SignalDashboardViewModel.swift  # Coordinates services and UI
│
├── Views (UI Layer)
│   ├── DashboardView.swift         # Main dashboard interface
│   └── HistoryLogView.swift        # History visualization
│
└── App
    └── OdinSignalCollectorApp.swift  # App entry point

```

### Architecture Highlights

- **Separation of Concerns**: Each module has a single, well-defined responsibility
- **Dependency Injection**: Services are injected into ViewModels
- **Observable Pattern**: Reactive updates using Combine framework
- **Protocol-Oriented**: Extensible and testable design
- **MVVM Pattern**: Clear separation between UI and business logic

## Core Components

### SignalTypes.swift
Defines all data models and enums:
- `SignalStrength`: Categorizes signal quality (Excellent, Good, Fair, Poor, No Signal)
- `NetworkTechnology`: Identifies connection type (5G, LTE, 4G, 3G, 2G, Wi-Fi)
- `SignalData`: Complete signal measurement snapshot
- `SignalAlert`: Alert representation
- `ConnectionStatus`: Current connection state

### SignalMonitor.swift
Core monitoring service:
- Real-time signal data collection using CoreTelephony and Network frameworks
- Periodic updates with configurable intervals
- Start/Stop/Pause/Resume controls
- Network path monitoring
- Signal strength simulation (iOS doesn't provide public API for dBm values)

### SignalHistoryLogger.swift
History management service:
- Persistent storage using UserDefaults
- Automatic data retention management
- Statistical analysis (average, min, max, distribution)
- Time-range queries
- JSON export functionality

### SignalAlertEngine.swift
Alert system:
- Configurable signal strength thresholds
- Push notification support
- Alert cooldown mechanism
- Alert history tracking
- Acknowledgment and dismissal handling

### SignalDashboardViewModel.swift
Main ViewModel coordinating all services:
- Manages service lifecycle
- Reactive data binding
- Settings persistence
- Statistics aggregation
- Centralized state management

### DashboardView.swift
Main UI with:
- Real-time signal display
- Monitoring controls
- Alert notifications
- Quick actions
- Statistics overview
- Settings panel

### HistoryLogView.swift
History visualization with:
- Time-range filtering
- Interactive signal trend charts
- Detailed history logs
- Export functionality
- Search and filtering

## Requirements

- iOS 15.0 or later
- Xcode 13.0 or later
- Swift 5.5 or later

## Installation

1. Clone the repository:
```bash
git clone https://github.com/HolycostOG/OfinSignalCollector.git
cd OfinSignalCollector
```

2. Open the project in Xcode:
```bash
open OdinSignalCollector.xcodeproj
```

3. Build and run on your device or simulator

## Usage

### Starting Monitoring

1. Launch the app
2. Tap "Start Monitoring" on the dashboard
3. The app will begin collecting signal data at the configured interval

### Viewing History

1. Tap the "History" button on the dashboard
2. Select a time range (1 hour, 6 hours, 24 hours, etc.)
3. View signal trends in the chart
4. Scroll through detailed history logs

### Configuring Alerts

1. Tap the settings gear icon
2. Enable "Alerts"
3. Adjust the alert threshold (dBm value)
4. Alerts will trigger when signal drops below threshold

### Exporting Data

1. Navigate to History view
2. Tap the menu icon (•••)
3. Select "Export"
4. History is exported as JSON format

## Configuration

### Default Settings

- **Monitoring Interval**: 5 seconds
- **Alert Threshold**: -100 dBm
- **Max History Size**: 1000 entries
- **Alert Cooldown**: 60 seconds

These can be modified in `AppConfiguration` within `OdinSignalCollectorApp.swift`.

## Technical Details

### Signal Strength Mapping

| dBm Range | Signal Quality | Color |
|-----------|---------------|-------|
| -70 to 0 | Excellent | Green |
| -85 to -70 | Good | Yellow |
| -100 to -85 | Fair | Orange |
| -120 to -100 | Poor | Red |
| Below -120 | No Signal | Gray |

### Network Technologies Supported

- 5G (NR NSA/SA)
- LTE (4G)
- WCDMA/HSDPA/HSUPA (3G)
- GPRS/EDGE (2G)
- Wi-Fi

### Data Persistence

- **Signal History**: UserDefaults (JSON encoded)
- **Settings**: UserDefaults
- **Alert Configuration**: UserDefaults

For production apps, consider using Core Data or SQLite for larger datasets.

## Limitations

### iOS Signal Strength API

iOS does not provide a public API to access actual signal strength in dBm. The current implementation simulates signal values for demonstration purposes. In a production environment, you would need to:

1. Use carrier-specific SDKs (if available)
2. Implement private APIs (not allowed on App Store)
3. Use network performance metrics as proxy indicators
4. Partner with carriers for API access

### Location Services

Location data is prepared but not fully implemented. To enable:

1. Add location permissions to Info.plist
2. Implement CLLocationManager in SignalMonitor
3. Request location authorization

## Future Enhancements

- [ ] Core Data integration for better data management
- [ ] Map view showing signal strength by location
- [ ] Speed test integration
- [ ] Network performance metrics (latency, throughput)
- [ ] Widget support for iOS 14+
- [ ] Apple Watch companion app
- [ ] Cloud sync across devices
- [ ] Advanced analytics and insights
- [ ] Comparison with other carriers
- [ ] Offline mode improvements

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is open source and available under the MIT License.

## Acknowledgments

- Built with SwiftUI and Combine
- Uses CoreTelephony for network information
- Uses Network framework for connectivity monitoring
- Charts powered by Swift Charts (iOS 16+)

## Support

For issues, questions, or contributions, please visit:
- GitHub Issues: https://github.com/HolycostOG/OfinSignalCollector/issues

---

**Note**: This app is designed for educational and monitoring purposes. Signal strength values are simulated due to iOS API limitations. Actual signal strength monitoring requires additional hardware or carrier partnerships.

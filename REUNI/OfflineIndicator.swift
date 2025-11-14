//
//  OfflineIndicator.swift
//  REUNI
//
//  Offline network indicator banner
//

import SwiftUI
import Network
import Combine

// MARK: - Network Monitor
class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    @Published var isConnected: Bool = true
    @Published var connectionType: NWInterface.InterfaceType?

    // Debug mode to manually test offline state
    @Published var isDebugMode: Bool = false
    @Published var debugOffline: Bool = false

    var effectiveConnectionState: Bool {
        isDebugMode ? !debugOffline : isConnected
    }

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type

                if path.status == .satisfied {
                    print("✅ Network connected")
                } else {
                    print("⚠️ Network disconnected")
                }
            }
        }
        monitor.start(queue: queue)
    }

    func toggleDebugOffline() {
        debugOffline.toggle()
        print("🐛 Debug offline mode: \(debugOffline ? "ON" : "OFF")")
    }

    deinit {
        monitor.cancel()
    }
}

// MARK: - Offline Banner View
struct OfflineBanner: View {
    @Bindable var themeManager: ThemeManager
    let isOffline: Bool

    var body: some View {
        if isOffline {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Offline")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                Circle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 4, height: 4)

                Text("Please reconnect to internet")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.red.opacity(0.9), Color.red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 0) {
        OfflineBanner(themeManager: ThemeManager(), isOffline: true)

        Color.blue.opacity(0.1)
            .frame(height: 200)
            .overlay(
                Text("Your Content Here")
                    .font(.headline)
            )
    }
}

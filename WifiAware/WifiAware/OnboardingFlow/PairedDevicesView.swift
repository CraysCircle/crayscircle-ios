//
//  PairedDevicesView.swift
//  WifiAware
//
//  Created by Gurdeep Singh  on 31/07/25.
//

import SwiftUI
import WiFiAware

struct PairedDevicesView: View {
    @State var engine: SimulationEngine
    @State private var pairedDevices: [WAPairedDevice] = []
    @State private var deviceConnectionInfo: [WAPairedDevice: DeviceConnectionInfo] = [:]
    let mode: SimulationEngine.Mode

    var body: some View {
        List(self.pairedDevices) {
            let device: WAPairedDevice = $0
            let isConnected = deviceConnectionInfo[device]?.isConnected ?? false
            NavigationLink {
                ChatDetailView(engine: self.engine, userDetail: device, mode: self.mode)
            } label: {
                HStack {
                    // Show the connection status.
                    Image(systemName: "circle.fill")
                        .foregroundColor(isConnected ? .green : .gray)
                    
                    // Show the device name.
                    Text(device.displayName)
                    
                    Spacer()
                    
                    // Show the transmit latency.
                    if isConnected, let latency = deviceConnectionInfo[device]?.txLatency {
                        Text(String(format: "%.2f ms", latency.milliseconds))
                            .padding([.leading, .trailing], 10)
                            .overlay { RoundedRectangle(cornerRadius: 16).stroke() }
                    }
                    
                    // Show the signal strength.
                    Image(systemName: "wifi", variableValue: deviceConnectionInfo[device]?.signalStrength ?? 0.0)
                        .padding([.leading, .trailing], 10)
                    
                    // Show the disconnect button.
                    Button {
                        Task {
                            await engine.stopConnection(to: device)
                        }
                    } label: {
                        Image(systemName: "stop.circle")
                            .foregroundColor(isConnected ? .red : .gray)
                    }
                    .disabled(!isConnected)
                }
            }
        }
        .task {
            do {
                for try await updatedDeviceList in WAPairedDevice.allDevices {
                    self.pairedDevices = Array(updatedDeviceList.values)
                }
            } catch {
                logger.error("Failed to get paired devices: \(error)")
            }
        }
        .onChange(of: engine.deviceConnections) { _, deviceConnections in
            var perfLog = "Connection performance updates\n"
            for (pairedDevice, connectionDetail) in deviceConnections {
                perfLog += "\(pairedDevice.displayName): \(connectionDetail.performanceReport.display)\n"
            }
            logger.debug("\(deviceConnections.isEmpty ? "No Active Connections" : perfLog)")
            
            self.deviceConnectionInfo = Dictionary(uniqueKeysWithValues: deviceConnections.map { (key: WAPairedDevice, value: ConnectionDetail) in
                return (key, DeviceConnectionInfo(value))
            })
        }
    }
}

struct DeviceConnectionInfo {
    var isConnected: Bool
    var signalStrength: Double?
    var txLatency: Duration?

    init(_ info: ConnectionDetail) {
        isConnected = info.connection.state == .ready
        signalStrength = info.performanceReport.signalStrength
        txLatency = info.performanceReport.transmitLatency[appAccessCategory]?.average
    }
}

extension Duration {
    // Converts the duration to milliseconds.
    var milliseconds: Double {
        return Double(self.components.seconds * 1000) + Double(self.components.attoseconds) / Double(1_000_000_000_000_000)
    }
}

//
//  DeviceDiscoveryPairingView.swift
//  WifiAware
//
//  Created by Gurdeep Singh  on 31/07/25.
//

import DeviceDiscoveryUI
import WiFiAware
import SwiftUI
import Network
import OSLog

struct DeviceDiscoveryPairingView: View {
    let mode: SimulationEngine.Mode

    var body: some View {
        if mode == .viewer {
            DevicePicker(.wifiAware(.connecting(to: .selected([]), from: .simulationService))) { endpoint in
                logger.info("Paired Endpoint: \(endpoint)")
            } label: {
                Image(systemName: "plus")
                Text("Add Device")
            } fallback: {
                Image(systemName: "xmark.circle")
                Text("Unavailable")
            }
            .buttonStyle(.borderedProminent).controlSize(.extraLarge)
            .padding(.trailing,15)
        } else {
            DevicePairingView(.wifiAware(.connecting(to: .simulationService, from: .selected([])))) {
                Image(systemName: "plus")
                Text("Add Device")
            } fallback: {
                Image(systemName: "xmark.circle")
                Text("Unavailable")
            }
            .buttonStyle(.borderedProminent).controlSize(.extraLarge)
            .padding(.trailing,15)
        }
    }
}

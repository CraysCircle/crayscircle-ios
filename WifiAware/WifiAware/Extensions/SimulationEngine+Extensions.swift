//
//  SimulationEngine+Extensions.swift
//  WifiAware
//
//  Created by Gurdeep Singh  on 31/07/25.
//


import WiFiAware
import Network

extension SimulationEngine {
    enum Mode: String, CustomStringConvertible {
        case host = "Host"
        case viewer = "Viewer"

        var description: String {
            self.rawValue
        }
    }

    enum NetworkState {
        case notStarted
        case running
        case stopped

        func description(for mode: Mode, isConnected: Bool) -> String {
            if mode == .viewer && isConnected { return "Connected" }

            switch self {
            case .notStarted, .stopped: return mode == .host ? "Advertise" : "Find & Connect"
            case .running: return mode == .host ? "Stop Advertising" : "Stop Finding"
            }
        }
    }
}

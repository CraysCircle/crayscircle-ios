//
//  NetworkManager.swift
//  WifiAware
//
//  Created by Gurdeep Singh  on 31/07/25.
//



import WiFiAware
import Network
import OSLog
import AccessorySetupKit

actor NetworkManager {
    public let localEvents: AsyncStream<LocalEvent>
    private let localEventsContinuation: AsyncStream<LocalEvent>.Continuation

    public let networkEvents: AsyncStream<NetworkEvent>
    private let networkEventsContinuation: AsyncStream<NetworkEvent>.Continuation

    private let connectionManager: ConnectionManager

    init(connectionManager: ConnectionManager) {
        (self.localEvents, self.localEventsContinuation) = AsyncStream.makeStream(of: LocalEvent.self)
        (self.networkEvents, self.networkEventsContinuation) = AsyncStream.makeStream(of: NetworkEvent.self)

        self.connectionManager = connectionManager
    }

// MARK: - NetworkListener (Publisher)

    func listen() async throws {
        logger.info("Start NetworkListener")

        try await NetworkListener(for:
            .wifiAware(.connecting(to: .simulationService, from: .allPairedDevices)),
        using: .parameters {
            Coder(receiving: NetworkEvent.self, sending: NetworkEvent.self, using: NetworkJSONCoder()) {
                UDP()
            }
        }
        .wifiAware { $0.performanceMode = appPerformanceMode }
        .serviceClass(appServiceClass))
        .onStateUpdate { listener, state in
            logger.info("\(String(describing: listener)): \(String(describing: state))")

            switch state {
            case .setup, .waiting: break
            case .ready: self.localEventsContinuation.yield(.listenerRunning)
            case .failed, .cancelled: self.localEventsContinuation.yield(.listenerStopped)
            default: break
            }
        }
        .run { connection in
            logger.info("Received connection: \(String(describing: connection))")
            await self.connectionManager.add(connection)
        }
    }

// MARK: - NetworkBrowser (Subscriber)

    func browse() async throws {
        logger.info("Start NetworkBrowser")

        var attemptingConnection = false

        try await NetworkBrowser(for:
            .wifiAware(.connecting(to: .allPairedDevices, from: .simulationService))
        )
        .onStateUpdate { browser, state in
            logger.info("\(String(describing: browser)): \(String(describing: state))")

            switch state {
            case .setup, .waiting: break
            case .ready: self.localEventsContinuation.yield(.browserRunning)
            case .failed, .cancelled: self.localEventsContinuation.yield(.browserStopped)
            default: break
            }
        }
        .run { waEndpoints in
            logger.info("Discovered: \(waEndpoints)")
            waEndpoints.forEach { endpoint in
                Task{
                    await self.connectionManager.setupConnection(to: endpoint)
                }
            }
//            if let endpoint = waEndpoints.first, !attemptingConnection {
//                attemptingConnection = true
//                await self.connectionManager.setupConnection(to: endpoint)
//            }
        }
    }

// MARK: - Send

    func send(_ event: NetworkEvent, to connection: WiFiAwareConnection) async {
        await connectionManager.send(event, to: connection)
    }

    func sendToAll(_ event: NetworkEvent) async {
        await connectionManager.sendToAll(event)
    }

// MARK: - Deinit

    deinit {
        localEventsContinuation.finish()
        networkEventsContinuation.finish()
    }
}

public enum NetworkEvent: Codable, Sendable {
    case startStreaming
    case sendMessage(message:String)
}

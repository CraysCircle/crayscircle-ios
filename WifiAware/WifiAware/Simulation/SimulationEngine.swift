//
//  SimulationEngine.swift
//  WifiAware
//
//  Created by Gurdeep Singh  on 31/07/25.
//


import Foundation
import Observation
import SpriteKit
import WiFiAware
import Network
import SwiftUI
import OSLog

@MainActor @Observable class SimulationEngine {
    private let mode: Mode
    var networkState: NetworkState = .notStarted
    var deviceConnections: [WAPairedDevice: ConnectionDetail] = [:]

    private let connectionManager: ConnectionManager
    private let networkManager: NetworkManager

    @ObservationIgnored private var networkTask: Task<Void, Error>?
    @ObservationIgnored private var simulationEventsTask: Task<Void, Error>?
    @ObservationIgnored private var monitorTimer: Timer?
    private let messageStreamContinuation: AsyncStream<Message>.Continuation
    let messageStream: AsyncStream<Message>
    var onMessageReceived: ((Message) -> Void)?
    
    init(mode: Mode) async {
        self.mode = mode

        connectionManager = await ConnectionManager()
        networkManager = NetworkManager(connectionManager: connectionManager)
        var continuation: AsyncStream<Message>.Continuation!
         self.messageStream = AsyncStream<Message> { cont in
             continuation = cont
         }
         self.messageStreamContinuation = continuation

        await withTaskGroup { group in
            group.addTask {
                await self.setupEventProcessing(for: self.networkManager.localEvents)
            }
            group.addTask {
                await self.setupEventProcessing(for: self.networkManager.networkEvents)
            }
            group.addTask {
                await self.setupEventProcessing(for: self.connectionManager.localEvents)
            }
            group.addTask {
                await self.setupEventProcessing(for: self.connectionManager.networkEvents)
            }

            group.cancelAll()
        }

        startConnectionMonitor(interval: 3.0)
    }

    func setupEventProcessing<T>(for stream: AsyncStream<T>) -> Task<Void, Error> {
        return Task {
            for await event in stream {
                if T.self == LocalEvent.self {
                    await processLocalEvent(event as? LocalEvent)
                } else if T.self == NetworkEvent.self {
                    await processNetworkEvent(event as? NetworkEvent)
                }
            }
        }
    }

    func startConnectionMonitor(interval: TimeInterval) {
        monitorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            Task { [weak self] in
                try await self?.connectionManager.monitor()
            }
        }
    }

    func processLocalEvent(_ event: LocalEvent?) async {
        guard let event else { return }

        switch event {
        case .browserRunning, .listenerRunning:
            networkState = .running

        case .browserStopped, .listenerStopped:
            networkState = .stopped

        case .connectionReady(let device, let connectionInfo):
            deviceConnections[device] = connectionInfo
            if mode == .viewer {
                networkTask?.cancel()
                networkTask = nil
                await networkManager.send(.startStreaming, to: connectionInfo.connection)
            }

        case .connectionStopped(let device, let connection):
            deviceConnections.removeValue(forKey: device)
            await connectionManager.invalidate(connection)
            if mode == .viewer {
                networkState = .stopped
            }

        case .connectionPerformanceUpdate(let device, let connectionInfo):
            deviceConnections[device] = connectionInfo
       
        case .sendMessage(let message):
            await networkManager.sendToAll(.sendMessage(message: message))
            break
        }
    }

    func processNetworkEvent(_ event: NetworkEvent?) async {
        guard let event else { return }

        switch event {
        case .startStreaming: logger.info("Received Start streaming")
   
        case .sendMessage(message: let message):
            let newMessage = Message(text: message, isMe: false)
            logger.info("Received message: \(message)")
            onMessageReceived?(newMessage)
            break
        }
    }

    func run() -> Task<Void, Error>? {
        networkTask = Task {
            _ = try await withTaskCancellationHandler {
                switch mode {
                case .host: try await networkManager.listen()
                case .viewer: try await networkManager.browse()
                }
            } onCancel: {
                Task { @MainActor in
                    networkState = .stopped
                }
            }
        }

        return networkTask
    }

    func stopConnection(to device: WAPairedDevice) async {
        if let connection = deviceConnections[device]?.connection {
            await connectionManager.stop(connection)
        } else {
            logger.error("Unable to find the connection for \(device)")
        }
    }

    nonisolated func stopConnectionMonitor() {
        Task { @MainActor in
            self.monitorTimer?.invalidate()
            self.monitorTimer = nil
        }
    }

    deinit {
        self.simulationEventsTask?.cancel()
        self.simulationEventsTask = nil

        self.networkTask?.cancel()
        self.networkTask = nil

        self.stopConnectionMonitor()
    }
}

struct ConnectionDetail: Sendable, Equatable {
    let connection: WiFiAwareConnection
    let performanceReport: WAPerformanceReport

    public static func == (lhs: ConnectionDetail, rhs: ConnectionDetail) -> Bool {
        return lhs.performanceReport.localTimestamp == rhs.performanceReport.localTimestamp
    }
}

enum LocalEvent: Sendable {
    case browserRunning
    case browserStopped

    case listenerRunning
    case listenerStopped

    case connectionReady(WAPairedDevice, ConnectionDetail)
    case connectionStopped(WAPairedDevice, WiFiAwareConnection.ID)
    case connectionPerformanceUpdate(WAPairedDevice, ConnectionDetail)
    case sendMessage(message:String)
}

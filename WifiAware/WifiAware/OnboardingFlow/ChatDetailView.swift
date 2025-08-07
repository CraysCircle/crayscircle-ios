//
//  ChatDetailView.swift
//  WifiAware
//
//  Created by Gurdeep Singh  on 28/07/25.
//

import SwiftUI
import WiFiAware

struct Message: Identifiable {
    let id = UUID()
    let text: String
    let isMe: Bool
}

struct ChatDetailView: View {
    @State private var newMessage: String = ""
    @State var engine: SimulationEngine
    @State private var networkTask: Task<Void, Error>?
    @State private var deviceConnectionInfo: [WAPairedDevice: DeviceConnectionInfo] = [:]
    @State private var messages: [Message] = []

    var userDetail:WAPairedDevice
    let mode: SimulationEngine.Mode

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(self.messages) { message in
                            HStack {
                                if message.isMe { Spacer() }
                                
                                Text(message.text)
                                    .padding()
                                    .background(message.isMe ? Color.blue : Color.gray)
                                    .foregroundColor(message.isMe ? .white : .white)
                                    .cornerRadius(16)
                                    .frame(maxWidth: 250, alignment: message.isMe ? .trailing : .leading)
                                
                                if !message.isMe { Spacer() }
                            }
                            .padding(.horizontal)
                            .id(message.id)
                        }
                    }
                }
                .onChange(of: self.messages.count) { _,_ in
                    if let last =  self.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            
            // Input field
            HStack {
                TextField("Type a message...", text: self.$newMessage)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                
                Button(action: {
                    if !self.newMessage.isEmpty {
                        self.messages.append(Message(text: self.newMessage, isMe: true))
                        Task {
                            await self.engine.processLocalEvent(.sendMessage(message: self.newMessage))
                            self.newMessage = ""
                        }
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image(systemName: "circle.fill")
                        .foregroundColor((self.deviceConnectionInfo[self.userDetail]?.isConnected ?? false) ? .green : .gray)
                    
                    Text(self.userDetail.displayName)
                        .font(.headline)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            self.networkTask = self.engine.run()
            self.engine.onMessageReceived = { message in
                 self.messages.append(message)
             }
        }
        .onDisappear {
            Task {
                await self.engine.stopConnection(to: self.userDetail)
            }
        }
        .onChange(of: self.engine.deviceConnections) { _, deviceConnections in
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


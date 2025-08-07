//
//  ChatListView.swift
//  WifiAware
//
//  Created by Gurdeep Singh  on 28/07/25.
//

import SwiftUI

struct NearbyUser: Identifiable {
    let id = UUID()
    let emoji: String
    let name: String
    let subtitle: String
}

struct ChatListView: View {
    @State var openProfile:Bool = false
    @State private var engine: SimulationEngine?
    @State private var networkTask: Task<Void, Error>?
    let mode: SimulationEngine.Mode

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                if let engine {
                    PairedDevicesView(engine: engine,mode: self.mode)
                    
                    HStack {
                        Spacer()
                        DeviceDiscoveryPairingView(mode: self.mode)
                    }
                }
                else{
                    Text("Wifi aware not available")
                }
            }
            .task {
                if self.engine == nil{
                    self.engine = await .init(mode: self.mode)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: self.$openProfile, destination: {
            ProfileView()
        })
    }
}


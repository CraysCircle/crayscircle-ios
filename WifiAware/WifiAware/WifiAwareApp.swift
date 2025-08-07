//
//  WifiAwareApp.swift
//  WifiAware
//
//  Created by Gurdeep Singh  on 28/07/25.
//

import SwiftUI
import WiFiAware
import OSLog

let logger = Logger(subsystem: "com.example.apple-samplecode.WifiAware", category: "App")

@main
struct WifiAwareApp: App {
    var body: some Scene {
        WindowGroup {
            if WACapabilities.supportedFeatures.contains(.wifiAware) {
                NavigationView {
                    VStack(spacing:15){
                        NavigationLink {
                            ChatListView(mode: .host)
                        } label: {
                            Text("Subscriber")
                                .frame(width: 150,height: 50)
                                .background(Color.blue)
                                .foregroundColor(.white)
                        }
                        
                        NavigationLink {
                            ChatListView(mode: .viewer)
                        } label: {
                            
                            Text("Publiser")
                                .frame(width: 150,height: 50)
                                .background(Color.blue)
                                .foregroundColor(.white)
                        }
                    }
                }
                .navigationBarHidden(true)
            } else {
                ContentUnavailableView {
                    Label("This device does not support Wi-Fi Aware", systemImage: "exclamationmark.octagon")
                }
            }
        }
    }
}

//
//  appPerformanceMode.swift
//  WifiAware
//
//  Created by Gurdeep Singh  on 31/07/25.
//

import WiFiAware
import Network

let appPerformanceMode: WAPerformanceMode = .realtime

let appAccessCategory: WAAccessCategory = .interactiveVideo
let appServiceClass: NWParameters.ServiceClass = appAccessCategory.serviceClass

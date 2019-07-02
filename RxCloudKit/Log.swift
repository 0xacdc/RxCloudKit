//
//  Log.swift
//  RxCloudKit
//
//  Created by Maxim Volgin on 02/11/2017.
//  Copyright (c) RxSwiftCommunity. All rights reserved.
//

import os.log

struct Log {
    fileprivate static let subsystem: String = Bundle.main.bundleIdentifier ?? ""
    
    static let cache = OSLog(subsystem: subsystem, category: "cache")
}

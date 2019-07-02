//
//  Errors.swift
//  RxCloudKit
//
//  Created by Maxim Volgin on 22/06/2017.
//  Copyright (c) RxSwiftCommunity. All rights reserved.
//

import RxSwift

public enum SerializationError: Error {
    case structRequired
    case unknownEntity(name: String)
    case unsupportedSubType(label: String?)
}

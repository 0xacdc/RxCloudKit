//
//  Cloud.swift
//  RxCloudKit
//
//  Created by Maxim Volgin on 10/08/2017.
//  Copyright (c) RxSwiftCommunity. All rights reserved.
//

import RxSwift
import CloudKit

public class Cloud {
    
    public let container: CKContainer
    public let privateDB: CKDatabase
    @available(iOS 10, *)
    public let sharedDB: CKDatabase
    public let publicDB: CKDatabase
    
    public init() {
        self.container = CKContainer.default()
        self.privateDB = container.privateCloudDatabase
        if #available(iOS 10.0, *) {
            self.sharedDB = container.sharedCloudDatabase
        }
        self.publicDB = container.publicCloudDatabase
    }
    
}

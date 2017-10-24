//
//  Cache.swift
//  RxCloudKit
//
//  Created by Maxim Volgin on 10/08/2017.
//  Copyright © 2017 Maxim Volgin. All rights reserved.
//

import RxSwift
import CloudKit

public protocol CacheDelegate {
    func cache(record: CKRecord)
    func deleteCache(for recordID: CKRecordID)
    func deleteCache(in zoneID: CKRecordZoneID)
}

public final class Cache {

    static let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
    static let privateSubscriptionID = "\(appName).privateDatabaseSubscriptionID"
    static let sharedSubscriptionID = "\(appName).sharedDatabaseSubscriptionID"
    static let privateTokenKey = "\(appName).privateDatabaseTokenKey"
    static let sharedTokenKey = "\(appName).sharedDatabaseTokenKey"
    static let zoneTokenMapKey = "\(appName).zoneTokenMapKey"

    public let cloud = Cloud()
    public let zoneIDs: [String]

    private let token = Token()
    private let delegate: CacheDelegate
    private let disposeBag = DisposeBag()
    private var cachedZoneIDs: [CKRecordZoneID] = []
//    private var missingZoneIDs: [CKRecordZoneID] = []

    public init(delegate: CacheDelegate, zoneIDs: [String]) {
        self.delegate = delegate
        self.zoneIDs = zoneIDs
    }

    public func applicationDidFinishLaunching() {

        let zones = zoneIDs.map({ Zone.create(name: $0) })
        cloud.privateDB.rx.modify(recordZonesToSave: zones, recordZoneIDsToDelete: nil).subscribe { event in
            switch event {
            case .success(let (saved, deleted)):
                print("\(saved)")
            case .error(let error):
                print("Error: ", error)
            }
        }.disposed(by: disposeBag)

        let subscription = CKDatabaseSubscription.init(subscriptionID: Cache.privateSubscriptionID)
        let notificationInfo = CKNotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        cloud.privateDB.rx.modify(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil).subscribe { event in
            switch event {
            case .success(let (saved, deleted)):
                print("\(saved)")
            case .error(let error):
                print("Error: ", error)
            }
        }.disposed(by: disposeBag)

        // TODO same for shared

        //let createZoneGroup = DispatchGroup()
        //createZoneGroup.enter()
        //self.createZoneGroup.leave()
//        createZoneGroup.notify(queue: DispatchQueue.global()) {
//        }

    }

    public func applicationDidReceiveRemoteNotification(userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let dict = userInfo as! [String: NSObject]
        guard let notification: CKDatabaseNotification = CKNotification(fromRemoteNotificationDictionary: dict) as? CKDatabaseNotification else { return }
        self.fetchDatabaseChanges(fetchCompletionHandler: completionHandler)
    }

    public func fetchDatabaseChanges(fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let token = self.token.token(for: Cache.privateTokenKey)
        cloud.privateDB.rx.fetchChanges(previousServerChangeToken: token).subscribe { event in
            switch event {
            case .next(let zoneEvent):
                print("\(zoneEvent)")
                
                switch zoneEvent {
                case .changed(let zoneID):
                    print("changed: \(zoneID)")
                    self.cacheChanged(zoneID: zoneID)
                case .deleted(let zoneID):
                    print("deleted: \(zoneID)")
                    self.delegate.deleteCache(in: zoneID)
                case .token(let token):
                    print("token: \(token)")
                    self.token.save(token: token, for: Cache.privateTokenKey)
                    self.processAndPurgeCachedZones(fetchCompletionHandler: completionHandler)
                }
                
            case .error(let error):
                print("Error: ", error)
                completionHandler(.failed)
            case .completed:
                
                if self.cachedZoneIDs.count == 0 {
                    completionHandler(.noData)
                }
                
            }
        }.disposed(by: disposeBag)
    }

    public func fetchZoneChanges(recordZoneIDs: [CKRecordZoneID], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        var optionsByRecordZoneID: [CKRecordZoneID: CKFetchRecordZoneChangesOptions] = [:]

        let tokenMap = self.token.zoneTokenMap(for: Cache.zoneTokenMapKey)
        for recordZoneID in recordZoneIDs {
            if let token = tokenMap[recordZoneID] {
                let options = CKFetchRecordZoneChangesOptions()
                options.previousServerChangeToken = token
                optionsByRecordZoneID[recordZoneID] = options
            }
        }

        cloud.privateDB.rx.fetchChanges(recordZoneIDs: recordZoneIDs, optionsByRecordZoneID: optionsByRecordZoneID).subscribe { event in
            switch event {
            case .next(let recordEvent):
                print("\(recordEvent)")
                
                switch recordEvent {
                case .changed(let record):
                    print("changed: \(record)")
                    self.delegate.cache(record: record)
                case .deleted(let recordID):
                    print("deleted: \(recordID)")
                    self.delegate.deleteCache(for: recordID)
                case .token(let (zoneID, token)):
                    print("token: \(zoneID)->\(token)")
                    self.token.save(zoneID: zoneID, token: token, for: Cache.zoneTokenMapKey)
                }
                
            case .error(let error):
                print("Error: ", error)
                completionHandler(.failed)
            case .completed:
                completionHandler(.newData)
            }
        }.disposed(by: disposeBag)
    }
    
    public func cacheChanged(zoneID: CKRecordZoneID) {
        self.cachedZoneIDs.append(zoneID)
    }
    
    public func processAndPurgeCachedZones(fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let recordZoneIDs = self.cachedZoneIDs
        self.cachedZoneIDs = []
        self.fetchZoneChanges(recordZoneIDs: recordZoneIDs, fetchCompletionHandler: completionHandler)
    }
    
}
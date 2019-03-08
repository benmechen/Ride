//
//  Connection.swift
//  Ride
//
//  Created by Ben Mechen on 19/07/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.

import UIKit
import Crashlytics
import Firebase

class Connection: Equatable {
    static func == (lhs: Connection, rhs: Connection) -> Bool {
        return lhs._connectionUser == rhs._connectionUser
    }
    
    //MARK: Properties
    public var selected: Bool = false
    public var index: NSInteger
    private(set) var _connectionHost: String!
    private(set) var _connectionUser: String!
    private(set) var _userName: String?
    private(set) var _userPhoto: String?
    private(set) var _userCar: [String: Any]?
    
    //MARK: Initialization
    init?(hostId: String, userId: String, name: String, photo: String, car: [String: Any] = [:], index: NSInteger) {
        
        guard !hostId.isEmpty else {
            return nil
        }

        guard !userId.isEmpty else {
            return nil
        }
        
        guard !name.isEmpty else {
            return nil
        }
        
        guard !photo.isEmpty else {
            return nil
        }
        
        self._connectionHost = hostId
        self._connectionUser = userId
        self._userName = name
        self._userPhoto = photo
        self._userCar = car
        self.index = index
    }
    
    public func getCarName() -> String {
        if (self._userCar?.count)! > 0 {
            return self._userCar!["type"] as! String
        }
        
        return ""
    }
}

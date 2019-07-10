//
//  Request.swift
//  Ride
//
//  Created by Ben Mechen on 02/01/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import Foundation
import Crashlytics
import Firebase
import os.log
import MapKit

class Request {
    
    var _id: String? = nil
    var _driver: String!
    var _sender: String!
    var _from: CLLocationCoordinate2D!
    var _fromName: String!
    var _to: CLLocationCoordinate2D!
    var _toName: String!
    var _time: Int!
    var _passengers: Int!
    var new: Bool = false
    var status: Int = 0
    var deleted: Bool = false
    var sent: Int!
    lazy var RideDB = Database.database().reference()
    
    init (id: String? = nil, driver: String, sender: String, from: CLLocationCoordinate2D, fromName: String, to: CLLocationCoordinate2D, toName: String, time: Int, passengers: Int, status: Int, sent: Int? = 0) {
        
        self._id = id
        self._driver = driver
        self._sender = sender
        self._from = from
        self._fromName = fromName
        self._to = to
        self._toName = toName
        self._time = time
        self._passengers = passengers
        self.status = status
        self.sent = sent
    }
    
    public func send(userManager: UserManagerProtocol, completion: @escaping (Bool, String?)->()) {
        userManager.getCurrentUser(completion: { (success, user) in
            guard success && user != nil else {
                return
            }
            let key = self.RideDB.child("Requests").childByAutoId().key
            
            let from: [String: Any] = ["latitude": self._from.latitude, "longitude": self._from.longitude, "name": self._fromName]
            let to: [String: Any] = ["latitude": self._to.latitude, "longitude": self._to.longitude, "name": self._toName]
            
            self.RideDB.child("Users").child(self._driver).child("name").observeSingleEvent(of: .value, with: { snapshot in
                let driver_name = snapshot.value as! String
                
                let request: [String : Any] = ["driver": self._driver,
                                            "driver_name": driver_name,
                                            "sender": self._sender,
                                            "sender_name": user!.name as Any,
                                            "from": from,
                                            "to": to,
                                            "time": self._time,
                                            "passengers": self._passengers,
                                            "status": self.status,
                                            "sent": ServerValue.timestamp(),
                                            "deleted": false]
                
                let childUpdates: [String : Any] = ["/Requests/\(key!)": request]
                
                self.RideDB.updateChildValues(childUpdates, withCompletionBlock: { error, data in
                    if let error = error {
                        os_log("Error updating database: %@", log: OSLog.default, type: .error, error.localizedDescription)
                        print(error.localizedDescription)
                        completion(false, "")
                    } else {
                        completion(true, key!)
                    }
                })
            })
            
            self.RideDB.child("Users").child(self._driver).child("requests").child("received").child(key!).setValue(["timestamp": ServerValue.timestamp(), "new": true])
            self.RideDB.child("Users").child(self._sender).child("requests").child("sent").child(key!).setValue(["timestamp": ServerValue.timestamp(), "new": true])
        })
    }
}

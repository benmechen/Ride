//
//  User
//  Ride
//
//  Created by Ben Mechen on 24/10/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit
import Crashlytics
import Firebase
import os.log
import MapKit

class User {
    
    //MARK: Properties
    let _userID: String
    var _userName: String
    var _userPhotoURL: URL
    var _userCar: Car
    var _userAvailable: [String: Bool]
    var _userLocation: [String: CLLocationDegrees]
    var _userTimestamp: TimeInterval
    
    init? (id: String, name: String, photo: String, car: [String: String], available: [String: Bool], location: [String: CLLocationDegrees], timestamp: TimeInterval) {
        
        var car = car
        //TODO: Validation
        if car["type"] == nil {
            car["type"] = ""
        }
        
        if car["mpg"] == nil {
            car["mpg"] = ""
        }
        
        if car["seats"] == nil {
            car["seats"] = ""
        }
        
        if car["registration"] == nil {
            car["registration"] = ""
        }
        
        _userID = id
        _userName = name
        _userCar = Car(type: car["type"]!, mpg: car["mpg"]!, seats: car["seats"]!, registration: (car["registration"] ?? ""))
        _userPhotoURL = URL(string: photo)!
        _userAvailable = available
        _userLocation = location
        _userTimestamp = timestamp
        
    }
}

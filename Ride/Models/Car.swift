//
//  Car.swift
//  Ride
//
//  Created by Ben Mechen on 24/10/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit
import Firebase
import os.log

class Car {
    
    //MARK: Properties
    var _carType: String
    var _carMPG: String
    var _carSeats: String
    var _carRegistration: String
    
    init (type: String = "", mpg: String = "", seats: String = "", registration: String = "") {
        
        _carType = type
        _carMPG = mpg
        _carSeats = seats
        _carRegistration = registration
        
    }
}

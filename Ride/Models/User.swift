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
import MessageKit

struct User: SenderType {
    let id: String
    let name: String
    let photo: URL!
    let car: Car
    let available: [String: Bool]
    let location: [String: CLLocationDegrees]
    
    // MessageKit Conformation
    var senderId: String
    var displayName: String
}

protocol UserManagerProtocol {
    func getCurrentUser(completion: @escaping (Bool, User?)->())
    func updateCurrentUser()
    func fetch(byID id: String, completion: @escaping (Bool, User?)->())
    func logout()
}

protocol UserManagerClient {
    func setUserManager(_ userManager: UserManagerProtocol)
}

class UserManager: UserManagerProtocol {
    
    //MARK: Properties
    private var userCache = [User]()
    private var references = [DatabaseReference]()
    fileprivate var currentUser: User?
    
    
    // Create current user
    init () {
        guard Auth.auth().currentUser != nil else {
            return
        }
        
        self.fetch(byID: Auth.auth().currentUser!.uid) { (success, user) in
            guard success else {
                return
            }
            
            self.currentUser = user
        }
    }
    
    func getCurrentUser(completion: @escaping (Bool, User?)->()) {
        guard Auth.auth().currentUser?.uid != nil else {
            completion(false, nil)
            return
        }
        
        if self.currentUser == nil {
            self.fetch(byID: Auth.auth().currentUser!.uid) { (success, user) in
                guard success else {
                    return
                }
                
                self.currentUser = user
                completion(true, user)
            }
        }
        
        completion(true, self.currentUser)
    }
    
    func updateCurrentUser() {
        self.fetch(byID: Auth.auth().currentUser!.uid) { (success, user) in
            guard success else {
                return
            }
            
            self.currentUser = user
        }
    }
    
    func logout() {
        self.currentUser = nil
    }
    
    func fetch(byID id: String, completion: @escaping (Bool, User?)->()) {
        let search = self.userCache.filter{$0.id == id}
        if search.count > 0 {
            completion(true, search[0])
            return
        }

        let RideDB = Database.database().reference()
        self.references.append(RideDB)

        RideDB.child("Users").child(id).observe(.value, with: { (snapshot) in
            if var value = snapshot.value as? [String: Any] {
                guard value["name"] != nil && value["photo"] != nil else {
                    completion(false, nil)
                    return
                }

                if value["car"] == nil {
                    value["car"] = ["type": "", "mpg": "", "seats": "", "registration": ""]
                }
                if value["available"] == nil {
                    value["available"] = [:]
                }
                if value["location"] == nil {
                    value["location"] = [:]
                }

                let car = value["car"] as! [String: String]

                let newUser = User(id: id, name: value["name"] as! String, photo: URL(string: value["photo"] as! String)!, car: Car(type: car["type"]  ?? "", mpg: car["mpg"] ?? "", seats: car["seats"] ?? "", registration: car["registration"] ?? ""), available: value["available"] as! [String : Bool], location: value["location"] as! [String : CLLocationDegrees], senderId: id, displayName: value["name"] as! String)
                
                self.userCache.append(newUser)
                
                completion(true, newUser)
            }
        })
    }
    
    deinit {
        for reference in self.references {
            reference.removeAllObservers()
        }
    }
    

}

//var _userID: String
//var _userName: String
//var _userPhotoURL: URL!
//var _userCar: Car
//var _userAvailable: [String: Bool]
//var _userLocation: [String: CLLocationDegrees]
//private var references = [DatabaseReference]()
//static private var currentUserCached: User!
//
//static var currentUser: User {
//    get {
//        guard Auth.auth().currentUser?.uid != nil else {
//            return User(id: "", name: "", photo: "", car: [:], available: [:], location: [:])!
//        }
//
//        if self.currentUserCached != nil && self.currentUserCached._userID == Auth.auth().currentUser?.uid {
//            return self.currentUserCached
//        }
//
//        self.currentUserCached = User(uid: Auth.auth().currentUser!.uid)
//        return self.currentUserCached
//    }
//}
//
//init? (id: String, name: String, photo: String, car: [String: String], available: [String: Bool], location: [String: CLLocationDegrees]) {
//
//    var car = car
//    //TODO: Validation
//    if car["type"] == nil {
//        car["type"] = ""
//    }
//
//    if car["mpg"] == nil {
//        car["mpg"] = ""
//    }
//
//    if car["seats"] == nil {
//        car["seats"] = ""
//    }
//
//    if car["registration"] == nil {
//        car["registration"] = ""
//    }
//
//    _userID = id
//    _userName = name
//    _userCar = Car(type: car["type"]!, mpg: car["mpg"]!, seats: car["seats"]!, registration: (car["registration"] ?? ""))
//    _userPhotoURL = URL(string: photo)!
//    _userAvailable = available
//    _userLocation = location
//
//}
//
//init (uid: String) {
//    let RideDB = Database.database().reference()
//    self.references.append(RideDB)
//    _userID = uid
//    _userName = ""
//    _userCar = Car(type: "", mpg: "", seats: "", registration: "")
//    //        _userPhotoURL = URL(string: "")!
//    _userAvailable = [:]
//    _userLocation = [:]
//
//    RideDB.child("Users").child(uid).observe(.value, with: { (snapshot) in
//        if var value = snapshot.value as? [String: Any] {
//            guard value["name"] != nil && value["photo"] != nil else {
//                return
//            }
//
//            if value["car"] == nil {
//                value["car"] = ["type": "", "mpg": "", "seats": "", "registration": ""]
//            }
//            if value["available"] == nil {
//                value["available"] = [:]
//            }
//            if value["location"] == nil {
//                value["location"] = [:]
//            }
//
//            var car = value["car"] as! [String: String]
//
//            self._userID = uid
//            self._userName = value["name"] as! String
//            self._userCar = Car(type: car["type"]  ?? "", mpg: car["mpg"] ?? "", seats: car["seats"] ?? "", registration: car["registration"] ?? "")
//            self._userPhotoURL = URL(string: value["photo"] as! String)!
//            self._userAvailable = value["available"] as! [String : Bool]
//            self._userLocation = value["location"] as! [String : CLLocationDegrees]
//        }
//    })
//}

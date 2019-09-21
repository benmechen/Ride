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

struct User: SenderType, Equatable {
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }
    
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
    private var currentUserReference: Int?
    
    /// Create current user
    init () {
        guard Auth.auth().currentUser != nil else {
            return
        }
        
        fetch(byID: Auth.auth().currentUser!.uid) { (success, user) in
            guard success else {
                return
            }
            
            self.currentUser = user
            self.watch()
        }
    }
    
    func getCurrentUser(completion: @escaping (Bool, User?)->()) {
        guard Auth.auth().currentUser?.uid != nil else {
            completion(false, nil)
            return
        }
            
        if currentUser == nil {
            print(Auth.auth().currentUser!.uid)
            fetch(byID: Auth.auth().currentUser!.uid) { (success, user) in
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
        fetch(byID: Auth.auth().currentUser!.uid) { (success, user) in
            guard success else {
                return
            }
            
            self.currentUser = user
        }
    }
    
    func logout() {
        currentUser = nil
        userCache.removeAll()
    }
    
    func fetch(byID id: String, completion: @escaping (Bool, User?)->()) {
        /// User cache disabled
//        let search = self.userCache.filter{$0.id == id}
//        if search.count > 0 {
//            completion(true, search[0])
//            return
//        }

        let RideDB = Database.database().reference()
        RideDB.keepSynced(true)
        references.append(RideDB)
        if id == Auth.auth().currentUser!.uid {
            self.currentUserReference = self.references.count - 1
        }

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
    
    /// Watch user for availability updates
    private func watch() {
        let reference = references[currentUserReference ?? 0]
        reference.child("Users").child(currentUser!.id).child("available").observe(.value) { (snapshot) in
            if let value = snapshot.value as? [String: Bool] {
                var available = false
                for group in value.keys {
                    if value[group]! {
                        available = true
                        break
                    }
                }
                
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                
                if available {
                    appDelegate?.updateUserLocation()
                } else {
                    appDelegate?.locationManager.stopUpdatingLocation()
                }
            }
        }
    }
    
    deinit {
        for reference in self.references {
            reference.removeAllObservers()
        }
    }
    

}

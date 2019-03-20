//
//  FBLoginViewController.swift
//  Ride
//
//  Created by Ben Mechen on 08/07/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit
import Crashlytics
import Firebase
import FacebookLogin
import FacebookCore
import WebKit
import os.log

class FBLoginViewController: UIViewController, WKNavigationDelegate {
    
    //MARK: Properties
    @IBOutlet weak var welcome: UILabel!
    @IBOutlet weak var changeLoginMethod: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.welcome.textColor = rideRed
        self.changeLoginMethod.setTitleColor(rideClickableRed, for: .normal)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func loginButtonClicked(_ sender: UIButton) {
        let loginManager = LoginManager()
        loginManager.logIn(readPermissions: [.publicProfile, .userFriends], viewController: self) { loginResult in
            switch loginResult {
            case .failed(let error):
                print("Error: \(error)")
            case .cancelled:
                print("User cancelled login.")
            case .success(let grantedPermissions, let declinedPermissions, let accessToken):
                print(grantedPermissions)
                print(declinedPermissions)
                fbAccessToken = accessToken
                let credential = FacebookAuthProvider.credential(withAccessToken: (fbAccessToken?.authenticationToken)!)
                Auth.auth().signInAndRetrieveData(with: credential, completion: { (user, error) in
                    if let error = error {
                        print(error)
                        return
                    }
                    currentUser = Auth.auth().currentUser
                    
                    if fbAccessToken?.userId != nil && currentUser?.uid != nil {
                        RideDB?.child("IDs").observeSingleEvent(of: .value, with: { (snapshot) in
                            if let value = snapshot.value as? NSDictionary {
                                if value[fbAccessToken?.userId as Any] == nil {
                                    print("Adding user id")
                                    RideDB?.child("IDs").updateChildValues([(fbAccessToken?.userId)!: currentUser?.uid as Any])
                                } else {
                                    print("Entry already exists")
                                }
                            }
                        })
                    } else {
                        //TODO: Sort out whole file
                        moveToLoginController()
                        return
                    }
                    
                    RideDB?.child("Users").observeSingleEvent(of: .value, with: { (snapshot) in
                        if !snapshot.hasChild((currentUser?.uid)!){
                            RideDB?.child("Users").child((currentUser?.uid)!).setValue(["name": currentUser?.displayName as Any, "photo": currentUser?.photoURL?.absoluteString as Any, "car": ["type": "", "mpg": "", "seats": "", "registration": ""]])
                            
                            mainUser = User(id: (currentUser?.uid)!, name: (currentUser?.displayName)!, photo: (currentUser?.photoURL?.absoluteString)!, car: ["type": "", "mpg": "", "seats": "", "registration": ""], available: [:], location: [:], timestamp: 0.0)
                        } else {
                            getMainUser(welcome: true)
                        }
                        self.populateFriends(userId: (fbAccessToken?.userId)!, completion: { success, data in
                            if success {
                                for id in data {
                                    RideDB?.child("Connections").child((currentUser?.uid)!).child(id).setValue(true)
                                }
                            } else {
                                os_log("Error populating friends", log: .default, type: .error)
                            }
                            moveToWelcomeController()
                        })
                    })
                    
                    print("\(String(describing: currentUser)) logged in")
                })
            }
        }
    }
    
    private func populateFriends(userId: String, completion: @escaping (Bool, Array<String>) -> ()) {
        let params = ["fields": "id"]

        let connection = GraphRequestConnection()
        connection.add(GraphRequest(graphPath: "/me/friends", parameters: params)) { httpResponse, result in
            switch result {
            case .success(let response):
                if let userData = response.dictionaryValue {
                    if let ids = userData["data"] as? NSArray {
                        var idArray: Array<String> = Array()
                        var i = 1
                        for idDict in ids {
                            if let id = idDict as? NSDictionary {
                                RideDB?.child("IDs").observeSingleEvent(of: .value, with: { (snapshot) in
                                    let value = snapshot.value as? NSDictionary
                                    if let uid = value?[id["id"] as Any] as? String {
                                        idArray.append(uid)
                                    }
                                    
                                    if i == ids.count {
                                        completion(true, idArray)
                                    }
                                    i += 1
                                })
                            }
                        }
                    }
                }
            case .failed(let error):
                //TODO: Handle error
                print("Graph Request Failed: \(error)")
                completion(false, [])
            }
        }
        connection.start()
    }
}

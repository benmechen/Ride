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
import FacebookCore
import FacebookLogin
import FBSDKLoginKit
import WebKit
import os.log

class FBLoginViewController: UIViewController, WKNavigationDelegate {
    
    //MARK: Properties
    @IBOutlet weak var welcome: UILabel!
    @IBOutlet weak var changeLoginMethod: UIButton!
    
    var userManager: UserManagerProtocol!
    lazy var RideDB = Database.database().reference()
    var vSpinner: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.welcome.textColor = UIColor(named: "Main")
        self.changeLoginMethod.setTitleColor(UIColor(named: "Accent"), for: .normal)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    // MARK: Actions
    
    @IBAction func loginButtonClicked(_ sender: UIButton) {
        vSpinner = self.showSpinner(onView: self.view)
        let loginManager = LoginManager()
//        loginManager.loginBehavior = LoginBehavior.systemAccount
//        loginManager.loginBehavior = FBSDKLoginBehaviorSystemAccount;
        loginManager.logIn(permissions: [.publicProfile, .userFriends], viewController: self) { loginResult in
            print(loginResult)
            
            switch loginResult {
            case .failed(let error):
                print("Error: \(error)")
            case .cancelled:
                print("User cancelled login.")
            case .success(let grantedPermissions, let declinedPermissions, let accessToken):
                print(grantedPermissions)
                print(declinedPermissions)
                let credential = FacebookAuthProvider.credential(withAccessToken: accessToken.tokenString)
                Auth.auth().signIn(with: credential) { (user, error) in
                    if let error = error {
                        print(error)
                        return
                    }
                    
                    if accessToken.userID != nil && Auth.auth().currentUser?.uid != nil {
                        self.RideDB.child("IDs").observeSingleEvent(of: .value, with: { (snapshot) in
                            if let value = snapshot.value as? NSDictionary {
                                if value[accessToken.userID as Any] == nil {
                                    print("Adding user id")
                                    self.RideDB.child("IDs").updateChildValues([(accessToken.userID): Auth.auth().currentUser?.uid as Any])
                                } else {
                                    print("Entry already exists")
                                }
                            }
                        })
                    } else {
                        let alert = UIAlertController(title: "An error occurred. Please try again.", message: "", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                            os_log("Error logging in with Facebook")
                        }))
                        sender.resignFirstResponder()
                        self.removeSpinner(spinner: self.vSpinner!)
                        self.present(alert, animated: true, completion: {
                            self.dismiss(animated: true, completion: nil)
                        })
                        return
                    }
                    
                    self.RideDB.child("Users").observeSingleEvent(of: .value, with: { (snapshot) in
                        if !snapshot.hasChild((Auth.auth().currentUser?.uid)!){
                            self.RideDB.child("Users").child((Auth.auth().currentUser?.uid)!).setValue(["name": Auth.auth().currentUser?.displayName as Any, "photo": Auth.auth().currentUser?.photoURL?.absoluteString as Any, "car": ["type": "", "mpg": "", "seats": "", "registration": ""]])
                        }
                        
                        self.userManager?.getCurrentUser(completion: { (_, _) in })
                        
                        self.populateFriends(userId: (accessToken.userID), completion: { success, data in
                            if success {
                                for id in data {
                                    self.RideDB.child("Connections").child((Auth.auth().currentUser?.uid)!).child(id).setValue(true)
                                    self.RideDB.child("Connections").child(id).child((Auth.auth().currentUser?.uid)!).setValue(true)
                                }
                            } else {
                                os_log("Error populating friends", log: .default, type: .error)
                            }
                            
//                            self.performSegue(withIdentifier: "showMainNav", sender: nil)
                            self.removeSpinner(spinner: self.vSpinner!)
                            moveToWelcomeController()
                        })
                    })
                    
                    print("\(String(describing: Auth.auth().currentUser)) logged in")
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        if segue.identifier == "showEmailLogin" {
            if let navigationViewController = segue.destination as? UINavigationController, let emailLoginViewController = navigationViewController.children.first as? EmailLoginViewController {
                emailLoginViewController.userManager = self.userManager
            }
        }
    }
    
    
    // MARK: Private functions
    
    private func populateFriends(userId: String, completion: @escaping (Bool, Array<String>) -> ()) {
        let params = ["fields": "id"]
        
        let connection = GraphRequestConnection()
        
        connection.add(GraphRequest(graphPath: "/me/friends"), batchParameters: params) { (httpResponse, result, error) in
            if let resultDict = result as? [String: Any], let data = resultDict["data"] as? [[String: String]] {
                var idArray: Array<String> = Array()
                var i = 1
                for idDict in data {
                    if let id = idDict["id"] {
                        self.RideDB.child("IDs").observeSingleEvent(of: .value, with: { (snapshot) in
                            let value = snapshot.value as? NSDictionary
                            if let uid = value?[id] as? String {
                                idArray.append(uid)
                            }
        
                            if i == data.count {
                                completion(true, idArray)
                            }
                            i += 1
                        })
                    }
                }
            }
            
//            switch result {
//            case .success(let response):
//                if let userData = response.dictionaryValue {
//                    if let ids = userData["data"] as? NSArray {
//                    var idArray: Array<String> = Array()
//                    var i = 1
//                    for idDict in ids {
//                        if let id = idDict as? NSDictionary {
//                            self.RideDB.child("IDs").observeSingleEvent(of: .value, with: { (snapshot) in
//                                let value = snapshot.value as? NSDictionary
//                                if let uid = value?[id["id"] as Any] as? String {
//                                    idArray.append(uid)
//                                }
//
//                                if i == ids.count {
//                                    completion(true, idArray)
//                                }
//                                i += 1
//                            })
//                        }
//                    }
//                }
//            }
//            case .failed(let error):
//                //TODO: Handle error
//                print("Graph Request Failed: \(error)")
//                completion(false, [])
//            }
        }
        connection.start()
    }
}

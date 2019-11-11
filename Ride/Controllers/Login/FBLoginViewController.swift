//
//  FBLoginViewController.swift
//  Ride
//
//  Created by Ben Mechen on 08/07/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit
import AuthenticationServices
import Crashlytics
import Firebase
import FirebaseFunctions
import FacebookCore
import FacebookLogin
import FBSDKLoginKit
import WebKit
import os.log

class FBLoginViewController: UIViewController, WKNavigationDelegate {
    
    //MARK: Properties
    @IBOutlet weak var welcome: UILabel!
    @IBOutlet weak var loginStackView: UIStackView!
    @IBOutlet weak var logInCollectionView: UICollectionView!
    @IBOutlet weak var changeLoginMethod: UIButton!
    @IBOutlet weak var disclamerButton: UIButton!
    
    var userManager: UserManagerProtocol!
    lazy var RideDB = Database.database().reference()
    lazy var RideFunctions = Functions.functions()
    var vSpinner: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        logInCollectionView.delegate = self
        logInCollectionView.dataSource = self
        logInCollectionView.frame.size.width = self.view.frame.width
        logInCollectionView.isPrefetchingEnabled = true
        logInCollectionView.clipsToBounds = false
        loginStackView.clipsToBounds = false
        
        self.welcome.textColor = UIColor(named: "Main")
        self.changeLoginMethod.setTitleColor(UIColor(named: "Accent"), for: .normal)
        
        disclamerButton.setAttributedTitle(attributedText(withString: "By creating an account you agree to the Ride Terms and Conditions and Privacy Policy", boldString: "Ride Terms and Conditions and Privacy Policy", font: UIFont.systemFont(ofSize: 14)), for: .normal)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    // MARK: Login Functions
    
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
                self.removeSpinner(spinner: self.vSpinner!)
            case .cancelled:
                print("User cancelled login.")
                self.removeSpinner(spinner: self.vSpinner!)
            case .success(let grantedPermissions, let declinedPermissions, let accessToken):
                print(grantedPermissions)
                print(declinedPermissions)
                let credential = FacebookAuthProvider.credential(withAccessToken: accessToken.tokenString)
                Auth.auth().signIn(with: credential) { (user, error) in
                    if let error = error {
                        print(error)
                        self.removeSpinner(spinner: self.vSpinner!)
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
                            var userDetails = ["name": Auth.auth().currentUser?.displayName as Any, "photo": Auth.auth().currentUser?.photoURL?.absoluteString as Any, "car": ["type": "", "mpg": "", "seats": "", "registration": ""]]
                            
                            let defaults = UserDefaults.standard
                            if let invitedBy = defaults.string(forKey: "invited_by") {
                                userDetails["invited_by"] = invitedBy
                                defaults.set(nil, forKey: "invited_by")
                                
                                self.RideDB.child("Connections").child((Auth.auth().currentUser?.uid)!).child(invitedBy).setValue(true)
                                self.RideDB.child("Connections").child(invitedBy).child((Auth.auth().currentUser?.uid)!).setValue(true)
                            }
                            self.RideDB.child("Users").child((Auth.auth().currentUser?.uid)!).setValue(userDetails)
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
                            self.RideDB.child("Users").child(Auth.auth().currentUser!.uid).child("token").setValue(Messaging.messaging().fcmToken)
                            self.removeSpinner(spinner: self.vSpinner!)
                            moveToWelcomeController()
                        })
                    })
                    
                    print("\(String(describing: Auth.auth().currentUser?.displayName)) logged in")
                }
            }
        }
    }
    
//    func signIn(withCustomToken id: String) {
//        guard id.count > 0 else {
//            return
//        }
//
//        Auth.auth().signIn(withCustomToken: id) { (user, error) in
//            if let error = error {
//                print(error.localizedDescription)
//
//                let alert = UIAlertController(title: "Error", message: "An error occured during sign in, please try again", preferredStyle: .alert)
//                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
//                    os_log("Error logging in with Facebook")
//                }))
//                self.present(alert, animated: true, completion: {
//                    self.dismiss(animated: true, completion: nil)
//                })
//            } else {
//                moveToWelcomeController()
//            }
//        }
//    }
    
    @available(iOS 13.0, *)
    @objc
    func handleAuthorizationAppleIDButtonPress() {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    
    // MARK: - Navigation
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
    
    private func attributedText(withString string: String, boldString: String, font: UIFont) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: string,
                                                         attributes: [NSAttributedString.Key.font: font])
        let boldFontAttribute: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: font.pointSize)]
        let range = (string as NSString).range(of: boldString)
        if #available(iOS 13.0, *) {
            attributedString.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: (string as NSString).range(of: string))
        } else {
            // Fallback on earlier versions
            attributedString.addAttribute(.foregroundColor, value: UIColor.black, range: (string as NSString).range(of: string))
        }
        attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        return attributedString
    }
}

extension FBLoginViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if #available(iOS 13.0, *) {
            return 2
        }
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if #available(iOS 13.0, *) {
            if indexPath.item == 1 {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Apple Login", for: indexPath)
                var style: ASAuthorizationAppleIDButton.Style = .black
                cell.backgroundColor = .black
                if self.traitCollection.userInterfaceStyle == .dark {
                    style = .white
                    cell.backgroundColor = .white
                }
                let appleAuthorizationButton = ASAuthorizationAppleIDButton(authorizationButtonType: .signIn, authorizationButtonStyle: style)
                appleAuthorizationButton.layer.cornerRadius = 0
                appleAuthorizationButton.superview?.cornerRadius = 0
                appleAuthorizationButton.sizeThatFits(cell.layer.frame.size)
                appleAuthorizationButton.layer.frame.size = cell.layer.frame.size
                appleAuthorizationButton.addTarget(self, action: #selector(handleAuthorizationAppleIDButtonPress), for: .touchUpInside)
                cell.addSubview(appleAuthorizationButton)
                return cell
            }
        }
        
        return collectionView.dequeueReusableCell(withReuseIdentifier: "Facebook Login", for: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.layer.frame.size.width - 10, height: 44)
    }
}

@available(iOS 13.0, *)
extension FBLoginViewController: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            print(appleIDCredential)
            let fullNameCreds = appleIDCredential.fullName
            let firstName = fullNameCreds?.givenName ?? "(First name not given)"
            let lastName = fullNameCreds?.familyName ?? "(Last name not given)"
            let fullName = "\(firstName) \(lastName)"
            let email = appleIDCredential.email ?? "(Email not given)"
            let userId = appleIDCredential.user
            
            let params: [String: String] = [
                "fullName": fullName,
                "email": email,
                "userId": userId
            ]
            
            RideFunctions.httpsCallable("getUserTokenForAppleLogIn").call(params) { (result, error) in
                if let error = error as NSError? {
                    print("Token Error: " + error.localizedDescription)
                }
                
                if let token = result?.data as? String {
//                    self.signIn(withCustomToken: token)
                }
            }
            
        } else if let passwordCredential = authorization.credential as? ASPasswordCredential {
            // Sign in using an existing iCloud Keychain credential.
            let username = passwordCredential.user
            let password = passwordCredential.password
            
            // For the purpose of this demo app, show the password credential as an alert.
            DispatchQueue.main.async {
                let message = "The app has received your selected credential from the keychain. \n\n Username: \(username)\n Password: \(password)"
                let alertController = UIAlertController(title: "Keychain Credential Received",
                                                        message: message,
                                                        preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Handle error.
        print(error.localizedDescription)
    }
}

@available(iOS 13.0, *)
extension FBLoginViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }
}

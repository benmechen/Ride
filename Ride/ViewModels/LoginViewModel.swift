//
//  LoginViewModel.swift
//  Ride
//
//  Created by Ben Mechen on 23/11/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import Foundation
import UIKit
import Firebase

class LoginViewModel {
    
    let viewController: UIViewController = LoginViewController()
    var userManager: UserManagerProtocol!

    func login(withService service: LoginServices, completion: @escaping ((Result<Bool>) -> ())) {
            
        switch service {
        case .facebook:
            // Sign in with Facebook
            login(withFacebook: { (result) in
                switch result {
                // Successfully signed in with Facebook, pass to Firebase for Ride account
                case .success(let authCredential):
                    self.login(withCredential: authCredential, service: service) { result in
                        //
                    }
                case .error(let error):
                    completion(.error(error))
                }
            })
        case .apple:
            break
        }

    }
    
    private func login(withFacebook completion: @escaping ((Result<AuthCredential>) -> ())) {
        FacebookLoginService.shared.login(viewController: viewController) { (result) in
            switch result {
            case .success(let loginServiceResponse):
                completion(.success(loginServiceResponse))
            case .error(let error):
                switch error {
                case LoginError.loginServiceCanceled:
                    Analytics.logEvent("Login System", parameters: ["type": "info", "name": "fb_login_canceled", "message": "Facebook login canceled by user"])
                    completion(.error(error))
                case LoginError.loginServiceFail(let errorMessage):
                    Analytics.logEvent("Login System", parameters: ["type": "error", "name": "fb_login_failure", "message": errorMessage])
                    completion(.error(error))
                default:
                    Analytics.logEvent("Login System", parameters: ["type": "error", "name": "fb_login_failure", "message": "Unknown error occured"])
                    completion(.error(LoginError.loginServiceUnknownFailure))
                }
            }
        }
    }
    
    private func login(withCredential credential: AuthCredential, service: LoginServices, completion: @escaping ((Result<AuthCredential>) -> ())) {
        Auth.auth().signIn(with: credential) { (user, error) in
            if let error = error {
                Analytics.logEvent("Login System", parameters: ["type": "error", "name": "firebase_login_failure", "message": error.localizedDescription])
                completion(.error(LoginError.loginServiceFail(error.localizedDescription)))
            }
            
            guard Auth.auth().currentUser != nil && Auth.auth().currentUser?.displayName != nil && Auth.auth().currentUser?.photoURL != nil else {
                Analytics.logEvent("Login System", parameters: ["type": "error", "name": "firebase_login_failure", "message": "Current user not set correctly"])
                completion(.error(LoginError.loginServiceFail("Current user not set")))
                return
            }
            
            let currentUser = Auth.auth().currentUser!
            
            // Add Facebook ID to lookup table
            if service == .facebook {
                guard let userID = FacebookLoginService.shared.accessToken()?.userID else {
                    Analytics.logEvent("Login System", parameters: ["type": "error", "name": "firebase_login_failure", "message": "Access token not set (Facebook)"])
                completion(.error(LoginError.loginServiceFail("Current user not set")))
                    return
                }
                
                guard FacebookLoginService.shared.addUserToLookup(withID: userID, internalID: currentUser.uid) else {
                    Analytics.logEvent("Login System", parameters: ["type": "error", "name": "firebase_login_failure", "message": "Facebook access token user id invalid"])
                    completion(.error(LoginError.loginServiceFail("Facebook access token not set")))
                    return
                }
            }
            
            LoginService.shared.checkUserExists(currentUser.uid) { result in
                if !result {
                    // User doesn't exist, add data
                    switch LoginService.shared.addUserDetails(id: currentUser.uid, name: currentUser.displayName!, photo: currentUser.photoURL!.absoluteString, car: [
                        "type": "",
                        "mpg": "",
                        "seats": "",
                        "registration": ""
                    ]) {
                    case .error(let error):
                        switch error {
                        case LoginError.newUserIDNotSet:
                            Analytics.logEvent("Login System", parameters: ["type": "error", "name": "firebase_signup_failure", "message": "Firebase user id not set"])
                        case LoginError.newUserNameNotSet:
                            Analytics.logEvent("Login System", parameters: ["type": "error", "name": "firebase_signup_failure", "message": "Firebase user name not set"])
                        case LoginError.newUserPhotoNotSet:
                            Analytics.logEvent("Login System", parameters: ["type": "error", "name": "firebase_signup_failure", "message": "Firebase user photo not set"])
                        case LoginError.newUserCarNotSet:
                            Analytics.logEvent("Login System", parameters: ["type": "error", "name": "firebase_signup_failure", "message": "Firebase user car not set"])
                        default:
                            Analytics.logEvent("Login System", parameters: ["type": "error", "name": "firebase_signup_failure", "message": "Unknown firebase sign up error"])
                            
                        }
                        
                        completion(.error(error))
                    default:
                        break
                    }
                    
                    let defaults = UserDefaults.standard
                    if let invitedBy = defaults.string(forKey: "invited_by") {
                        guard invitedBy.count > 0 else {
                            Analytics.logEvent("Login System", parameters: ["type": "error", "name": "firebase_signup_failure", "message": "Invited by user not set"])
                            completion(.error(LoginError.newUserInvitedByNotSet))
                            return
                        }
                        
                        defaults.set(nil, forKey: "invited_by")
                        LoginService.shared.connectUsers(currentUser.uid, invitedBy)
                    }
                    
                   // Connect user's Facebook friends
                    if service == .facebook {
                        guard let userID = FacebookLoginService.shared.accessToken()?.userID else {
                            Analytics.logEvent("Login System", parameters: ["type": "error", "name": "firebase_login_failure", "message": "Access token not set (Facebook)"])
                            completion(.error(LoginError.loginServiceFail("Current user not set")))
                            return
                        }
                        FacebookLoginService.shared.fetchFriends(forUser: userID) { result in
                            switch result {
                            case .error(let error):
                                // Failed, not terminal
                                switch error {
                                case LoginError.newUserIDNotSet:
                                    Analytics.logEvent("Login System", parameters: ["type": "error", "name": "facebook_fetch_friends_error", "message": "ID not given"])
                                case LoginError.facebookGraphRequestFailed(let facebookError):
                                    if facebookError != nil {
                                        Analytics.logEvent("Login System", parameters: ["type": "error", "name": "facebook_fetch_friends_error", "message": facebookError!.localizedDescription])
                                    } else {
                                        Analytics.logEvent("Login System", parameters: ["type": "error", "name": "facebook_fetch_friends_error", "message": "Unknown graph request error"])
                                    }
                                default:
                                    Analytics.logEvent("Login System", parameters: ["type": "error", "name": "facebook_fetch_friends_error", "message": "Unknown fetch friends error"])
                                }
                            case .success(let friends):
                                for friend in friends {
                                    LoginService.shared.connectUsers(currentUser.uid, friend)
                                }
                            }
                        }
                    }
                }
            }
            
            self.userManager?.getCurrentUser(){ (success, _) in
                if success {
                    completion(.success(<#T##AuthCredential#>))
                }
            }
        }
    }
}
